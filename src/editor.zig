const std = @import("std");
const window = @import("window.zig");

const Window = window.Window;

pub const Editor = struct {
    allocator: std.mem.Allocator,
    window: Window,

    pub fn init(base_allocator: std.mem.Allocator) !Editor {
        return Editor{
            .allocator = base_allocator,
            .window = try Window.init(base_allocator),
        };
    }

    pub fn deinit(self: *Editor) void {
        self.window.deinit();
    }
};
