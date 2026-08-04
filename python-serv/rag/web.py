"""Web retrieval: DuckDuckGo search + page crawling (stdlib only).

Uses ``ddgs`` for search and a pure-stdlib HTTP + HTML parser for crawling —
no browser, no ``crawl4ai``/Playwright, and no extra web-scraping dependency.
Pages are fetched concurrently under a small semaphore, each request is
time-boxed, oversized or near-duplicate bodies are dropped, and per-page
failures never abort the rest of the crawl.

HTML is converted to a structured, context-passable markdown (headings, lists
and links preserved) so the RAG retriever can pull meaning from real pages
instead of raw markup or flattened text.
"""

import asyncio
import os
import re
import urllib.request
from html.parser import HTMLParser
from urllib.parse import urlparse

# Guard against pathological pages: cap how much html/text we read and how many
# bytes we keep per page.
MAX_CONTENT_BYTES = 300_000
MIN_KEEP_CHARS = 200
MAX_CONCURRENT = 8
FETCH_TIMEOUT = 15
_RETRIES = 2

_URL_SCHEME_RE = re.compile(r"^https?://", re.I)

# HTML elements treated as block boundaries (add a line break around them).
_BLOCK_TAGS = {
    "p", "div", "br", "li", "tr", "section", "article", "blockquote",
    "pre", "table", "ul", "ol", "dl", "figure",
}
# Elements whose content is chrome/navigation/branding, never prose. Any page
# silently drops these so cookie banners, nav bars and footers don't pollute the
# retrieved context. These are CONTAINERS: they wrap child content, so they need
# matching open/close tags to balance the skip depth.
_SKIP_TAGS = {
    "script", "style", "noscript", "template", "head", "title",
    "nav", "footer", "header", "aside", "form", "svg", "iframe",
    "canvas", "video", "audio", "select",
}
# Void elements (no closing tag) that should simply be ignored when seen —
# <link>, <meta>, <input> etc. never emit an end tag, so they must NOT be part
# of the depth-tracked set above or skip-depth would never balance.
_VOID_SKIP_TAGS = {"meta", "link", "input", "button", "img", "source", "area", "base", "br", "hr"}
_HEADING_TAGS = {"h1", "h2", "h3", "h4", "h5", "h6"}
_LINE_TAGS = _BLOCK_TAGS | _HEADING_TAGS


def fetch_duckduckgo_urls(query: str, target_count: int = 10) -> list:
    """Return de-duplicated, validated result URLs for ``query``.

    Transient DuckDuckGo failures are retried once; invalid or duplicate URLs
    are filtered so the crawler only sees unique http(s) pages.
    """
    urls: list = []
    for _ in range(_RETRIES):
        try:
            from ddgs import DDGS

            with DDGS() as ddgs:
                results = list(ddgs.text(query, max_results=target_count))
            urls = [item.get("href") for item in results if item.get("href")]
            if urls:
                break
        except Exception:  # pragma: no cover
            urls = []
            continue
    seen, out = set(), []
    for u in urls:
        u = (u or "").strip()
        if not _URL_SCHEME_RE.match(u):
            u = "https://" + u.lstrip("/")
        if not _URL_SCHEME_RE.match(u):
            continue
        if u in seen:
            continue
        seen.add(u)
        out.append(u)
    return out[:target_count]


async def crawl_and_save_urls(urls, output_dir: str, clear_dir: bool = True) -> int:
    """Crawl ``urls`` and save each page's markdown/text into ``output_dir``.

    Old crawled files are removed first (when ``clear_dir``) so a fresh search
    never retrieves stale results. Pages are crawled concurrently (bounded by
    ``MAX_CONCURRENT``) and near-identical/empty pages are skipped. Returns the
    number of pages successfully saved.
    """
    if not urls:
        return 0
    os.makedirs(output_dir, exist_ok=True)
    if clear_dir:
        for name in os.listdir(output_dir):
            if name.endswith(".md"):
                os.remove(os.path.join(output_dir, name))

    sem = asyncio.Semaphore(MAX_CONCURRENT)

    def fetch_one(url):
        last = None
        for _ in range(_RETRIES):
            try:
                req = urllib.request.Request(
                    url, headers={"User-Agent": "Mozilla/5.0 (KT-search)"}
                )
                with urllib.request.urlopen(req, timeout=FETCH_TIMEOUT) as resp:
                    # Honour charset if the server tells us; otherwise assume utf-8.
                    encoding = (resp.headers.get_content_charset() or "utf-8")
                    html = resp.read(MAX_CONTENT_BYTES)
                    try:
                        html = html.decode(encoding, errors="ignore")
                    except LookupError:
                        html = html.decode("utf-8", errors="ignore")
                text = _html_to_markdown(html)
                if len(text.strip()) < MIN_KEEP_CHARS:
                    return None
                return _canonical(text), _text(text)
            except Exception as e:  # pragma: no cover
                last = e
        return None

    async def worker(url):
        async with sem:
            return await asyncio.to_thread(fetch_one, url)

    outcomes = await asyncio.gather(*(worker(u) for u in urls), return_exceptions=True)
    seen_bodies = set()
    saved = 0
    for idx, result in enumerate(outcomes):
        if isinstance(result, Exception) or not isinstance(result, tuple):
            continue
        key, text = result
        if key in seen_bodies:
            continue
        seen_bodies.add(key)
        try:
            _save_markdown(urls[idx], text, output_dir, saved)
            saved += 1
        except Exception:  # pragma: no cover
            continue
    return saved


def _save_markdown(url: str, content: str, output_dir: str, idx: int) -> None:
    parsed = urlparse(url)
    domain = parsed.netloc.replace(".", "_") or "unknown"
    filename = f"{idx}_{domain}.md"
    with open(os.path.join(output_dir, filename), "w", encoding="utf-8") as f:
        f.write(content)


class _PageParser(HTMLParser):
    """HTML -> structured markdown converter (no deps).

    Emits headings as ``# …``, list items as ``* …``, block quotes as ``> …``,
    and keeps meaningful links as ``[text](url)`` while dropping navigation and
    branding subtrees entirely.
    """

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self._parts: list = []
        self._skip_depth = 0
        self._link_href = ""
        self._link_wrote = False

    def handle_starttag(self, tag, attrs):
        tag = tag.lower()
        if tag in _VOID_SKIP_TAGS:
            return
        if tag in _SKIP_TAGS:
            self._skip_depth += 1
            return
        if self._skip_depth:
            return
        attr = dict(attrs)
        if tag in _HEADING_TAGS:
            self._parts.append("\n" + "#" * int(tag[1]) + " ")
        elif tag == "a":
            href = (attr.get("href") or "").strip()
            if href and not href.startswith(("#", "javascript:", "mailto:")):
                self._link_href = href
                self._parts.append("[")
            else:
                self._link_href = ""
        elif tag == "li":
            self._parts.append("\n* ")
        elif tag == "blockquote":
            self._parts.append("\n> ")
        elif tag in _BLOCK_TAGS:
            self._parts.append("\n")

    def handle_endtag(self, tag):
        tag = tag.lower()
        if tag in _VOID_SKIP_TAGS:
            return
        if tag in _SKIP_TAGS:
            if self._skip_depth > 0:
                self._skip_depth -= 1
            return
        if self._skip_depth:
            return
        if tag == "a":
            if self._link_href:
                self._parts.append("](%s)" % self._link_href)
            self._link_href = ""
        elif tag in _LINE_TAGS:
            self._parts.append("\n")

    def handle_data(self, data):
        if self._skip_depth or not data:
            return
        self._parts.append(data)


def _html_to_markdown(html: str) -> str:
    """Robustly convert ``html`` into clean, context-passable markdown."""
    parser = _PageParser()
    try:
        parser.feed(html or "")
        parser.close()
    except Exception:  # pragma: no cover - malformed/truncated markup never aborts
        pass
    md = "".join(parser._parts)
    # Collapse horizontal whitespace but preserve paragraph/line structure.
    md = re.sub(r"[ \t]+", " ", md)
    md = re.sub(r" *\n *", "\n", md)
    md = re.sub(r"\n{4,}", "\n\n\n", md)
    return _clean_markdown(md)


def _clean_markdown(md: str) -> str:
    """Trim generated markdown down to the useful block (drop link noise)."""
    lines = []
    for line in (md or "").splitlines():
        stripped = line.strip()
        if not stripped:
            if lines and lines[-1]:
                lines.append("")
            continue
        # Skip pure navigation / link-noise lines that add no prose.
        if re.fullmatch(r"(\[[^\]]*\]\([^)]*\)|[\|\s:▸●#*>\-])*", stripped):
            continue
        lines.append(stripped)
    out = re.sub(r"\n\s*\n+", "\n\n", "\n".join(lines)).strip()
    return out[:MAX_CONTENT_BYTES]


def _canonical(text: str) -> str:
    """Rough normalised signature used to drop near-duplicate pages."""
    words = re.findall(r"[a-z0-9]+", text.lower())
    return " ".join(words[:400])


def _text(text: str) -> str:
    return text[:MAX_CONTENT_BYTES]


if __name__ == "__main__":  # quick smoke test
    print(fetch_duckduckgo_urls("delhi monsoon 2026"))