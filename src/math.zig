const c = @cImport({
    @cInclude("SDL3/SDL.h");
});

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
