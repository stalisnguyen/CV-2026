#!/usr/bin/env python3
"""Build the public CV site from this source repository.

The public repository should contain only the files GitHub Pages serves.
Comments stay in this source tree and are removed from the published copy.
"""

from __future__ import annotations

import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
# Files the page actually loads. image.jpg is the unused photo master and
# stays in the source repository; the page embeds the photo itself.
PUBLISHED_SUFFIXES = {".html", ".css", ".js", ".png", ".jpg", ".jpeg", ".gif", ".webp", ".svg", ".ico", ".pdf"}


def strip_html_comments(text: str) -> str:
    out: list[str] = []
    i = 0
    while True:
        start = text.find("<!--", i)
        if start < 0:
            out.append(text[i:])
            return "".join(out)
        end = text.find("-->", start + 4)
        if end < 0:
            raise SystemExit("Unclosed HTML comment")
        out.append(text[i:start])
        i = end + 3


def strip_code_comments(text: str, line_comments: bool) -> str:
    """Remove comments without touching quoted strings or https:// URLs."""
    out: list[str] = []
    i = 0
    n = len(text)
    while i < n:
        ch = text[i]
        nxt = text[i + 1] if i + 1 < n else ""
        if ch == "/" and nxt == "*":
            end = text.find("*/", i + 2)
            if end < 0:
                raise SystemExit("Unclosed block comment")
            i = end + 2
            continue
        if line_comments and ch == "/" and nxt == "/":
            end = text.find("\n", i + 2)
            if end < 0:
                break
            i = end
            continue
        if ch in ("'", '"'):
            quote = ch
            out.append(ch)
            i += 1
            while i < n:
                out.append(text[i])
                if text[i] == "\\":
                    i += 1
                    if i < n:
                        out.append(text[i])
                    i += 1
                    continue
                if text[i] == quote:
                    i += 1
                    break
                i += 1
            continue
        out.append(ch)
        i += 1
    return "".join(out)


def publish_html(html: str) -> str:
    pattern = re.compile(
        r"(?is)(<style\b[^>]*>)(.*?)(</style>)|(<script\b[^>]*>)(.*?)(</script>)"
    )
    cursor = 0
    parts: list[str] = []
    for match in pattern.finditer(html):
        parts.append(strip_html_comments(html[cursor:match.start()]))
        if match.group(1) is not None:
            parts.append(match.group(1))
            parts.append(strip_code_comments(match.group(2), line_comments=False))
            parts.append(match.group(3))
        else:
            parts.append(match.group(4))
            parts.append(strip_code_comments(match.group(5), line_comments=True))
            parts.append(match.group(6))
        cursor = match.end()
    parts.append(strip_html_comments(html[cursor:]))
    published = "".join(parts)
    if "<!--" in published or "-->" in published:
        raise SystemExit("Published HTML still contains an HTML comment")
    for match in pattern.finditer(published):
        body = match.group(2) if match.group(1) is not None else match.group(5)
        if "/*" in body or "*/" in body:
            raise SystemExit("Published style or script still contains a block comment")
    return published


def linked_assets(html: str) -> set[str]:
    names = set(re.findall(r'(?:src|href)=["\']([^"\']+)["\']', html))
    local = set()
    for name in names:
        if name.startswith(("http://", "https://", "data:", "mailto:", "tel:", "#")):
            continue
        local.add(name.split("?", 1)[0].split("#", 1)[0])
    return local


def build(dest: Path) -> None:
    source = (ROOT / "index.html").read_text(encoding="utf-8")
    published = publish_html(source)
    if dest.exists():
        shutil.rmtree(dest)
    dest.mkdir(parents=True)
    (dest / "index.html").write_text(published, encoding="utf-8")
    (dest / ".nojekyll").write_text("", encoding="utf-8")

    for asset in sorted(linked_assets(published)):
        src = ROOT / asset
        if not src.is_file():
            raise SystemExit(f"The page links to {asset}, which is not in the source repository")
        if src.suffix.lower() not in PUBLISHED_SUFFIXES:
            raise SystemExit(f"Refusing to publish {asset}")
        target = dest / asset
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, target)

    leaked = []
    for path in dest.rglob("*"):
        if not path.is_file():
            continue
        if path.name == ".nojekyll":
            continue
        if path.suffix.lower() not in PUBLISHED_SUFFIXES:
            leaked.append(path.name)
    if leaked:
        raise SystemExit(f"Public build contains unexpected files: {leaked}")


def main() -> None:
    dest = Path(sys.argv[1] if len(sys.argv) > 1 else "dist")
    if not dest.is_absolute():
        dest = ROOT / dest
    build(dest)
    print(f"Wrote {dest}")


if __name__ == "__main__":
    main()
