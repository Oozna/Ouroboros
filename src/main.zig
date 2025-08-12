const std = @import("std");

const c = @cImport({
    //@cDefine("SDL_DISABLE_OLD_NAMES", {});
    @cInclude("SDL3/SDL.h");
    //@cInclude("SDL3/SDL_revision.h");
    //@cDefine("SDL_MAIN_HANDLED", {}); // We are providing our own entry point
    //@cInclude("SDL3/SDL_main.h");
});

const PROG_NAME = "draco";
const W = 800;
const H = 600;

var window: ?*c.SDL_Window = undefined;
var renderer: ?*c.SDL_Renderer = undefined;
var refresh_rate_ns: u64 = undefined;

fn setRefreshRate(display_fps: f32) void {
    refresh_rate_ns = @intFromFloat(1_000_000 / display_fps);
}

pub fn main() !void {
    //Initialize SDL
    if (!c.SDL_Init(c.SDL_INIT_VIDEO)) {
        c.SDL_Log("SDL could not initialize! SDL error: %s\n", c.SDL_GetError());
        return;
    }
    defer c.SDL_Quit();

    const display_mode = c.SDL_GetCurrentDisplayMode(c.SDL_GetPrimaryDisplay());
    setRefreshRate(display_mode.*.refresh_rate);

    _ = c.SDL_SetHint(c.SDL_HINT_WINDOW_ALLOW_TOPMOST, "1");

    const win_flags = c.SDL_WINDOW_INPUT_FOCUS | c.SDL_WINDOW_HIGH_PIXEL_DENSITY | c.SDL_WINDOW_MAXIMIZED;

    if (!c.SDL_CreateWindowAndRenderer(PROG_NAME, W, H, win_flags, &window, &renderer)) {
        std.debug.print("Couldn't create window/renderer:", .{});
        return;
    }

    var running = true;
    var event: c.SDL_Event = undefined;
    while (running) {
        while (c.SDL_PollEvent(&event)) {
            //If event is quit type
            if (event.type == c.SDL_EVENT_QUIT) {
                running = false;
            }
        }
        if (!running) {
            break;
        }

        _ = c.SDL_SetRenderDrawColorFloat(renderer, 0.0, 0.0, 0.0, 0.0);
        _ = c.SDL_RenderClear(renderer);
        //
        _ = c.SDL_RenderPresent(renderer);
    }
}
