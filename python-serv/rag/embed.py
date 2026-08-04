"""Super-lightweight semantic embedding + similarity (no model, no deps).

A "small embedder" for relevance scoring. Text is represented as a sparse
bag of hashed features: exact word tokens plus character n-grams (2-4),
which approximate subword semantics. Features are weighted by log-frequency
and corpus IDF, and similarity is cosine distance.

This catches meaning overlap that exact-token BM25 misses — e.g. the query
"how do I fix the app crashing" still ranks high against a chunk that says
"the application keeps crashing" because both share the word tokens ``crash``
and the subword n-grams ``cra/rash/cras``.

Why no neural model: the server runs on Termux (aarch64 Android) where
torch/transformers/onnx are impractical. This is pure Python + stdlib.
"""

import math
import re
import zlib

_WORD_RE = re.compile(r"[a-z0-9]+")

# Fixed feature space: features are hashed into [0, _FEATURE_DIM). Sparse dicts
# keep memory proportional to vocabulary, not the dimension.
_FEATURE_DIM = 1 << 16

# Relative weight of char n-grams vs whole words. Words dominate exact matches;
# short n-grams (2) are common and diluted with a lower factor.
_WORD_WEIGHT = 1.0
_NGRAM_WEIGHTS = {2: 0.25, 3: 0.45, 4: 0.40}


def _feature_id(key: str) -> int:
    """Deterministic hash of a feature string into the fixed space."""
    return zlib.crc32(key.encode("utf-8")) % _FEATURE_DIM


def collect(text: str) -> dict:
    """Raw feature counts {feature_id: weight} with no IDF applied yet.

    Words contribute ``_WORD_WEIGHT`` per occurrence, character n-grams
    ``_NGRAM_WEIGHTS[n]`` each, so informative subword features never drown
    out exact tokens.
    """
    words = _WORD_RE.findall((text or "").lower())
    compact = "".join(words)  # concatenation keeps n-grams crossing word gaps
    counts: dict = {}
    for w in words:
        fid = _feature_id("w:" + w)
        counts[fid] = counts.get(fid, 0.0) + _WORD_WEIGHT
    for n, factor in _NGRAM_WEIGHTS.items():
        if factor <= 0:
            continue
        limit = len(compact) - n + 1
        for i in range(limit):
            fid = _feature_id("n%d:" % n + compact[i : i + n])
            counts[fid] = counts.get(fid, 0.0) + factor
    return counts


def build_idf(raw_features) -> dict:
    """Corpus IDF map from a list of raw feature-count dicts."""
    df: dict = {}
    for feats in raw_features:
        for fid in feats:
            df[fid] = df.get(fid, 0) + 1
    n = len(raw_features)
    if n == 0:
        return {}
    return {fid: math.log((n + 1.0) / (doc_count + 1.0)) + 1.0
            for fid, doc_count in df.items()}


def weight(counts: dict, idf: dict) -> dict:
    """Apply log-frequency + IDF weights to raw counts."""
    if not counts:
        return {}
    return {
        fid: (1.0 + math.log(c)) * idf.get(fid, 1.0)
        for fid, c in counts.items()
    }


def embed(text: str, idf: dict | None = None) -> dict:
    """Weighted feature vector (sparse dict) for ``text``."""
    return weight(collect(text), idf or {})


def cosine(a: dict, b: dict) -> float:
    """Cosine similarity in [0, 1] between two sparse feature dicts."""
    if not a or not b:
        return 0.0
    dot = 0.0
    for fid, va in a.items():
        vb = b.get(fid)
        if vb is not None:
            dot += va * vb
    if dot <= 0.0:
        return 0.0
    na = math.sqrt(sum(v * v for v in a.values()))
    nb = math.sqrt(sum(v * v for v in b.values()))
    if na <= 0.0 or nb <= 0.0:
        return 0.0
    return dot / (na * nb)
