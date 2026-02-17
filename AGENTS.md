# Agent Instructions (wgpu-zig-bindings)

Requires Zig >= 0.15.1 (see `build.zig.zon`). No Cursor/Copilot rules found.

## Build / Lint / Test
- Generate bindings: `zig build gen` (writes `src/bindings.zig`; fetches `webgpu_headers`).
- Format: `zig fmt build.zig src/*.zig`
- Format check (CI-style): `zig fmt --check build.zig src/*.zig`
- Run tests in a file: `zig test src/schema.zig` (or `zig test src/gen.zig`)
- Run a single test: `zig test src/schema.zig --test-filter "substring"`

## Code Style
- Always run `zig fmt`; don’t hand-align whitespace.
- Imports at top: `const std = @import("std");` first, then local modules; one import per line.
- Naming: types/enums `PascalCase`, functions `camelCase`, fields/consts `snake_case`.
- Prefer slices (`[]T`, `[]const T`) for collections; use `?*T` for optional C pointers.
- Use `[]const u8` / `?[]const u8` at the API boundary; convert to ABI structs internally.
- Error handling: return `!T`, propagate with `try`; use `defer`/`errdefer` for cleanup.
- Use `std.debug.assert` for invariants; avoid panics for user/input errors.
- Don’t edit generated `src/bindings.zig` by hand—change `src/gen.zig`/`src/schema.zig` instead.
