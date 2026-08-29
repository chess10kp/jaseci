# VM operation registry breaking ceval<->spoke import cycles.
# ceval.jac wires ceval_ops at module load via `with entry`; spokes
# import forwarders from ceval_api.jac (which reads this dict) instead
# of importing ceval directly. Dict item assignment mutates in place
# (same idiom as compiler_dispatch.jac).
glob ceval_ops: dict[str, any] = {};

# Frame chain accessor: ceval_exec_frame owns the slot; PyFrame in
# ceval_defs reads it through this getter so ceval_defs stays acyclic.
glob _frame_chain_slot: list[any] = [];

def jac_frame_chain_slot_ref() -> list[any] {
    return _frame_chain_slot;
}
