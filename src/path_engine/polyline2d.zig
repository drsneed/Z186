const std = @import("std");
usingnamespace @import("../glm.zig");
usingnamespace @import("../c_dependencies.zig");


pub const Polyline2d = struct
{
    pub const JointStyle = enum {
        /// Corners are drawn with sharp joints. If the joint's outer angle is too large,
        /// the joint is drawn as beveled instead, to avoid the miter extending too far out.
        Miter,
        /// Corners are flattened.
        Bevel,
        /// Corners are rounded off.
        Round
    };
    pub const EndCapStyle = enum {
        
        /// Path ends are drawn flat, and don't exceed the actual end point.
        Butt,
        /// Path ends are drawn flat, but extended beyond the end point by half the line thickness.
        Square,
        /// Path ends are rounded off.
        Round,
        /// Path ends are connected according to the JointStyle.
        /// When using this EndCapStyle, don't specify the common start/end point twice,
        /// as Polyline2D connects the first and last input point itself.
        Joint
    };

    pub const LineSegment = struct {
        a: Vector2,
        b: Vector2,

        pub fn offset(self: *LineSegment, amount: Vector2) void {
            self.a.x += amount.x;
            self.b.x += amount.x;
            self.a.y += amount.y;
            self.b.y += amount.y;
        }

        pub fn normal(self: LineSegment) Vector2 {
            var dir = self.ndirection();
            // return the direction vector
            // rotated by 90 degrees counter-clockwise
            return Vector2{.x=-dir.y, .y=dir.x};
        }
        pub fn direction(self: LineSegment) Vector2 {
            return self.b.sub(self.a);
        }
        pub fn ndirection(self: LineSegment) Vector2 {
            return self.b.sub(self.a).normalize();
        }
        
        pub fn intersection(a: LineSegment, b: LineSegment, infiniteLines: bool) ?Vector2 {
            // calculate un-normalized direction vectors
            var r = a.direction();
            var s = b.direction();

            var originDist = b.a.sub(a.a);

            var uNumerator = originDist.x * r.y - originDist.y * r.x;
            var denominator = r.x * s.y - r.y * s.x;

            if (std.math.absFloat(denominator) < 0.0001) {
                // The lines are parallel
                return null;
            }

            // solve the intersection positions
            var u = uNumerator / denominator;
            var t = (originDist.x * s.y - originDist.y * s.x) / denominator;

            if (!infiniteLines and (t < 0.0 or t > 1.0 or u < 0.0 or u > 1.0)) {
                // the intersection lies outside of the line segments
                return null;
            }

            // calculate the intersection point
            // a.a + r * t;
            return a.a.add(r.mulScalar(t));
        }
    };

    pub const PolySegment = struct {
        center: LineSegment, 
        edge1: LineSegment,
        edge2: LineSegment,

        pub fn init(center: LineSegment, thickness: f32) PolySegment {
            // calculate the segment's outer edges by offsetting
            // the central line by the normal vector
            // multiplied with the thickness
            // center + center.normal() * thickness
            var amount = center.normal().mulScalar(thickness);
            var edge1 = center;
            edge1.offset(amount);
            var edge2 = center;
            edge2.offset(amount.neg());

            return PolySegment {
                .center = center,
                .edge1 = edge1,
                .edge2 = edge2
            };
        }
    };

    
    /// The threshold for mitered joints.
    /// If the joint's angle is smaller than this angle,
    /// the joint will be drawn beveled instead.
    const MiterMinAngle:f32 = 0.349066; // ~20 degrees

    /// The minimum angle of a round joint's triangles.
    const RoundMinAngle:f32 = 0.174533; // ~10 degrees

    /// Creates a vector of vertices describing a solid path through the input points.
    /// points: The points of the path.
    /// thickness: The path's thickness.
    /// jointStyle: The path's joint style.
    /// endCapStyle: The path's end cap style.
    /// allowOverlap: Whether to allow overlapping vertices.
    /// This yields better results when dealing with paths
    /// whose points have a distance smaller than the thickness,
    /// but may introduce overlapping vertices,
    /// which is undesirable when rendering transparent paths.
    /// returns the vertices describing the path.
    
    pub fn create(allocator: *std.mem.Allocator, points: std.ArrayList(Vector2), thickness: f32,
                jointStyle: JointStyle,
                endCapStyle: EndCapStyle,
                allowOverlap:bool) !std.ArrayList(Vector2) {
        var vertices = std.ArrayList(Vector2).init(allocator);
        _ = try createAppend(allocator, &vertices, points, thickness, jointStyle, endCapStyle, allowOverlap);
        return vertices;
    }

    pub fn createAppend(allocator: *std.mem.Allocator, vertices: *std.ArrayList(Vector2), 
        points: std.ArrayList(Vector2),
        thickness: f32,
        jointStyle: JointStyle,
        endCapStyle: EndCapStyle,
        allowOverlap:bool) !usize {
        var originalLength = vertices.items.len;

        // operate on half the thickness to make our lives easier
        var thick = thickness / 2.0;
        // create poly segments from the points
        var segments = std.ArrayList(PolySegment).init(allocator);
        defer segments.deinit();
        var i:usize = 0;
        while(i < points.items.len - 1) : (i += 1)
        {
            var point1 = points.items[i];
            var point2 = points.items[i + 1];
            // to avoid division-by-zero errors,
            // only create a line segment for non-identical points
            if (!point1.eql(point2)) {
                try segments.append(PolySegment.init(LineSegment{.a=point1, .b=point2}, thick));
            }
        }

        if (endCapStyle == EndCapStyle.Joint) {
            // create a connecting segment from the last to the first point
            var point1 = points.items[points.items.len - 1];
            var point2 = points.items[0];

            // to avoid division-by-zero errors,
            // only create a line segment for non-identical points
            if (!point1.eql(point2)) {
                try segments.append(PolySegment.init(LineSegment{.a=point1, .b=point2}, thick));
            }
        }

        if (segments.items.len == 0) {
            // handle the case of insufficient input points
            return 0;
        }

        var nextStart1 = Vector2{};
        var nextStart2 = Vector2{};
        var start1 = Vector2{};
        var start2 = Vector2{};
        var end1 = Vector2{};
        var end2 = Vector2{};

        // calculate the path's global start and end points
        var firstSegment = segments.items[0];
        var lastSegment = segments.items[segments.items.len - 1];

        var pathStart1 = firstSegment.edge1.a;
        var pathStart2 = firstSegment.edge2.a;
        var pathEnd1 = lastSegment.edge1.b;
        var pathEnd2 = lastSegment.edge2.b;

        // handle different end cap styles
        switch(endCapStyle) {
            EndCapStyle.Butt => {}, // do nothing
            EndCapStyle.Square => {
                // extend the start/end points by half the thickness
                pathStart1 = pathStart1.sub(firstSegment.edge1.direction().mulScalar(thick));
                pathStart2 = pathStart2.sub(firstSegment.edge2.direction().mulScalar(thick));
                pathEnd1 = pathEnd1.add(lastSegment.edge1.direction().mulScalar(thick));
                pathEnd2 = pathEnd2.add(lastSegment.edge2.direction().mulScalar(thick));
            },
            EndCapStyle.Round => {
                // draw half circle end caps
                try createTriangleFan(vertices, firstSegment.center.a, firstSegment.center.a,
                        firstSegment.edge1.a, firstSegment.edge2.a, false);
                try createTriangleFan(vertices, lastSegment.center.b, lastSegment.center.b,
                        lastSegment.edge1.b, lastSegment.edge2.b, true);
            },
            EndCapStyle.Joint => {
                // // join the last (connecting) segment and the first segment
                try createJoint(vertices, lastSegment, firstSegment, jointStyle,
                    &pathEnd1, &pathEnd2, &pathStart1, &pathStart2, allowOverlap);
            },
        }
        // generate mesh data for path segments
        i = 0;
        while(i < segments.items.len) : (i += 1) {
            var segment = segments.items[i];

            // calculate start
            if (i == 0) {
                // this is the first segment
                start1 = pathStart1;
                start2 = pathStart2;
            }

            if (i == segments.items.len - 1) {
                // this is the last segment
                end1 = pathEnd1;
                end2 = pathEnd2;

            } else {
                try createJoint(vertices, segment, segments.items[i + 1], jointStyle,
                    &end1, &end2, &nextStart1, &nextStart2, allowOverlap);
            }

            // emit vertices
            try vertices.append(start1);
            try vertices.append(start2);
            try vertices.append(end1);

            try vertices.append(end1);
            try vertices.append(start2);
            try vertices.append(end2);

            start1 = nextStart1;
            start2 = nextStart2;
        }
        
        
        return vertices.items.len - originalLength;
    }

    fn createJoint(vertices: *std.ArrayList(Vector2), 
        segment1: PolySegment, 
        segment2: PolySegment,
        jointStyle: JointStyle, 
        end1: *Vector2, 
        end2: *Vector2,
        nextStart1: *Vector2, 
        nextStart2: *Vector2,
        allowOverlap: bool) !void 
    {
        // calculate the angle between the two line segments
        var dir1 = segment1.center.direction();
        var dir2 = segment2.center.direction();
        var magnitude = std.math.sqrt(dir1.x * dir1.x + dir1.y * dir1.y);
        var angle = std.math.acos(dir1.dot(dir2) / (magnitude * magnitude));

        // wrap the angle around the 180° mark if it exceeds 90°
        // for minimum angle detection
        var wrappedAngle = angle;
        if (wrappedAngle > std.math.pi / 2.0) {
            wrappedAngle = std.math.pi - wrappedAngle;
        }
        var style = jointStyle;
        if (style == JointStyle.Miter and wrappedAngle < MiterMinAngle) {
            // the minimum angle for mitered joints wasn't exceeded.
            // to avoid the intersection point being extremely far out,
            // thus producing an enormous joint like a rasta on 4/20,
            // we render the joint beveled instead.
            style = JointStyle.Bevel;
        }

        if (jointStyle == JointStyle.Miter) {
            // calculate each edge's intersection point
            // with the next segment's central line
            end1.* = segment1.edge1.intersection(segment2.edge1, true) orelse segment1.edge1.b;
            end2.* = segment1.edge2.intersection(segment2.edge2, true) orelse segment1.edge2.b;
            nextStart1.* = end1.*;
            nextStart2.* = end2.*;

        } else {
            // // joint style is either Bevel or Round
            // // find out which are the inner edges for this joint
            var x1 = dir1.x;
            var x2 = dir2.x;
            var y1 = dir1.y;
            var y2 = dir2.y;

            var clockwise = x1 * y2 - x2 * y1 < 0;

            const inner1 = if(clockwise) &segment1.edge2 else &segment1.edge1;
            const inner2 = if(clockwise) &segment2.edge2 else &segment2.edge1;
            const outer1 = if(clockwise) &segment1.edge1 else &segment1.edge2;
            const outer2 = if(clockwise) &segment2.edge1 else &segment2.edge2;
            
            // calculate the intersection point of the inner edges
            var innerSec: Vector2 = undefined;
            var innerStart: Vector2 = undefined;
            if(LineSegment.intersection(inner1.*, inner2.*, allowOverlap)) |intersectPoint| {
                innerSec = intersectPoint;
                innerStart = innerSec;
            } else {
                // for parallel lines (else), simply connect them directly
                innerSec = inner1.b;
                // if there's no inner intersection, flip
                // the next start position for near-180° turns
                innerStart = if(angle > pi / 2.0) outer1.b else inner1.b;
            }

            if (clockwise) {
                end1.* = outer1.b;
                end2.* = innerSec;

                nextStart1.* = outer2.a;
                nextStart2.* = innerStart;

            } else {
                end1.* = innerSec;
                end2.* = outer1.b;

                nextStart1.* = innerStart;
                nextStart2.* = outer2.a;
            }

            // connect the intersection points according to the joint style

            if (jointStyle == JointStyle.Bevel) {
                // simply connect the intersection points
                try vertices.append(outer1.b);
                try vertices.append(outer2.a);
                try vertices.append(innerSec);

            } else if (jointStyle == JointStyle.Round) {
                // draw a circle between the ends of the outer edges,
                // centered at the actual point
                // with half the line thickness as the radius
                try createTriangleFan(vertices, innerSec, segment1.center.b, outer1.b, outer2.a, clockwise);
            }
        }
    }

    fn createTriangleFan(vertices: *std.ArrayList(Vector2), 
        connectTo: Vector2, 
        origin: Vector2,
        start: Vector2,
        end: Vector2,
        clockwise: bool) !void
    {
        var point1 = start.sub(origin);
        var point2 = end.sub(origin);

        // calculate the angle between the two points
        var angle1 = std.math.atan2(f32, point1.y, point1.x);
        var angle2 = std.math.atan2(f32, point2.y, point2.x);

        // ensure the outer angle is calculated
        if (clockwise) {
            if (angle2 > angle1) {
                angle2 = angle2 - 2 * pi;
            }
        } else {
            if (angle1 > angle2) {
                angle1 = angle1 - 2 * pi;
            }
        }

        var jointAngle = angle2 - angle1;

        // calculate the amount of triangles to use for the joint
        var numTriangles = std.math.max(@as(i32, 1), @floatToInt(i32, std.math.floor(std.math.absFloat(jointAngle) / RoundMinAngle)));
        
        // calculate the angle of each triangle
        var triAngle = jointAngle / @intToFloat(f32, numTriangles);


        var startPoint = start;
        var endPoint:Vector2 = undefined;
        var t:i32 = 0;
        while(t < numTriangles) : (t += 1) {
            if (t + 1 == numTriangles) {
                // it's the last triangle - ensure it perfectly
                // connects to the next line
                endPoint = end;

                // emit the triangle
                try vertices.append(startPoint);
                try vertices.append(endPoint);
                try vertices.append(connectTo);

            } else {
                var rot = @intToFloat(f32, t + 1) * triAngle;

                // rotate the original point around the origin
                endPoint.x = std.math.cos(rot) * point1.x - std.math.sin(rot) * point1.y;
                endPoint.y = std.math.sin(rot) * point1.x + std.math.cos(rot) * point1.y;

                // re-add the rotation origin to the target point
                endPoint = endPoint.add(origin);

                // emit the triangle
                try vertices.append(startPoint);
                try vertices.append(endPoint);
                try vertices.append(connectTo);

                startPoint = endPoint;
            }
        }
    }
};