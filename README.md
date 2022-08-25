# zig-rexpaint

A library for reading `.xp` REXPaint files.

See [main.zig](main.zig) for an example usage, or browse
[RexMap.zig](RexMap.zig) for documentation.

## Usage

At the moment zig-rexpaint doesn't support usage from a package manager. In the
future this will be fixed. For now you must use Git's submodules or a similar
solution.

Simply add this library's source to your project however you choose, then add
the following lines to your `build.zig`:

```
pub fn build(b: *Builder) void {
    // snip
    exe.addPackagePath("rexpaint", "path/to/zig-rexpaint/lib.zig");
    // snip
}
```
