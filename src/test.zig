const std = @import("std");
pub const TgaPixel = struct {
    r: u8, b: u8, g: u8, a: u8
};
test "tester" {
    // const Vec4 =std.meta.Vector(4, f32);
    // const x: Vec4 = .{ 1, -10, 20, -1 };
    // const y: Vec4 = .{ 2, 10, 0, 1 };
    // const z = x + y;
    // try std.testing.expect(std.meta.eql(z, Vec4 { 3, 0, 20, 0 }));
    std.debug.warn("sizeof tgapixel = {d}\n", .{@sizeOf(TgaPixel)});
}