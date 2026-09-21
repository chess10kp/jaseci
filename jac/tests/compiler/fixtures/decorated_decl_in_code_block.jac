glob d1 = None,
     d2 = None;

@d1
class A_TopClass {}

@d1
def F_top_fn {}

@d1
class A_InEntryClass {}

@d1
obj A_InEntryObj {}

@d1
def F_in_entry_fn {}

@d1
@d2
@d1
class A_StackedDec {}

@d1
@d2
def F_stacked_fn {}

def F_outer {
    @d1
    class A_InDefBodyClass {}

    @d1
    obj A_InDefBodyObj {}

    @d1
    def F_in_def_body_fn {}
}

obj A_Container {
    def F_method {
        @d1
        class A_InMethodClass {}

        @d1
        def F_in_method_fn {}
    }
}
