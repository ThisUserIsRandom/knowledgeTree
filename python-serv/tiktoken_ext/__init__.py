"""Stub for the real ``tiktoken_ext`` Rust registry.

Present so that any transitive ``import tiktoken_ext`` succeeds even after the
real (Rust) ``tiktoken`` is uninstalled from Termux. The local pure-Python
``tiktoken`` shim in this directory does not load any encodings through it.
"""

__all__ = ["openai_public"]


class openai_public:
    """Namespaced placeholder; never actually used by the shim tokenizer."""

    @staticmethod
    def gpt2() -> list:  # pragma: no cover
        return []

    @staticmethod
    def cl100k_base() -> list:  # pragma: no cover
        return []
