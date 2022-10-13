const std = @import("std");
const Allocator = std.mem.Allocator;
usingnamespace @import("../util.zig");
usingnamespace @import("../glm.zig");
usingnamespace @import("bitmap_font.zig");

pub const BitmapChar = struct
{
    char: BitmapFont.Char,
    xadvance: i32,

    pub fn init(char: BitmapFont.Char, xadvance: i32) BitmapChar
    {
        return BitmapChar
        {
            .char = char,
            .xadvance = xadvance,
        };
    }
};