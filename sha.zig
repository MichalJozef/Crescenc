const std = @import("std");

const Word: type = [4]u8;
const Block: type = [16]Word;

const K1: Word = [_]u8{'\x5A', '\x82', '\x79', '\x99'};
const K2: Word = [_]u8{'\x6E', '\xD9', '\xEB', '\xA1'};
const K3: Word = [_]u8{'\x8F', '\x1B', '\xBC', '\xDC'};
const K4: Word = [_]u8{'\xCA', '\x62', '\xC1', '\xD6'};

fn wand(x: Word, y: Word) Word {
    var result: Word = undefined;
    for (x) |val, i| {
        result[i] = val & y[i];
    }
    return result;
}

fn wor(x: Word, y: Word) Word {
    var result: Word = undefined;
    for (x) |val, i| {
        result[i] = val | y[i];
    }
    return result;
}

fn wxor(x: Word, y: Word) Word {
    var result: Word = undefined;
    for (x) |val, i| {
        result[i] = val ^ y[i];
    }
    return result;
}

fn wnot(x: Word) Word {
    var result: Word = undefined;
    for (x) |val, i| {
        result[i] = ~val;
    }
    return result;
}

fn wplus(x: Word, y: Word) Word {
    return convertFromU32(convertToU32(x) +% convertToU32(y));
}

fn convertToU32(str: Word) u32 {
    return std.mem.readInt(u32, &str, std.Target.Cpu.Arch.endian(std.Target.Cpu.Arch.arm));
}

fn convertFromU32(u: u32) Word {
    return std.mem.toBytes(u);
}

test "wplus" {
    const w1: Word = [_]u8{ '\x61', '\x62', '\x63', '\x64' };
    const w2: Word = [_]u8{ '\x65', '\x66', '\x67', '\x68' };
    const w3: Word = wplus(w1, w2);
    std.debug.assert(std.mem.eql(u8, &w3, &[_]u8{ '\xC6', '\xC8', '\xCA', '\xCC' }));
}

fn circular(n: u5, w: Word) Word {
    var w1: Word = w;
    var w2: Word = w;
    var tmpA: *align(1) u32 = std.mem.bytesAsValue(u32, &w1);
    var tmpB: *align(1) u32 = std.mem.bytesAsValue(u32, &w2);
    tmpA.* <<= n;
    tmpB.* >>= 31 - n + 1;
    return wor(std.mem.bytesToValue(Word, @ptrCast(*Word, tmpA)), std.mem.bytesToValue(Word, @ptrCast(*Word, tmpB)));
}

fn f(u: u8, b: Word, c: Word, d: Word) !Word {
    if (u <= 19 ) {
        return wor(wand(b, c), wand(wnot(b), d));
    }
    if (u <= 39) {
        return wxor(b, wxor(c, d));
    }
    if (u <= 59) {
        return wor(wand(b, c), wor(wand(b, d), wand(c, d)));
    }
    if (u <= 79) {
        return wxor(b, wxor(c, d));
    }
    return error.WordError;
}

fn k(u: u8) !Word {
    if (u <= 19) {
        return K1;
    }
    if (u <= 39) {
        return K2;
    }
    if (u <= 59) {
        return K3;
    }
    if (u <= 79) {
        return K4;
    }
    return error.WordError;
}

fn padding(block: *Block, message: [] const u8) void {
    var formator: u64 = 0xff << 0x38;
    var comparator: u6 = 56;
    @memcpy(@ptrCast([*]u8, block), @ptrCast([*]const u8, message), message.len);
    for (@ptrCast(*[64]u8, block)) |*value, i| {
        if (i == message.len) {
            value.* = '\x80';
        }
        if ((i > message.len) and (i < 56)) {
            value.* = '\x00';
        }
        if (i >= 56) {
            value.* = @intCast(u8, ((formator & (message.len * 8)) >> comparator));
            formator >>= 8;
            comparator -|= 8;
        }
        // if (i % 4 == 0) std.debug.print(" ", .{});
        // if (i % 16 == 0) std.debug.print("\n", .{});
        // std.debug.print("{x:0^2}", .{value.*});
    }
}

test "k" {
    const k1 = try k(1);
    const k2 = try k(21);
    const k3 = try k(41);
    const k4 = try k(61);
    std.debug.assert(std.mem.eql(u8, &K1, &k1));
    std.debug.assert(std.mem.eql(u8, &K2, &k2));
    std.debug.assert(std.mem.eql(u8, &K3, &k3));
    std.debug.assert(std.mem.eql(u8, &K4, &k4));
}

fn calculate(message: [] const u8) !void {
    var block: Block = undefined;
    var bufferA: [5]Word = undefined;
    var bufferB: [5]Word = [_]Word{
        [_]u8{ '\x67', '\x45', '\x23', '\x01' },
        [_]u8{ '\xEF', '\xCD', '\xAB', '\x89' },
        [_]u8{ '\x98', '\xBA', '\xDC', '\xFE' },
        [_]u8{ '\x10', '\x32', '\x54', '\x76' },
        [_]u8{ '\xC3', '\xD2', '\xE1', '\xF0' },
    };
    var temp: Word = undefined;
    var seq: [80]Word = undefined;

    padding(&block, message);

    // for (block) |val, i| {
    //     seq[i] = val;
    // }

    for (seq) |*val, i| {
        if (i < 16) {
            val.* = block[i];
        } else {
            val.* = wxor(circular(1, seq[i - 3]), wxor(seq[i - 8], wxor(seq[i - 14], seq[i - 16])));
        }
    }
    // for (seq) |value| {
    //     for (value) |val| {
    //         std.debug.print("{x:0^2}", .{val});
    //     }
    // }
    for (bufferA) |*val, i| {
        val.* = bufferB[i];
    }

    for ([_]u8{0} ** 80) |_, i| {
        // std.debug.print("{d} ", .{i});
        temp = wplus(circular(5, bufferA[0]), wplus(try f(@intCast(u8, i), bufferA[1], bufferA[2], bufferA[3]), wplus(bufferA[4], wplus(seq[i], try k(@intCast(u8, i))))));
        bufferA[4] = bufferA[3];
        bufferA[3] = bufferA[2];
        bufferA[2] = circular(30, bufferA[1]);
        bufferA[1] = bufferA[0];
        bufferA[0] = temp;
    }

    bufferB[0] = wplus(bufferB[0], bufferA[0]);
    bufferB[1] = wplus(bufferB[1], bufferA[1]);
    bufferB[2] = wplus(bufferB[2], bufferA[2]);
    bufferB[3] = wplus(bufferB[3], bufferA[3]);
    bufferB[4] = wplus(bufferB[4], bufferA[4]);

    for (bufferB) |value| {
        for (value) |val| {
            std.debug.print("{x:0^2}", .{val});
        }
    }
}

pub fn main() !void {
    // const a: Word = [_]u8 {'\x61', '\x62', '\x63', '\x64'};
    // const b: Word = [_]u8 {'\x65', '\x66', '\x67', '\x68'};
    // const c: Word = [_]u8 {'\x69', '\x70', '\x71', '\x72'};
    // const result = try f(42, a, b, c);
    // for (result) |val| {
    //     std.debug.print("{x:0^2} ", .{val});
    // }
    // std.debug.print("\n", .{});
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    if (args.len != 2) {
        std.debug.print("Usage '{s}' <string>\n", .{args[0]});
        std.process.exit(1);
    }

    const message = args[1];
    // for (message) |val| {
    //     std.debug.print("{d} ", .{val});
    // }
    // check(message);
    // var block: Block = undefined;
    // padding(&block, message);
    // const msg = try k(40);
    // std.debug.print("\n", .{});
    const result = try calculate(message);
    _ = result;
    // for (msg) |val| {
    //     std.debug.print("{X:0^2} ", .{val});
    // }
    // const msg = circular(2, a);
    // std.debug.print("\n", .{});
    // for (msg) |val| {
    //     std.debug.print("{X:0^2} ", .{val});
    // }
    // std.debug.print("{}\n", .{@typeInfo(Block)});
}
