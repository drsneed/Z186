const std = @import("std");
usingnamespace @import("util.zig");
const Allocator = std.mem.Allocator;


const TgaDataTypeCode = enum(u8) {
    no_image_data = 0,
    uncompressed_color_mapped = 1,
    uncompressed_rgb = 2,
    uncompressed_bw = 3,
    rle_color_mapped = 9,
    rle_rgb = 10,
    compressed_bw = 11,
    compressed_color_mapped = 32,
    compressed_color_mapped_4_pass_quad = 33
};

const TgaHeader = packed struct {   
    idLength: u8,
    colormapType: u8,
    dataTypeCode: TgaDataTypeCode,
    colormapOrigin: i16,
    colormapLength: i16,
    colormapDepth: u8,
    xOrigin: i16,
    yOrigin: i16,
    width: i16,
    height: i16,
    bitsPerPixel: u8,
    imageDescriptor: u8,
};

pub const TgaPixel = struct {
    r: u8, b: u8, g: u8, a: u8
};

pub const TgaImage = struct {
    allocator: *Allocator,
    image: []TgaPixel,
    width: i32,
    height: i32,
    bitsPerPixel: u8,

    pub fn init(allocator: *Allocator) TgaImage {
        return TgaImage {
            .allocator = allocator,
            .image = undefined,
            .width = 0,
            .height = 0,
            .bitsPerPixel = 0
        };
    }

    pub fn loadFromFile(self: *TgaImage, filePath: [] const u8) !void {

        debugPrint("load tga file: {s}\n", .{filePath});

        // read the entire file contents into memory
        var file = try std.fs.cwd().openFile(filePath, std.fs.File.OpenFlags{ .read = true });
        var fileContents = try file.readToEndAlloc(self.allocator, std.math.maxInt(u64));
        defer self.allocator.free(fileContents);
        defer file.close();

        // convert header bytes into TgaHeader struct
        var header = std.mem.bytesToValue(TgaHeader, fileContents[0 .. @sizeOf(TgaHeader)]);

        if(header.dataTypeCode != TgaDataTypeCode.uncompressed_rgb) {
            return error.ImageFormatUnsupported;
        }
        if(header.bitsPerPixel != 16 and header.bitsPerPixel != 24 and header.bitsPerPixel != 32) {
            return error.ImageBitDepthUnsupported;
        }
        if(header.colormapType != 0 and header.colormapType != 1) {
            return error.ColorMapTypeUnsupported;
        }

        // allocate space for image data and store image metrics
        var numPixels = @intCast(usize, header.width) * @intCast(usize, header.height);
        self.image = try self.allocator.alloc(TgaPixel, numPixels);
        self.width = @intCast(i32, header.width);
        self.height = @intCast(i32, header.height);
        self.bitsPerPixel = header.bitsPerPixel;

        var headerOffset:usize = @sizeOf(TgaHeader);
        headerOffset = headerOffset + @intCast(usize, header.idLength);
        headerOffset = headerOffset + @intCast(usize, header.colormapType * header.colormapLength);

        var bytesPerPixel = @intCast(usize, header.bitsPerPixel / 8);
        var n:usize = 0;
        
        var imageData = fileContents[headerOffset .. fileContents.len];
        while(n < numPixels) : (n += 1) {
            var index = n * bytesPerPixel;
            self.image[n] = convertToPixel(imageData[index .. index + bytesPerPixel]);
        }
    }

    fn convertToPixel(p: []u8) TgaPixel {
        return switch(p.len) {
            2 => TgaPixel {
                .r = (p[1] & 0x7c) << 1,
                .g = ((p[1] & 0x03) << 6) | ((p[0] & 0xe0) >> 2),
                .b = (p[0] & 0x1f) << 3,
                .a = (p[1] & 0x80)
            },
            3 => TgaPixel { .r = p[2], .g = p[1], .b = p[0], .a = 255 },
            4 => TgaPixel { .r = p[2], .g = p[1], .b = p[0], .a = p[3] },
            else => TgaPixel {.r = 0, .g = 0, .b = 0, .a = 0}
        };
    }
    

    pub fn deinit(self: TgaImage) void {
        if(self.width > 0) {
            self.allocator.free(self.image);
        }
    }
};