"""``compat`` submodule mirroring ``uuid_utils.compat`` (pure-Python shim).

Provides ``uuid1``..``uuid8`` returning stdlib ``UUID`` objects, plus the
constants exported by the real package. ``langchain_core.utils.uuid`` imports
``uuid7`` from here.
"""

from __future__ import annotations

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
    getnode,
)

import uuid_utils

NIL = UUID("00000000-0000-0000-0000-000000000000")
MAX = UUID("ffffffff-ffff-ffff-ffff-ffffffffffff")

__version__ = uuid_utils.__version__


def _from_int(n: int) -> UUID:
    return UUID(int=n)


def uuid1(node=None, clock_seq=None) -> UUID:
    return _from_int(uuid_utils.uuid1(node, clock_seq).int)


def uuid3(namespace, name) -> UUID:
    ns = namespace if isinstance(namespace, UUID) else UUID(str(namespace))
    return _from_int(uuid_utils.uuid3(ns, name).int)


def uuid4() -> UUID:
    return _from_int(uuid_utils.uuid4().int)


def uuid5(namespace, name) -> UUID:
    ns = namespace if isinstance(namespace, UUID) else UUID(str(namespace))
    return _from_int(uuid_utils.uuid5(ns, name).int)


def uuid6(node=None, timestamp=None) -> UUID:
    return _from_int(uuid_utils.uuid6(node, timestamp).int)


def uuid7(timestamp=None, nanos=None) -> UUID:
    return _from_int(uuid_utils.uuid7(timestamp, nanos).int)


def uuid8(raw: bytes) -> UUID:
    return _from_int(uuid_utils.uuid8(raw).int)


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
]