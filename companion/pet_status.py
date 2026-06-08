#!/usr/bin/env python3
"""Publish this Claude Code session's status for the floating pet overlay.

Invoked from Claude Code hooks (stdin = hook JSON). Writes one file per session to
~/.claude/pets/status/<session_id>.json that the duple_pet overlay polls and renders.

  Header (always): the session's generated name (ai-title / terminal title).
  Blurb: a 1-2 sentence summary of what Claude is currently doing (its latest
         narration), NOT the user's prompt. Empty right after a prompt so the
         overlay shows animated "thinking" verbs until Claude starts narrating.

  UserPromptSubmit         -> state=working, blurb="" (thinking phase)
  PreToolUse / PostToolUse -> state=working, blurb=summary(latest narration)
  Stop                     -> state=ready,   blurb=summary(final message)
  Notification             -> state=waiting, blurb=notification message
  SessionEnd               -> remove the file

Stdlib only; no dependencies.
"""
import sys, json, os, time, re


def collapse(s: str) -> str:
    return " ".join((s or "").split())


def shorten(s: str, n: int) -> str:
    s = collapse(s)
    return s if len(s) <= n else s[: n - 1].rstrip() + "…"


def strip_markdown(s: str) -> str:
    s = re.sub(r"```[\s\S]*?```", " ", s or "")     # code fences
    s = re.sub(r"`([^`]*)`", r"\1", s)               # inline code
    s = re.sub(r"[*_#>~]+", "", s)                    # bold/italic/headers/quotes
    s = re.sub(r"^\s*[-•]\s+", "", s, flags=re.M)     # bullets
    s = re.sub(r"!?\[([^\]]*)\]\([^)]*\)", r"\1", s)  # links/images
    return s


def summarize(text: str, target: int = 210, hardcap: int = 260) -> str:
    """A 2-3 sentence summary of Claude's narration — manager-to-employee style."""
    text = collapse(strip_markdown(text))
    if not text:
        return ""
    parts = re.split(r"(?<=[.!?])\s+", text)
    out = ""
    for p in parts:
        if not out:
            out = p
        elif len(out) < target:
            out = out + " " + p
        else:
            break
    return shorten(out, hardcap)


def done_blurb(title: str) -> str:
    """Friendly, pet-voiced completion line — one short sentence, no emoji."""
    title = collapse(title).rstrip(".!")
    if title and title.lower() not in ("claude code",):
        return f"All done — {title} is wrapped up."
    return "All done — your task is wrapped up."


def _message_text(content) -> str:
    if isinstance(content, str):
        return content.strip()
    if isinstance(content, list):
        out = ""
        for b in content:
            if isinstance(b, dict) and b.get("type") == "text" and b.get("text", "").strip():
                out = b["text"].strip()
        return out
    return ""


def parse_transcript(path: str):
    """Return (ai_title, last_assistant) from a transcript JSONL."""
    ai_title = last_assistant = ""
    if not path or not os.path.exists(path):
        return ai_title, last_assistant
    try:
        with open(path, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    rec = json.loads(line)
                except Exception:
                    continue
                t = rec.get("type")
                if t == "ai-title" and rec.get("aiTitle"):
                    ai_title = rec["aiTitle"]
                elif t == "assistant":
                    txt = _message_text(rec.get("message", {}).get("content"))
                    if txt:
                        last_assistant = txt
    except Exception:
        pass
    return ai_title, last_assistant


def main() -> None:
    try:
        data = json.load(sys.stdin)
    except Exception:
        return
    event = data.get("hook_event_name", "")
    session = data.get("session_id", "")
    if not session:
        return

    d = os.path.expanduser("~/.claude/pets/status")
    os.makedirs(d, exist_ok=True)
    path = os.path.join(d, f"{session}.json")

    if event == "SessionEnd":
        try:
            os.remove(path)
        except FileNotFoundError:
            pass
        return

    st = {}
    if os.path.exists(path):
        try:
            st = json.load(open(path, encoding="utf-8"))
        except Exception:
            st = {}

    st["session_id"] = session
    cwd = data.get("cwd", st.get("cwd", ""))
    st["cwd"] = cwd
    # Capture the terminal session so the overlay can focus it on click.
    iterm = os.environ.get("ITERM_SESSION_ID", "")
    if iterm:
        st["iterm_session"] = iterm

    ai_title, last_assistant = parse_transcript(data.get("transcript_path", ""))
    # Header is ALWAYS the terminal/session name. Fall back to the folder name only
    # until Claude Code generates the title.
    if ai_title:
        st["title"] = shorten(ai_title, 60)
    elif not st.get("title"):
        st["title"] = os.path.basename(cwd) or "Claude Code"

    if event == "UserPromptSubmit":
        st["blurb"] = ""          # thinking phase → overlay shows animated verbs
        st["state"] = "working"
    elif event in ("PreToolUse", "PostToolUse"):
        st["blurb"] = summarize(last_assistant)
        st["state"] = "working"
    elif event == "Stop":
        st["blurb"] = done_blurb(st.get("title", ""))
        st["state"] = "ready"
    elif event == "Notification":
        st["blurb"] = shorten(data.get("message", ""), 200)
        st["state"] = "waiting"
    elif event == "SessionStart":
        st.setdefault("blurb", "")
        st.setdefault("state", "ready")

    st["updated"] = time.time()
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(st, f)
    os.replace(tmp, path)


if __name__ == "__main__":
    main()
