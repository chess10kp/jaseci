# Product-path facade for _ssl.
# Semantics mirror CPython 3.14 ``Modules/_ssl.c``: the module-level constant
# surface built by ``sslmodule_init_constants`` (error codes, cert requirements,
# verification flags, alert descriptions, protocol selectors, OpenSSL option
# bits, hostname-check flags, encoding tags, capability booleans).
#
# REPRESENTATION CHOICE (divergence ledger candidate): the C original is a thin
# binding over libssl/libcrypto -- every session-bearing object (SSLSocket,
# SSLObject, SSLContext) and every call-through (RAND_*, get_default_verify_
# paths, certificate parsing, enum_certificates) requires live OpenSSL handles
# and stays host-side, resolved through the delegation registry exactly like
# re/hashlib/zlib. This facade lifts everything _ssl.c exports that is a pure
# compile-time value, so guest code (and py2jac'd test_ssl snippets) can bind
# ``import ssl`` constants without crossing the boundary. Numeric values are
# pinned byte-exact against the CPython 3.14 linux-x86_64 build linked against
# OpenSSL 3.x (the platform CI gates); build-dependent capability bools carry
# that build's answers by design, mirroring how the C module bakes them in at
# compile time.
#
# Out of scope by design (needs OpenSSL state): SSLError/SSLZeroReturnError
# class hierarchy, SSLContext/SSLSocket/SSLObject types, RAND_*,
# get_default_verify_paths, _test_decode_cert, enum_certificates/enum_crls.

# ---- enum py_ssl_error -> SSL_ERROR_* (mirror ssl.h + non-ssl.h tail) ----

glob SSL_ERROR_SSL: int = 1,
     SSL_ERROR_WANT_READ: int = 2,
     SSL_ERROR_WANT_WRITE: int = 3,
     SSL_ERROR_WANT_X509_LOOKUP: int = 4,
     SSL_ERROR_SYSCALL: int = 5,
     SSL_ERROR_ZERO_RETURN: int = 6,
     SSL_ERROR_WANT_CONNECT: int = 7,

     # non ssl.h errorcodes (special cases of SYSCALL / GC'd socket)
     SSL_ERROR_EOF: int = 8,
     SSL_ERROR_INVALID_ERROR_CODE: int = 10;

# ---- enum py_ssl_cert_requirements -> CERT_* ----

glob CERT_NONE: int = 0,
     CERT_OPTIONAL: int = 1,
     CERT_REQUIRED: int = 2;

# ---- X509_V_FLAG_* verification flags (VERIFY_*) ----

glob VERIFY_DEFAULT: int = 0,
     VERIFY_CRL_CHECK_LEAF: int = 0x4,
     VERIFY_CRL_CHECK_CHAIN: int = 0x4 | 0x8,
     VERIFY_X509_STRICT: int = 0x20,
     VERIFY_ALLOW_PROXY_CERTS: int = 0x40,
     VERIFY_X509_TRUSTED_FIRST: int = 0x8000,
     VERIFY_X509_PARTIAL_CHAIN: int = 0x80000;

# ---- Alert descriptions (IANA tls-parameters registry; SSL_AD_*) ----

glob ALERT_DESCRIPTION_CLOSE_NOTIFY: int = 0,
     ALERT_DESCRIPTION_UNEXPECTED_MESSAGE: int = 10,
     ALERT_DESCRIPTION_BAD_RECORD_MAC: int = 20,
     ALERT_DESCRIPTION_RECORD_OVERFLOW: int = 22,
     ALERT_DESCRIPTION_DECOMPRESSION_FAILURE: int = 30,
     ALERT_DESCRIPTION_HANDSHAKE_FAILURE: int = 40,
     ALERT_DESCRIPTION_BAD_CERTIFICATE: int = 42,
     ALERT_DESCRIPTION_UNSUPPORTED_CERTIFICATE: int = 43,
     ALERT_DESCRIPTION_CERTIFICATE_REVOKED: int = 44,
     ALERT_DESCRIPTION_CERTIFICATE_EXPIRED: int = 45,
     ALERT_DESCRIPTION_CERTIFICATE_UNKNOWN: int = 46,
     ALERT_DESCRIPTION_ILLEGAL_PARAMETER: int = 47,
     ALERT_DESCRIPTION_UNKNOWN_CA: int = 48,
     ALERT_DESCRIPTION_ACCESS_DENIED: int = 49,
     ALERT_DESCRIPTION_DECODE_ERROR: int = 50,
     ALERT_DESCRIPTION_DECRYPT_ERROR: int = 51,
     ALERT_DESCRIPTION_PROTOCOL_VERSION: int = 70,
     ALERT_DESCRIPTION_INSUFFICIENT_SECURITY: int = 71,
     ALERT_DESCRIPTION_INTERNAL_ERROR: int = 80,
     ALERT_DESCRIPTION_USER_CANCELLED: int = 90,
     ALERT_DESCRIPTION_NO_RENEGOTIATION: int = 100,
     ALERT_DESCRIPTION_UNSUPPORTED_EXTENSION: int = 110,
     ALERT_DESCRIPTION_CERTIFICATE_UNOBTAINABLE: int = 111,
     ALERT_DESCRIPTION_UNRECOGNIZED_NAME: int = 112,
     ALERT_DESCRIPTION_BAD_CERTIFICATE_STATUS_RESPONSE: int = 113,
     ALERT_DESCRIPTION_BAD_CERTIFICATE_HASH_VALUE: int = 114,
     ALERT_DESCRIPTION_UNKNOWN_PSK_IDENTITY: int = 115;

# ---- enum py_ssl_version -> PROTOCOL_* (SSLv2 gone; SSLv3 absent on
#      OpenSSL >= 1.0.2 builds with OPENSSL_NO_SSL3, matching the reference
#      build where the constant is not registered at all) ----

glob PROTOCOL_SSLv23: int = 2,
     PROTOCOL_TLS: int = 2,
     PROTOCOL_TLS_CLIENT: int = 0x10,
     PROTOCOL_TLS_SERVER: int = 0x11,
     PROTOCOL_TLSv1: int = 3,
     PROTOCOL_TLSv1_1: int = 4,
     PROTOCOL_TLSv1_2: int = 5;

# ---- SSL_OP_* option bits (uint64; SSL_OP_ALL minus the empty-fragments
#      quirk, per sslmodule_add_option) ----

glob OP_ALL: int = 2147483728,
     OP_NO_SSLv2: int = 0,
     OP_NO_SSLv3: int = 33554432,
     OP_NO_TLSv1: int = 67108864,
     OP_NO_TLSv1_1: int = 268435456,
     OP_NO_TLSv1_2: int = 134217728,
     OP_NO_TLSv1_3: int = 536870912,
     OP_CIPHER_SERVER_PREFERENCE: int = 4194304,
     OP_SINGLE_DH_USE: int = 0,
     OP_SINGLE_ECDH_USE: int = 0,
     OP_NO_TICKET: int = 16384,
     OP_LEGACY_SERVER_CONNECT: int = 4,
     OP_NO_COMPRESSION: int = 131072,
     OP_ENABLE_MIDDLEBOX_COMPAT: int = 1048576,
     OP_NO_RENEGOTIATION: int = 1073741824,
     OP_IGNORE_UNEXPECTED_EOF: int = 128,
     OP_ENABLE_KTLS: int = 8;

# ---- X509_CHECK_FLAG_* hostname matching flags (HOSTFLAG_*) ----

glob HOSTFLAG_ALWAYS_CHECK_SUBJECT: int = 0x1,
     HOSTFLAG_NEVER_CHECK_SUBJECT: int = 0x2,
     HOSTFLAG_NO_WILDCARDS: int = 0x4,
     HOSTFLAG_NO_PARTIAL_WILDCARDS: int = 0x8,
     HOSTFLAG_MULTI_LABEL_WILDCARDS: int = 0x10,
     HOSTFLAG_SINGLE_LABEL_SUBDOMAINS: int = 0x20;

# ---- enum py_ssl_encoding (X509_FILETYPE_*) ----

glob ENCODING_PEM: int = 1,
     ENCODING_DER: int = 2;

# ---- enum py_proto_version wire-version numbers (PROTO_*) ----

glob PROTO_MINIMUM_SUPPORTED: int = -2,
     PROTO_MAXIMUM_SUPPORTED: int = -1,
     PROTO_SSLv3: int = 0x300,
     PROTO_TLSv1: int = 0x301,
     PROTO_TLSv1_1: int = 0x302,
     PROTO_TLSv1_2: int = 0x303,
     PROTO_TLSv1_3: int = 0x304;

# ---- capability booleans (compile-time feature probes baked into the
#      reference linux-x86_64 / OpenSSL 3.x build) ----

glob HAS_SNI: bool = True,
     HAS_TLS_UNIQUE: bool = True,
     HAS_ECDH: bool = True,
     HAS_NPN: bool = False,
     HAS_ALPN: bool = True,
     HAS_SSLv2: bool = False,
     HAS_SSLv3: bool = False,
     HAS_TLSv1: bool = True,
     HAS_TLSv1_1: bool = True,
     HAS_TLSv1_2: bool = True,
     HAS_TLSv1_3: bool = True,
     HAS_PSK: bool = True,
     HAS_PHA: bool = True,
     HAS_NEVER_CHECK_COMMON_NAME: bool = True;

# ---- cipher-string defaults (PY_SSL_DEFAULT_CIPHER_STRING and the
#      restricted server profile derived from it) ----

glob _DEFAULT_CIPHERS: str =
    "@SECLEVEL=2:ECDH+AESGCM:ECDH+CHACHA20:ECDH+AES:DHE+AES:!aNULL:!eNULL:"
    "!aDSS:!SHA1:!AESCCM",
    _RESTRICTED_SERVER_CIPHERS: str =
    "@SECLEVEL=2:ECDH+AESGCM:ECDH+CHACHA20:ECDH+AES:DHE+AES:!aNULL:!eNULL:"
    "!aDSS:!SHA1:!AESCCM";
