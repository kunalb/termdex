const std = @import("std");
const net = std.net;

pub fn main() !void {
    const host: [4]u8 = [4]u8{ 127, 0, 0, 1 };
    const port = 1234;
    const addr = net.Address.initIp4(host, port);
    const socket = try std.posix.socket(
        addr.any.family,
        std.posix.SOCK.STREAM,
        std.posix.IPPROTO.TCP,
    );
    const stream = net.Stream{ .handle = socket };
    _ = stream;

    var server = try addr.listen(.{});
    _ = try server.accept();
}
