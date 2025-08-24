const std = @import("std");

const c = @cImport({
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3_ttf/SDL_ttf.h");
    @cInclude("SDL3_image/SDL_image.h");
});

pub const KeyInput = struct {
    key: c.SDL_Keycode,
    mod: packed struct {
        ctrl: bool,
        alt: bool,
        shift: bool,
    },
    write: []const u8,
};

pub const WriteInput = struct {
    key: c.SDL_Keycode,
    mod: packed struct {
        ctrl: bool,
        alt: bool,
        shift: bool,
    },
};

pub fn new() void {}
