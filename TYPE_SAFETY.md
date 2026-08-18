# Type-safety policy

Mojotui is a statically typed Mojo library. Public APIs use concrete types or
compile-time generics constrained by traits. Runtime-erased widget, backend,
message, and clipboard interfaces are outside the design.

## Function declarations

The project uses `def`, not `fn`. Mojo 1.1 unified function declarations on
`def`; the pinned compiler rejects the removed `fn` declaration. In current
Mojo, `def` is non-raising by default and has the former strict `fn` behavior.
Fallible functions declare `raises` in their signatures.

This is a syntax migration, not a relaxation of the type system. Mojo requires
function argument types, requires a return type whenever a value is returned,
and resolves generic constraints at compile time.

References:

- [Mojo function declarations reference](https://docs.modular.com/mojo/reference/mojo-function-declarations/)
- [Mojo changelog: `def`/`fn` unification](https://docs.modular.com/mojo/changelog/)

## Enforced rules

- The exact Mojo nightly is pinned in `pixi.toml` and `pixi.lock`.
- Package compilation runs with `--Werror`.
- Function arguments and value-returning functions have compiler-checked
  types; `raises` is explicit on fallible functions.
- Backends, application contracts, stateful widgets, and clipboard providers
  use statically dispatched trait-constrained generics.
- `AnyType` and `PythonObject` are rejected from the library package.
- The removed `fn` declaration is rejected from the library package.
- Raw pointers and FFI remain confined to the separately audited platform
  boundary described in `mojotui/platform/SAFETY.md`.

Run `pixi run type-check` for the policy scan and warnings-as-errors package
compilation. `pixi run check` includes it.
