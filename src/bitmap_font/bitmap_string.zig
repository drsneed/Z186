const std = @import("std");
const Allocator = std.mem.Allocator;
usingnamespace @import("../util.zig");
usingnamespace @import("../glm.zig");
usingnamespace @import("bitmap_font.zig");
usingnamespace @import("bitmap_char.zig");

pub const BitmapString = struct
{



    const BitmapCharList = std.ArrayList(BitmapChar);
    chars: BitmapCharList,
    width: i32,
    position: Vec2,
    rotation: f32,
    scale_xy: Vector2,
    fontDescriptor: *BitmapFont,
    allocator: *Allocator,

    pub fn init(allocator: *Allocator, fontDescriptor: *BitmapFont) BitmapString
    {
        return BitmapString
        {
            .allocator = allocator,
            .chars = BitmapCharList.init(allocator),
            .fontDescriptor = fontDescriptor,
            .width = 0,
            .position = vec2(0.0,0.0),
            .rotation = 0.0,
            .scale_xy = Vector2.init(1.0, 1.0),
        };
    }
    pub fn initText(allocator: *Allocator, fontDescriptor: *BitmapFont, text: []const u8) !BitmapString
    {
        var string = BitmapString.init(allocator, fontDescriptor);
        try string.setText(text);
        return string;
    }

    pub fn deinit(self: *BitmapString) void
    {
        self.chars.deinit();
    }

    pub fn setText(self: *BitmapString, text: []const u8) !void
    {
        // first destroy any preexisting char array and make a new one
        self.chars.deinit();
        self.chars = try BitmapCharList.initCapacity(self.allocator, text.len);

        // now we loop through and create a new bitmap char for each char.
        // cursor is the x position of the current char. We start at zero
        var cursor:i32 = 0;
        var i:usize = 0;
        while(i < text.len) : (i = i + 1) 
        {
            // does the font have a glyph for this char?
            if(self.fontDescriptor.getChar(text[i])) |charDescriptor| {
                // okay it does, make a bitmap char at the cursor location
                var bitmapChar = BitmapChar.init(charDescriptor, cursor);
                try self.chars.append(bitmapChar);

                // Now we must advance the cursor. To do that we need to check
                // if there is a kerning between this char and the next.
                var kerning: i32 = 0;
                // Only check for kerning if we are not on the last char
                if(i != text.len - 1)
                {
                    if(self.fontDescriptor.getKerning(text[i], text[i+1])) |kerningDescriptor| {
                        // there is a kerning here so we store the amount.
                        kerning = kerningDescriptor.amount;
                    }
                }
                cursor = cursor + charDescriptor.xadvance + kerning;
            }
        }
        self.width = cursor;
    }



    pub fn prettyPrint(self: *BitmapString) void 
    {
        debugPrint("BitmapString\n{{\n", .{});
            debugPrint("  chars\n  [\n", .{});
            for(self.chars.items) |char| {
                debugPrint("    {}\n", .{char});
            }
            debugPrint("  ]\n", .{});
        debugPrint("}}\n", .{});
    }
};