# Test that bare `root` resolves to the Root type (not Unknown).
# `root` is a SpecialVarRef the type checker resolves directly to Root.
glob r = root,
     x: Root = root;
