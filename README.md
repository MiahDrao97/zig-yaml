# zig-yaml

YAML parser for Zig:

Forked from https://github.com/kubkon/zig-yaml

## What is it?

Words from kubkon:

This lib is meant to serve as a basic (or maybe not?) YAML parser for Zig. It will strive to be YAML 1.2 compatible
but one step at a time.

This is very much a work-in-progress, so expect things to break on a regular basis. Oh, I'd love to get the
community involved in helping out with this btw! Feel free to fork and submit patches, enhancements, and of course
issues.

Words from me (MiahDrao97):

I wanted to stay on top of the newest Zig releases.
I found this particular YAML parser the best because it allowed for loading a schema-less YAML file, which is a requirement for my use-case.
When using the original, I quickly found that it needed to be updated to Zig 0.15, but that wasn't in the main branch yet.
Also fixed a couple bugs I encountered in my personal usage of it, which resulted in deviating from the original API's.

## Basic installation

The library can be installed using the Zig tools. First, you need to fetch the required release of the library into your project. 
```
zig fetch --save https://github.com/MiahDrao97/zig-yaml/archive/main.tar.gz
```

It's more convenient to save the library with a desired name, for example, like this (assuming you are targeting latest release of Zig):
```
zig fetch --save https://github.com/MiahDrao97/zig-yaml/archive/main.tar.gz
```

And then configure your dependency in your project's `build.zig` file:
```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const yaml_module = b.dependency("zig_yaml", .{}).module("yaml");

    const my_module = b.addModule("my_module", .{
        .root_source_file = b.path("src/my_module/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "yaml", .module = yaml_module },
        },
    });

    // rest of build def...
}
```

After that, you can simply import the zig-yaml library in your project's code by using `const yaml = @import("yaml");`.

Note that main branch leverages zig 0.15.2.
For zig-0.14, please use any release after `0.1.0`. For pre-zig-0.14 (e.g., zig-0.13), use `0.0.1`.

## Basic usage

The parser currently understands a few YAML primitives such as:
* explicit documents (`---`, `...`)
* mappings (`:`)
* sequences (`-`, `[`, `]`)

In fact, if you head over to `examples/` dir, you will find YAML examples that have been tested against this
parser. You can also have a look at end-to-end test inputs in `test/` directory.

If you want to use the parser as a library, add it as a package the usual way, and then:

```zig
const std = @import("std");
const Yaml = @import("yaml").Yaml;
const Managed = Yaml.Managed;
const LoadYaml = Yaml.LoadYaml;
const gpa = std.testing.allocator;

const source =
    \\names: [ John Doe, MacIntosh, Jane Austin ]
    \\numbers:
    \\  - 10
    \\  - -8
    \\  - 6
    \\nested:
    \\  some: one
    \\  wick: john doe
    \\finally: [ 8.17,
    \\           19.78      , 17 ,
    \\           21 ]
;

const load_yaml: Managed(LoadYaml) = try Yaml.load(gpa, source);
defer load_yaml.deinit(); // all the memory produced from parsing is owned by this managed value

const yaml: Yaml = load_yaml.value.yaml catch |err| {
    // if we encountered parse errors, we can rendering the errors to a writer (std err in this example)
    load_yaml.value.parser_errors.renderToStdErr(.{ .ttyconf = .detect(.stderr()) });
    return err;
}
```

1. For untyped, raw representation of YAML, use the `rootObject()` method to access the root of the parse tree.

```zig
const map: Yaml.Map = yaml.rootObject().?; // would be null if the YAML is empty or just a list
try std.testing.expect(map.contains("names"));
try std.testing.expectEqual(map.get("names").?.list.len, 3);
```

2. For typed representation of YAML, use the `parse()` method:

```zig
const Simple = struct {
    names: []const []const u8,
    numbers: []const i16,
    nested: struct {
        some: []const u8,
        wick: []const u8,
    },
    finally: [4]f16,
};

const simple: Managed(Simple) = try yaml.parse(Simple, gpa);
defer simple.deinit();

try std.testing.expectEqual(simple.value.names.len, 3);
```

3. To convert `Yaml` structure back into text representation, use `stringify()` method:

```zig
var buf: [64]u8 = undefined;
var stdout: File.Writer = File.stdout().writer(&buf):
try yaml.stringify(&stdout.interface); // or any writer here
```

which should write the following output to standard output when run:

```sh
names: [ John Doe, MacIntosh, Jane Austin  ]
numbers: [ 10, -8, 6  ]
nested:
    some: one
    wick: john doe
finally: [ 8.17, 19.78, 17, 21  ]
```

## Running YAML spec test suite (WARNING: Not tested since creating this fork)

Remember to clone the repo with submodules first

```sh
git clone --recurse-submodules
```

Then, you can run the test suite as follows

```sh
zig build test -Denable-spec-tests
```

See also [issue #48](https://github.com/kubkon/zig-yaml/issues/48) for a meta issue tracking failing spec tests.

Any test that you think of working on and would like to include in the spec tests (that was previously skipped), can be removed from the skipped tests lists in https://github.com/kubkon/zig-yaml/blob/b3cc3a3319ab40fa466a4d5e9c8483267e6ffbee/test/spec.zig#L239-L562
