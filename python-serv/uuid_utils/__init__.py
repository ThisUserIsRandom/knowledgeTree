"""Pure-Python stand-in for the Rust ``uuid_utils``/``uuid-utils`` package.

``langchain_core.utils.uuid`` does ``from uuid_utils.compat import uuid7`` and
LangGraph calls ``uuid_utils.uuid4`` during ``graph.invoke``. On Termux the Rust
build links ``ndk-context`` and panics ("android context was not initialized"),
aborting the whole server. This package shadows the Rust one (it sits ahead of
site-packages on ``sys.path``) and provides the same API using only the stdlib
``uuid`` module plus a pure-Python RFC 9562 ``uuid6``/``uuid7`` implementation.

UUIDs generated here are perfectly valid and unique; the server only uses them
as opaque identifiers for tracing/run IDs.
"""

from __future__ import annotations

import secrets
import time
import uuid as _std_uuid
from uuid import (
    NAMESPACE_DNS,
    NAMESPACE_OID,
    NAMESPACE_URL,
    NAMESPACE_X500,
    RESERVED_FUTURE,
    RESERVED_MICROSOFT,
    RESERVED_NCS,
    RFC_4122,
    SafeUUID,
    UUID,
)

__version__ = "0.0.0-stdlib-shim"

NIL = UUID("00000000-0000-0000-0000-000000000000")
MAX = UUID("ffffffff-ffff-ffff-ffff-ffffffffffff")


def getnode(*args, **kwargs) -> int:
    return _std_uuid.getnode(*args, **kwargs)


def uuid1(node=None, clock_seq=None) -> UUID:
    return _std_uuid.uuid1(node, clock_seq)


def uuid3(namespace, name) -> UUID:
    ns = namespace if isinstance(namespace, UUID) else UUID(str(namespace))
    return _std_uuid.uuid3(ns, name)


def uuid4() -> UUID:
    return _std_uuid.uuid4()


def uuid5(namespace, name) -> UUID:
    ns = namespace if isinstance(namespace, UUID) else UUID(str(namespace))
    return _std_uuid.uuid5(ns, name)


def uuid6(node=None, timestamp=None, *, nanos: int | None = None) -> UUID:
    return UUID(int=_uuid6_int(node, timestamp, nanos))


def uuid7(timestamp=None, nanos=None) -> UUID:
    return UUID(int=_uuid7_int(timestamp, nanos))


def uuid8(raw: bytes) -> UUID:
    return UUID(bytes=raw)


def _now_ns(timestamp=None, nanos=None) -> int:
    if timestamp is None:
        return time.time_ns()
    return int(timestamp) * 1_000_000_000 + int(nanos or 0)


def _uuid7_int(timestamp=None, nanos=None) -> int:
    """RFC 9562, version 7: (48-bit ms | 4-bit ver | 12-bit rand | 10-variant | 62-bit rand)."""
    ms = _now_ns(timestamp, nanos) // 1_000_000
    rand_a = secrets.randbits(12)
    rand_b = secrets.randbits(62)
    return (ms << 80) | (0x7 << 76) | (rand_a << 64) | (0b10 << 62) | rand_b


def _uuid6_int(node=None, timestamp=None, nanos=None) -> int:
    """RFC 9562, version 6: Gregorian epoch + node + sequence (sortable)."""
    now_ns = _now_ns(timestamp, nanos)
    gregorian = int(now_ns / 1_000_000) + 0x01B21DD213814000  # 100ns units since 1582
    node = node if node is not None else _std_uuid.getnode()
    seq = secrets.randbits(14)

    time_high = (gregorian >> 28) & 0xFFFFFFFF
    time_mid = (gregorian >> 12) & 0xFFFF
    time_low = gregorian & 0xFFF

    int_part = (
        (time_high << 96)
        | (time_mid << 80)
        | ((0x6 << 12) | (time_low & 0xFFF)) << 64
        | (0b10 << 62)
        | (seq << 48)
        | node
    )
    return int_part


def _uuid4_int() -> int:
    return _std_uuid.uuid4().int


def _uuid6_int_alias(*args, **kwargs) -> int:
    return _uuid6_int(*args, **kwargs)


__all__ = [
    "MAX",
    "NAMESPACE_DNS",
    "NAMESPACE_OID",
    "NAMESPACE_URL",
    "NAMESPACE_X500",
    "NIL",
    "RESERVED_FUTURE",
    "RESERVED_MICROSOFT",
    "RESERVED_NCS",
    "RFC_4122",
    "SafeUUID",
    "UUID",
    "__version__",
    "getnode",
    "uuid1",
    "uuid3",
    "uuid4",
    "uuid5",
    "uuid6",
    "uuid7",
    "uuid8",
    "_uuid4_int",
    "_uuid7_int",
]