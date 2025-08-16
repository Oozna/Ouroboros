const std = @import("std");
const pow = std.math.pow;

pub const Vec2 = struct {
    x: f32,
    y: f32,
};

pub const Vec4 = struct {
    x: f32,
    y: f32,
    z: f32,
    w: f32,
};

pub fn square(x: f32) f32 {
    return x * x;
}

pub fn lerp(to: f32, from: f32, t: f32) f32 {
    return (1.0 - t) * from + t * to;
}

pub fn damp(to: f32, from: f32, smoothing: f32, dt: f32) f32 {
    return lerp(to, from, 1.0 - pow(f32, smoothing, dt));
}
