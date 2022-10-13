const std = @import("std");
const Allocator = std.mem.Allocator;
const cwd = std.fs.cwd;
const OpenFlags = std.fs.File.OpenFlags;
const indexOf = std.ascii.indexOfIgnoreCase;
usingnamespace @import("../util.zig");
usingnamespace @import("../c_dependencies.zig");
pub usingnamespace @import("bitmap_font_renderer.zig");
usingnamespace @import("../glm.zig");

const LINE_SIZE:usize = 1024;
pub const INVALID_TEXTURE:c_uint = 65535;

pub fn CharHashMapContext() type {
    return struct {
        const Self = @This();
        pub fn eql(self: Self, a: i32, b: i32) bool {
            _ = self;
            return a == b;
        }

        pub fn hash(self: Self, s: i32) u64 {
            _ = self;
            return @intCast(u64, s);
        }
    };
}

pub fn CharHashMap(comptime V: type) type {
    return std.HashMap(i32, V, CharHashMapContext(), 99);
}
/// BitmapFont parses .fnt files generated from tools such as BMFont and Hiero (https://www.angelcode.com/products/bmfont/).
pub const BitmapFont = struct 
{
    /// The info struct holds information on how the font was generated.
    pub const Info = struct {
        /// The padding for each character (up, right, down, left).
        const Padding = struct {
            up: i32 = 0,
            right: i32 = 0,
            down: i32 = 0,
            left: i32 = 0
        };

        ///	The spacing for each character (horizontal, vertical).
        const Spacing = struct {
            horizontal: i32 = 0,
            vertical: i32 = 0
        };

        /// This is the name of the true type font.
        face: []u8 = "",

        /// The size of the true type font.
        size: i32 = 0,

        /// The font is bold.
        bold: bool = false,

        /// The font is italic.
        italic: bool = false,

        /// The name of the OEM charset used (when not unicode).
        charset: []u8 = "",

        /// The font supports the unicode charset.
        unicode: bool = false,

        /// The font height stretch in percentage. 100% means no stretch.
        stretchH: i32 = 0,

        ///	Smoothing was turned on.
        smooth: bool = false,

        /// The supersampling level used. 1 means no supersampling was used.
        aa: i32 = 0,

        padding: Padding = Padding {},
        spacing: Spacing = Spacing {},

    };

    /// The common struct holds information common to all characters.
    pub const Common = struct {

        /// Set to 0 if the channel holds the glyph data, 
        ///        1 if it holds the outline,
        ///        2 if it holds the glyph and the outline,
        ///        3 if its set to zero, 
        ///    and 4 if its set to one.
        const ChannelType = enum {
            GlyphData,
            Outline,
            GlyphAndOutline,
            Zero,
            One,
            Undefined
        };
        /// This is the distance in pixels between each line of text.
        lineHeight: i32 = 0,

        /// The number of pixels from the absolute top of the line to the base of the characters.
        base: i32 = 0,

        /// The width of the texture, normally used to scale the x pos of the character image.
        scaleW: i32 = 0,
        
        /// The height of the texture, normally used to scale the y pos of the character image.
        scaleH: i32 = 0,

        /// The number of texture pages included in the font.
        pages: i32 = 0,

        /// True if the monochrome characters have been packed into each of the texture channels. 
        /// In this case alphaChnl describes what is stored in each channel.
        isPacked: bool = false,

        alphaChnl: ChannelType = ChannelType.Undefined,
        redChnl: ChannelType = ChannelType.Undefined,
        greenChnl: ChannelType = ChannelType.Undefined,
        blueChnl: ChannelType = ChannelType.Undefined
    };


    /// Provides the name of a texture file. There is one for each page in the font.
    pub const Page = struct {

        /// The page id.
        id: usize = 0,

        /// The file name.
        file: []u8 = "",

        /// The opengl texture id
        textureId: c_uint = 0,

    };


    /// Describes on character in the font. There is one for each included character in the font.
    pub const Char = struct {
        /// The character id.
        id: u8 = 0,

        /// The left position of the character image in the texture.
        x: i32 = 0,

        /// The top position of the character image in the texture.
        y: i32 = 0,

        /// The width of the character image in the texture.
        width: i32 = 0,

        /// The height of the character image in the texture.
        height: i32 = 0,

        /// How much the current position should be offset when copying the image from the texture to the screen.
        xoffset: i32 = 0,

        /// How much the current position should be offset when copying the image from the texture to the screen.
        yoffset: i32 = 0,

        /// How much the current position should be advanced after drawing the character.
        xadvance: i32 = 0,

        /// The texture page where the character image is found.
        page: i32 = 0,

        /// The texture channel where the character image is found (1 = blue, 2 = green, 4 = red, 8 = alpha, 0 = all channels).
        chnl: i32 = 0
    };

    /// The kerning information is used to adjust the distance between certain characters, 
    /// e.g. some characters should be placed closer to each other than others.
    pub const Kerning = struct {
            /// The first character id.
            first: i32 = 0,

            /// The second character id.
            second: i32 = 0,

            /// How much the x position should be adjusted when drawing the second character immediately following the first.
            amount: i32 = 0
    };

    allocator: *Allocator,
    info: Info = Info {},
    common: Common = Common {},
    pages: std.ArrayList(Page),
    chars: CharHashMap(Char),
    kernings: std.ArrayList(Kerning),
    renderer: BitmapFontRenderer,
    textBuffer: [256] u8 = undefined,
    //-------------------------------------------------------------------------------------------------------------------------

    pub fn init(allocator: *Allocator, fileName: []const u8) !BitmapFont
    {
        const file = try cwd().openFile(fileName, OpenFlags {.read = true, .write = false});
        const fileDir = std.fs.path.dirname(fileName);
        
        defer file.close();
        const stream = file.reader();
        var lineBuffer: [LINE_SIZE]u8 = undefined;
        var lineNumber:i32 = 1;
        var self = BitmapFont
        {
            .allocator = allocator, 
            .pages = std.ArrayList(Page).init(allocator),
            .chars = CharHashMap(Char).init(allocator),
            .kernings = std.ArrayList(Kerning).init(allocator),
            .renderer = try BitmapFontRenderer.init(allocator)
        };

        

        while (true) 
        {
            // try to read until new line character into line buffer.
            // if it returns null then break out of loop
            var line = (try stream.readUntilDelimiterOrEof(lineBuffer[0..], '\n')) orelse break;
            // find index of first space. If the line doesn't have a space then skip it
            var space = indexOf(line, " ") orelse continue;
            // each line in a .fnt file begins with the line key.
            // everything after the first space is considered the value
            const key = line[0..space];
            const value = line[(space + 1) .. line.len];
            
            if (std.mem.eql(u8, key, "info"))  {
                try self.parseInfoLine(value);
            }
            if (std.mem.eql(u8, key, "common"))  {
                try self.parseCommonLine(value);
            }
            if (std.mem.eql(u8, key, "page"))  {
                // fileDir is optional because it could be invalid so we have to check for it here
                if (fileDir) |dir| {
                    debugPrint("dir = {s}\n", .{dir});
                    try self.parsePageLine(value, dir);
                } else {
                    debugPrint("fileDir is null?\n", .{});
                }
                
            }
            if (std.mem.eql(u8, key, "char"))  {
                debugPrint("char line: {s}", .{value});
                try self.parseCharLine(value);
            }
            if (std.mem.eql(u8, key, "kerning"))  {
                try self.parseKerningLine(value);
            }
            //debugPrint("{}. key: {}, value: {}\n", .{lineNumber, key, value});
            lineNumber = lineNumber + 1;
        }

        return self;
    }

    pub fn deinit(self: *BitmapFont) void 
    {
        self.renderer.deinit();
        self.chars.deinit();
        for(self.pages.items) |page| {
            self.allocator.free(page.file);
            if(page.textureId > 0) {
                glDeleteTextures(1, &page.textureId);
            }
        }
        self.pages.deinit();
        if(self.info.face.len > 0) self.allocator.free(self.info.face);
        if(self.info.charset.len > 0) self.allocator.free(self.info.charset);
    }

    pub fn render(self: *BitmapFont, pos: Vector2, color: u32, comptime fmt: []const u8, args: anytype) !void
    {
        var text = try std.fmt.bufPrint(self.textBuffer[0..], fmt, args);
        var textureId = try self.getFirstTexture();
        try self.renderer.render(self, pos, color, textureId, text);
    }

    pub fn getChar(self: *BitmapFont, char: u8) ?Char
    {
        if(self.chars.get(char)) |entry| {
            return entry;
        }
        return null;
    }

    pub fn getKerning(self: *BitmapFont, firstChar: u8, secondChar: u8) ?Kerning
    {
        for(self.kernings.items) |kerning|
        {
            if(kerning.first == firstChar and kerning.second == secondChar)
                return kerning;
        }
        return null;
    }

    pub fn getPage(self: *BitmapFont, pageId: usize) ?Page
    {
        if(pageId >= self.pages.items.len) {
            return null;
        }
        return self.pages.items[pageId];
    }

    pub fn getPageTexture(self: *BitmapFont, pageId: usize) !c_uint
    {
        if(self.getPage(pageId)) |page|
        {
            if(page.textureId == 0) {
                var textureId = try loadTexture(self.allocator, page.file);
                debugPrint("textureId = {}\n", .{textureId});
                self.pages.items[pageId].textureId = textureId;
            }
            return self.pages.items[pageId].textureId;
        }
        return 0;
    }

    pub fn getFirstTexture(self: *BitmapFont) !c_uint {
        if (self.pages.items.len == 0)
            return error.PageNotFound;
        return try self.getPageTexture(self.pages.items[0].id);
    }

    pub fn prettyPrint(self: *BitmapFont) void 
    {
        debugPrint("BitmapFont\n{{\n", .{});
            debugPrint("  info\n  {{\n", .{});
            debugPrint("    face: \"{s}\",\n", .{self.info.face});
            debugPrint("    size: {d},\n", .{self.info.size});
            debugPrint("    bold: {s},\n", .{self.info.bold});
            debugPrint("    italic: {s},\n", .{self.info.italic});
            debugPrint("    charset: \"{s}\",\n", .{self.info.charset});
            debugPrint("    unicode: {s},\n", .{self.info.unicode});
            debugPrint("    stretchH: {d},\n", .{self.info.stretchH});
            debugPrint("    smooth: {s},\n", .{self.info.smooth});
            debugPrint("    aa: {d},\n", .{self.info.aa});
            debugPrint("    padding: {d},\n", .{self.info.padding});
            debugPrint("    spacing: {d},\n", .{self.info.spacing});
            debugPrint("  }}\n", .{});
            debugPrint("  common\n  {{\n", .{});
            debugPrint("    lineHeight: {d},\n", .{self.common.lineHeight});
            debugPrint("    base: {d},\n", .{self.common.base});
            debugPrint("    scaleW: {d},\n", .{self.common.scaleW});
            debugPrint("    scaleH: {d},\n", .{self.common.scaleH});
            debugPrint("    pages: {d},\n", .{self.common.pages});
            debugPrint("    packed: {s},\n", .{self.common.isPacked});
            debugPrint("  }}\n", .{});
            debugPrint("  pages\n  [\n", .{});
            for(self.pages.items) |page| {
                debugPrint("    {s}\n", .{page});
            }
            debugPrint("  ]\n", .{});
            debugPrint("  chars\n  {{\n", .{});
            var iter = self.chars.iterator();

            while(iter.next()) |entry| {
                debugPrint("    {d}: {s}\n", .{entry.key_ptr.*, entry.value_ptr.*});
            }
            debugPrint("  }}\n", .{});
            debugPrint("  kernings\n  [\n", .{});
            for(self.kernings.items) |kerning| {
                debugPrint("    {s}\n", .{kerning});
            }
            debugPrint("  ]\n", .{});
        debugPrint("}}\n", .{});
    }

    /// Search for key in line, extract value of parameter
    fn getValue(line: []const u8, key: []const u8) ?[]const u8
    {
        var slice = line[0 ..];

        // find the index of key and chop off the key and everything before it
        var keyIndex = indexOf(slice, key) orelse return null;
        slice = slice[(keyIndex + key.len) ..];

        // if our logic is correct and the file is well-formed, the next char will be equals sign
        if(slice[0] != '=') return null;

        // now chop that off
        slice = slice[1..];
        
        // if it's a string value we read everything between the quotes
        if(slice[0] == '\"') {
            var endIndex:usize = 1;
            for(slice[1..]) |char| {
                if(char == '\"') break;
                endIndex = endIndex + 1;
            }
            return slice[1 .. endIndex];
        }
        // for all other values search for the next space
        var space = indexOf(slice, " ");
        // did we find a space?
        if(space) |s| {
            return slice[0 .. s];
        }
        // no space found. return the rest of string
        return slice;
    }

    fn parseInfoLine(self: *BitmapFont, line: []const u8) !void
    {
        if(getValue(line, "face")) |face| {
            self.info.face = try self.allocator.alloc(u8, face.len);
            std.mem.copy(u8, self.info.face, face);
        }
        if(getValue(line, "size")) |size| {
            self.info.size = try std.fmt.parseInt(i32, size, 10);
        }
        if(getValue(line, "bold")) |bold| {
            self.info.bold = (try std.fmt.parseInt(i32, bold, 10)) == 1;
        }
        if(getValue(line, "italic")) |italic| {
            self.info.italic = (try std.fmt.parseInt(i32, italic, 10)) == 1;
        }
        if(getValue(line, "charset")) |charset| {
            self.info.charset = try self.allocator.alloc(u8, charset.len);
            std.mem.copy(u8, self.info.charset, charset);
        }
        if(getValue(line, "unicode")) |unicode| {
            self.info.unicode = (try std.fmt.parseInt(i32, unicode, 10)) == 1;
        }
        if(getValue(line, "stretchH")) |stretchH| {
            self.info.stretchH = try std.fmt.parseInt(i32, stretchH, 10);
        }
        if(getValue(line, "smooth")) |smooth| {
            self.info.smooth = (try std.fmt.parseInt(i32, smooth, 10)) == 1;
        }
        if(getValue(line, "aa")) |aa| {
            self.info.aa = try std.fmt.parseInt(i32, aa, 10);
        }
        // padding and spacing are stored as comma separated values which we convert to structs.
        
        if(getValue(line, "padding")) |padding| {
            var iter = std.mem.split(padding, ",");
            var i:i32 = 0;
            while(iter.next()) |value| {
                switch(i) {
                    0 => { self.info.padding.up = try std.fmt.parseInt(i32, value, 10); },
                    1 => { self.info.padding.right = try std.fmt.parseInt(i32, value, 10); },
                    2 => { self.info.padding.down = try std.fmt.parseInt(i32, value, 10); },
                    3 => { self.info.padding.left = try std.fmt.parseInt(i32, value, 10); },
                    else => { break; }
                }
                i = i + 1;
            }
        }

        if(getValue(line, "spacing")) |spacing| {
            var iter = std.mem.split(spacing, ",");
            var i:i32 = 0;
            while(iter.next()) |value| {
                switch(i) {
                    0 => { self.info.spacing.horizontal = try std.fmt.parseInt(i32, value, 10); },
                    1 => { self.info.spacing.vertical = try std.fmt.parseInt(i32, value, 10); },
                    else => { break; }
                }
                i = i + 1;
            }
        }
    }

    fn parseCommonLine(self: *BitmapFont, line: []const u8) !void
    {
        if(getValue(line, "lineHeight")) |lineHeight| {
            self.common.lineHeight = try std.fmt.parseInt(i32, lineHeight, 10);
        }
        if(getValue(line, "base")) |base| {
            self.common.base = try std.fmt.parseInt(i32, base, 10);
        }
        if(getValue(line, "scaleW")) |scaleW| {
            self.common.scaleW = try std.fmt.parseInt(i32, scaleW, 10);
        }
        if(getValue(line, "scaleH")) |scaleH| {
            self.common.scaleH = try std.fmt.parseInt(i32, scaleH, 10);
        }
        if(getValue(line, "pages")) |pages| {
            self.common.pages = try std.fmt.parseInt(i32, pages, 10);
        }
        if(getValue(line, "packed")) |isPacked| {
            self.common.isPacked = (try std.fmt.parseInt(i32, isPacked, 10)) == 1;
        }
    }

    fn parsePageLine(self: *BitmapFont, line: []const u8, fontDir: []const u8) !void
    {
        debugPrint("Parsing page line...\n", .{});
        var page = Page {};
        if(getValue(line, "id")) |id| {
            page.id = try std.fmt.parseInt(usize, id, 10);
        }
        if(getValue(line, "file")) |fileName| {
            page.file = try std.fs.path.join(self.allocator, &[_][]const u8 {fontDir, fileName});
        }
        debugPrint("page.file = {s}\n", .{page.file});
        try self.pages.append(page);
    }

    fn parseCharLine(self: *BitmapFont, line: []const u8) !void
    {
        var char = Char {};
        if(getValue(line, "id")) |id| {
            char.id = try std.fmt.parseInt(u8, id, 10);
            // 10 == newline, skip it, we will simulate it
            if(char.id == 10) return;
        }
        if(getValue(line, "x")) |x| {
            char.x = try std.fmt.parseInt(i32, x, 10);
        }
        if(getValue(line, "y")) |y| {
            char.y = try std.fmt.parseInt(i32, y, 10);
        }
        if(getValue(line, "width")) |width| {
            char.width = try std.fmt.parseInt(i32, width, 10);
        }
        if(getValue(line, "height")) |height| {
            char.height = try std.fmt.parseInt(i32, height, 10);
        }
        if(getValue(line, "xoffset")) |xoffset| {
            char.xoffset = try std.fmt.parseInt(i32, xoffset, 10);
        }
        if(getValue(line, "yoffset")) |yoffset| {
            char.yoffset = try std.fmt.parseInt(i32, yoffset, 10);
        }
        if(getValue(line, "xadvance")) |xadvance| {
            char.xadvance = try std.fmt.parseInt(i32, xadvance, 10);
        }
        if(getValue(line, "page")) |page| {
            char.page = try std.fmt.parseInt(i32, page, 10);
        }
        if(getValue(line, "chnl")) |chnl| {
            debugPrint("chnl: {s}", .{chnl});
            //char.chnl = try std.fmt.parseInt(i32, chnl, 10);
        }
        _ = try self.chars.put(char.id, char);
    }

    fn parseKerningLine(self: *BitmapFont, line: []const u8) !void
    {
        var kerning = Kerning {};
        if(getValue(line, "first")) |first| {
            kerning.first = try std.fmt.parseInt(i32, first, 10);
        }
        if(getValue(line, "second")) |second| {
            kerning.second = try std.fmt.parseInt(i32, second, 10);
        }
        if(getValue(line, "amount")) |amount| {
            kerning.amount = try std.fmt.parseInt(i32, amount, 10);
        }
        try self.kernings.append(kerning);
    }
};

