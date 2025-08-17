const std = @import("std");

const Vec2 = @import("math.zig").Vec2;

const assert = std.debug.assert;

const Line = struct {
    begin: usize,
    end: usize,
};

pub const Window = struct {
    arena: std.heap.ArenaAllocator,
    buffer: std.ArrayList(u8),
    lines: std.ArrayList(Line),
    cursor: usize = 0,

    pub fn init(base_allocator: std.mem.Allocator) !Window {
        var arena = std.heap.ArenaAllocator.init(base_allocator);
        const buffer = try std.ArrayList(u8).initCapacity(arena.allocator(), 1024);
        var lines = try std.ArrayList(Line).initCapacity(arena.allocator(), 128);
        lines.appendAssumeCapacity(Line{
            .begin = 0,
            .end = 0,
        });
        return Window{
            .arena = arena,
            .buffer = buffer,
            .lines = lines,
        };
    }

    pub fn deinit(self: *Window) void {
        self.arena.deinit();
    }

    fn reindex(self: *Window) void {
        self.reindexLines() catch @panic("OOM");
    }

    fn reindexLines(self: *Window) !void {
        self.lines.clearRetainingCapacity();
        var begin: usize = 0;
        for (self.buffer.items, 0..) |c, idx| {
            if (c == '\n') {
                const end = idx;
                try self.lines.append(.{
                    .begin = begin,
                    .end = end,
                });
                begin = end + 1;
            }
        }
        try self.lines.append(.{
            .begin = begin,
            .end = self.buffer.items.len,
        });
    }

    pub fn insert(self: *Window, what: []const u8) void {
        self.buffer.insertSlice(self.cursor, what) catch @panic("OOM");
        self.cursor += what.len;
        self.reindex();
    }

    pub fn insertNewline(self: *Window) void {
        self.buffer.insert(self.cursor, '\n') catch @panic("OOM");
        self.reindex();
        self.cursor += 1;
        self.down();
    }

    fn byte(self: *Window, idx: usize) u8 {
        return self.buffer.items[idx];
    }

    const terminating_codepoints: []const u8 = &.{
        0b1100_0000,
        0b1110_0000,
        0b1111_0000,
    };

    const utf_1_inv_mask = 0b1000_0000;
    const utf_2_mask = 0b1100_0000;
    const utf_3_mask = 0b1110_0000;
    const utf_4_mask = 0b1111_0000;

    fn bytesUntilNearestCodepointLeft(self: *Window) usize {
        assert(self.cursor > 0);
        const offset: usize = if (self.cursor + 1 == self.buffer.items.len) 1 else 0;
        if (utf_1_inv_mask & self.byte(self.cursor - 1 - offset) == 0 or self.cursor < 2) {
            return 1;
        }
        if (utf_2_mask & self.byte(self.cursor - 2 - offset) != 0 or self.cursor < 3) {
            return 2;
        }
        if (utf_3_mask & self.byte(self.cursor - 3 - offset) != 0 or self.cursor < 4) {
            return 3;
        }
        return 4;
    }

    fn bytesUntilNearestCodepointRight(self: *Window) usize {
        const last_byte_index = @max(self.buffer.items.len, 1) - 1;
        if (self.cursor == last_byte_index) {
            return 0;
        }
        assert(self.cursor < last_byte_index);
        const b = self.byte(self.cursor);
        if (utf_2_mask & b == 0 or self.cursor + 1 == last_byte_index) {
            return 1;
        }
        if (utf_2_mask & b != 1 or self.cursor + 2 == last_byte_index) {
            return 2;
        }
        if (utf_3_mask & b != 1 or self.cursor + 3 == last_byte_index) {
            return 3;
        }
        return 4;
    }

    pub fn left(self: *Window) void {
        if (self.cursor > 0) {
            const n = self.bytesUntilNearestCodepointLeft();
            self.cursor -= n;
        }
    }

    pub fn right(self: *Window) void {
        if (self.cursor < self.buffer.items.len) {
            const n = self.bytesUntilNearestCodepointRight();
            self.cursor += n;
        }
    }

    pub fn up(self: *Window) void {
        const pos = self.cursorPos();
        if (pos.row <= 0) {
            return;
        }
        const line = self.allLines()[pos.row - 1];

        self.cursor = @min(line.begin + pos.column, line.end);
    }

    pub fn down(self: *Window) void {
        const pos = self.cursorPos();
        if (pos.row + 1 >= self.allLines().len) {
            return;
        }
        const line = self.allLines()[pos.row + 1];

        self.cursor = @min(line.begin + pos.column, line.end);
    }

    pub fn removeRightCursor(self: *Window) void {
        if (self.cursor < self.buffer.items.len) {
            const n = self.bytesUntilNearestCodepointRight();
            for (0..n) |_| {
                _ = self.buffer.orderedRemove(self.cursor);
            }
        }
        self.reindex();
    }

    pub fn removeLeftCursor(self: *Window) void {
        if (self.cursor > 0) {
            const n = self.bytesUntilNearestCodepointLeft();
            for (0..n) |_| {
                _ = self.buffer.orderedRemove(self.cursor - 1);
                self.cursor -= 1;
            }
        }
        self.reindex();
    }

    pub fn allLines(self: *Window) []const Line {
        return self.lines.items;
    }

    pub fn lineSlice(self: *Window, idx: usize) []const u8 {
        const line = self.lines.items[idx];
        return self.buffer.items[line.begin..line.end];
    }

    pub fn cursorPos(self: *Window) struct {
        row: usize,
        column: usize,
    } {
        const cursor = self.cursor;
        for (self.allLines(), 0..) |line, idx| {
            if (cursor >= line.begin and cursor <= line.end) {
                return .{
                    .row = idx,
                    .column = cursor - line.begin,
                };
            }
        }
        unreachable;
    }

    pub fn cursorDrawData(self: *Window) struct {
        row: f32,
        text_left_of_cursor: []const u8,
    } {
        const pos = self.cursorPos();
        const line = self.lines.items[pos.row];
        return .{
            .row = @floatFromInt(pos.row),
            .text_left_of_cursor = self.buffer.items[line.begin .. line.begin + pos.column],
        };
    }
};
