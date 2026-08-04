"""Local retrieval index.

Hierarchical chunking + hybrid (BM25 + lightweight semantic) retrieval for the
gateway RAG pipeline. Uses a structure-aware splitter (paragraph -> line ->
sentence -> words) so chunks never slice a sentence in half, and ranks *parent*
chunks by the aggregated evidence of all their child chunks (rather than blindly
taking the top-N children).

Ranking is hybrid: classic token-level BM25 is blended with cosine similarity
over the dependency-free semantic features from :mod:`.embed` (word tokens +
character n-grams). The semantic term lets paraphrases and morphological
variants rank even when they share few exact tokens.

Files (crawled web pages + uploaded documents) are chunked hierarchically:
parent chunks (~160 words) subdivided into child chunks (~100 words). BM25 is
a self-contained Okapi implementation (no external dependency).
"""

import math
import os
import re

from . import embed as rag_embed

# Okapi BM25 tuning. k1 controls term-frequency saturation (how much a repeated
# query term keeps adding) and b controls length normalisation (how much a long
# chunk is penalised). These are tuned for short RAG chunks (~100 words): b is
# slightly below the classic 0.75 so over-long parents aren't over-penalised.
_K1 = 1.5
_B = 0.7
_DELTA = 0.5


class BM25:
    """Task-specialised Okapi BM25 (self-contained, no external dependency).

    Scores child chunks against a query using the classic BM25 formula with the
    Robertson sparse-term IDF. This implementation is built for the retrieval
    pipeline's short, cleaned chunks: it is O(terms) per document and keeps no
    heap allocations beyond the term-frequency maps.
    """

    def __init__(self, corpus, k1: float = _K1, b: float = _B, delta: float = _DELTA):
        self.k1 = k1
        self.b = b
        self.delta = delta
        self.corpus_size = len(corpus)
        self.doc_freqs: list = []
        self.doc_len: list = []
        self.total_terms = 0
        self.avgdl = 0.0
        self.doc_freq: dict = {}
        self._idf_cache: dict = {}

        for doc in corpus:
            df: dict = {}
            dl = 0
            seen: set = set()
            for term in doc:
                df[term] = df.get(term, 0) + 1
                dl += 1
                if term not in seen:
                    seen.add(term)
                    self.doc_freq[term] = self.doc_freq.get(term, 0) + 1
            self.doc_freqs.append(df)
            self.doc_len.append(dl)
            self.total_terms += dl
        if self.corpus_size:
            self.avgdl = self.total_terms / self.corpus_size

    def _idf(self, n: int) -> float:
        if n not in self._idf_cache:
            self._idf_cache[n] = math.log(
                (self.corpus_size - n + 0.5) / (n + 0.5) + 1.0
            )
        return self._idf_cache[n]

    def get_scores(self, query: list) -> list:
        """BM25 relevance of every corpus doc for the tokenized ``query``."""
        if not query or self.corpus_size == 0:
            return [0.0] * self.corpus_size
        scores = [0.0] * self.corpus_size
        qf = {}
        for term in query:
            qf[term] = qf.get(term, 0) + 1
        for i in range(self.corpus_size):
            df = self.doc_freqs[i]
            dl = self.doc_len[i]
            denom_scale = self.k1 * (1 - self.b + self.b * dl / self.avgdl)
            total = 0.0
            for term, qw in qf.items():
                tf = df.get(term, 0)
                if not tf:
                    continue
                idf = self._idf(self.doc_freq.get(term, 0))
                total += qw * idf * (tf * (self.k1 + 1)) / (tf + denom_scale)
            scores[i] = total
        return scores

_TXT_EXT = {".txt", ".md", ".markdown", ".text"}
_PDF_EXT = {".pdf"}
_DOCX_EXT = {".docx"}

# Max words in a single topically-coherent parent chunk.
PARENT_SIZE = 160
CHILD_SIZE = 100
MIN_PARENT_WORDS = 30
MIN_CHILD_WORDS = 5

# Semantic chunking tuning: sentences are grouped while their embedding stays
# coherent with the running chunk. A sentence diverges if its cosine to the
# chunk falls below COHERENCE_THRESHOLD (and the chunk is already substantial),
# which is what separates one topic's section from the next.
COHERENCE_THRESHOLD = 0.14
MIN_JOIN_WORDS = 14

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
    return _coherent_chunks(text)


def _split_children(text: str) -> list:
    return _split_with(text, CHILD_SIZE, (_SENTENCE_BREAK,))


def _coherent_chunks(text: str, max_words: int = PARENT_SIZE) -> list:
    """Split ``text`` into topically-coherent chunks.

    Real articles are organised into paragraphs, so paragraphs are the coarse
    unit: oversized paragraphs are first subdivided by sentence, then consecutive
    paragraphs are greedily merged while their running semantic embedding stays
    coherent (cosine >= ``COHERENCE_THRESHOLD``). A paragraph introducing a new
    subject (a big drop in similarity to the running chunk) starts the next
    chunk, so a page covering several topics becomes several focused sections
    instead of one mixed window. This lets retrieval surface just the relevant
    section.
    """
    text = (text or "").strip()
    if not text:
        return []

    units: list = []
    for para in re.split(r"\n\s*\n", text):
        para = re.sub(r"\s*\n\s*", " ", para).strip()
        if not para:
            continue
        pw = len(para.split())
        if pw == 0:
            continue
        if pw <= max_words:
            units.append(para)
        else:
            words = para.split()
            for i in range(0, len(words), max_words):
                units.append(" ".join(words[i : i + max_words]))

    # A tiny page-local IDF down-weights n-gram noise ("th", "he", "in")
    # shared by every paragraph, so unrelated sections stand apart while a
    # genuinely distinct subject stays coherent.
    raw = [rag_embed.collect(u) for u in units]
    page_idf = rag_embed.build_idf(raw)

    chunks: list = []
    cur: list = []
    cur_counts: dict = {}
    cur_words = 0
    for unit, raw_count in zip(units, raw):
        unit_words = len(unit.split())
        unit_count = rag_embed.weight(raw_count, page_idf)
        diverges = cur_words >= MIN_JOIN_WORDS and (
            rag_embed.cosine(cur_counts, unit_count) < COHERENCE_THRESHOLD
        )
        if cur and (cur_words + unit_words > max_words or diverges):
            chunks.append(" ".join(cur))
            cur, cur_counts, cur_words = [unit], unit_count, unit_words
        else:
            cur.append(unit)
            for fid, c in unit_count.items():
                cur_counts[fid] = cur_counts.get(fid, 0.0) + c
            cur_words += unit_words
    if cur:
        chunks.append(" ".join(cur))
    return [_c for _c in chunks if _c.strip()]


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
    """Hybrid BM25 + semantic retrieval; return (parents, sources, relevance).

    Every parent's score is the sum of its children's scores, where each child
    score blends its BM25 rank with the semantic cosine similarity of the
    query to the chunk. The returned ``relevance`` is the best parent's hybrid
    score in [0, 1], letting the pipeline decide whether the context is
    actually about the query.
    """
    child_to_parent, source_map = build_index(dirs)
    if not child_to_parent:
        return [], [], 0.0
    tokens = _tokenize(query)
    if not tokens:
        return [], [], 0.0

    children = list(child_to_parent.keys())
    bm25 = BM25([_tokenize(c) for c in children])
    bm_scores = bm25.get_scores(tokens)

    # Lightweight semantic features shared between query and chunks so IDF is
    # computed over the same corpus the cosine scores come from.
    raw_feats = [rag_embed.collect(c) for c in children]
    idf = rag_embed.build_idf(raw_feats)
    chunk_feats = [rag_embed.weight(raw, idf) for raw in raw_feats]
    query_feats = rag_embed.embed(query, idf)

    max_bm = max(bm_scores) if len(bm_scores) else 0.0
    child_hybrid: dict = {}
    for i, child in enumerate(children):
        bm_norm = bm_scores[i] / max_bm if max_bm > 0 else 0.0
        sim = rag_embed.cosine(query_feats, chunk_feats[i])
        child_hybrid[child] = 0.55 * bm_norm + 0.45 * sim

    parent_scores: dict = {}
    parent_sources: dict = {}
    for child, parent in child_to_parent.items():
        parent_scores[parent] = parent_scores.get(parent, 0.0) + child_hybrid.get(child, 0.0)
        parent_sources.setdefault(parent, source_map.get(child, "unknown"))

    top_parents = sorted(parent_scores, key=parent_scores.get, reverse=True)[:top_n]
    relevance = max(parent_scores.values()) if parent_scores else 0.0
    return (
        [p for p in top_parents],
        [parent_sources.get(p, "unknown") for p in top_parents],
        min(relevance, 1.0),
    )
