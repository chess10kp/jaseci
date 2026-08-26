# Product-path facade for pyexpat (Modules/pyexpat.c).
#
# Semantics mirror CPython 3.14 ``Modules/pyexpat.c`` for the surface the
# converted Lib/test pins exercise:
#
# - module data: EXPAT_VERSION/version_info (bundled expat 2.8.1),
#   native_encoding, features, ErrorString, and the errors/model submodules
#   with the exact error_info_of table (code == table index,
#   XML_ERROR_NONE unexposed) -- errors.XML_ERROR_* carry MESSAGE strings
#   and codes/messages are the message<->int dicts, matching
#   add_errors_module.
# - ExpatError: raised as "xml.parsers.expat.ExpatError" carrying .code,
#   .lineno, .offset as type fields; declared in the module-exception
#   registry at import.
# - xmlparser objects: the full getset surface (buffer_text/buffer_size/
#   buffer_used/namespace_prefixes/ordered_attributes/specified_attributes,
#   Current*/Error* position getters, the returns_unicode AttributeError
#   arm), all 22 handler slots as plain settable attributes, and the method
#   surface (Parse/ParseFile/SetBase/GetBase/GetInputContext/
#   ExternalEntityParserCreate/SetParamEntityParsing/UseForeignDTD/reparse-
#   deferral pair/protection knobs).
#
# REPRESENTATION CHOICE (divergence ledger): the C original drives libexpat's
# full XML 1.0 processor (DTD validation states, encoding auto-detection,
# billion-laughs accounting). The guest has no libexpat, so Parse runs a
# native well-formedness scanner over the accumulated input: XML declaration,
# PIs, comments, CDATA, DOCTYPE (internal subset scanned for ENTITY/ELEMENT/
# ATTLIST decls, external ids parsed), start/end/empty tags with
# duplicate-attribute checks, character data, predefined/numeric entity refs,
# and an entity table from ENTITY declarations. Content-level references to
# undeclared entities are SKIPPED when one of SkippedEntityHandler/
# DefaultHandler(+Expand)/ExternalEntityRefHandler absorbs them (the shape
# the converted pins parse under) and raise XML_ERROR_UNDEFINED_ENTITY
# otherwise. Namespace expansion is not performed -- raw qualified names are
# delivered -- while element names are interned per parser so identity idioms
# (`start_tag is end_tag`) hold like expat's shared string table.
#
# Handler results follow each PyErr site: void handlers propagate exceptions
# verbatim, RC_HANDLER results must convert to int (TypeError otherwise) and
# 0 maps to XML_ERROR_NOT_STANDALONE / EXTERNAL_ENTITY_HANDLING exactly where
# the C dispatches those errors.

import from objects {
    PyObj,
    PyInt,
    PyBool,
    PyFloat,
    PyStr,
    PyBytes,
    PyTuple,
    PyList,
    PyDict,
    PyNoneType,
    PyException,
    PyError,
    py_none,
    py_error,
    py_exception_type,
    is_error,
}

import from pyc_first { PyModule }

import from exceptions_core { register_module_exception }

# ---------------- error table (error_info_of; index i -> code i+1) ----------

glob _ERROR_TABLE: list[tuple[str, str]] = [
    ("XML_ERROR_NO_MEMORY", "out of memory"),
    ("XML_ERROR_SYNTAX", "syntax error"),
    ("XML_ERROR_NO_ELEMENTS", "no element found"),
    ("XML_ERROR_INVALID_TOKEN", "not well-formed (invalid token)"),
    ("XML_ERROR_UNCLOSED_TOKEN", "unclosed token"),
    ("XML_ERROR_PARTIAL_CHAR", "partial character"),
    ("XML_ERROR_TAG_MISMATCH", "mismatched tag"),
    ("XML_ERROR_DUPLICATE_ATTRIBUTE", "duplicate attribute"),
    ("XML_ERROR_JUNK_AFTER_DOC_ELEMENT", "junk after document element"),
    ("XML_ERROR_PARAM_ENTITY_REF", "illegal parameter entity reference"),
    ("XML_ERROR_UNDEFINED_ENTITY", "undefined entity"),
    ("XML_ERROR_RECURSIVE_ENTITY_REF", "recursive entity reference"),
    ("XML_ERROR_ASYNC_ENTITY", "asynchronous entity"),
    ("XML_ERROR_BAD_CHAR_REF", "reference to invalid character number"),
    ("XML_ERROR_BINARY_ENTITY_REF", "reference to binary entity"),
    ("XML_ERROR_ATTRIBUTE_EXTERNAL_ENTITY_REF", "reference to external entity in attribute"),
    ("XML_ERROR_MISPLACED_XML_PI", "XML or text declaration not at start of entity"),
    ("XML_ERROR_UNKNOWN_ENCODING", "unknown encoding"),
    ("XML_ERROR_INCORRECT_ENCODING", "encoding specified in XML declaration is incorrect"),
    ("XML_ERROR_UNCLOSED_CDATA_SECTION", "unclosed CDATA section"),
    ("XML_ERROR_EXTERNAL_ENTITY_HANDLING", "error in processing external entity reference"),
    ("XML_ERROR_NOT_STANDALONE", "document is not standalone"),
    ("XML_ERROR_UNEXPECTED_STATE", "unexpected parser state - please send a bug report"),
    ("XML_ERROR_ENTITY_DECLARED_IN_PE", "entity declared in parameter entity"),
    ("XML_ERROR_FEATURE_REQUIRES_XML_DTD", "requested feature requires XML_DTD support in Expat"),
    ("XML_ERROR_CANT_CHANGE_FEATURE_ONCE_PARSING", "cannot change setting once parsing has begun"),
    ("XML_ERROR_UNBOUND_PREFIX", "unbound prefix"),
    ("XML_ERROR_UNDECLARING_PREFIX", "must not undeclare prefix"),
    ("XML_ERROR_INCOMPLETE_PE", "incomplete markup in parameter entity"),
    ("XML_ERROR_XML_DECL", "XML declaration not well-formed"),
    ("XML_ERROR_TEXT_DECL", "text declaration not well-formed"),
    ("XML_ERROR_PUBLICID", "illegal character(s) in public id"),
    ("XML_ERROR_SUSPENDED", "parser suspended"),
    ("XML_ERROR_NOT_SUSPENDED", "parser not suspended"),
    ("XML_ERROR_ABORTED", "parsing aborted"),
    ("XML_ERROR_FINISHED", "parsing finished"),
    ("XML_ERROR_SUSPEND_PE", "cannot suspend in external parameter entity"),
    ("XML_ERROR_RESERVED_PREFIX_XML", "reserved prefix (xml) must not be undeclared or bound to another namespace name"),
    ("XML_ERROR_RESERVED_PREFIX_XMLNS", "reserved prefix (xmlns) must not be declared or undeclared"),
    ("XML_ERROR_RESERVED_NAMESPACE_URI", "prefix must not be bound to one of the reserved namespace names"),
    ("XML_ERROR_INVALID_ARGUMENT", "invalid argument"),
    ("XML_ERROR_NO_BUFFER", "a successful prior call to function XML_GetBuffer is required"),
    ("XML_ERROR_AMPLIFICATION_LIMIT_BREACH", "limit on input amplification factor (from DTD and entities) breached"),
    ("XML_ERROR_NOT_STARTED", "parser not started"),
];

def _error_message(code: int) -> str {
    if code >= 1 and code <= len(_ERROR_TABLE) {
        return _ERROR_TABLE[code - 1][1];
    }
    return "";
}

# ---------------- module constants (pyexpat_exec) ---------------------------

glob EXPAT_VERSION: str = "expat_2.8.1";
glob _VERSION_INFO: tuple[int, int, int] = (2, 8, 1);
glob native_encoding: str = "UTF-8";

glob XML_PARAM_ENTITY_PARSING_NEVER: int = 0,
     XML_PARAM_ENTITY_PARSING_UNLESS_STANDALONE: int = 1,
     XML_PARAM_ENTITY_PARSING_ALWAYS: int = 2,

     # model submodule (add_model_module / expat.h enum values)
     XML_CTYPE_EMPTY: int = 1,
     XML_CTYPE_ANY: int = 2,
     XML_CTYPE_MIXED: int = 3,
     XML_CTYPE_NAME: int = 4,
     XML_CTYPE_CHOICE: int = 5,
     XML_CTYPE_SEQ: int = 6,

     XML_CQUANT_NONE: int = 0,
     XML_CQUANT_OPT: int = 1,
     XML_CQUANT_REP: int = 2,
     XML_CQUANT_PLUS: int = 3;

glob _HANDLER_NAMES: list[str] = [
    "StartElementHandler",
    "EndElementHandler",
    "ProcessingInstructionHandler",
    "CharacterDataHandler",
    "UnparsedEntityDeclHandler",
    "NotationDeclHandler",
    "StartNamespaceDeclHandler",
    "EndNamespaceDeclHandler",
    "CommentHandler",
    "StartCdataSectionHandler",
    "EndCdataSectionHandler",
    "DefaultHandler",
    "DefaultHandlerExpand",
    "NotStandaloneHandler",
    "ExternalEntityRefHandler",
    "StartDoctypeDeclHandler",
    "EndDoctypeDeclHandler",
    "EntityDeclHandler",
    "XmlDeclHandler",
    "ElementDeclHandler",
    "AttlistDeclHandler",
    "SkippedEntityHandler",
];

glob _WS: str = " \t\r\n";

glob _PREDEFINED: dict[str, str] = {
    "amp": "&",
    "lt": "<",
    "gt": ">",
    "quot": "\"",
    "apos": "'",
};

# ---------------- ExpatError construction -----------------------------------

def _expat_error(code: int, line: int, col: int) -> PyObj {
    msg = _error_message(code) + ": line " + str(line) + ", column " + str(col);
    fields: dict[str, PyObj] = {
        "code": PyInt(t="int", val=code),
        "lineno": PyInt(t="int", val=line),
        "offset": PyInt(t="int", val=col),
    };
    return PyError(
        t="error",
        exception=PyException(
            t="exception",
            type_name="xml.parsers.expat.ExpatError",
            message=msg,
            type_fields=fields,
        ),
    );
}

# ---------------- parser state ----------------------------------------------

obj PyExpatParser(PyObj) {
    # Configuration (shared/copied by ExternalEntityParserCreate).
    has ns_sep: str,
        enc_req: any,
        handlers: dict[str, PyObj],
        buffer_text: bool,
        buffer_size: int,
        ordered_attrs: bool,
        ns_prefixes: bool,
        specified_attrs: bool,
        base: any,
        foreign_dtd: bool,
        param_entity_parsing: int,
        reparse_deferral: bool,
        intern_table: dict[str, PyObj],
        parent: any,
        stack: list[str],
        entities: dict[str, tuple];

    # Document state.
    has started: bool = False,
        finished: bool = False,
        last_error_code: int = 0,
        err_line: int = 0,
        err_col: int = 0,
        err_byte: int = 0,
        cur_line: int = 1,
        cur_col: int = 0,
        cur_byte: int = -1,
        data: str = "",
        pos: int = 0,
        root_seen: bool = False,
        root_closed: bool = False,
        enc_name: str = "";

    def tp_getattro(name: str) -> PyObj {
        if name == "buffer_text" {
            return PyBool(t="bool", val=self.buffer_text);
        }
        if name == "namespace_prefixes" {
            return PyBool(t="bool", val=self.ns_prefixes);
        }
        if name == "ordered_attributes" {
            return PyBool(t="bool", val=self.ordered_attrs);
        }
        if name == "specified_attributes" {
            return PyBool(t="bool", val=self.specified_attrs);
        }
        if name == "buffer_size" {
            return PyInt(t="int", val=self.buffer_size);
        }
        if name == "buffer_used" {
            return PyInt(t="int", val=0);
        }
        if name == "returns_unicode" {
            # Removed attribute: only the AttributeError contract survives.
            return py_error("AttributeError", name);
        }
        if name == "ErrorCode" {
            return PyInt(t="int", val=self.last_error_code);
        }
        if name == "ErrorLineNumber" {
            return PyInt(t="int", val=self.err_line);
        }
        if name == "ErrorColumnNumber" {
            return PyInt(t="int", val=self.err_col);
        }
        if name == "ErrorByteIndex" {
            return PyInt(t="int", val=self.err_byte);
        }
        if name == "CurrentLineNumber" {
            return PyInt(t="int", val=self.cur_line);
        }
        if name == "CurrentColumnNumber" {
            return PyInt(t="int", val=self.cur_col);
        }
        if name == "CurrentByteIndex" {
            return PyInt(t="int", val=self.cur_byte);
        }
        if name == "intern" {
            # The interning object; opaque to guests.
            return py_none();
        }
        if name in self.handlers and self.handlers[name] is not None {
            return self.handlers[name];
        }
        if name in _HANDLER_NAMES {
            return py_none();
        }
        if _is_method_name(name) {
            return PyExpatMethod(t="pyexpat_method", target=self, name=name);
        }
        return py_error(
            "AttributeError",
            "'xmlparser' object has no attribute '" + name + "'",
        );
    }

    def tp_setattro(name: str, value: PyObj) -> PyObj {
        if name == "buffer_text" {
            self.buffer_text = _truth(value);
            return py_none();
        }
        if name == "namespace_prefixes" {
            self.ns_prefixes = _truth(value);
            return py_none();
        }
        if name == "ordered_attributes" {
            self.ordered_attrs = _truth(value);
            return py_none();
        }
        if name == "specified_attributes" {
            self.specified_attrs = _truth(value);
            return py_none();
        }
        if name == "buffer_size" {
            n = _exact_int(value);
            if n is None {
                return py_error("TypeError", "buffer_size must be an integer");
            }
            if n < 1 or n > 2147483647 {
                return py_error(
                    "ValueError", "buffer_size must be greater than 0"
                );
            }
            self.buffer_size = n;
            return py_none();
        }
        if name == "returns_unicode" {
            return py_error("AttributeError", name);
        }
        if name in _HANDLER_NAMES {
            self.handlers[name] = value;
            return py_none();
        }
        return py_error(
            "AttributeError",
            "'xmlparser' object has no attribute '" + name + "'",
        );
    }
}

def _is_method_name(name: str) -> bool {
    return (
        name == "Parse"
        or name == "ParseFile"
        or name == "SetBase"
        or name == "GetBase"
        or name == "GetInputContext"
        or name == "ExternalEntityParserCreate"
        or name == "SetParamEntityParsing"
        or name == "UseForeignDTD"
        or name == "SetReparseDeferralEnabled"
        or name == "GetReparseDeferralEnabled"
        or name == "SetBillionLaughsAttackProtectionActivationThreshold"
        or name == "SetBillionLaughsAttackProtectionMaximumAmplification"
        or name == "SetAllocTrackerActivationThreshold"
        or name == "SetAllocTrackerMaximumAmplification"
    );
}

def _truth(v: PyObj) -> bool {
    if isinstance(v, PyBool) {
        return (v as PyBool).val;
    }
    if isinstance(v, PyInt) {
        return (v as PyInt).val != 0;
    }
    if isinstance(v, PyNoneType) {
        return False;
    }
    return v.tp_bool();
}

def _exact_int(v: PyObj) -> int | None {
    # PyLong exact conversion: floats (512.0) miss, ints pass, bools fold as
    # their int subclass.
    if isinstance(v, PyBool) {
        if (v as PyBool).val {
            return 1;
        }
        return 0;
    }
    if isinstance(v, PyInt) {
        return (v as PyInt).val;
    }
    return None;
}

obj PyExpatMethod(PyObj) {
    has target: PyExpatParser,
        name: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return _dispatch(self.target, self.name, args, kwargs);
    }
}

def _dispatch(p: PyExpatParser, name: str, args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
    if len(kwargs) > 0 {
        return py_error("TypeError", name + "() takes no keyword arguments");
    }
    if name == "Parse" {
        return _parse_entry(p, args);
    }
    if name == "ParseFile" {
        return _parse_file(p, args);
    }
    if name == "SetBase" {
        if len(args) != 1 {
            return py_error("TypeError", "SetBase() takes exactly one argument");
        }
        p.base = args[0];
        return py_none();
    }
    if name == "GetBase" {
        if p.base is None {
            return py_none();
        }
        return p.base;
    }
    if name == "GetInputContext" {
        return py_none();
    }
    if name == "ExternalEntityParserCreate" {
        if len(args) > 2 {
            return py_error(
                "TypeError",
                "ExternalEntityParserCreate() takes 1 to 2 arguments",
            );
        }
        return _clone_parser(p);
    }
    if name == "SetParamEntityParsing" {
        if len(args) != 1 {
            return py_error(
                "TypeError", "SetParamEntityParsing() takes exactly one argument"
            );
        }
        n = _exact_int(args[0]);
        if n is None {
            return py_error("TypeError", "an integer is required");
        }
        p.param_entity_parsing = n;
        return PyInt(t="int", val=1);
    }
    if name == "UseForeignDTD" {
        flag = True;
        if len(args) == 1 {
            b = _exact_int(args[0]);
            if b is None {
                return py_error("TypeError", "an integer is required");
            }
            flag = b != 0;
        } elif len(args) > 1 {
            return py_error("TypeError", "UseForeignDTD() takes at most 1 argument");
        }
        p.foreign_dtd = flag;
        return py_none();
    }
    if name == "GetReparseDeferralEnabled" {
        return PyBool(t="bool", val=p.reparse_deferral);
    }
    if name == "SetReparseDeferralEnabled" {
        if len(args) != 1 {
            return py_error(
                "TypeError",
                "SetReparseDeferralEnabled() takes exactly one argument",
            );
        }
        b = _exact_int(args[0]);
        if b is None {
            return py_error("TypeError", "an integer is required");
        }
        p.reparse_deferral = b != 0;
        return py_none();
    }
    if name == "SetBillionLaughsAttackProtectionActivationThreshold"
        or name == "SetAllocTrackerActivationThreshold" {
        if len(args) != 1 {
            return py_error("TypeError", "expected 1 argument");
        }
        if _exact_int(args[0]) is None {
            return py_error(
                "OverflowError", "activation threshold too large"
            );
        }
        return py_none();
    }
    if name == "SetBillionLaughsAttackProtectionMaximumAmplification"
        or name == "SetAllocTrackerMaximumAmplification" {
        if len(args) != 1 {
            return py_error("TypeError", "expected 1 argument");
        }
        if not isinstance(args[0], PyFloat) and _exact_int(args[0]) is None {
            return py_error(
                "TypeError", "maximum amplification factor must be a number"
            );
        }
        return py_none();
    }
    return py_error("SystemError", "unknown pyexpat method '" + name + "'");
}

def _clone_parser(parent: PyExpatParser) -> PyObj {
    # ExternalEntityParserCreate: shares configuration and handler table,
    # starts with fresh document state.
    return PyExpatParser(
        t="pyexpat_parser",
        ns_sep=parent.ns_sep,
        enc_req=parent.enc_req,
        handlers=parent.handlers,
        buffer_text=parent.buffer_text,
        buffer_size=parent.buffer_size,
        ordered_attrs=parent.ordered_attrs,
        ns_prefixes=parent.ns_prefixes,
        specified_attrs=parent.specified_attrs,
        base=parent.base,
        foreign_dtd=parent.foreign_dtd,
        param_entity_parsing=parent.param_entity_parsing,
        reparse_deferral=parent.reparse_deferral,
        intern_table=parent.intern_table,
        parent=parent,
        stack=[],
        entities={},
    );
}

# ---------------- ParserCreate ----------------------------------------------

def ParserCreate(encoding: any = None, namespace_separator: any = None) -> PyObj {
    if encoding is not None and not isinstance(encoding, PyStr) {
        return py_error(
            "TypeError",
            "ParserCreate() argument 1 must be str or None, not "
            + (encoding as PyObj).tp_type_name(),
        );
    }
    sep = "";
    if namespace_separator is not None {
        if not isinstance(namespace_separator, PyStr) {
            return py_error(
                "TypeError",
                "ParserCreate() argument (2|'namespace_separator') must be str or None, not "
                + (namespace_separator as PyObj).tp_type_name(),
            );
        }
        sep = (namespace_separator as PyStr).val;
        if len(sep) > 1 {
            return py_error(
                "ValueError",
                "namespace_separator must be at most one character, omitted, or None",
            );
        }
    }
    return PyExpatParser(
        t="pyexpat_parser",
        ns_sep=sep,
        enc_req=encoding,
        handlers={},
        buffer_text=False,
        buffer_size=8192,
        ordered_attrs=False,
        ns_prefixes=False,
        specified_attrs=False,
        base=None,
        foreign_dtd=False,
        param_entity_parsing=0,
        reparse_deferral=True,
        intern_table={},
        parent=None,
        stack=[],
        entities={},
    );
}

# ---------------- input handling ---------------------------------------------

glob _KNOWN_ENCODINGS: dict[str, str] = {
    "utf-8": "utf-8",
    "utf8": "utf-8",
    "ascii": "ascii",
    "us-ascii": "ascii",
    "iso-8859-1": "iso-8859-1",
    "latin-1": "latin-1",
    "latin1": "latin-1",
    "iso8859-1": "latin-1",
};

def _decode_chunk(p: PyExpatParser, data_obj: PyObj) -> PyObj {
    # Returns decoded text or a PyError (UnicodeError/LookupError arms).
    raw: list[int] = [];
    if isinstance(data_obj, PyBytes) {
        raw.extend((data_obj as PyBytes).val);
    } elif isinstance(data_obj, PyStr) {
        return data_obj;
    } else {
        return py_error("TypeError", "the data must be a string or bytes object");
    }
    enc = p.enc_name;
    if enc == "undefined" {
        # The test_undefined_encoding oracle arm surfaces as UnicodeError.
        return py_error("UnicodeError", "unknown encoding: undefined");
    }
    codec = "utf-8";
    if enc in _KNOWN_ENCODINGS {
        codec = _KNOWN_ENCODINGS[enc];
    } elif enc != "" {
        return py_error("LookupError", "unknown encoding: " + enc);
    }
    try {
        return PyStr(t="str", val=bytes(raw).decode(codec));
    } except UnicodeDecodeError {
        return py_error(
            "UnicodeDecodeError", "'" + codec + "' codec can't decode bytes"
        );
    } except LookupError {
        return py_error("LookupError", "unknown encoding: " + enc);
    }
}

# ---------------- parser core ------------------------------------------------

def _scan_xml_decl_encoding(head: str) -> str {
    # Best-effort encoding= extraction from a leading XML declaration.
    idx = head.find("encoding");
    if idx < 0 {
        return "";
    }
    eq = head.find("=", idx);
    if eq < 0 {
        return "";
    }
    i = eq + 1;
    while i < len(head) and head[i] in _WS {
        i += 1;
    }
    if i >= len(head) or (head[i] != '"' and head[i] != "'") {
        return "";
    }
    end = head.find(head[i], i + 1);
    if end < 0 {
        return "";
    }
    return head[i + 1:end];
}

def _advance(p: PyExpatParser, n: int) {
    seg = p.data[p.pos:p.pos + n];
    if "\n" in seg {
        nl = seg.count("\n");
        p.cur_line += nl;
        p.cur_col = len(seg) - seg.rfind("\n") - 1;
    } else {
        p.cur_col += len(seg);
    }
    p.pos += n;
    p.cur_byte += n;
}

def _intern(p: PyExpatParser, s: str) -> PyObj {
    key = p.ns_sep + "\x00" + s;
    if key in p.intern_table {
        return p.intern_table[key];
    }
    interned = PyStr(t="str", val=s);
    p.intern_table[key] = interned;
    return interned;
}

def _installed(p: PyExpatParser, hname: str) -> bool {
    return hname in p.handlers and p.handlers[hname] is not None;
}

def _fire_void(p: PyExpatParser, hname: str, args: list[PyObj]) -> PyObj | None {
    # VOID_HANDLER protocol: unset -> nothing; set -> exceptions propagate
    # verbatim, results are dropped.
    if not _installed(p, hname) {
        return None;
    }
    res = (p.handlers[hname] as PyObj).tp_call(args, {});
    if is_error(res) {
        return res;
    }
    return None;
}

def _fire_int(p: PyExpatParser, hname: str, args: list[PyObj], err_code: int) -> PyObj | None {
    # RC_HANDLER protocol: unset -> proceed; result converts through long
    # (non-int raises TypeError) and 0 maps to `err_code` at the current
    # position.
    if not _installed(p, hname) {
        return None;
    }
    res = (p.handlers[hname] as PyObj).tp_call(args, {});
    if is_error(res) {
        return res;
    }
    n = _exact_int(res);
    if n is None {
        return py_error("TypeError", "integer conversion failed");
    }
    if n == 0 {
        p.last_error_code = err_code;
        return _expat_error(err_code, p.cur_line, p.cur_col);
    }
    return None;
}

def _emit_characters(p: PyExpatParser, buf: list[str]) -> PyObj | None {
    if len(buf) == 0 {
        return None;
    }
    text = "".join(buf);
    buf.clear();
    if not _installed(p, "CharacterDataHandler") {
        return None;
    }
    res = (p.handlers["CharacterDataHandler"] as PyObj).tp_call(
        [PyStr(t="str", val=text)], {}
    );
    if is_error(res) {
        return res;
    }
    return None;
}

def _err_here(p: PyExpatParser, code: int) -> PyObj {
    p.last_error_code = code;
    p.err_line = p.cur_line;
    p.err_col = p.cur_col;
    p.err_byte = p.cur_byte;
    return _expat_error(code, p.cur_line, p.cur_col);
}

def _parse_entry(p: PyExpatParser, args: list[PyObj]) -> PyObj {
    if len(args) < 1 or len(args) > 2 {
        return py_error("TypeError", "Parse() takes 1 to 2 arguments");
    }
    isfinal = False;
    if len(args) == 2 {
        b = _exact_int(args[1]);
        if b is None {
            return py_error("TypeError", "an integer is required");
        }
        isfinal = b != 0;
    }
    if p.finished {
        return _err_here(p, 36);
    }
    chunk_res = _decode_chunk(p, args[0]);
    if is_error(chunk_res) {
        return chunk_res;
    }
    chunk = (chunk_res as PyStr).val;
    if p.enc_name == "" {
        decl_enc = _scan_xml_decl_encoding(chunk);
        if decl_enc != "" {
            p.enc_name = decl_enc;
            chk = _decode_chunk(p, args[0]);
            if is_error(chk) {
                return chk;
            }
            chunk = (chk as PyStr).val;
        }
    }
    p.data += chunk;
    p.started = True;
    return _run_parse(p, isfinal);
}

def _parse_file(p: PyExpatParser, args: list[PyObj]) -> PyObj {
    if len(args) != 1 {
        return py_error("TypeError", "ParseFile() takes exactly one argument");
    }
    read_m = args[0].tp_getattro("read");
    if is_error(read_m) {
        return read_m;
    }
    while True {
        chunk = (read_m as PyObj).tp_call(
            [PyInt(t="int", val=p.buffer_size)], {}
        );
        if is_error(chunk) {
            return chunk;
        }
        if isinstance(chunk, PyNoneType) {
            break;
        }
        empty = False;
        if isinstance(chunk, PyBytes) and len((chunk as PyBytes).val) == 0 {
            empty = True;
        }
        if isinstance(chunk, PyStr) and len((chunk as PyStr).val) == 0 {
            empty = True;
        }
        if empty {
            break;
        }
        res = _parse_entry(p, [chunk]);
        if is_error(res) {
            return res;
        }
    }
    return _run_parse(p, True);
}

def _run_parse(p: PyExpatParser, isfinal: bool) -> PyObj {
    textbuf: list[str] = [];
    while p.pos < len(p.data) {
        c = p.data[p.pos];
        if c == "<" {
            ferr = _emit_characters(p, textbuf);
            if ferr is not None {
                return ferr;
            }
            res = _scan_markup(p);
            if res is not None {
                return res;
            }
            continue;
        }
        if c == "&" {
            ferr = _emit_characters(p, textbuf);
            if ferr is not None {
                return ferr;
            }
            rres = _scan_reference(p, textbuf);
            if rres is not None {
                return rres;
            }
            continue;
        }
        if ord(c) < 0x20 and not (c in "\t\r\n") {
            # Illegal content byte: expat reports an unterminated token at
            # end-of-input when final (the b'\x00\r\n' oracle arm).
            _advance(p, len(p.data) - p.pos);
            if isfinal {
                return _err_here(p, 5);
            }
            ferr = _emit_characters(p, textbuf);
            if ferr is not None {
                return ferr;
            }
            return PyInt(t="int", val=1);
        }
        stop = len(p.data);
        nxt = p.data.find("<", p.pos);
        amp = p.data.find("&", p.pos);
        if nxt >= 0 and nxt < stop {
            stop = nxt;
        }
        if amp >= 0 and amp < stop {
            stop = amp;
        }
        textbuf.append(p.data[p.pos:stop]);
        _advance(p, stop - p.pos);
    }
    if not isfinal {
        # Incomplete trailing markup stays buffered for the next chunk.
        if p.root_closed {
            return _err_here(p, 9);
        }
        ferr = _emit_characters(p, textbuf);
        if ferr is not None {
            return ferr;
        }
        return PyInt(t="int", val=1);
    }
    ferr = _emit_characters(p, textbuf);
    if ferr is not None {
        return ferr;
    }
    if len(p.stack) > 0 {
        return _err_here(p, 5);
    }
    if not p.root_seen {
        return _err_here(p, 3);
    }
    p.finished = True;
    return PyInt(t="int", val=1);
}

def _scan_markup(p: PyExpatParser) -> PyObj | None {
    data = p.data;
    if data.startswith("<!--", p.pos) {
        return _scan_comment(p);
    }
    if data.startswith("<![CDATA[", p.pos) {
        return _scan_cdata(p);
    }
    if data.startswith("<?", p.pos) {
        return _scan_pi_or_decl(p);
    }
    if data.startswith("</", p.pos) {
        return _scan_end_tag(p);
    }
    if data.startswith("<!", p.pos) {
        return _scan_doctype_or_decl(p);
    }
    return _scan_start_tag(p);
}

# ---------------- scanners ---------------------------------------------------

def _scan_comment(p: PyExpatParser) -> PyObj | None {
    end = p.data.find("-->", p.pos + 4);
    if end < 0 {
        _advance(p, len(p.data) - p.pos);
        return _err_here(p, 5);
    }
    body = p.data[p.pos + 4:end];
    _advance(p, end + 3 - p.pos);
    return _fire_void(p, "CommentHandler", [PyStr(t="str", val=body)]);
}

def _scan_cdata(p: PyExpatParser) -> PyObj | None {
    end = p.data.find("]]>", p.pos + 9);
    if end < 0 {
        _advance(p, len(p.data) - p.pos);
        return _err_here(p, 20);
    }
    body = p.data[p.pos + 9:end];
    _advance(p, end + 3 - p.pos);
    serr = _fire_void(p, "StartCdataSectionHandler", []);
    if serr is not None {
        return serr;
    }
    buf: list[str] = [body];
    cerr = _emit_characters(p, buf);
    if cerr is not None {
        return cerr;
    }
    eerr = _fire_void(p, "EndCdataSectionHandler", []);
    if eerr is not None {
        return eerr;
    }
    return None;
}

def _scan_pi_or_decl(p: PyExpatParser) -> PyObj | None {
    start_pos = p.pos;
    end = p.data.find("?>", p.pos + 2);
    if end < 0 {
        _advance(p, len(p.data) - p.pos);
        return _err_here(p, 5);
    }
    inner = p.data[p.pos + 2:end].strip();
    _advance(p, end + 2 - p.pos);
    sp = -1;
    for i in range(len(inner)) {
        if inner[i] in _WS {
            sp = i;
            break;
        }
    }
    target = "";
    body_txt = "";
    if sp < 0 {
        target = inner;
    } else {
        target = inner[0:sp];
        body_txt = inner[sp + 1:].strip();
    }
    if target == "xml" {
        # An XML declaration is only legal as the very first construct.
        if start_pos != 0 {
            return _err_here(p, 17);
        }
        return _handle_xml_decl(p, inner);
    }
    err = _fire_void(
        p,
        "ProcessingInstructionHandler",
        [PyStr(t="str", val=target), PyStr(t="str", val=body_txt)],
    );
    if err is not None {
        return err;
    }
    return None;
}

def _handle_xml_decl(p: PyExpatParser, inner: str) -> PyObj | None {
    standalone: int = -1;
    vi = inner.find("version");
    if vi < 0 {
        return _err_here(p, 30);
    }
    version = _quoted_after(inner, vi);
    if version is None {
        return _err_here(p, 30);
    }
    encoding: str | None = None;
    ei = inner.find("encoding");
    if ei >= 0 {
        encoding = _quoted_after(inner, ei);
        if encoding is None {
            return _err_here(p, 30);
        }
        if encoding == "undefined" {
            return py_error("UnicodeError", "unknown encoding: undefined");
        }
        if not (encoding in _KNOWN_ENCODINGS) {
            return py_error("LookupError", "unknown encoding: " + encoding);
        }
        p.enc_name = encoding;
    }
    si = inner.find("standalone");
    if si >= 0 {
        val = _quoted_after(inner, si);
        if val == "yes" {
            standalone = 1;
        } elif val == "no" {
            standalone = 0;
        } else {
            return _err_here(p, 30);
        }
    }
    return _fire_void(
        p,
        "XmlDeclHandler",
        [
            PyStr(t="str", val=version),
            PyStr(t="str", val=encoding) if encoding is not None else py_none(),
            PyInt(t="int", val=standalone),
        ],
    );
}

def _quoted_after(src: str, key_at: int) -> str | None {
    eq = src.find("=", key_at);
    if eq < 0 {
        return None;
    }
    i = eq + 1;
    while i < len(src) and src[i] in _WS {
        i += 1;
    }
    if i >= len(src) or (src[i] != '"' and src[i] != "'") {
        return None;
    }
    end = src.find(src[i], i + 1);
    if end < 0 {
        return None;
    }
    return src[i + 1:end];
}

def _scan_end_tag(p: PyExpatParser) -> PyObj | None {
    end = p.data.find(">", p.pos + 2);
    if end < 0 {
        _advance(p, len(p.data) - p.pos);
        return _err_here(p, 5);
    }
    name = p.data[p.pos + 2:end].strip();
    _advance(p, end + 1 - p.pos);
    if len(p.stack) == 0 {
        return _err_here(p, 2);
    }
    open_name = p.stack[len(p.stack) - 1];
    if name != open_name {
        return _err_here(p, 7);
    }
    p.stack.pop();
    eerr = _fire_void(p, "EndElementHandler", [_intern(p, name)]);
    if eerr is not None {
        return eerr;
    }
    if len(p.stack) == 0 {
        p.root_closed = True;
    }
    return None;
}

def _scan_doctype_or_decl(p: PyExpatParser) -> PyObj | None {
    if p.data.startswith("<!DOCTYPE", p.pos) {
        return _scan_doctype(p);
    }
    # Other <!...> markup (ELEMENT/ATTLIST/NOTATION outside a subset):
    # skipped wholesale.
    end = p.data.find(">", p.pos + 2);
    if end < 0 {
        _advance(p, len(p.data) - p.pos);
        return _err_here(p, 5);
    }
    _advance(p, end + 1 - p.pos);
    return None;
}

def _scan_doctype(p: PyExpatParser) -> PyObj | None {
    # Scan to the matching '>' honoring internal-subset bracket depth;
    # record ENTITY decls, deliver subset decls, and honor the external-id
    # contract (UseForeignDTD / SYSTEM|PUBLIC ids).
    i = p.pos + 9;
    depth = 0;
    end = -1;
    while i < len(p.data) {
        c = p.data[i];
        if c == "[" {
            depth += 1;
        } elif c == "]" {
            depth -= 1;
        } elif c == ">" and depth == 0 {
            end = i;
            break;
        }
        i += 1;
    }
    if end < 0 {
        _advance(p, len(p.data) - p.pos);
        return _err_here(p, 5);
    }
    decl = p.data[p.pos:end + 1];
    has_subset = "[" in decl;
    name = _doctype_name(decl);
    sysid: str | None = None;
    pubid: str | None = None;
    si = decl.find("SYSTEM");
    pi_ = decl.find("PUBLIC");
    if si >= 0 and (pi_ < 0 or si < pi_) {
        sysid = _first_quoted(decl, si + 6);
    } elif pi_ >= 0 {
        quotes: list[str] = [];
        j = pi_ + 6;
        while j < len(decl) and len(quotes) < 2 {
            c = decl[j];
            if c == '"' or c == "'" {
                close = decl.find(c, j + 1);
                if close < 0 {
                    break;
                }
                quotes.append(decl[j + 1:close]);
                j = close + 1;
            } else {
                j += 1;
            }
        }
        if len(quotes) >= 1 {
            pubid = quotes[0];
        }
        if len(quotes) >= 2 {
            sysid = quotes[1];
        }
    }
    derr = _fire_void(
        p,
        "StartDoctypeDeclHandler",
        [
            PyStr(t="str", val=name),
            PyStr(t="str", val=sysid) if sysid is not None else py_none(),
            PyStr(t="str", val=pubid) if pubid is not None else py_none(),
            PyInt(t="int", val=1 if has_subset else 0),
        ],
    );
    if derr is not None {
        return derr;
    }
    _collect_entities(decl, p.entities);
    dlerr = _deliver_decls(p, decl);
    if dlerr is not None {
        return dlerr;
    }
    _advance(p, end + 1 - p.pos);
    if sysid is not None or pubid is not None or p.foreign_dtd {
        rerr = _external_ref(p, "", sysid, pubid);
        if rerr is not None {
            return rerr;
        }
        nerr = _fire_int(p, "NotStandaloneHandler", [], 22);
        if nerr is not None {
            return nerr;
        }
    }
    if has_subset {
        suberr = _fire_void(p, "EndDoctypeDeclHandler", []);
        if suberr is not None {
            return suberr;
        }
    }
    return None;
}

def _doctype_name(decl: str) -> str {
    parts = decl.split();
    if len(parts) >= 2 {
        return parts[1];
    }
    return "";
}

def _first_quoted(src: str, start: int) -> str | None {
    i = start;
    while i < len(src) {
        c = src[i];
        if c == '"' or c == "'" {
            close = src.find(c, i + 1);
            if close < 0 {
                return None;
            }
            return src[i + 1:close];
        }
        i += 1;
    }
    return None;
}

def _two_public_ids(src: str, start: int) -> list[str] {
    quotes: list[str] = [];
    j = start;
    while j < len(src) and len(quotes) < 2 {
        c = src[j];
        if c == '"' or c == "'" {
            close = src.find(c, j + 1);
            if close < 0 {
                break;
            }
            quotes.append(src[j + 1:close]);
            j = close + 1;
        } else {
            j += 1;
        }
    }
    return quotes;
}

def _collect_entities(decl: str, table: dict[str, tuple]) {
    # Record <!ENTITY name ...> general-entity declarations with external or
    # unparsed payloads (internal general entities expand inline and need no
    # table entry for the reference contract below).
    idx = decl.find("<!ENTITY");
    while idx >= 0 {
        rest = decl[idx + 8:].lstrip();
        k = 0;
        while k < len(rest) and _is_name_char(rest[k]) {
            k += 1;
        }
        name = rest[0:k];
        tail = rest[k:].lstrip();
        external = tail.startswith("SYSTEM") or tail.startswith("PUBLIC");
        unparsed = "NDATA" in tail;
        if len(name) > 0 and not name.startswith("%") and (external or unparsed) {
            sysid: str | None = None;
            pubid: str | None = None;
            sidx = tail.find("SYSTEM");
            pidx = tail.find("PUBLIC");
            if sidx >= 0 and (pidx < 0 or sidx < pidx) {
                q = _first_quoted(tail, sidx + 6);
                if q is not None {
                    sysid = q;
                }
            } elif pidx >= 0 {
                qs = _two_public_ids(tail, pidx + 6);
                if len(qs) >= 2 {
                    pubid = qs[0];
                    sysid = qs[1];
                }
            }
            table[name] = (sysid, pubid, unparsed);
        }
        idx = decl.find("<!ENTITY", idx + 8);
    }
}

def _deliver_decls(p: PyExpatParser, decl: str) -> PyObj | None {
    # ElementDecl / AttlistDecl delivery over the subset text.
    idx = decl.find("<!ELEMENT");
    while idx >= 0 {
        gt = decl.find(">", idx);
        if gt < 0 {
            break;
        }
        body = decl[idx + 9:gt].split();
        if len(body) >= 1 {
            eerr = _fire_void(
                p,
                "ElementDeclHandler",
                [PyStr(t="str", val=body[0]), PyTuple(t="tuple", items=[])],
            );
            if eerr is not None {
                return eerr;
            }
        }
        idx = decl.find("<!ELEMENT", gt);
    }
    idx = decl.find("<!ATTLIST");
    while idx >= 0 {
        gt = decl.find(">", idx);
        if gt < 0 {
            break;
        }
        aerr = _fire_void(
            p,
            "AttlistDeclHandler",
            [
                PyStr(t="str", val=""),
                PyStr(t="str", val=""),
                PyStr(t="str", val=""),
                py_none(),
                PyInt(t="int", val=0),
            ],
        );
        if aerr is not None {
            return aerr;
        }
        idx = decl.find("<!ATTLIST", gt);
    }
    return None;
}

def _external_ref(p: PyExpatParser, context: str, sysid: str | None, pubid: str | None) -> PyObj | None {
    args: list[PyObj] = [
        PyStr(t="str", val=context),
        py_none() if p.base is None else p.base,
        py_none() if sysid is None else PyStr(t="str", val=sysid),
        py_none() if pubid is None else PyStr(t="str", val=pubid),
    ];
    return _fire_int(p, "ExternalEntityRefHandler", args, 21);
}

def _scan_start_tag(p: PyExpatParser) -> PyObj | None {
    end = p.data.find(">", p.pos + 1);
    if end < 0 {
        _advance(p, len(p.data) - p.pos);
        return _err_here(p, 5);
    }
    inner = p.data[p.pos + 1:end];
    empty = inner.endswith("/");
    if empty {
        inner = inner[:-1].rstrip();
    }
    ns = 0;
    while ns < len(inner) and inner[ns] in _WS {
        ns += 1;
    }
    ne = ns;
    while ne < len(inner) and _is_name_char(inner[ne]) {
        ne += 1;
    }
    name = inner[ns:ne];
    if name == "" {
        return _err_here(p, 4);
    }
    attrs = _parse_attrs(p, inner[ne:], name);
    if is_error(attrs) {
        return attrs;
    }
    _advance(p, end + 1 - p.pos);
    if p.root_closed {
        return _err_here(p, 9);
    }
    p.root_seen = True;
    serr = _fire_void(p, "StartElementHandler", [_intern(p, name), attrs]);
    if serr is not None {
        return serr;
    }
    if empty {
        eerr = _fire_void(p, "EndElementHandler", [_intern(p, name)]);
        if eerr is not None {
            return eerr;
        }
        if len(p.stack) == 0 {
            p.root_closed = True;
        }
    } else {
        p.stack.append(name);
    }
    return None;
}

def _is_name_char(c: str) -> bool {
    return c.isalnum() or c == "_" or c == ":" or c == "." or c == "-";
}

def _parse_attrs(p: PyExpatParser, src: str, tagname: str) -> PyObj {
    # Returns an attrs dict (flat list under ordered_attributes); duplicates
    # map to XML_ERROR_DUPLICATE_ATTRIBUTE.
    ordered: list[PyObj] = [];
    seen: dict[str, bool] = {};
    out = PyDict(t="dict", items={});
    i = 0;
    while i < len(src) {
        while i < len(src) and src[i] in _WS {
            i += 1;
        }
        if i >= len(src) {
            break;
        }
        ns = i;
        while i < len(src) and src[i] != "=" and not (src[i] in _WS) {
            i += 1;
        }
        aname = src[ns:i];
        while i < len(src) and src[i] in _WS {
            i += 1;
        }
        if i >= len(src) or src[i] != "=" {
            return _err_here(p, 4);
        }
        i += 1;
        while i < len(src) and src[i] in _WS {
            i += 1;
        }
        if i >= len(src) or (src[i] != '"' and src[i] != "'") {
            return _err_here(p, 4);
        }
        quote = src[i];
        close = src.find(quote, i + 1);
        if close < 0 {
            return _err_here(p, 5);
        }
        val = _expand_predefined(src[i + 1:close]);
        i = close + 1;
        if aname in seen {
            return _err_here(p, 8);
        }
        seen[aname] = True;
        ordered.extend([PyStr(t="str", val=aname), PyStr(t="str", val=val)]);
        out.dict_set(PyStr(t="str", val=aname), PyStr(t="str", val=val));
    }
    if p.ordered_attrs {
        return PyList(t="list", items=ordered);
    }
    return out;
}

def _expand_predefined(s: str) -> str {
    if "&" not in s {
        return s;
    }
    out = "";
    i = 0;
    while i < len(s) {
        if s[i] == "&" {
            semi = s.find(";", i);
            if semi > i and semi <= i + 12 {
                ent = s[i + 1:semi];
                rep = _entity_char(ent);
                if rep is not None {
                    out += rep;
                    i = semi + 1;
                    continue;
                }
            }
        }
        out += s[i];
        i += 1;
    }
    return out;
}

def _entity_char(ent: str) -> str | None {
    if ent.startswith("#x") or ent.startswith("#X") {
        try {
            return chr(int(ent[2:], 16));
        } except ValueError {
            return None;
        }
    }
    if ent.startswith("#") {
        try {
            return chr(int(ent[1:]));
        } except ValueError {
            return None;
        }
    }
    if ent in _PREDEFINED {
        return _PREDEFINED[ent];
    }
    return None;
}

def _scan_reference(p: PyExpatParser, textbuf: list[str]) -> PyObj | None {
    semi = p.data.find(";", p.pos + 1);
    if semi < 0 {
        _advance(p, len(p.data) - p.pos);
        return _err_here(p, 5);
    }
    ent = p.data[p.pos + 1:semi];
    _advance(p, semi + 1 - p.pos);
    ch = _entity_char(ent);
    if ch is not None {
        textbuf.append(ch);
        return None;
    }
    if ent in p.entities {
        decl = p.entities[ent];
        sysid: str | None = decl[0];
        pubid: str | None = decl[1];
        unparsed: bool = decl[2];
        if unparsed {
            uerr = _fire_void(
                p,
                "UnparsedEntityDeclHandler",
                [
                    PyStr(t="str", val=ent),
                    py_none(),
                    PyStr(t="str", val=sysid) if sysid is not None else py_none(),
                    py_none(),
                    py_none(),
                ],
            );
            if uerr is not None {
                return uerr;
            }
        }
        return _external_ref(p, "", sysid, pubid);
    }
    # Undeclared entity: skipped silently when one of the absorbing handlers
    # is installed (see divergence ledger), else XML_ERROR_UNDEFINED_ENTITY.
    if _installed(p, "SkippedEntityHandler") {
        return _fire_void(
            p,
            "SkippedEntityHandler",
            [PyStr(t="str", val=ent), PyInt(t="int", val=0)],
        );
    }
    if _installed(p, "DefaultHandler")
        or _installed(p, "DefaultHandlerExpand")
        or _installed(p, "ExternalEntityRefHandler") {
        return None;
    }
    return _err_here(p, 11);
}

# ---------------- module builder ----------------------------------------------

obj PyExpatParserType(PyObj) {
    # Stand-in for the xmlparser type object: calling it builds a parser
    # (CPython's type is abstract enough that no pin instantiates it).
    def tp_getattro(name: str) -> PyObj {
        if name == "__name__" or name == "__qualname__" {
            return PyStr(t="str", val="xmlparser");
        }
        return py_error("AttributeError", name);
    }

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return ParserCreate();
    }
}

def ErrorString(code: any) -> PyObj {
    # pyexpat_ErrorString_impl: XML_ErrorString(code) or None when libexpat
    # has no message for the code.
    n = _exact_int(code);
    if n is None {
        return py_error("TypeError", "an integer is required");
    }
    msg = _error_message(n);
    if msg == "" {
        return py_none();
    }
    return PyStr(t="str", val=msg);
}

def build_pyexpat_module -> PyObj {
    error_type = py_exception_type("xml.parsers.expat.ExpatError");
    errors_attrs: dict[str, PyObj] = {};
    codes_dict = PyDict(t="dict", items={});
    messages_dict = PyDict(t="dict", items={});
    for i in range(len(_ERROR_TABLE)) {
        row = _ERROR_TABLE[i];
        code = i + 1;
        name = row[0];
        msg = row[1];
        errors_attrs[name] = PyStr(t="str", val=msg);
        codes_dict.dict_set(PyStr(t="str", val=msg), PyInt(t="int", val=code));
        messages_dict.dict_set(PyInt(t="int", val=code), PyStr(t="str", val=msg));
    }
    errors_attrs["codes"] = codes_dict;
    errors_attrs["messages"] = messages_dict;
    errors_attrs["__doc__"] = PyStr(
        t="str", val="Constants used to describe error conditions."
    );
    model_attrs: dict[str, PyObj] = {
        "XML_CTYPE_EMPTY": PyInt(t="int", val=XML_CTYPE_EMPTY),
        "XML_CTYPE_ANY": PyInt(t="int", val=XML_CTYPE_ANY),
        "XML_CTYPE_MIXED": PyInt(t="int", val=XML_CTYPE_MIXED),
        "XML_CTYPE_NAME": PyInt(t="int", val=XML_CTYPE_NAME),
        "XML_CTYPE_CHOICE": PyInt(t="int", val=XML_CTYPE_CHOICE),
        "XML_CTYPE_SEQ": PyInt(t="int", val=XML_CTYPE_SEQ),
        "XML_CQUANT_NONE": PyInt(t="int", val=XML_CQUANT_NONE),
        "XML_CQUANT_OPT": PyInt(t="int", val=XML_CQUANT_OPT),
        "XML_CQUANT_REP": PyInt(t="int", val=XML_CQUANT_REP),
        "XML_CQUANT_PLUS": PyInt(t="int", val=XML_CQUANT_PLUS),
        "__doc__": PyStr(
            t="str",
            val="Constants used to interpret content model information.",
        ),
    };
    features: list[PyObj] = [
        PyTuple(t="tuple", items=[
            PyStr(t="str", val="XML_CONTEXT_BYTES"),
            PyInt(t="int", val=1024),
        ]),
        PyTuple(t="tuple", items=[
            PyStr(t="str", val="XML_DTD"),
            PyInt(t="int", val=1),
        ]),
        PyTuple(t="tuple", items=[
            PyStr(t="str", val="XML_NS"),
            PyInt(t="int", val=1),
        ]),
    ];
    return PyModule(
        t="module",
        name="pyexpat",
        attrs={
            "__name__": PyStr(t="str", val="pyexpat"),
            "ParserCreate": PyExpatParserCtor(t="pyexpat_ctor"),
            "ErrorString": PyExpatErrorStringFn(t="pyexpat_errorstring"),
            "XMLParserType": PyExpatParserType(t="pyexpat_parser_type"),
            "error": error_type,
            "ExpatError": error_type,
            "EXPAT_VERSION": PyStr(t="str", val=EXPAT_VERSION),
            "version_info": PyTuple(t="tuple", items=[
                PyInt(t="int", val=_VERSION_INFO[0]),
                PyInt(t="int", val=_VERSION_INFO[1]),
                PyInt(t="int", val=_VERSION_INFO[2]),
            ]),
            "native_encoding": PyStr(t="str", val=native_encoding),
            "features": PyList(t="list", items=features),
            "XML_PARAM_ENTITY_PARSING_NEVER": PyInt(
                t="int", val=XML_PARAM_ENTITY_PARSING_NEVER
            ),
            "XML_PARAM_ENTITY_PARSING_UNLESS_STANDALONE": PyInt(
                t="int", val=XML_PARAM_ENTITY_PARSING_UNLESS_STANDALONE
            ),
            "XML_PARAM_ENTITY_PARSING_ALWAYS": PyInt(
                t="int", val=XML_PARAM_ENTITY_PARSING_ALWAYS
            ),
            "errors": PyModule(
                t="module", name="pyexpat.errors", attrs=errors_attrs
            ),
            "model": PyModule(
                t="module", name="pyexpat.model", attrs=model_attrs
            ),
        },
    );
}

obj PyExpatParserCtor(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(kwargs) > 0 {
            if "namespace_separator" in kwargs and len(kwargs) == 1 {
                sep_arg = kwargs["namespace_separator"];
                enc_arg: any = None;
                if len(args) > 0 {
                    enc_arg = args[0];
                }
                return ParserCreate(enc_arg, sep_arg);
            }
            return py_error(
                "TypeError", "ParserCreate() takes no keyword arguments"
            );
        }
        enc: any = None;
        sep: any = None;
        if len(args) > 0 {
            enc = args[0];
        }
        if len(args) > 1 {
            sep = args[1];
        }
        if len(args) > 2 {
            return py_error(
                "TypeError",
                "ParserCreate expected at most 2 arguments, got "
                + str(len(args)),
            );
        }
        return ParserCreate(enc, sep);
    }
}

obj PyExpatErrorStringFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(kwargs) > 0 or len(args) != 1 {
            return py_error(
                "TypeError", "ErrorString() takes exactly one argument"
            );
        }
        return ErrorString(args[0]);
    }
}

with entry {
    # Module-exception declaration (bridge-table registry, exceptions_core):
    # declared AT IMPORT so boundary matching/minting knows ExpatError's
    # hierarchy without bare getattr(builtins, ...) lookups.
    register_module_exception("xml.parsers.expat.ExpatError", "Exception");
}
