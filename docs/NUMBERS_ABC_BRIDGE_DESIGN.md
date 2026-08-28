# numbers.py ABC virtual registration across the host bridge (DESIGN)

Status: DESIGN-FIRST (mech lane, 2026-08-28). Implementation blocked on a
single-pass scope: needs coordinated `py_issubclass` / `_abc_subclasscheck`
bridge work, not a numbers.py-only edit.

## Problem

`Lib/numbers.py` ends with virtual registrations:

```python
Integral.register(int)
```

(and analogous registrations for `float`, `complex` on their ABC bases). The
`test_abstract_numbers` pin cluster fails on guest `issubclass` checks:

- `issubclass(int, numbers.Integral)` (and Real/Complex)
- downstream `isinstance` / default-method tests that depend on those
  registrations

Evidence: `jac-py/tests/conv_abstract_numbers/conv_abstract_numbers_pins.triage.md`
(1/7 pins pass; 6 fail on assertIsSubclass or derived behavior).

## Root cause

Two independent ABC machinery paths do not meet at `issubclass`:

1. **Guest facade `_abc`** (`jac-py/jacpython/abc.jac`): `_abc_register` stores
   virtual subclasses in `_impls[id(cls)].registry`. `_abc_subclasscheck`
   walks that registry. This path works when both the ABC and the candidate are
   guest-recoverable `type` objects the facade can `id()` consistently.

2. **Host C `ABCMeta`** (`_JacABCMeta` standins in `ceval.jac`): host
   `__subclasscheck__` cannot see guest MROs; standins delegate back to guest
   `issubclass` trampolines only when *both* sides recover via
   `_jac_recover_guest`.

At module init, `Integral.register(int)` typically records the **host** `int`
type on a **guest** `numbers.Integral` class (facade `abc.ABCMeta` backed by
`_abc`). Later, `py_issubclass` (`ceval.jac:10443`) handles:

| cls | typ | current behavior |
|-----|-----|------------------|
| PyClass | PyClass | guest MRO only (no virtual registry) |
| PyClass | PyHostProxy | standin MRO / native_base name fallback |
| PyHostProxy | PyHostProxy | `_jac_host_issubclass` (host C API) |
| PyHostProxy | PyClass | **falls through to False** |

The failing pin is the last row (or host-type cls with guest ABC typ): the
virtual registration in `_impls` is never consulted, and host
`issubclass(int, Integral)` is not reached because `numbers.Integral` is not a
host type in the guest namespace.

Symmetric gap: `register(host_builtin)` stores a host type in the guest
registry, but `_p2_real_issubclass` / `_p2_virtual_subclasscheck` compare MRO
nodes that may not unify host and guest class identities.

## Target design (agreed)

**Unify virtual-subclass resolution in one bridge-aware check** used by both
`py_issubclass` and `_JacABCMeta.__subclasscheck__` fallbacks.

### Phase 1: registry lookup bridge (fixes test_abstract_numbers pins)

Add `_p2_abc_virtual_issubclass(sub, sup) -> bool` in `abc.jac`:

1. Resolve `sup` to the guest ABC class that owns `_impls[id(sup)]` (walk
   standin `_jac_guest_cls_` marker if `sup` is a host standin).
2. Resolve `sub` to a comparable type key: guest `PyClass`, or host `type` from
   `PyHostProxy`, using `_jac_hostproxy_val_is_type`.
3. If `sub` is in `data.registry` (identity or canonical host-type equality),
   return True.
4. Recurse `_p2_virtual_subclasscheck` for nested registrations (existing).

Wire into `py_issubclass` **before** the final `return False`:

```text
if _p2_abc_virtual_issubclass(normalize(cls), normalize(typ)):
    return True;
```

Normalize = guest recover OR host type extraction; exact helper signatures TBD
at implementation time.

### Phase 2: register() canonical keys

Teach `_abc_register` to store a **canonical registration key** per subclass:

- Guest `PyClass` -> `id(cls)` (current)
- Host builtin `type` -> stable host-type id (e.g. `id(int)` on the host object
  reached via `to_host`/`from_host` round-trip)

Ensures step 3 of Phase 1 hits for `Integral.register(int)` regardless of
whether `int` arrives as `PyHostProxy` or bare host `type` at the call site.

### Phase 3: isinstance symmetry

Mirror Phase 1 in `py_isinstance` / `_abc_instancecheck` for
`isinstance(0, numbers.Integral)` fast paths (uses subclass check on
`type(instance)`).

## Non-goals

- Re-implementing full `typing` protocol ABC machinery (separate cluster).
- Changing `numbers.py` itself (stdlib subject; bridge must absorb it).
- Host-side mutation of CPython's global ABC registries.

## Verification

1. `conv_abstract_numbers_pins.jac`: `TestNumbers.test_{int,float,complex}`
   GREEN.
2. `TestNumbersDefaultMethods` cluster GREEN (depends on Phase 1 + existing
   operator/divmod bridges).
3. No regression on `conv_fractions` pins that call `numbers.Rational.register`
   on guest classes (guest-guest path must remain unchanged).

## Files (implementation pass)

| File | Change |
|------|--------|
| `jac-py/jacpython/abc.jac` | `_p2_abc_virtual_issubclass`, canonical register keys |
| `jac-py/jacpython/ceval.jac` | `py_issubclass` / `py_isinstance` bridge hook |
| (tests) | none required for design sign-off; pins gate the implementation PR |

## Risks

- **Identity collisions**: host `int` vs guest wrappers must not double-register.
- **Invalidation**: `_invalidation_counter` already bumps on register; bridge
  cache in `_abc_subclasscheck` remains valid.
- **Blast radius**: every `issubclass` pays one registry scan when MRO fails;
  mitigated by negative cache already in `_abc_subclasscheck`.
