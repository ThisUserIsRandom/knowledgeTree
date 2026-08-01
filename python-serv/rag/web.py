"""Web retrieval: DuckDuckGo search + page crawling (port from execute.py).

Uses ``ddgs`` for search and ``crawl4ai`` for crawling when installed. If
``crawl4ai`` (and its Playwright browsers) is not available the crawler falls
back to a lightweight stdlib HTML-to-text extractor so the pipeline still
works out of the box.
"""

import asyncio
import os
import re
import urllib.request
from html.parser import HTMLParser
from urllib.parse import urlparse


def fetch_duckduckgo_urls(query: str, target_count: int = 4) -> list:
    """Return result URLs for ``query`` via DuckDuckGo (empty on failure)."""
    try:
        from ddgs import DDGS

        with DDGS() as ddgs:
            results = list(ddgs.text(query, max_results=target_count))
        return [item.get("href") for item in results if item.get("href")]
    except Exception:  # pragma: no cover
        return []


async def crawl_and_save_urls(urls, output_dir: str) -> int:
    """Crawl ``urls`` and save each page's markdown/text into ``output_dir``.

    Old crawled files are removed first so a fresh search never retrieves stale
    results (matches the original ``execute.py`` behaviour). Returns the number
    of pages successfully saved.
    """
    if not urls:
        return 0
    os.makedirs(output_dir, exist_ok=True)
    for name in os.listdir(output_dir):
        if name.endswith(".md"):
            os.remove(os.path.join(output_dir, name))

    try:
        from crawl4ai import AsyncWebCrawler, CrawlerRunConfig
        from crawl4ai.content_scraping_strategy import LXMLWebScrapingStrategy

        cfg = CrawlerRunConfig(scraping_strategy=LXMLWebScrapingStrategy(), verbose=False)
        saved = 0
        async with AsyncWebCrawler() as crawler:
            for idx, url in enumerate(urls):
                try:
                    result = await crawler.arun(url=url, config=cfg)
                    if result.success and result.markdown:
                        _save_markdown(url, result.markdown, output_dir, idx)
                        saved += 1
                except Exception:  # pragma: no cover
                    continue
        return saved
    except Exception:  # pragma: no cover - crawl4ai unavailable
        return await _crawl_fallback(urls, output_dir)


async def _crawl_fallback(urls, output_dir: str) -> int:
    saved = 0
    for idx, url in enumerate(urls):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=15) as resp:
                html = resp.read().decode("utf-8", errors="ignore")
            text = _html_to_text(html)
            if text.strip():
                _save_markdown(url, text, output_dir, idx)
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


class _TextExtractor(HTMLParser):
    """Minimal HTML -> text converter (falls back to this when crawl4ai is absent)."""

    def __init__(self):
        super().__init__()
        self._parts = []
        self._skip = False

    def handle_starttag(self, tag, attrs):
        if tag in ("script", "style", "noscript"):
            self._skip = True
        if tag in ("p", "div", "br", "li", "tr", "h1", "h2", "h3", "h4", "h5", "pre"):
            self._parts.append("\n")

    def handle_endtag(self, tag):
        if tag in ("script", "style", "noscript"):
            self._skip = False

    def handle_data(self, data):
        if not self._skip:
            self._parts.append(data)


def _html_to_text(html: str) -> str:
    parser = _TextExtractor()
    parser.feed(html or "")
    text = "".join(parser._parts)
    text = re.sub(r"\n\s*\n+", "\n\n", text)
    return text.strip()


if __name__ == "__main__":  # quick smoke test
    print(fetch_duckduckgo_urls("delhi monsoon 2026"))
