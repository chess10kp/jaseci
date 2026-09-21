# 1. Test initialization order.
obj Test1 {
    has var1: int,
        var2: int = 42,
        var3: int;
}

# <-- This should be syntax error.
# 2. Test if postinit is needed but not provided.
obj Test2 {
    has var1: str,
        var2: int postinit;
}

# 3. Postinit should be considered as has default initialization.
obj Test3 {
    has var1: int,
        var2: int = 42,
        var3: int postinit,
        var4: int;

    def postinit {
        self.var3 = 3;
    }
}
# <-- This is fine.
# <-- This should be syntax error.
