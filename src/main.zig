const std = @import("std");
const math = @import("math.zig");
const rend = @import("renderer.zig");
const Editor = @import("editor.zig").Editor;

const c = @cImport({
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3_ttf/SDL_ttf.h");
    @cInclude("SDL3_image/SDL_image.h");
});

const Vec2 = math.Vec2;
const Vec4 = math.Vec4;
const cwd = std.fs.cwd;

const PROG_NAME = "draco";
const W = 1200;
const H = 800;

const BG = Vec4{
    .x = 0.0,
    .y = 0.0,
    .z = 0.0,
    .w = 1.0,
};

const FG = Vec4{
    .x = 1.0,
    .y = 1.0,
    .z = 1.0,
    .w = 1.0,
};

var window: ?*c.SDL_Window = undefined;
pub var renderer: ?*c.SDL_Renderer = undefined;
var refresh_rate_ns: u64 = undefined;
var header_font: ?*c.TTF_Font = undefined;
var body_font: ?*c.TTF_Font = undefined;
var font_bytes: []const u8 = "";
var font_bold_italic_bytes: []const u8 = "";
var editor: Editor = undefined;
var arena_impl: std.heap.ArenaAllocator = undefined;

fn setRefreshRate(display_fps: f32) void {
    refresh_rate_ns = @intFromFloat(1_000_000 / display_fps);
}

fn sleepNextFrame() void {
    std.Thread.sleep(refresh_rate_ns);
}

pub fn main() !void {
    //Initialize SDL
    if (!c.SDL_Init(c.SDL_INIT_VIDEO)) {
        c.SDL_Log("SDL could not initialize! SDL error: %s\n", c.SDL_GetError());
        return;
    }
    defer c.SDL_Quit();

    if (!c.TTF_Init()) {
        std.debug.print("TTF failed init\n", .{});
        return;
    }
    defer c.TTF_Quit();

    arena_impl = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    defer arena_impl.deinit();
    const arena = arena_impl.allocator();

    font_bold_italic_bytes = cwd().readFileAlloc(arena, "/usr/share/fonts/TTF/TinosNerdFont-BoldItalic.ttf", 10_000_000) catch |e| {
        std.debug.print("Couldn't open font: {any}\n", .{e});
        return;
    };
    font_bytes = cwd().readFileAlloc(arena, "/usr/share/fonts/TTF/TinosNerdFont-Regular.ttf", 10_000_000) catch |e| {
        std.debug.print("Couldn't open font: {any}\n", .{e});
        return;
    };

    header_font = c.TTF_OpenFontIO(c.SDL_IOFromConstMem(font_bold_italic_bytes.ptr, font_bold_italic_bytes.len), false, 62.0) orelse {
        std.debug.print("Couldn't open font: {s}\n", .{c.SDL_GetError()});
        return;
    };

    body_font = c.TTF_OpenFontIO(c.SDL_IOFromConstMem(font_bytes.ptr, font_bytes.len), false, 20.0) orelse {
        std.debug.print("Couldn't open font: {s}\n", .{c.SDL_GetError()});
        return;
    };

    editor = try Editor.init(std.heap.c_allocator);
    defer editor.deinit();

    const display_mode = c.SDL_GetCurrentDisplayMode(c.SDL_GetPrimaryDisplay()) orelse {
        c.SDL_Log("Could not get display mode! SDL error: %s\n", c.SDL_GetError());
        return;
    };
    setRefreshRate(display_mode.*.refresh_rate);

    //const win_flags = c.SDL_WINDOW_INPUT_FOCUS | c.SDL_WINDOW_HIGH_PIXEL_DENSITY | c.SDL_WINDOW_MAXIMIZED | c.SDL_WINDOW_RESIZABLE | c.SDL_WINDOW_BORDERLESS;
    const win_flags = c.SDL_WINDOW_INPUT_FOCUS | c.SDL_WINDOW_HIGH_PIXEL_DENSITY | c.SDL_WINDOW_RESIZABLE | c.SDL_WINDOW_BORDERLESS;

    if (!c.SDL_CreateWindowAndRenderer(PROG_NAME, W, H, win_flags, &window, &renderer)) {
        std.debug.print("Couldn't create window/renderer:", .{});
        return;
    }

    _ = c.SDL_StartTextInput(window);

    loop();
}

var animating = false;
var last_tick: i64 = 0;
var was_pos = Vec2{
    .x = -1.0,
    .y = -1.0,
};

fn maybeAnimate() void {}

fn loop() void {
    last_tick = std.time.microTimestamp();
    var running = true;
    var event: c.SDL_Event = undefined;
    while (running) {
        const current_tick = std.time.microTimestamp();
        defer last_tick = current_tick;
        const dt = @as(f32, @floatFromInt(current_tick - last_tick)) / std.time.us_per_s;
        while (c.SDL_PollEvent(&event)) {
            switch (event.type) {
                c.SDL_EVENT_QUIT => {
                    running = false;
                },
                c.SDL_EVENT_KEY_DOWN => {
                    switch (event.key.key) {
                        c.SDLK_ESCAPE => {
                            running = false;
                        },
                        c.SDLK_A => {
                            if (event.key.mod & c.SDL_KMOD_CTRL != 0) {
                                std.debug.print("A PRESSED\n", .{});
                            }
                        },
                        c.SDLK_BACKSPACE => {
                            editor.window.removeFrontCursor();
                            maybeAnimate();
                        },
                        c.SDLK_DELETE => {
                            editor.window.removeBehindCursor();
                            maybeAnimate();
                        },
                        c.SDLK_LEFT => {
                            editor.window.left();
                            maybeAnimate();
                        },
                        c.SDLK_RIGHT => {
                            editor.window.right();
                            maybeAnimate();
                        },
                        else => {},
                    }
                },
                c.SDL_EVENT_TEXT_INPUT => {
                    editor.window.insert(std.mem.span(event.text.text));
                    maybeAnimate();
                },
                else => {},
            }
        }
        if (!running) {
            break;
        }

        const dim = rend.strdim(body_font, editor.window.buffer.items[0..editor.window.cursor]);
        const is_pos = Vec2{
            .x = dim.w + 100.0,
            .y = 200.0,
        };

        if (was_pos.x == -1.0 and was_pos.y == -1.0) {
            was_pos = is_pos;
        }

        was_pos = .{
            .x = math.damp(is_pos.x, was_pos.x, 0.0001, dt),
            .y = math.damp(is_pos.y, was_pos.y, 0.0001, dt),
        };
        const rect = c.SDL_FRect{
            .x = was_pos.x,
            .y = was_pos.y,
            .w = 2.0,
            .h = 20.0,
        };

        _ = c.SDL_SetRenderDrawColorFloat(renderer, BG.x, BG.y, BG.z, BG.w);
        _ = c.SDL_RenderClear(renderer);
        rend.drawText(header_font, "Title", FG, 100.0, 100.0);
        rend.drawText(body_font, editor.window.buffer.items, FG, 100.0, 200.0);
        _ = c.SDL_SetRenderDrawColorFloat(renderer, FG.x, FG.y, FG.z, FG.w);
        _ = c.SDL_RenderFillRect(renderer, &rect);
        _ = c.SDL_RenderPresent(renderer);

        sleepNextFrame();
    }
}

comptime {
    std.testing.refAllDecls(@import("window.zig"));
}
