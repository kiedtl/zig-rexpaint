/// Showcase example usage of RexMap.
const std = @import("std");
const RexMap = @import("RexMap.zig");

pub fn main() anyerror!void {
    // Get an allocator up and running
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    // Read in a file. In this case it's simply an xp file with the text "Hello,
    // World!" on two alternating layers.
    const map = try RexMap.initFromFile(arena.allocator(), "tests/layer_test.xp");
    defer map.deinit();

    // Display the image to the terminal via escape sequences.
    //
    var y: usize = 0;
    while (y < map.height) : (y += 1) {
        var x: usize = 0;
        while (x < map.width) : (x += 1) {
            // Various map.get* functions can be used. This one just grabs the
            // first non-transparent tile from a coordinate, starting from the
            // top layer.
            const tile = map.get(x, y);

            if (tile.isTransparent()) {
                std.debug.print("\x1b[m ", .{});
                continue;
            }

            std.debug.print(
                "\x1b[38;2;{};{};{}m\x1b[48;2;{};{};{}m",
                .{ tile.fg.r, tile.fg.g, tile.fg.b, tile.bg.r, tile.bg.g, tile.bg.b },
            );

            // By default, tile.ch contains the "raw" character value that was
            // stored in the xp file. REXPaint treats this value as an index
            // into a tilemap, *not* as an actual Unicode codepoint. For this
            // reason, box-drawing characters are stored as values in the
            // 128...255 range, not their actual Unicode values.
            //
            // In this case, we just get the real Unicode value from
            // DEFAULT_TILEMAP.
            std.debug.print("{u}", .{RexMap.DEFAULT_TILEMAP[tile.ch]});
        }

        std.debug.print("\x1b[m\n", .{});
    }
}
