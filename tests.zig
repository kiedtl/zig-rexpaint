// TODO:
// - Ensure images from pre-0.9 versions are parsed correctly (i.e. files
//   without the version metadata in the header)
//

const std = @import("std");

const RexMap = @import("RexMap.zig");

// Tests:
// - transforming text with the tilemap correctly
// - replacing transparent characters with those on the lower level
// - reading layer/height/width metadata
//
// layer_test.xp consists of the text "Hello, world!", with each alternating
// letter written on the above layer.
//
test "layer_test" {
    const map = try RexMap.initFromFile(std.testing.allocator, "tests/layer_test.xp");
    defer map.deinit();

    try std.testing.expectEqual(@as(usize, 2), map.layers);
    try std.testing.expectEqual(@as(usize, 1), map.height);
    try std.testing.expectEqual(@as(usize, 13), map.width);

    var text: [13]u8 = undefined;

    // Both layers
    for (text) |*slot, i|
        slot.* = @intCast(u8, RexMap.DEFAULT_TILEMAP[map.get(i, 0).ch]);
    try std.testing.expectEqualSlices(u8, "Hello, World!", &text);

    // Second layer
    for (text) |*slot, i|
        slot.* = @intCast(u8, RexMap.DEFAULT_TILEMAP[map.getRaw(1, i, 0).ch]);
    try std.testing.expectEqualSlices(u8, "H l o   o l !", &text);

    // First layer
    for (text) |*slot, i|
        slot.* = @intCast(u8, RexMap.DEFAULT_TILEMAP[map.getRaw(0, i, 0).ch]);
    try std.testing.expectEqualSlices(u8, " e l , W r d ", &text);
}

test "color_test" {
    const map = try RexMap.initFromFile(std.testing.allocator, "tests/color_test.xp");
    defer map.deinit();

    try std.testing.expectEqual(@as(usize, 1), map.layers);
    try std.testing.expectEqual(@as(usize, 1), map.height);
    try std.testing.expectEqual(@as(usize, 7), map.width);

    try std.testing.expectEqual(RexMap.Tile.RGB{ .r = 255, .g = 51, .b = 51 }, map.get(0, 0).bg);
    try std.testing.expectEqual(RexMap.Tile.RGB{ .r = 255, .g = 255, .b = 51 }, map.get(1, 0).bg);
    try std.testing.expectEqual(RexMap.Tile.RGB{ .r = 0, .g = 255, .b = 0 }, map.get(2, 0).bg);

    try std.testing.expectEqual(RexMap.Tile.RGB{ .r = 0, .g = 191, .b = 255 }, map.get(3, 0).bg);
    try std.testing.expectEqual(RexMap.Tile.RGB{ .r = 191, .g = 0, .b = 255 }, map.get(4, 0).bg);

    try std.testing.expectEqual(RexMap.Tile.RGB{ .r = 255, .g = 0, .b = 64 }, map.get(5, 0).bg);
    try std.testing.expectEqual(RexMap.Tile.RGB{ .r = 158, .g = 134, .b = 100 }, map.get(6, 0).bg);
}
