"""Pure-Python stand-in for the ``tiktoken`` Rust tokenizer.

``langchain-openai`` imports ``tiktoken`` unconditionally and calls
``get_encoding``/``encoding_for_model`` for token counting. On Termux the real
Rust build links ``ndk-context`` and panics ("android context was not
initialized"), aborting the whole server process. This package shadows the
Rust one (it sits ahead of site-packages on ``sys.path``) and provides a tiny
stdlib-only tokenizer so LangChain's optional token counting never touches the
Rust code. Token counts are only approximate — the server never depends on them.
"""

import re

__all__ = [
    "Encoding",
    "get_encoding",
    "encoding_for_model",
    "list_encoding_names",
    "core",
    "errors",
]

_TOKEN_RE = re.compile(r"\s+|\S+")


class Encoding:
    """Minimal tiktoken-compatible encoder backed by stdlib only."""

    def __init__(self, name="shim", *, vocab_size: int = 2**16):
        self.name = name
        self.n_vocab = vocab_size
        self._tokens: list[str] = []
        self._index: dict[str, int] = {}

    def _id(self, piece: str) -> int:
        token_id = self._index.get(piece)
        if token_id is None:
            token_id = len(self._tokens)
            self._index[piece] = token_id
            self._tokens.append(piece)
        return token_id

    def encode(
        self,
        text: str,
        *,
        allowed_special=None,
        disallowed_special=None,
    ) -> list[int]:
        return [self._id(p) for p in _TOKEN_RE.findall(text or "")]

    def encode_ordinary(self, text: str) -> list[int]:
        return self.encode(text)

    def encode_with_unstable(self, text: str) -> list[int]:
        return self.encode(text)

    def encode_ordinary_batch(self, texts: list[str]) -> list[list[int]]:
        return [self.encode(t) for t in texts]

    def decode(self, tokens: list[int]) -> str:
        return "".join(
            self._tokens[t] if 0 <= t < len(self._tokens) else ""
            for t in tokens
        )

    def decode_single_token_bytes(self, token: int) -> bytes:
        if 0 <= token < len(self._tokens):
            return self._tokens[token].encode("utf-8")
        return b""

    def decode_with_offsets(self, tokens: list[int]) -> tuple[str, list[tuple]]:
        return self.decode(tokens), []

    def encode_with_offsets(self, text: str) -> tuple[list[int], list[tuple]]:
        ids = []
        offsets = []
        pos = 0
        for piece in _TOKEN_RE.findall(text or ""):
            ids.append(self._id(piece))
            offsets.append((pos, pos + len(piece)))
            pos += len(piece)
        return ids, offsets


def get_encoding(name: str = "shim") -> Encoding:
    return Encoding(name)


def encoding_for_model(model_name: str = "gpt-3.5-turbo") -> Encoding:
    return Encoding(model_name)


def list_encoding_names() -> list[str]:
    return ["shim"]


class core:
    """Module-style shim for anything importing ``tiktoken.core``."""

    Encoding = Encoding  # noqa: F811 (re-expose for attribute access)


class errors:
    """Stub for ``tiktoken.errors`` so attribute access never fails."""

    class EncodingLoadError(Exception):
        pass

    class TiktokenError(Exception):
        pass
