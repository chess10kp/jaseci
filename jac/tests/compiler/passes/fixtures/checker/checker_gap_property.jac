"""Test that @property resolves to return type on union types."""

import jaclang.compiler.frontend.unitree as uni;

def use_scope(scope: uni.UniScopeNode) {}

glob
     # Single type - property works (Path A)
     nodes: list[uni.ListVal] = [];
with entry {
    for node in nodes {
        use_scope(node.sym_tab);
    }
}

glob
     # Union type - property must also work (Path B)
     items: list[uni.AstSymbolNode] = [];
with entry {
    for i in items {
        if isinstance(i, (uni.ListVal, uni.TupleVal)) {
            use_scope(i.sym_tab);
        }
    }
}
