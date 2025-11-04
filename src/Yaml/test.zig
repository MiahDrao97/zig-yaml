const std = @import("std");
const mem = std.mem;
const stringify = @import("../stringify.zig").stringify;
const testing = std.testing;

const Arena = std.heap.ArenaAllocator;
const Yaml = @import("../Yaml.zig");
const Managed = Yaml.Managed;

test "simple list" {
    const source =
        \\- a
        \\- b
        \\- c
    ;
    var arena: Arena = .init(testing.allocator);
    defer arena.deinit();

    var yaml: Yaml = .{ .source = source };
    try yaml.load(&arena);

    try testing.expectEqual(yaml.docs.items.len, 1);

    const list = yaml.docs.items[0].list;
    try testing.expectEqual(list.len, 3);

    try testing.expectEqualStrings("a", list[0].scalar);
    try testing.expectEqualStrings("b", list[1].scalar);
    try testing.expectEqualStrings("c", list[2].scalar);
}

test "simple list parsed as booleans" {
    const source =
        \\- true
        \\- false
        \\- true
    ;
    var arena: Arena = .init(testing.allocator);
    defer arena.deinit();

    var yaml: Yaml = .{ .source = source };
    try yaml.load(&arena);

    const parsed: Managed([]const bool) = try yaml.parse(testing.allocator, []const bool);
    defer parsed.deinit();

    try testing.expectEqual(parsed.value.len, 3);

    try testing.expect(parsed.value[0]);
    try testing.expect(!parsed.value[1]);
    try testing.expect(parsed.value[2]);
}

test "simple list typed as array of strings" {
    const source =
        \\- a
        \\- b
        \\- c
    ;
    var arena: Arena = .init(testing.allocator);
    defer arena.deinit();

    var yaml: Yaml = .{ .source = source };
    try yaml.load(&arena);

    try testing.expectEqual(yaml.docs.items.len, 1);

    const arr: Managed([3][]const u8) = try yaml.parse(testing.allocator, [3][]const u8);
    defer arr.deinit();

    try testing.expectEqual(3, arr.value.len);
    try testing.expectEqualStrings("a", arr.value[0]);
    try testing.expectEqualStrings("b", arr.value[1]);
    try testing.expectEqualStrings("c", arr.value[2]);
}

test "simple list typed as array of ints" {
    const source =
        \\- 0
        \\- 1
        \\- 2
    ;
    var arena: Arena = .init(testing.allocator);
    defer arena.deinit();

    var yaml: Yaml = .{ .source = source };
    try yaml.load(&arena);

    try testing.expectEqual(yaml.docs.items.len, 1);

    const arr: Managed([3]u8) = try yaml.parse(testing.allocator, [3]u8);
    defer arr.deinit();

    try testing.expectEqualSlices(u8, &[_]u8{ 0, 1, 2 }, &arr.value);
}

test "list of mixed sign integer" {
    const source =
        \\- 0
        \\- -1
        \\- 2
    ;
    var arena: Arena = .init(testing.allocator);
    defer arena.deinit();

    var yaml: Yaml = .{ .source = source };
    try yaml.load(&arena);

    try testing.expectEqual(yaml.docs.items.len, 1);

    const arr: Managed([3]i8) = try yaml.parse(testing.allocator, [3]i8);
    defer arr.deinit();

    try testing.expectEqualSlices(i8, &[_]i8{ 0, -1, 2 }, &arr.value);
}

test "several integer bases" {
    const source =
        \\- 10
        \\- -10
        \\- 0x10
        \\- -0X10
        \\- 0o10
        \\- -0O10
    ;
    var arena: Arena = .init(testing.allocator);
    defer arena.deinit();

    var yaml: Yaml = .{ .source = source };
    try yaml.load(&arena);

    try testing.expectEqual(yaml.docs.items.len, 1);

    const arr: Managed([6]i8) = try yaml.parse(testing.allocator, [6]i8);
    defer arr.deinit();

    try testing.expectEqualSlices(i8, &[_]i8{ 10, -10, 16, -16, 8, -8 }, &arr.value);
}

test "simple flow sequence / bracket list" {
    const source =
        \\a_key: [a, b, c]
    ;
    var arena: Arena = .init(testing.allocator);
    defer arena.deinit();

    var yaml: Yaml = .{ .source = source };
    try yaml.load(&arena);

    try testing.expectEqual(yaml.docs.items.len, 1);

    const map = yaml.docs.items[0].map;

    const list = map.get("a_key").?.list;
    try testing.expectEqual(list.len, 3);

    try testing.expectEqualStrings("a", list[0].scalar);
    try testing.expectEqualStrings("b", list[1].scalar);
    try testing.expectEqualStrings("c", list[2].scalar);
}

test "simple flow sequence / bracket list with trailing comma" {
    const source =
        \\a_key: [a, b, c,]
    ;
    var arena: Arena = .init(testing.allocator);
    defer arena.deinit();

    var yaml: Yaml = .{ .source = source };
    try yaml.load(&arena);

    try testing.expectEqual(yaml.docs.items.len, 1);

    const map = yaml.docs.items[0].map;

    const list = map.get("a_key").?.list;
    try testing.expectEqual(list.len, 3);

    try testing.expectEqualStrings("a", list[0].scalar);
    try testing.expectEqualStrings("b", list[1].scalar);
    try testing.expectEqualStrings("c", list[2].scalar);
}

test "simple flow sequence / bracket list with invalid comment" {
    const source =
        \\a_key: [a, b, c]#invalid
    ;
    var arena: Arena = .init(testing.allocator);
    defer arena.deinit();

    var yaml: Yaml = .{ .source = source };
    const err = yaml.load(&arena);

    try std.testing.expectError(error.ParseFailure, err);
}

test "simple flow sequence / bracket list with double trailing commas" {
    const source =
        \\a_key: [a, b, c,,]
    ;
    var arena: Arena = .init(testing.allocator);
    defer arena.deinit();

    var yaml: Yaml = .{ .source = source };
    const err = yaml.load(&arena);

    try std.testing.expectError(error.ParseFailure, err);
}

test "more bools" {
    const source =
        \\- false
        \\- true
        \\- off
        \\- on
        \\- no
        \\- yes
        \\- n
        \\- y
    ;
    var arena: Arena = .init(testing.allocator);
    defer arena.deinit();

    var yaml: Yaml = .{ .source = source };
    try yaml.load(&arena);

    try testing.expectEqual(yaml.docs.items.len, 1);

    const arr: Managed([8]bool) = try yaml.parse(testing.allocator, [8]bool);
    defer arr.deinit();

    try testing.expectEqualSlices(bool, &[_]bool{
        false,
        true,
        false,
        true,
        false,
        true,
        false,
        true,
    }, &arr.value);
}

test "invalid enum" {
    const TestEnum = enum {
        alpha,
        bravo,
        charlie,
    };

    const source =
        \\- delta
        \\- echo
    ;
    var arena: Arena = .init(testing.allocator);
    defer arena.deinit();

    var yaml: Yaml = .{ .source = source };
    try yaml.load(&arena);

    try testing.expectEqual(yaml.docs.items.len, 1);
    try testing.expectError(Yaml.Error.InvalidEnum, yaml.parse(testing.allocator, [2]TestEnum));
}

test "simple map untyped" {
    const source =
        \\a: 0
    ;
    var arena: Arena = .init(testing.allocator);
    defer arena.deinit();

    var yaml: Yaml = .{ .source = source };
    try yaml.load(&arena);

    try testing.expectEqual(yaml.docs.items.len, 1);

    const map = yaml.docs.items[0].map;
    try testing.expect(map.contains("a"));
    try testing.expectEqualStrings("0", map.get("a").?.scalar);
}

test "simple map untyped with a list of maps" {
    const source =
        \\a: 0
        \\b:
        \\  - foo: 1
        \\    bar: 2
        \\  - foo: 3
        \\    bar: 4
        \\c: 1
    ;
    var arena: Arena = .init(testing.allocator);
    defer arena.deinit();

    var yaml: Yaml = .{ .source = source };
    try yaml.load(&arena);

    try testing.expectEqual(yaml.docs.items.len, 1);

    const map = yaml.docs.items[0].map;
    try testing.expect(map.contains("a"));
    try testing.expect(map.contains("b"));
    try testing.expect(map.contains("c"));
    try testing.expectEqualStrings("0", map.get("a").?.scalar);
    try testing.expectEqualStrings("1", map.get("c").?.scalar);
    try testing.expectEqualStrings("1", map.get("b").?.list[0].map.get("foo").?.scalar);
    try testing.expectEqualStrings("2", map.get("b").?.list[0].map.get("bar").?.scalar);
    try testing.expectEqualStrings("3", map.get("b").?.list[1].map.get("foo").?.scalar);
    try testing.expectEqualStrings("4", map.get("b").?.list[1].map.get("bar").?.scalar);
}

test "simple map untyped with a list of maps. no indent" {
    const source =
        \\b:
        \\- foo: 1
        \\c: 1
    ;
    var arena: Arena = .init(testing.allocator);
    defer arena.deinit();

    var yaml: Yaml = .{ .source = source };
    try yaml.load(&arena);

    try testing.expectEqual(yaml.docs.items.len, 1);

    const map = yaml.docs.items[0].map;
    try testing.expect(map.contains("b"));
    try testing.expect(map.contains("c"));
    try testing.expectEqualStrings("1", map.get("c").?.scalar);
    try testing.expectEqualStrings("1", map.get("b").?.list[0].map.get("foo").?.scalar);
}

test "simple map untyped with a list of maps. no indent 2" {
    const source =
        \\a: 0
        \\b:
        \\- foo: 1
        \\  bar: 2
        \\- foo: 3
        \\  bar: 4
        \\c: 1
    ;
    var arena: Arena = .init(testing.allocator);
    defer arena.deinit();

    var yaml: Yaml = .{ .source = source };
    try yaml.load(&arena);

    try testing.expectEqual(yaml.docs.items.len, 1);

    const map = yaml.docs.items[0].map;
    try testing.expect(map.contains("a"));
    try testing.expect(map.contains("b"));
    try testing.expect(map.contains("c"));
    try testing.expectEqualStrings("0", map.get("a").?.scalar);
    try testing.expectEqualStrings("1", map.get("c").?.scalar);
    try testing.expectEqualStrings("1", map.get("b").?.list[0].map.get("foo").?.scalar);
    try testing.expectEqualStrings("2", map.get("b").?.list[0].map.get("bar").?.scalar);
    try testing.expectEqualStrings("3", map.get("b").?.list[1].map.get("foo").?.scalar);
    try testing.expectEqualStrings("4", map.get("b").?.list[1].map.get("bar").?.scalar);
}

test "simple map typed" {
    const S = struct { a: usize, b: []const u8, c: []const u8 };
    const source =
        \\a: 0
        \\b: hello there
        \\c: 'wait, what?'
    ;
    var arena: Arena = .init(testing.allocator);
    defer arena.deinit();

    var yaml: Yaml = .{ .source = source };
    try yaml.load(&arena);

    const simple: Managed(S) = try yaml.parse(testing.allocator, S);
    defer simple.deinit();

    try testing.expectEqual(@as(usize, 0), simple.value.a);
    try testing.expectEqualStrings("hello there", simple.value.b);
    try testing.expectEqualStrings("wait, what?", simple.value.c);
}

test "typed nested structs" {
    const source =
        \\a:
        \\  b: hello there
        \\  c: 'wait, what?'
    ;
    var arena: Arena = .init(testing.allocator);
    defer arena.deinit();

    var yaml: Yaml = .{ .source = source };
    try yaml.load(&arena);

    const simple = try yaml.parse(testing.allocator, struct {
        a: struct {
            b: []const u8,
            c: []const u8,
        },
    });
    defer simple.deinit();

    try testing.expectEqualStrings("hello there", simple.value.a.b);
    try testing.expectEqualStrings("wait, what?", simple.value.a.c);
}

test "typed union with nested struct" {
    const source =
        \\a:
        \\  b: hello there
    ;
    var arena: Arena = .init(testing.allocator);
    defer arena.deinit();

    var yaml: Yaml = .{ .source = source };
    try yaml.load(&arena);

    const simple = try yaml.parse(testing.allocator, union(enum) {
        tag_a: struct {
            a: struct {
                b: []const u8,
            },
        },
        tag_c: struct {
            c: struct {
                d: []const u8,
            },
        },
    });
    defer simple.deinit();

    try testing.expectEqualStrings("hello there", simple.value.tag_a.a.b);
}

test "typed union with nested struct 2" {
    const source =
        \\c:
        \\  d: hello there
    ;
    var arena: Arena = .init(testing.allocator);
    defer arena.deinit();

    var yaml: Yaml = .{ .source = source };
    try yaml.load(&arena);

    const simple = try yaml.parse(testing.allocator, union(enum) {
        tag_a: struct {
            a: struct {
                b: []const u8,
            },
        },
        tag_c: struct {
            c: struct {
                d: []const u8,
            },
        },
    });
    defer simple.deinit();
    try testing.expectEqualStrings("hello there", simple.value.tag_c.c.d);
}

test "single quoted string" {
    const source =
        \\- 'hello'
        \\- 'here''s an escaped quote'
        \\- 'newlines and tabs\nare not\tsupported'
    ;
    var arena: Arena = .init(testing.allocator);
    defer arena.deinit();

    var yaml: Yaml = .{ .source = source };
    try yaml.load(&arena);

    const arr = try yaml.parse(testing.allocator, [3][]const u8);
    defer arr.deinit();

    try testing.expectEqual(arr.value.len, 3);
    try testing.expectEqualStrings("hello", arr.value[0]);
    try testing.expectEqualStrings("here's an escaped quote", arr.value[1]);
    try testing.expectEqualStrings("newlines and tabs\\nare not\\tsupported", arr.value[2]);
}

test "double quoted string" {
    const source =
        \\- "hello"
        \\- "\"here\" are some escaped quotes"
        \\- "newlines and tabs\nare\tsupported"
        \\- "let's have
        \\some fun!"
    ;
    var arena: Arena = .init(testing.allocator);
    defer arena.deinit();

    var yaml: Yaml = .{ .source = source };
    try yaml.load(&arena);

    const arr = try yaml.parse(testing.allocator, [4][]const u8);
    defer arr.deinit();

    try testing.expectEqual(arr.value.len, 4);
    try testing.expectEqualStrings("hello", arr.value[0]);
    try testing.expectEqualStrings(
        \\"here" are some escaped quotes
    , arr.value[1]);
    try testing.expectEqualStrings("newlines and tabs\nare\tsupported", arr.value[2]);
    try testing.expectEqualStrings(
        \\let's have
        \\some fun!
    , arr.value[3]);
}

test "commas in string" {
    const source =
        \\a: 900,50,50
    ;
    var arena: Arena = .init(testing.allocator);
    defer arena.deinit();

    var yaml: Yaml = .{ .source = source };
    try yaml.load(&arena);

    const simple = try yaml.parse(testing.allocator, struct {
        a: []const u8,
    });
    defer simple.deinit();
    try testing.expectEqualStrings("900,50,50", simple.value.a);
}

test "multidoc typed as a slice of structs" {
    const source =
        \\---
        \\a: 0
        \\---
        \\a: 1
        \\...
    ;
    var arena: Arena = .init(testing.allocator);
    defer arena.deinit();

    var yaml: Yaml = .{ .source = source };
    try yaml.load(&arena);

    {
        const result = try yaml.parse(testing.allocator, [2]struct { a: usize });
        defer result.deinit();

        try testing.expectEqual(result.value.len, 2);
        try testing.expectEqual(result.value[0].a, 0);
        try testing.expectEqual(result.value[1].a, 1);
    }

    {
        const result = try yaml.parse(testing.allocator, []struct { a: usize });
        defer result.deinit();

        try testing.expectEqual(result.value.len, 2);
        try testing.expectEqual(result.value[0].a, 0);
        try testing.expectEqual(result.value[1].a, 1);
    }
}

test "multidoc typed as a struct is an error" {
    const source =
        \\---
        \\a: 0
        \\---
        \\b: 1
        \\...
    ;
    var arena: Arena = .init(testing.allocator);
    defer arena.deinit();

    var yaml: Yaml = .{ .source = source };
    try yaml.load(&arena);

    try testing.expectError(Yaml.Error.TypeMismatch, yaml.parse(testing.allocator, struct { a: usize }));
    try testing.expectError(Yaml.Error.TypeMismatch, yaml.parse(testing.allocator, struct { b: usize }));
    try testing.expectError(Yaml.Error.TypeMismatch, yaml.parse(testing.allocator, struct { a: usize, b: usize }));
}

test "multidoc typed as a slice of structs with optionals" {
    const source =
        \\---
        \\a: 0
        \\c: 1.0
        \\---
        \\a: 1
        \\b: different field
        \\...
    ;
    var arena: Arena = .init(testing.allocator);
    defer arena.deinit();

    var yaml: Yaml = .{ .source = source };
    try yaml.load(&arena);

    const result = try yaml.parse(testing.allocator, []struct { a: usize, b: ?[]const u8, c: ?f16 });
    defer result.deinit();
    try testing.expectEqual(result.value.len, 2);

    try testing.expectEqual(result.value[0].a, 0);
    try testing.expect(result.value[0].b == null);
    try testing.expect(result.value[0].c != null);
    try testing.expectEqual(result.value[0].c.?, 1.0);

    try testing.expectEqual(result.value[1].a, 1);
    try testing.expect(result.value[1].b != null);
    try testing.expectEqualStrings("different field", result.value[1].b.?);
    try testing.expect(result.value[1].c == null);
}

test "empty yaml can be represented as void" {
    const source = "";
    var arena: Arena = .init(testing.allocator);
    defer arena.deinit();

    var yaml: Yaml = .{ .source = source };
    try yaml.load(&arena);

    const result = try yaml.parse(testing.allocator, void);
    defer result.deinit();
    try testing.expect(@TypeOf(result.value) == void);
}

test "nonempty yaml cannot be represented as void" {
    const source =
        \\a: b
    ;
    var arena: Arena = .init(testing.allocator);
    defer arena.deinit();

    var yaml: Yaml = .{ .source = source };
    try yaml.load(&arena);

    try testing.expectError(Yaml.Error.TypeMismatch, yaml.parse(testing.allocator, void));
}

test "typed array size mismatch" {
    const source =
        \\- 0
        \\- 0
    ;
    var arena: Arena = .init(testing.allocator);
    defer arena.deinit();

    var yaml: Yaml = .{ .source = source };
    try yaml.load(&arena);

    try testing.expectError(Yaml.Error.ArraySizeMismatch, yaml.parse(testing.allocator, [1]usize));
    try testing.expectError(Yaml.Error.ArraySizeMismatch, yaml.parse(testing.allocator, [5]usize));
}

test "comments" {
    const source =
        \\
        \\key: # this is the key
        \\# first value
        \\
        \\- val1
        \\
        \\# second value
        \\- val2
    ;
    var arena: Arena = .init(testing.allocator);
    defer arena.deinit();

    var yaml: Yaml = .{ .source = source };
    try yaml.load(&arena);

    const simple = try yaml.parse(testing.allocator, struct {
        key: []const []const u8,
    });
    defer simple.deinit();

    try testing.expect(simple.value.key.len == 2);
    try testing.expectEqualStrings("val1", simple.value.key[0]);
    try testing.expectEqualStrings("val2", simple.value.key[1]);
}

test "promote ints to floats in a list mixed numeric types" {
    const source =
        \\a_list: [0, 1.0]
    ;
    var arena: Arena = .init(testing.allocator);
    defer arena.deinit();

    var yaml: Yaml = .{ .source = source };
    try yaml.load(&arena);

    const simple = try yaml.parse(testing.allocator, struct {
        a_list: []const f64,
    });
    defer simple.deinit();
    try testing.expectEqualSlices(f64, &[_]f64{ 0.0, 1.0 }, simple.value.a_list);
}

test "demoting floats to ints in a list is an error" {
    const source =
        \\a_list: [0, 1.0]
    ;
    var arena: Arena = .init(testing.allocator);
    defer arena.deinit();

    var yaml: Yaml = .{ .source = source };
    try yaml.load(&arena);

    try testing.expectError(error.InvalidCharacter, yaml.parse(testing.allocator, struct {
        a_list: []const u64,
    }));
}

test "duplicate map keys" {
    const source =
        \\a: b
        \\a: c
    ;
    var arena: Arena = .init(testing.allocator);
    defer arena.deinit();

    var yaml: Yaml = .{ .source = source };
    try testing.expectError(error.DuplicateMapKey, yaml.load(&arena));
}

fn testStringify(expected: []const u8, input: anytype) !void {
    var writer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer writer.deinit();

    try stringify(testing.allocator, input, &writer.writer);
    try testing.expectEqualStrings(expected, writer.written());
}

test "stringify an int" {
    try testStringify("128", @as(u32, 128));
}

test "stringify a simple struct" {
    try testStringify(
        \\a: 1
        \\b: 2
        \\c: 2.5
    , struct { a: i64, b: f64, c: f64 }{ .a = 1, .b = 2.0, .c = 2.5 });
}

test "stringify a struct with an optional" {
    try testStringify(
        \\a: 1
        \\b: 2
        \\c: 2.5
    , struct { a: i64, b: ?f64, c: f64 }{ .a = 1, .b = 2.0, .c = 2.5 });

    try testStringify(
        \\a: 1
        \\c: 2.5
    , struct { a: i64, b: ?f64, c: f64 }{ .a = 1, .b = null, .c = 2.5 });
}

test "stringify a struct with all optionals" {
    try testStringify("", struct { a: ?i64, b: ?f64 }{ .a = null, .b = null });
}

test "stringify an optional" {
    try testStringify("", null);
    try testStringify("", @as(?u64, null));
}

test "stringify a union" {
    const Dummy = union(enum) {
        x: u64,
        y: f64,
    };
    try testStringify("a: 1", struct { a: Dummy }{ .a = .{ .x = 1 } });
    try testStringify("a: 2.1", struct { a: Dummy }{ .a = .{ .y = 2.1 } });
}

test "stringify a string" {
    try testStringify("a: name", struct { a: []const u8 }{ .a = "name" });
    try testStringify("name", "name");
}

test "stringify a list" {
    try testStringify("[ 1, 2, 3 ]", @as([]const u64, &.{ 1, 2, 3 }));
    try testStringify("[ 1, 2, 3 ]", .{ @as(i64, 1), 2, 3 });
    try testStringify("[ 1, name, 3 ]", .{ 1, "name", 3 });

    const arr: [3]i64 = .{ 1, 2, 3 };
    try testStringify("[ 1, 2, 3 ]", arr);
}

test "pointer of a value" {
    const TestStruct = struct {
        a: usize,
        b: i64,
        c: u12,
        d: ?*const @This() = null,
    };

    const source =
        \\a: 1
        \\b: 2
        \\c: 3
        \\d:
        \\  a: 4
        \\  b: 5
        \\  c: 6
    ;

    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var yaml = Yaml{ .source = source };
    try yaml.load(&arena);

    const parsed = try yaml.parse(testing.allocator, *TestStruct);
    defer parsed.deinit();

    try testing.expectEqual(1, parsed.value.a);
    try testing.expectEqual(2, parsed.value.b);
    try testing.expectEqual(3, parsed.value.c);
    try testing.expectEqual(4, parsed.value.d.?.a);
    try testing.expectEqual(5, parsed.value.d.?.b);
    try testing.expectEqual(6, parsed.value.d.?.c);
    try testing.expectEqual(@as(?*const TestStruct, null), parsed.value.d.?.d);
}

test "struct default value test" {
    const TestStruct = struct {
        a: i32,
        b: ?[]const u8 = "test",
        c: ?u8 = 5,
        d: u8 = 12,
    };

    const TestCase = struct {
        yaml: []const u8,
        container: TestStruct,
    };

    const tcs = [_]TestCase{
        .{
            .yaml =
            \\---
            \\a: 1
            \\b: "asd"
            \\c: 3
            \\d: 1
            \\...
            ,
            .container = .{
                .a = 1,
                .b = "asd",
                .c = 3,
                .d = 1,
            },
        },
        .{
            .yaml =
            \\---
            \\a: 1
            \\c: 3
            \\d: 1
            \\...
            ,
            .container = .{
                .a = 1,
                .b = "test",
                .c = 3,
                .d = 1,
            },
        },
        .{
            .yaml =
            \\---
            \\a: 1
            \\b: "asd"
            \\d: 1
            \\...
            ,
            .container = .{
                .a = 1,
                .b = "asd",
                .c = 5,
                .d = 1,
            },
        },
        .{
            .yaml =
            \\---
            \\a: 1
            \\b: "asd"
            \\...
            ,
            .container = .{
                .a = 1,
                .b = "asd",
                .c = 5,
                .d = 12,
            },
        },
    };

    for (&tcs) |tc| {
        var arena = std.heap.ArenaAllocator.init(testing.allocator);
        defer arena.deinit();
        var yamlParser = Yaml{ .source = tc.yaml };
        try yamlParser.load(&arena);

        const parsed = try yamlParser.parse(arena.allocator(), TestStruct);
        defer parsed.deinit();

        try testing.expectEqual(tc.container.a, parsed.value.a);
        try testing.expectEqualDeep(tc.container.b, parsed.value.b);
        try testing.expectEqual(tc.container.c, parsed.value.c);
        try testing.expectEqual(tc.container.d, parsed.value.d);
    }
}

test "enums" {
    const source =
        \\- a
        \\- b
        \\- c
    ;
    var arena: Arena = .init(testing.allocator);
    defer arena.deinit();

    const Enum = enum { a, b, c };

    var yaml: Yaml = .{ .source = source };
    try yaml.load(&arena);

    const parsed = try yaml.parse(testing.allocator, []const Enum);
    defer parsed.deinit();

    try testing.expectEqualDeep(&[_]Enum{
        .a,
        .b,
        .c,
    }, parsed.value);
}

test "stringify a bool" {
    try testStringify("false", false);
    try testStringify("true", true);
}

test "stringify an enum" {
    const TestEnum = enum {
        alpha,
        bravo,
        charlie,
    };

    try testStringify("alpha", TestEnum.alpha);
    try testStringify("bravo", TestEnum.bravo);
    try testStringify("charlie", TestEnum.charlie);
}

test "parse struct as list of structs" {
    const source =
        \\a: 1
    ;
    var arena: Arena = .init(testing.allocator);
    defer arena.deinit();

    const Struct = struct { a: u32 };

    var yaml: Yaml = .{ .source = source };
    try yaml.load(&arena);

    const result = yaml.parse(testing.allocator, []Struct);
    try testing.expectError(error.TypeMismatch, result);

    const parsed = try yaml.parse(testing.allocator, Struct);
    defer parsed.deinit();

    try testing.expectEqualDeep(Struct{ .a = 1 }, parsed.value);
}

test "duplicate key error" {
    // we get a double-free if the duplicate keys are nested deep enough
    const source =
        \\components:
        \\  schemas:
        \\    Obj:
        \\      type: object
        \\      description: asdf
        \\      properties:
        \\        MyProp:
        \\          type: string
        \\          description: blarf
        \\        MyProp:
        \\          type: string
        \\          description: oh my
    ;

    var arena: Arena = .init(testing.allocator);
    defer arena.deinit();

    var yaml: Yaml = .{ .source = source };
    try testing.expectError(error.DuplicateMapKey, yaml.load(&arena));
}
