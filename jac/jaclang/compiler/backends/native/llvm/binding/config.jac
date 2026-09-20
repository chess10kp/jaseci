import os;
import warnings;
import from ctypes { c_int, c_char_p }
import from jaclang.compiler.backends.native.llvm.binding { ffi }

with entry {
    ffi.lib.LLVMPY_HasSVMLSupport.argtypes = ();
    ffi.lib.LLVMPY_HasSVMLSupport.restype = c_int;
    ffi.lib.LLVMPY_IsStaticLibstdcxxLinkageBuild.argtypes = ();
    ffi.lib.LLVMPY_IsStaticLibstdcxxLinkageBuild.restype = c_int;
    ffi.lib.LLVMPY_IsDynamicLLVMLinkageBuild.argtypes = ();
    ffi.lib.LLVMPY_IsDynamicLLVMLinkageBuild.restype = c_int;
    ffi.lib.LLVMPY_PackageFormat.argtypes = ();
    ffi.lib.LLVMPY_PackageFormat.restype = c_char_p;
    ffi.lib.LLVMPY_LlvmAssertionsState.argtypes = ();
    ffi.lib.LLVMPY_LlvmAssertionsState.restype = c_char_p;
}

"""
    Returns True if SVML was enabled at FFI support compile time.
    """
def _has_svml -> object {
    try {
        _svml = ffi.lib.LLVMPY_HasSVMLSupport();
    } except OSError {
        return False;
    }
    if (_svml == 0) {
        return False;
    } else {
        return True;
    }
}

"""
    Returns "static" if the FFI support is statically linked against LLVM,
    returns "dynamic" otherwise.
    """
"""
    Returns "static" if the FFI support is statically linked against libstdc++,
    returns "dynamic" otherwise.
    """
"""
    Returns "wheel", "conda" or "unspecified"
    """
"""
    Returns one of "on", "off" or "unknown". Depending on whether it is
    determined that LLVM was build with assertions on, off, or is not known.
    "Is not known" is typically from a dynamic linkage against LLVM in which
    case it's not easily identified whether LLVM was built with assertions.
    """
