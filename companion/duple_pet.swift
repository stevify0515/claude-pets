// Floating desktop pet companion — a Claude Code take on the Codex pets overlay.
// Borderless, transparent, always-on-top window that floats over every app/Space,
// plays in-place idle animations, and shows a status card per active Claude Code
// session (terminal name + what Claude is doing + working/waiting/ready glyph).
//
// Build:  swiftc -O duple_pet.swift -o duple_pet
// Run:    ./duple_pet [--sheet <path>] [--size <points>]
// Quit:   right-click → Tuck Away, press q / ⌘Q, or Ctrl+C in the launching terminal.

import Cocoa
import ImageIO

// MARK: - Atlas (matches references/animation-rows.md)

struct RowDef { let state: String; let row: Int; let durations: [Double] }
let CELL_W = 192, CELL_H = 208

let ROWS: [RowDef] = [
    RowDef(state: "idle",    row: 0, durations: [280, 110, 110, 140, 140, 320]),
    RowDef(state: "waving",  row: 3, durations: [140, 140, 140, 280]),
    RowDef(state: "jumping", row: 4, durations: [140, 140, 140, 140, 280]),
    RowDef(state: "waiting", row: 6, durations: [150, 150, 150, 150, 150, 260]),
    RowDef(state: "review",  row: 8, durations: [150, 150, 150, 150, 150, 280]),
]

let THINKING_VERBS = [
    "Thinking", "Levitating", "Symbioting", "Pondering", "Noodling", "Percolating",
    "Ruminating", "Cogitating", "Marinating", "Conjuring", "Synthesizing", "Mulling",
    "Musing", "Incubating", "Tinkering", "Puzzling", "Spelunking", "Reticulating",
    "Simmering", "Brewing", "Computing", "Wibbling", "Manifesting", "Vibing",
]

// MARK: - Layout

let CONTENT_W: CGFloat = 308
let CARD_W: CGFloat = 300
let GAP: CGFloat = 8
let CARD_PAD: CGFloat = 10
let TITLE_H: CGFloat = 18
let TITLE_GAP: CGFloat = 3
let GLYPH_ROOM: CGFloat = 20
let HANDLE: CGFloat = 18
let TITLE_FONT = NSFont.systemFont(ofSize: 13, weight: .semibold)
let BODY_FONT = NSFont.systemFont(ofSize: 12)

func bodyLineHeight() -> CGFloat { ceil(BODY_FONT.ascender - BODY_FONT.descender + BODY_FONT.leading) }

// MARK: - Args / frames

func parseArgs() -> (sheet: String?, size: CGFloat?) {
    var sheet: String? = nil; var size: CGFloat? = nil
    let a = CommandLine.arguments; var i = 1
    while i < a.count {
        switch a[i] {
        case "--sheet": i += 1; if i < a.count { sheet = a[i] }
        case "--size":  i += 1; if i < a.count { size = CGFloat(Double(a[i]) ?? 120) }
        default: break
        }
        i += 1
    }
    return (sheet, size)
}

func resolveSheet(_ explicit: String?) -> String? {
    if let e = explicit { return (e as NSString).expandingTildeInPath }
    // The active pet is whatever ~/.claude/pets/active points to (set by /hatch-pet or install).
    for c in ["~/.claude/pets/active/spritesheet.webp", "~/.codex/pets/duple/spritesheet.webp"] {
        let p = (c as NSString).expandingTildeInPath
        if FileManager.default.fileExists(atPath: p) { return p }
    }
    return nil
}

func loadFrames(_ path: String) -> (frames: [String: [CGImage]], durations: [String: [Double]])? {
    guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
          let sheet = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
    var frames: [String: [CGImage]] = [:], durations: [String: [Double]] = [:]
    for r in ROWS {
        var cells: [CGImage] = []
        for col in 0..<r.durations.count {
            let rect = CGRect(x: col * CELL_W, y: r.row * CELL_H, width: CELL_W, height: CELL_H)
            if let c = sheet.cropping(to: rect) { cells.append(c) }
        }
        if !cells.isEmpty { frames[r.state] = cells; durations[r.state] = r.durations }
    }
    return frames.isEmpty ? nil : (frames, durations)
}

// MARK: - Saved pet size

func sizePath() -> String { (("~/.claude/pets/.petsize") as NSString).expandingTildeInPath }
func readSavedSize() -> CGFloat? {
    guard let s = try? String(contentsOfFile: sizePath(), encoding: .utf8),
          let v = Double(s.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
    return CGFloat(v)
}
func saveSize(_ v: CGFloat) { try? String(format: "%.0f", Double(v)).write(toFile: sizePath(), atomically: true, encoding: .utf8) }

// MARK: - Status model

struct StatusEntry { let id: String; let title: String; let blurb: String; let state: String; let updated: Double; let iterm: String }

let STATUS_DIR = (("~/.claude/pets/status") as NSString).expandingTildeInPath

func readStatus() -> [StatusEntry] {
    guard let names = try? FileManager.default.contentsOfDirectory(atPath: STATUS_DIR) else { return [] }
    var out: [StatusEntry] = []
    let now = Date().timeIntervalSince1970
    for n in names where n.hasSuffix(".json") {
        let p = (STATUS_DIR as NSString).appendingPathComponent(n)
        guard let data = FileManager.default.contents(atPath: p),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
        let updated = (obj["updated"] as? Double) ?? 0
        if now - updated > 1800 { continue }
        let title = (obj["title"] as? String) ?? ""
        let blurb = (obj["blurb"] as? String) ?? ""
        let state = (obj["state"] as? String) ?? "ready"
        let iterm = (obj["iterm_session"] as? String) ?? ""
        let id = String(n.dropLast(5))
        if title.isEmpty && blurb.isEmpty && state != "working" { continue }
        out.append(StatusEntry(id: id, title: title, blurb: blurb, state: state, updated: updated, iterm: iterm))
    }
    return out.sorted { $0.updated > $1.updated }
}

func dismissStatus(_ id: String) {
    let p = (STATUS_DIR as NSString).appendingPathComponent(id + ".json")
    try? FileManager.default.removeItem(atPath: p)
}

func itermUUID(_ s: String) -> String { s.contains(":") ? String(s.split(separator: ":").last!) : s }

// MARK: - View

final class PetView: NSView {
    var image: CGImage?
    var entries: [StatusEntry] = []
    var petPx: CGFloat = 120
    var spinnerPhase: CGFloat = 0
    var verbIndex: Int = 0
    var hoveringPet = false
    var resizing = false
    var resizeStartMouse = NSPoint.zero
    var resizeStartPet: CGFloat = 120
    weak var controller: PetController?
    override var isFlipped: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }   // one-click

    var petH: CGFloat { petPx * CGFloat(CELL_H) / CGFloat(CELL_W) }

    func blurbText(for e: StatusEntry) -> String {
        if e.blurb.isEmpty && e.state == "working" {
            return THINKING_VERBS[verbIndex % THINKING_VERBS.count] + "…"
        }
        return e.blurb.isEmpty ? "…" : e.blurb
    }

    func blurbHeight(for e: StatusEntry) -> CGFloat {
        let textW = CARD_W - CARD_PAD * 2 - GLYPH_ROOM
        let para = NSMutableParagraphStyle(); para.lineBreakMode = .byWordWrapping
        let b = (blurbText(for: e) as NSString).boundingRect(
            with: NSSize(width: textW, height: 10000),
            options: [.usesLineFragmentOrigin],
            attributes: [.font: BODY_FONT, .paragraphStyle: para])
        let maxH = bodyLineHeight() * 2 + 2          // cap at 2 lines
        return min(ceil(b.height), maxH)
    }

    func cardHeight(for e: StatusEntry) -> CGFloat {
        CARD_PAD + TITLE_H + TITLE_GAP + blurbHeight(for: e) + CARD_PAD
    }

    func contentHeight() -> CGFloat {
        var h = petH
        for e in entries { h += GAP + cardHeight(for: e) }
        return h
    }

    func petRect() -> CGRect { CGRect(x: bounds.width - petPx, y: 0, width: petPx, height: petH) }
    func handleRect() -> CGRect { CGRect(x: bounds.width - HANDLE, y: petH - HANDLE, width: HANDLE, height: HANDLE) }

    // MARK: drawing

    override func draw(_ dirty: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.clear(bounds)

        if let image {
            let r = petRect()
            ctx.saveGState()
            ctx.interpolationQuality = .none
            ctx.translateBy(x: 0, y: r.maxY); ctx.scaleBy(x: 1, y: -1)
            ctx.draw(image, in: CGRect(x: r.minX, y: 0, width: r.width, height: r.height))
            ctx.restoreGState()
        }
        if hoveringPet || resizing { drawResizeHandle() }

        var y = petH + GAP
        for e in entries {
            let h = cardHeight(for: e)
            drawCard(e, at: NSRect(x: bounds.width - CARD_W, y: y, width: CARD_W, height: h))
            y += h + GAP
        }
    }

    func drawResizeHandle() {
        let r = handleRect()
        NSColor(calibratedWhite: 0, alpha: 0.55).setFill()
        NSBezierPath(roundedRect: r, xRadius: 5, yRadius: 5).fill()
        NSColor.white.setStroke()
        let a = NSBezierPath(); a.lineWidth = 1.6; a.lineCapStyle = .round; a.lineJoinStyle = .round
        let lo = NSPoint(x: r.minX + 5, y: r.minY + 5), hi = NSPoint(x: r.maxX - 5, y: r.maxY - 5)
        a.move(to: lo); a.line(to: hi)
        a.move(to: hi); a.line(to: NSPoint(x: hi.x - 5, y: hi.y)); a.move(to: hi); a.line(to: NSPoint(x: hi.x, y: hi.y - 5))
        a.move(to: lo); a.line(to: NSPoint(x: lo.x + 5, y: lo.y)); a.move(to: lo); a.line(to: NSPoint(x: lo.x, y: lo.y + 5))
        a.stroke()
    }

    func drawCard(_ e: StatusEntry, at rect: NSRect) {
        let path = NSBezierPath(roundedRect: rect, xRadius: 12, yRadius: 12)
        NSColor(calibratedWhite: 0.10, alpha: 0.93).setFill(); path.fill()
        NSColor(calibratedWhite: 1, alpha: 0.10).setStroke(); path.lineWidth = 1; path.stroke()

        let textX = rect.minX + CARD_PAD
        let textW = CARD_W - CARD_PAD * 2 - GLYPH_ROOM
        let tpara = NSMutableParagraphStyle(); tpara.lineBreakMode = .byTruncatingTail
        (((e.title.isEmpty ? "Claude Code" : e.title)) as NSString).draw(
            in: NSRect(x: textX, y: rect.minY + CARD_PAD, width: textW, height: TITLE_H),
            withAttributes: [.font: TITLE_FONT, .foregroundColor: NSColor.white, .paragraphStyle: tpara])

        let bpara = NSMutableParagraphStyle(); bpara.lineBreakMode = .byWordWrapping
        (blurbText(for: e) as NSString).draw(
            with: NSRect(x: textX, y: rect.minY + CARD_PAD + TITLE_H + TITLE_GAP, width: textW, height: blurbHeight(for: e)),
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
            attributes: [.font: BODY_FONT, .foregroundColor: NSColor(calibratedWhite: 0.80, alpha: 1), .paragraphStyle: bpara])

        drawGlyph(state: e.state, center: NSPoint(x: rect.maxX - CARD_PAD - 6, y: rect.minY + CARD_PAD + 7))
    }

    func drawGlyph(state: String, center: NSPoint) {
        let r: CGFloat = 6
        switch state {
        case "working":
            NSColor(calibratedRed: 0.40, green: 0.66, blue: 1.0, alpha: 1).setStroke()
            let p = NSBezierPath(); let start = spinnerPhase * 24
            p.appendArc(withCenter: center, radius: r, startAngle: start, endAngle: start + 270)
            p.lineWidth = 2; p.lineCapStyle = .round; p.stroke()
        case "waiting":
            NSColor(calibratedRed: 1.0, green: 0.66, blue: 0.20, alpha: 1).setStroke()
            let c = NSBezierPath(ovalIn: NSRect(x: center.x - r, y: center.y - r, width: 2*r, height: 2*r))
            c.lineWidth = 1.6; c.stroke()
            let h = NSBezierPath()
            h.move(to: center); h.line(to: NSPoint(x: center.x, y: center.y + r - 2))
            h.move(to: center); h.line(to: NSPoint(x: center.x + r - 3, y: center.y))
            h.lineWidth = 1.4; h.lineCapStyle = .round; h.stroke()
        default:
            NSColor(calibratedRed: 0.36, green: 0.83, blue: 0.49, alpha: 1).setStroke()
            let ck = NSBezierPath()   // flipped view: vertex lower, tip higher
            ck.move(to: NSPoint(x: center.x - r + 1, y: center.y))
            ck.line(to: NSPoint(x: center.x - 1, y: center.y + r - 2))
            ck.line(to: NSPoint(x: center.x + r, y: center.y - r + 2))
            ck.lineWidth = 2; ck.lineCapStyle = .round; ck.lineJoinStyle = .round; ck.stroke()
        }
    }

    // MARK: tracking / hover

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways], owner: self, userInfo: nil))
    }
    override func mouseMoved(with e: NSEvent) { updateHover(convert(e.locationInWindow, from: nil)) }
    override func mouseEntered(with e: NSEvent) { updateHover(convert(e.locationInWindow, from: nil)) }
    override func mouseExited(with e: NSEvent) { if hoveringPet { hoveringPet = false; needsDisplay = true } }
    func updateHover(_ p: NSPoint) {
        let h = petRect().contains(p)
        if h != hoveringPet { hoveringPet = h; needsDisplay = true }
    }

    // MARK: clicks

    override func mouseDown(with e: NSEvent) {
        let p = convert(e.locationInWindow, from: nil)
        if handleRect().contains(p) {                       // start diagonal resize
            resizing = true; resizeStartMouse = NSEvent.mouseLocation; resizeStartPet = petPx
            return
        }
        if petRect().contains(p) { window?.performDrag(with: e); return }   // grab pet to move
        var y = petH + GAP                                   // otherwise: which card?
        for entry in entries {
            let h = cardHeight(for: entry)
            if p.y >= y && p.y <= y + h { controller?.openAndDismiss(entry); return }
            y += h + GAP
        }
    }

    override func mouseDragged(with e: NSEvent) {
        guard resizing else { return }
        let cur = NSEvent.mouseLocation
        let delta = (cur.x - resizeStartMouse.x) - (cur.y - resizeStartMouse.y)   // diagonal
        petPx = max(72, min(280, resizeStartPet + delta))
        controller?.layoutWindow(); needsDisplay = true
    }
    override func mouseUp(with e: NSEvent) {
        if resizing { resizing = false; saveSize(petPx) }
    }

    override func rightMouseDown(with e: NSEvent) {
        let m = NSMenu()
        m.addItem(withTitle: "Tuck Away Pet (Quit)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        NSMenu.popUpContextMenu(m, with: e, for: self)
    }
    override func keyDown(with e: NSEvent) { if e.charactersIgnoringModifiers == "q" { NSApp.terminate(nil) } }
}

final class PetWindow: NSWindow { override var canBecomeKey: Bool { true }; override var canBecomeMain: Bool { true } }

// MARK: - Controller

final class PetController: NSObject {
    let window: PetWindow, view: PetView
    let frames: [String: [CGImage]], durations: [String: [Double]]
    var state = "idle", frame = 0
    var frameTimer: Timer?
    var tickCount = 0
    var workingThinkingIds = Set<String>()   // sessions currently in the thinking phase

    init(window: PetWindow, view: PetView, frames: [String: [CGImage]], durations: [String: [Double]]) {
        self.window = window; self.view = view; self.frames = frames; self.durations = durations
        super.init()
        enterRest()
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.tickCount += 1
            self.view.spinnerPhase += 1
            if self.tickCount % 500 == 0 { self.view.verbIndex += 1 }   // rotate verbs ~every 50s
            self.view.needsDisplay = true
        }
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in self?.refreshStatus() }
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in self?.pollFocusDismiss() }
        refreshStatus()
    }

    func render() { if let imgs = frames[state], frame < imgs.count { view.image = imgs[frame]; view.needsDisplay = true } }

    func enterRest() {
        state = "idle"; frame = 0; render()
        let delay = Double.random(in: 2.5...5.0)
        frameTimer?.invalidate()
        frameTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in self?.enterPlay() }
    }
    func enterPlay() {
        let bag = ["idle", "idle", "waving", "jumping", "waiting", "review"]
        let pick = bag.randomElement()!
        state = frames[pick] != nil ? pick : "idle"
        frame = 0; render(); scheduleFrame()
    }
    func scheduleFrame() {
        let ms = durations[state]?[safe: frame] ?? 150
        frameTimer?.invalidate()
        frameTimer = Timer.scheduledTimer(withTimeInterval: ms / 1000.0, repeats: false) { [weak self] _ in self?.advance() }
    }
    func advance() {
        let count = frames[state]?.count ?? 1
        frame += 1
        if frame >= count { enterRest(); return }
        render(); scheduleFrame()
    }

    var lastSig = ""
    func refreshStatus() {
        let entries = readStatus()
        // When a session newly enters the thinking phase, change its verb immediately.
        let thinkingNow = Set(entries.filter { $0.blurb.isEmpty && $0.state == "working" }.map { $0.id })
        if !thinkingNow.subtracting(workingThinkingIds).isEmpty { view.verbIndex += 1; tickCount = 0 }
        workingThinkingIds = thinkingNow

        let sig = entries.map { "\($0.id)|\($0.title)|\($0.blurb)|\($0.state)" }.joined(separator: "~")
        view.entries = entries
        if sig != lastSig { lastSig = sig; layoutWindow() }
        view.needsDisplay = true
    }

    func layoutWindow() {
        let anchorRight = window.frame.maxX, anchorTop = window.frame.maxY
        let newH = view.contentHeight()
        let f = NSRect(x: anchorRight - CONTENT_W, y: anchorTop - newH, width: CONTENT_W, height: newH)
        window.setFrame(f, display: true)
        view.frame = NSRect(origin: .zero, size: f.size)
    }

    func openAndDismiss(_ e: StatusEntry) {
        focusTerminal(e.iterm)
        dismissStatus(e.id)
        refreshStatus()
    }

    func focusTerminal(_ iterm: String) {
        let uuid = itermUUID(iterm)
        let script: String
        if uuid.isEmpty {
            script = "tell application \"iTerm2\" to activate"
        } else {
            script = """
            tell application "iTerm2"
              activate
              repeat with w in windows
                repeat with t in tabs of w
                  repeat with s in sessions of t
                    if (id of s) is "\(uuid)" then
                      select w
                      tell t to select
                      tell s to select
                      return
                    end if
                  end repeat
                end repeat
              end repeat
            end tell
            """
        }
        runOsa(script)
    }

    // Best-effort: when the user views a session's terminal, clear its done/waiting card.
    func pollFocusDismiss() {
        let toCheck = view.entries.filter { $0.state != "working" && !$0.iterm.isEmpty }
        if toCheck.isEmpty { return }
        DispatchQueue.global(qos: .background).async { [weak self] in
            let front = self?.frontmostItermUUID() ?? ""
            if front.isEmpty { return }
            DispatchQueue.main.async {
                guard let self else { return }
                var changed = false
                for e in self.view.entries where e.state != "working" && itermUUID(e.iterm) == front {
                    dismissStatus(e.id); changed = true
                }
                if changed { self.refreshStatus() }
            }
        }
    }

    func frontmostItermUUID() -> String {
        let script = """
        tell application "System Events" to set fp to name of first process whose frontmost is true
        if fp is "iTerm2" then
          tell application "iTerm2" to return id of current session of current tab of current window
        end if
        return ""
        """
        return runOsaCapture(script)
    }

    func runOsa(_ s: String) {
        let t = Process(); t.launchPath = "/usr/bin/osascript"; t.arguments = ["-e", s]; try? t.run()
    }
    func runOsaCapture(_ s: String) -> String {
        let t = Process(); t.launchPath = "/usr/bin/osascript"; t.arguments = ["-e", s]
        let pipe = Pipe(); t.standardOutput = pipe; t.standardError = Pipe()
        do { try t.run() } catch { return "" }
        t.waitUntilExit()
        let d = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: d, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

extension Array { subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil } }

// MARK: - Bootstrap

let opts = parseArgs()
guard let sheetPath = resolveSheet(opts.sheet) else {
    FileHandle.standardError.write("duple_pet: no spritesheet found (pass --sheet)\n".data(using: .utf8)!); exit(1)
}
guard let loaded = loadFrames(sheetPath) else {
    FileHandle.standardError.write("duple_pet: failed to load frames\n".data(using: .utf8)!); exit(1)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let petPx = opts.size ?? readSavedSize() ?? 120
let petH = petPx * CGFloat(CELL_H) / CGFloat(CELL_W)

let sf = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
let margin: CGFloat = 16
let initialFrame = NSRect(x: sf.maxX - CONTENT_W - margin, y: sf.maxY - petH - margin, width: CONTENT_W, height: petH)

let window = PetWindow(contentRect: initialFrame, styleMask: .borderless, backing: .buffered, defer: false)
window.isOpaque = false
window.backgroundColor = .clear
window.hasShadow = false
window.isMovableByWindowBackground = false
window.acceptsMouseMovedEvents = true
window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

let view = PetView(frame: NSRect(origin: .zero, size: initialFrame.size))
view.petPx = petPx
window.contentView = view
window.makeKeyAndOrderFront(nil)

let controller = PetController(window: window, view: view, frames: loaded.frames, durations: loaded.durations)
view.controller = controller

signal(SIGINT, SIG_IGN)
let sigint = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
sigint.setEventHandler { NSApp.terminate(nil) }
sigint.resume()

app.run()
