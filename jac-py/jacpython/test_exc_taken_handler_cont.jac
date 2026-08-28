# Regression pin: taken except handler must reach after-try continuation.
#
# Bug: a handler body that handled the exception emitted module RETURN even
# when continuation code was already laid out in after_try_epilogue, so
# statements after the try never ran. Fix: jump back to the shared epilogue
# block (compiler_exc visit_try handler success path).
import from layer9_product_exec { product_exec }

glob SRC_TAKEN_THEN_CODE = (
    "r = []\n"
    "try:\n"
    "    raise ValueError(1)\n"
    "except ValueError:\n"
    "    r.append('handled')\n"
    "r.append('after')\n"
    "assert r == ['handled', 'after'], r\n"
);

glob SRC_TAKEN_THEN_ASSIGN = (
    "try:\n"
    "    raise KeyError('k')\n"
    "except KeyError:\n"
    "    r = 'caught'\n"
    "r = r + '!'\n"
    "assert r == 'caught!', r\n"
);

test "taken handler cont: code after try runs" {
    product_exec(SRC_TAKEN_THEN_CODE);
}

test "taken handler cont: assignment after try runs" {
    product_exec(SRC_TAKEN_THEN_ASSIGN);
}
