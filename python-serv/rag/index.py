"""Local retrieval index.

Hierarchical chunking + BM25 for the gateway RAG pipeline. Uses a
structure-aware splitter (paragraph -> line -> sentence -> words) so chunks
never slice a sentence in half, and ranks *parent* chunks by the aggregated
BM25 evidence of all their child chunks (rather than blindly taking the top-N
children) — which retrieves more relevant context without any embeddings.

Files (crawled web pages + uploaded documents) are chunked hierarchically:
parent chunks (~350 words) subdivided into child chunks (~100 words). BM25
ranks child chunks; the best parent chunks are returned as context.
"""

import os
import re

try:  # rank_bm25 is optional at import time; retrieval degrades gracefully.
    from rank_bm25 import BM25Okapi
except Exception:  # pragma: no cover
    BM25Okapi = None

_TXT_EXT = {".txt", ".md", ".markdown", ".text"}
_PDF_EXT = {".pdf"}
_DOCX_EXT = {".docx"}

PARENT_SIZE = 350
CHILD_SIZE = 100
MIN_PARENT_WORDS = 30
MIN_CHILD_WORDS = 5

_PARAGRAPH_BREAK = re.compile(r"\n{2,}")
_SENTENCE_BREAK = re.compile(r"(?<=[.!?])\s+")


def extract_text(path: str) -> str:
    """Return plain text for txt/md/pdf/docx files (empty string otherwise)."""
    ext = os.path.splitext(path)[1].lower()
    if ext in _TXT_EXT:
        try:
            with open(path, "r", encoding="utf-8", errors="ignore") as f:
                return f.read()
        except Exception:  # pragma: no cover
            return ""
    if ext in _PDF_EXT:
        try:
            from pypdf import PdfReader

            reader = PdfReader(path)
            return "\n".join(page.extract_text() or "" for page in reader.pages)
        except Exception:  # pragma: no cover
            return ""
    if ext in _DOCX_EXT:
        try:
            from docx import Document

            doc = Document(path)
            return "\n".join(p.text for p in doc.paragraphs)
        except Exception:  # pragma: no cover
            return ""
    return ""


def _split_with(text: str, max_words: int, separators: tuple) -> list:
    """Split ``text`` into pieces of at most ``max_words`` words, preferring to
    cut at the given structural boundaries before falling back to a hard word
    split, so chunks stay semantically coherent.

    Parent splitting uses only paragraph/line boundaries (never sentences), so
    a long single-paragraph body becomes contiguous ~350-word windows instead
    of hundreds of one-sentence parents.
    """
    text = (text or "").strip()
    words = text.split()
    if not words:
        return []
    if len(words) <= max_words:
        return [text]

    for sep_re in separators:
        pieces = [p.strip() for p in sep_re.split(text) if p.strip()]
        if len(pieces) > 1:
            out = []
            for p in pieces:
                out.extend(_split_with(p, max_words, separators))
            return out

    return [" ".join(words[i : i + max_words]) for i in range(0, len(words), max_words)]


def _split_parents(text: str) -> list:
    return _split_with(text, PARENT_SIZE, (_PARAGRAPH_BREAK, re.compile(r"\n")))


def _split_children(text: str) -> list:
    return _split_with(text, CHILD_SIZE, (_SENTENCE_BREAK,))


def chunk_hierarchical(text: str) -> dict:
    """Chunk ``text`` into child->parent chunks (deduplicated per parent).

    Tiny structural fragments (headlines, nav lines) are skipped so they never
    rank as standalone context.
    """
    child_to_parent: dict = {}
    for parent in _split_parents(text):
        if len(parent.split()) < MIN_PARENT_WORDS:
            continue
        for child in _split_children(parent):
            if len(child.split()) >= MIN_CHILD_WORDS:
                child_to_parent.setdefault(child, parent)
    return child_to_parent


def build_index(dirs):
    """Build the child->parent + child->source maps over every file in dirs."""
    child_to_parent: dict = {}
    source_map: dict = {}
    for d in dirs:
        if not os.path.isdir(d):
            continue
        for name in sorted(os.listdir(d)):
            path = os.path.join(d, name)
            if not os.path.isfile(path):
                continue
            text = extract_text(path)
            if not text.strip():
                continue
            mapping = chunk_hierarchical(text)
            for child, parent in mapping.items():
                if child not in child_to_parent:
                    child_to_parent[child] = parent
                    source_map[child] = name
    return child_to_parent, source_map


def count_chunks(dirs):
    child_to_parent, _ = build_index(dirs)
    return len(child_to_parent)


def _tokenize(text: str) -> list:
    """Lightweight lexical tokenizer: lowercase alphanumeric tokens, no
    punctuation so 'Flutter,' matches 'Flutter'."""
    return re.findall(r"[a-z0-9]+", (text or "").lower())


def retrieve(query: str, dirs, top_n: int = 2):
    """BM25 over child chunks; return (parent_chunks, source_names).

    Every parent's score is the sum of its children's BM25 scores, so parents
    with multiple relevant passages rank above parents with one strong hit —
    giving the LLM more complete context.
    """
    child_to_parent, source_map = build_index(dirs)
    if not child_to_parent or BM25Okapi is None:
        return [], []
    tokens = _tokenize(query)
    if not tokens:
        return [], []

    children = list(child_to_parent.keys())
    bm25 = BM25Okapi([_tokenize(c) for c in children])
    scores = bm25.get_scores(tokens)
    child_scores = dict(zip(children, scores))

    parent_scores: dict = {}
    parent_sources: dict = {}
    for child, parent in child_to_parent.items():
        parent_scores[parent] = parent_scores.get(parent, 0.0) + child_scores.get(child, 0.0)
        parent_sources.setdefault(parent, source_map.get(child, "unknown"))

    top_parents = sorted(parent_scores, key=parent_scores.get, reverse=True)[:top_n]
    return [p for p in top_parents], [parent_sources.get(p, "unknown") for p in top_parents]
