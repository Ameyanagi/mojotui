# Type-safety policy

Mojotui is a statically typed Mojo library. Public APIs use concrete types or
compile-time generics constrained by traits. Runtime-erased widget, backend,
message, and clipboard interfaces are outside the design.

## Function declarations

The project uses `def`, not `fn`. Mojo unified function declarations on `def`;
`fn` is deprecated upstream and rejected by this project's source policy and
warnings-as-errors build. In current Mojo, `def` is non-raising by default and
has the former strict `fn` behavior. Fallible functions declare `raises` in
their signatures.

This is a syntax migration, not a relaxation of the type system. Mojo requires
function argument types, requires a return type whenever a value is returned,
and resolves generic constraints at compile time.

References:

- [Mojo function declarations reference](https://docs.modular.com/mojo/reference/mojo-function-declarations/)
- [Mojo changelog: `def`/`fn` unification](https://docs.modular.com/mojo/changelog/)

## Enforced rules

- The exact Mojo release is pinned in `pixi.toml` and `pixi.lock`.
- Package compilation runs with `--Werror`.
- Function arguments and value-returning functions have compiler-checked
  types; `raises` is explicit on fallible functions.
- Backends, application contracts, stateful widgets, and clipboard providers
  use statically dispatched trait-constrained generics.
- Public semantic choices migrate to nominal types instead of raw integer
  discriminants. Their public constructors reject values outside the defined
  set rather than silently selecting a default.
- Collection selection, mouse-button absence, controller command payloads, and
  editor desired columns use `Optional`; absence is `None`, never `-1` or a
  dummy semantic value.
- Key/mouse tags, editor command and persistence kinds, color kinds, terminal
  color profiles, terminal appearances, modifier sets, and border sets are
  nominal types with validated construction.
- `AnyType` and `PythonObject` are rejected from the library package.
- The deprecated `fn` declaration is rejected from the library package.
- Raw pointers and FFI remain confined to the separately audited platform
  boundary described in `mojotui/platform/SAFETY.md`.

The 20 fixtures in `tests/compile_fail` contain intentionally ill-typed callers
proving raw integers cannot cross migrated API boundaries and negative
selection sentinels do not compile. Run `pixi run type-check` for those
fixtures, the policy scan, and warnings-as-errors package compilation.
`pixi run check` includes it.
