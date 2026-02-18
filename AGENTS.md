# AGENTS.md

Zig binding generator for the WebGPU C API. Reads the machine-readable
`webgpu.json` schema from webgpu-native/webgpu-headers and produces idiomatic
Zig bindings (`bindings.zig`).

## Build / Test Commands

```bash
# Generate bindings (writes to zig-out/bindings.zig)
zig build write

# Run ABI parity tests (comptime-only, validates Zig bindings match C header)
zig build test

# Build the gen-bindings executable without running it
zig build

# Format all Zig source files (built-in, no config file)
zig fmt src/ build.zig
```

There is no separate lint tool — `zig fmt` is the sole formatter/linter.

### Running a Single Test

The project has exactly one test target (`api_abi_parity_test.zig`). It runs
entirely at comptime — there are no runtime test cases or test filtering.
`zig build test` is the only test command needed.

## Code Style Guidelines

### Formatting

- **4-space indentation** (no tabs) — this is Zig standard, enforced by `zig fmt`
- Lines generally stay under ~120 characters; long expressions wrap naturally
- Single blank line between top-level declarations and between logical sections
- Never two consecutive blank lines
- Trailing commas in multi-line struct/enum/argument lists

### Imports

Strict ordering, one import per line, all `const`:

```zig
const std = @import("std");            // 1. standard library (always first)
const builtin = @import("builtin");    // 2. compiler builtins (when needed)
const Schema = @import("schema.zig");  // 3. local/project modules
const log = std.log.scoped(.@"...");   // 4. derived aliases from std
```

A single blank line separates the import block from the rest of the file.
Local file imports use the `.zig` extension; package imports use short names.

### Naming Conventions

| Category              | Convention   | Example                          |
|-----------------------|--------------|----------------------------------|
| Functions             | `camelCase`  | `generateBindings`, `writeIdent` |
| Types (struct/enum)   | `PascalCase` | `Bitflag`, `Parameter`, `Bool`   |
| Variables / params    | `snake_case` | `input_path`, `output_file`      |
| Constants (non-type)  | `snake_case` | `zig_keywords`, `uint32_max`     |
| Enum fields           | `snake_case` | `.camel`, `.immutable`, `.none`   |
| Comptime type params  | Single upper | `T`, `Z`, `C`                    |

### Visibility

Default to private (`fn`, `const`). Only use `pub` when the symbol is part of
the module's public API. Inner/helper types within a struct are private unless
referenced externally.

### Error Handling

- **Always propagate with `try`** — the codebase uses zero `catch` expressions
- Fallible functions return `!void` or `!T` (inferred error sets)
- Use named errors for user-facing failures: `return error.NoInputFile;`
- Use `orelse` for optional unwrapping: `args.next() orelse { ... }`
- Use `orelse continue` as a filter pattern in loops
- Use `unreachable` only for genuinely impossible states
- Resource cleanup always via `defer`:
  ```zig
  defer schema_parsed.deinit();
  defer std.debug.assert(gpa_state.deinit() == .ok);
  ```

### Type Annotations

- **Always explicit** on: function parameters, struct fields, return types
- **Inferred** for: `const` bindings from function returns, obvious initializers
- Annotate complex types even when inferable, for readability:
  ```zig
  var schema_parsed: std.json.Parsed(Schema) = try std.json.parseFromSlice(...);
  ```

### Comments

- `///` doc comments: used sparingly, only for genuinely important public API docs
- `//` line comments: for inline explanations and section markers
- No block comments (`/* */`)
- Section headers as comments within functions to mark logical regions:
  ```zig
  // Callback function pointer types
  // Callback info structs
  // Global functions
  ```

### Notable Idioms

- **`@This()`** for self-referential types instead of naming the enclosing type
- **Comptime enum parameters** for behavior variants instead of separate functions:
  ```zig
  fn writeIdent(writer: ..., str: ..., comptime case: Case) !void
  ```
- **`inline` only on thin wrappers**: `pub inline fn` for generated method
  wrappers that should always be inlined
- **Empty slice literal**: `&.{}` as default for empty slice fields
- **Scoped logging**: `std.log.scoped(.@"webgpu-zig-bindgen")`

### What NOT to Edit

- `zig-out/bindings.zig` — this is generated output; edit `gen.zig` or
  `prelude.zig` instead, then run `zig build write`
- `webgpu-headers/` — fetched dependency, gitignored
- `.zig-cache/` — build cache, gitignored
