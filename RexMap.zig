//! A parser for REXPaint's .xp data format.
//! The entire format is un-gzipped and read into memory at the same time.
//!
//! See main.zig for an example usage.
//!
//!
//! See also:
//! - REXPaint Homepage:
//!   https://www.gridsagegames.com/rexpaint/
//! - Format specification (Unofficial (and slightly outdated) version:
//!   https://github.com/Lucide/REXPaint-manual/blob/master/manual.md#appendix-b-xp-format-specification-and-import-libraries
//!
//! (c) 2022-2025 Kied Llaentenn
//!
//! zig-rexpaint is licensed under the MIT license. See the COPYING file for
//! more details.

const std = @import("std");

alloc: std.mem.Allocator,
width: usize,
height: usize,
layers: usize,
data: []Tile,

/// A single REXPaint tile.
///
/// <ch> is *not* a Unicode codepoint, it is an index into an
/// application-specific tilemap.
///
/// Use RexMap.DEFAULT_TILEMAP[tile.ch] to get a Unicode codepoint using
/// REXPaint's default tilemap.
///
pub const Tile = struct {
    ch: u32,
    fg: RGB,
    bg: RGB,

    /// Check if a tile should be considered transparent.
    ///
    /// (REXPaint considers tiles with a background of #ff00ff to be transparent.)
    pub fn isTransparent(self: Tile) bool {
        return self.bg.r == 255 and self.bg.g == 0 and self.bg.b == 255;
    }

    /// A 24-bit RGB value.
    pub const RGB = struct {
        r: u8,
        g: u8,
        b: u8,

        /// Convert an RGB{} to a u32 value of the formt #RRGGBB.
        pub fn asU32(self: RGB) u32 {
            return (@as(u32, self.r) << 16) | (@as(u32, self.g) << 8) | self.b;
        }
    };
};

pub const Self = @This();

// zig fmt: off
/// The default tilemap used by REXPaint.
///
/// If you used a custom font with custom glyph placements when creating your
/// images, you'll need to use your own tilemap.
pub const DEFAULT_TILEMAP = [256]u21{
    16,  978,  978,  982,  983,  982,  982,  822,  969,  9675,  9689,
    9794,  9792,  9834,  9835,  9788,  9658,  9668,  8597,  8252,  182,
    167,  9644,  8616,  8593,  8595,  8594,  8592,  8735,  8596,  9650,
    9660,  32,  33,  34,  35,  36,  37,  38,  39,  40,  41,  42,  43,  44,
    45,  46,  47,  48,  49,  50,  51,  52,  53,  54,  55,  56,  57,  58,
    59,  60,  61,  62,  63,  64,  65,  66,  67,  68,  69,  70,  71,  72,
    73,  74,  75,  76,  77,  78,  79,  80,  81,  82,  83,  84,  85,  86,
    87,  88,  89,  90,  91,  92,  93,  94,  95,  96,  97,  98,  99,  100,
    101,  102,  103,  104,  105,  106,  107,  108,  109,  110,  111,  112,
    113,  114,  115,  116,  117,  118,  119,  120,  121,  122,  123,  124,
    125,  126,  8962,  199,  252,  233,  226,  228,  224,  229,  231,  234,
    235,  232,  239,  238,  236,  196,  197,  201,  230,  198,  244,  246,
    242,  251,  249,  255,  214,  220,  162,  163,  165,  8359,  402,  225,
    237,  243,  250,  241,  209,  170,  186,  191,  8976,  172,  189,  188,
    161,  171,  187,  9617,  9618,  9619,  9474,  9508,  9569,  9570,
    9558,  9557,  9571,  9553,  9559,  9565,  9564,  9563,  9488,  9492,
    9524,  9516,  9500,  9472,  9532,  9566,  9567,  9562,  9556,  9577,
    9574,  9568,  9552,  9580,  9575,  9576,  9572,  9573,  9561,  9560,
    9554,  9555,  9579,  9578,  9496,  9484,  9608,  9604,  9612,  9616,
    9600,  945,  223,  915,  960,  931,  963,  181,  964,  934,  920,  937,
    948,  8734,  966,  949,  8745,  8801,  177,  8805,  8804,  8992,  8993,
    247,  8776,  176,  8729,  183,  8730,  8319,  178,  9632,  9633
};
// zig fmt: on

const GzipFileStream = std.compress.gzip.GzipStream(std.fs.File.Reader);

/// Open a file and completely parse it.
///
pub fn initFromFile(alloc: std.mem.Allocator, filename: []const u8) !Self {
    var self: Self = undefined;
    self.alloc = alloc;

    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    var gz_stream = std.compress.gzip.decompressor(file.reader());
    //defer gz_stream.deinit();

    const reader = gz_stream.reader();

    // If version >= 0, it's an old version of .xp format that doesn't have a version
    // marker at all (so we read the layer count instead)
    const version = try reader.readInt(i32, .little);

    self.layers = if (version >= 0) @as(u32, @bitCast(version)) else @intCast(try reader.readInt(i32, .little));
    self.width = @intCast(try reader.readInt(i32, .little));
    self.height = @intCast(try reader.readInt(i32, .little));

    if (self.layers < 1 or self.layers > 9) {
        return error.InvalidLayerCount;
    }

    self.data = try self.alloc.alloc(Tile, self.layers * self.height * self.width);

    var z: usize = 0;
    while (z < self.layers) : (z += 1) {
        // If this isn't the first layer, skip the two following u32's, which
        // are the (redundant) width and height for the current layer
        //
        if (z > 0) {
            _ = try reader.readInt(i32, .little);
            _ = try reader.readInt(i32, .little);
        }

        var x: usize = 0;
        while (x < self.width) : (x += 1) {
            var y: usize = 0;
            while (y < self.height) : (y += 1) {
                var tile: Tile = undefined;
                tile.ch = try reader.readInt(u32, .little);
                tile.fg.r = try reader.readInt(u8, .little);
                tile.fg.g = try reader.readInt(u8, .little);
                tile.fg.b = try reader.readInt(u8, .little);
                tile.bg.r = try reader.readInt(u8, .little);
                tile.bg.g = try reader.readInt(u8, .little);
                tile.bg.b = try reader.readInt(u8, .little);

                self.getRawMutPtr(z, x, y).* = tile;
            }
        }
    }

    return self;
}

/// Get a mutable pointer to the first opaque tile at an x,y coordinate,
/// starting from the top-most layer.
pub fn getMutPtr(self: *Self, x: usize, y: usize) *Tile {
    return self.getFromLayerMutPtr(self.layers - 1, x, y);
}

/// Get the first opaque tile at an x,y coordinate, starting from the top-most
/// layer.
pub fn get(self: *const Self, x: usize, y: usize) Tile {
    return self.getFromLayer(self.layers - 1, x, y);
}

/// Get a mutable pointer to the first opaque tile at an x,y coordinate,
/// starting from a specific layer.
pub fn getFromLayerMutPtr(self: *Self, z: usize, x: usize, y: usize) *Tile {
    const tile = self.getRawMutPtr(z, x, y);
    return if (z == 0 or !tile.isTransparent()) tile else self.getFromLayerMutPtr(z - 1, x, y);
}

/// Get the first opaque tile at an x,y coordinate, starting from a specific
/// layer.
pub fn getFromLayer(self: *const Self, z: usize, x: usize, y: usize) Tile {
    const tile = self.getRaw(z, x, y);
    return if (z == 0 or !tile.isTransparent()) tile else self.getFromLayer(z - 1, x, y);
}

/// Get a mutable pointer to the tile at an x,y coordinate from a specific
/// layer. Won't search the lower layers if the tile is transparent.
pub fn getRawMutPtr(self: *const Self, z: usize, x: usize, y: usize) *Tile {
    return &self.data[x + (y * self.width) + (z * (self.width * self.height))];
}

/// Get the tile at an x,y coordinate from a specific layer. Won't search the
/// lower layers if the tile is transparent.
pub fn getRaw(self: *const Self, z: usize, x: usize, y: usize) Tile {
    return self.data[x + (y * self.width) + (z * (self.width * self.height))];
}

pub fn deinit(self: *const Self) void {
    self.alloc.free(self.data);
}
