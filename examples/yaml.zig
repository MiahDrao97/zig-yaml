const std = @import("std");
const assert = std.debug.assert;
const build_options = @import("build_options");
const Yaml = @import("yaml").Yaml;
const Io = std.Io;

const mem = std.mem;

const usage =
    \\Usage: yaml <path-to-yaml>
    \\
    \\General options:
    \\--debug-log [scope]           Turn on debugging logs for [scope] (requires program compiled with -Dlog)
    \\-h, --help                    Print this help and exit
    \\
;

var log_scopes: std.ArrayList([]const u8) = .empty;

fn logFn(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    // Hide debug messages unless:
    // * logging enabled with `-Dlog`.
    // * the --debug-log arg for the scope has been provided
    if (@intFromEnum(level) > @intFromEnum(std.options.log_level) or
        @intFromEnum(level) > @intFromEnum(std.log.Level.info))
    {
        if (!build_options.enable_logging) return;

        const scope_name = @tagName(scope);
        for (log_scopes.items) |log_scope| {
            if (mem.eql(u8, log_scope, scope_name)) break;
        } else return;
    }

    // We only recognize 4 log levels in this application.
    const level_txt = switch (level) {
        .err => "error",
        .warn => "warning",
        .info => "info",
        .debug => "debug",
    };
    const prefix1 = level_txt;
    const prefix2 = if (scope == .default) ": " else "(" ++ @tagName(scope) ++ "): ";

    // Print the message to stderr, silently ignoring any errors
    std.debug.print(prefix1 ++ prefix2 ++ format ++ "\n", args);
}

pub const std_options: std.Options = .{ .logFn = logFn };

pub fn main(init: std.process.Init) !void {
    defer log_scopes.deinit(init.gpa);

    var arena = std.heap.ArenaAllocator.init(init.gpa);
    defer arena.deinit();
    const allocator = arena.allocator();

    const all_args = try init.minimal.args.toSlice(allocator);
    const args = all_args[1..];

    const stdout: Io.File = .stdout();
    const stderr: Io.File = .stderr();

    var file_path: ?[]const u8 = null;
    var arg_index: usize = 0;
    while (arg_index < args.len) : (arg_index += 1) {
        if (mem.eql(u8, "-h", args[arg_index]) or mem.eql(u8, "--help", args[arg_index])) {
            return try stdout.writeStreamingAll(init.io, usage);
        } else if (mem.eql(u8, "--debug-log", args[arg_index])) {
            if (arg_index + 1 >= args.len) {
                return try stderr.writeStreamingAll(init.io, "fatal: expected [scope] after --debug-log\n\n");
            }
            arg_index += 1;
            if (!build_options.enable_logging) {
                return try stderr.writeStreamingAll(init.io, "warn: --debug-log will have no effect as program was not built with -Dlog\n\n");
            } else {
                try log_scopes.append(init.gpa, args[arg_index]);
            }
        } else {
            file_path = args[arg_index];
        }
    }

    if (file_path == null) {
        return try stderr.writeStreamingAll(init.io, "fatal: no input path to yaml file specified\n\n");
    }

    const file = try Io.Dir.cwd().openFile(init.io, file_path.?, .{});
    defer file.close(init.io);

    var stream: Io.Writer.Allocating = .init(init.gpa);
    defer stream.deinit();

    var reader_buf: [1024]u8 = undefined;
    var reader: Io.File.Reader = file.reader(init.io, &reader_buf);
    _ = reader.interface.streamRemaining(&stream.writer) catch |err| return switch (err) {
        error.WriteFailed => error.OutOfMemory,
        error.ReadFailed => reader.err.?,
    };

    const source = stream.written();
    const load_yaml = try Yaml.load(init.gpa, source);
    defer load_yaml.deinit();

    const yaml: Yaml = load_yaml.value.yaml catch |err| {
        try load_yaml.value.parser_errors.renderToStderr(init.io, .{}, .auto);
        return err;
    };

    var writer = stdout.writer(init.io, &.{});
    try yaml.stringify(&writer.interface);
}
