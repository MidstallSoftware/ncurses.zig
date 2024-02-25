const std = @import("std");

const AwkStep = struct {
    step: std.Build.Step,
    script: std.Build.LazyPath,
    name: []const u8,
    inputs: std.ArrayListUnmanaged(std.Build.LazyPath),
    output_file: std.Build.GeneratedFile,

    pub const Options = struct {
        script: std.Build.LazyPath,
        name: []const u8,
        inputs: ?[]const std.Build.LazyPath,
    };

    pub fn create(b: *std.Build, options: Options) *AwkStep {
        const arena = b.allocator;
        const self = arena.create(AwkStep) catch @panic("OOM");

        self.* = .{
            .step = std.Build.Step.init(.{
                .id = .custom,
                .name = b.fmt("Generate {s}", .{options.name}),
                .owner = b,
                .makeFn = make,
            }),
            .script = options.script,
            .name = arena.dupe(u8, options.name) catch @panic("OOM"),
            .inputs = .{},
            .output_file = .{ .step = &self.step },
        };

        self.script.addStepDependencies(&self.step);

        if (options.inputs) |inputs| {
            self.inputs.ensureTotalCapacity(arena, inputs.len) catch @panic("OOM");

            for (inputs) |input| {
                self.inputs.appendAssumeCapacity(input);
                input.addStepDependencies(&self.step);
            }
        }
        return self;
    }

    fn make(step: *std.Build.Step, _: *std.Progress.Node) anyerror!void {
        const b = step.owner;
        const arena = b.allocator;
        const self = @fieldParentPtr(AwkStep, "step", step);

        var man = b.graph.cache.obtain();
        defer man.deinit();

        man.hash.addBytes(self.name);
        _ = try man.addFile(self.script.getPath2(b, step), null);

        for (self.inputs.items) |input| {
            _ = try man.addFile(input.getPath2(b, step), null);
        }

        if (try step.cacheHit(&man)) {
            const digest = man.final();
            self.output_file.path = try b.cache_root.join(arena, &.{ "o", &digest, self.name });
            return;
        }

        const digest = man.final();
        const cache_path = "o" ++ std.fs.path.sep_str ++ digest;
        self.output_file.path = try b.cache_root.join(arena, &.{ "o", &digest, self.name });

        var cache_dir = b.cache_root.handle.makeOpenPath(cache_path, .{}) catch |err| {
            return step.fail("unable to make path '{}{s}': {s}", .{
                b.cache_root, cache_path, @errorName(err),
            });
        };
        defer cache_dir.close();

        var args = std.ArrayList([]const u8).initCapacity(arena, 3 + self.inputs.items.len) catch @panic("OOM");
        defer args.deinit();

        args.appendSliceAssumeCapacity(&.{
            b.findProgram(&.{ "awk", "gawk" }, &.{}) catch return step.fail("Failed to find awk or gawk", .{}),
            "-f",
            self.script.getPath2(b, step),
        });

        for (self.inputs.items) |input| args.appendAssumeCapacity(input.getPath2(b, step));

        try step.handleChildProcUnsupported(null, args.items);
        try std.Build.Step.handleVerbose(b, null, args.items);

        const result = std.ChildProcess.run(.{
            .allocator = arena,
            .argv = args.items,
        }) catch |err| return step.fail("unable to spawn {s}: {s}", .{ args.items[0], @errorName(err) });

        if (result.stderr.len > 0) {
            try step.result_error_msgs.append(arena, result.stderr);
        }

        try step.handleChildProcessTerm(result.term, null, args.items);

        var file = try cache_dir.createFile(self.name, .{});
        defer file.close();

        try file.writeAll(result.stdout);
        try step.writeManifest(&man);
    }

    pub fn getDirectory(self: *AwkStep) std.Build.LazyPath {
        return .{ .generated_dirname = .{
            .generated = &self.output_file,
            .up = 0,
        } };
    }
};

const GenerateHeader = struct {
    step: std.Build.Step,
    head: std.Build.LazyPath,
    tail: std.Build.LazyPath,
    keys: std.Build.LazyPath,
    wide: std.Build.LazyPath,
    output_file: std.Build.GeneratedFile,

    pub const Options = struct {
        head: std.Build.LazyPath,
        tail: std.Build.LazyPath,
        keys: std.Build.LazyPath,
        wide: std.Build.LazyPath,
    };

    pub fn create(b: *std.Build, options: Options) *GenerateHeader {
        const arena = b.allocator;
        const self = arena.create(GenerateHeader) catch @panic("OOM");

        self.* = .{
            .step = std.Build.Step.init(.{
                .id = .custom,
                .name = "Generate ncurses.h",
                .owner = b,
                .makeFn = make,
            }),
            .head = options.head,
            .tail = options.tail,
            .keys = options.keys,
            .wide = options.wide,
            .output_file = .{ .step = &self.step },
        };

        self.head.addStepDependencies(&self.step);
        self.tail.addStepDependencies(&self.step);
        self.keys.addStepDependencies(&self.step);
        self.wide.addStepDependencies(&self.step);
        return self;
    }

    fn make(step: *std.Build.Step, _: *std.Progress.Node) anyerror!void {
        const b = step.owner;
        const arena = b.allocator;
        const self = @fieldParentPtr(GenerateHeader, "step", step);

        var man = b.graph.cache.obtain();
        defer man.deinit();

        _ = try man.addFile(self.head.getPath2(b, step), null);
        _ = try man.addFile(self.wide.getPath2(b, step), null);
        _ = try man.addFile(self.keys.getPath2(b, step), null);
        _ = try man.addFile(self.tail.getPath2(b, step), null);

        if (try step.cacheHit(&man)) {
            const digest = man.final();
            self.output_file.path = try b.cache_root.join(arena, &.{ "o", &digest, "curses.h" });
            return;
        }

        const digest = man.final();
        const cache_path = "o" ++ std.fs.path.sep_str ++ digest;
        self.output_file.path = try b.cache_root.join(arena, &.{ "o", &digest, "curses.h" });

        var cache_dir = b.cache_root.handle.makeOpenPath(cache_path, .{}) catch |err| {
            return step.fail("unable to make path '{}{s}': {s}", .{
                b.cache_root, cache_path, @errorName(err),
            });
        };
        defer cache_dir.close();

        var file = try cache_dir.createFile("curses.h", .{});
        defer file.close();

        var head = try std.fs.openFileAbsolute(self.head.getPath2(b, step), .{});
        defer head.close();

        while (true) {
            const byte = head.reader().readByte() catch |err| switch (err) {
                error.EndOfStream => break,
                else => |e| return e,
            };

            try file.writer().writeByte(byte);
        }

        var keys = try std.fs.openFileAbsolute(self.keys.getPath2(b, step), .{});
        defer keys.close();

        while (true) {
            const byte = keys.reader().readByte() catch |err| switch (err) {
                error.EndOfStream => break,
                else => |e| return e,
            };

            try file.writer().writeByte(byte);
        }

        var wide = try std.fs.openFileAbsolute(self.wide.getPath2(b, step), .{});
        defer wide.close();

        while (true) {
            const byte = wide.reader().readByte() catch |err| switch (err) {
                error.EndOfStream => break,
                else => |e| return e,
            };

            try file.writer().writeByte(byte);
        }

        var tail = try std.fs.openFileAbsolute(self.tail.getPath2(b, step), .{});
        defer tail.close();

        while (true) {
            const byte = tail.reader().readByte() catch |err| switch (err) {
                error.EndOfStream => break,
                else => |e| return e,
            };

            try file.writer().writeByte(byte);
        }

        try step.writeManifest(&man);
    }

    pub fn getDirectory(self: *GenerateHeader) std.Build.LazyPath {
        return .{ .generated_dirname = .{
            .generated = &self.output_file,
            .up = 0,
        } };
    }
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const linkage = b.option(std.Build.Step.Compile.Linkage, "linkage", "Sets the link mode") orelse .static;

    const source = b.dependency("ncurses", .{});

    const termcapHeader = b.addConfigHeader(.{
        .style = .{
            .cmake = source.path("include/termcap.h.in"),
        },
        .include_path = "termcap.h",
    }, .{
        .NCURSES_MAJOR = 6,
        .NCURSES_MINOR = 4,
        .NCURSES_OSPEED = "short",
    });

    const mkTermAwk = b.addConfigHeader(.{
        .style = .{
            .cmake = source.path("include/MKterm.h.awk.in"),
        },
        .include_path = "MKterm.h.awk",
    }, .{
        .NCURSES_MAJOR = 6,
        .NCURSES_MINOR = 4,
        .NCURSES_PATCH = 20221231,
        .NCURSES_SP_FUNCS = 1,
        .NCURSES_CONST = "const",
        .NCURSES_SBOOL = "signed char",
        .NCURSES_USE_DATABASE = 1,
        .NCURSES_USE_TERMCAP = 1,
        .NCURSES_XNAMES = 1,
        .HAVE_TERMIOS_H = 1,
        .HAVE_TCGETATTR = 1,
        .HAVE_TERMIO_H = 1,
        .EXP_WIN32_DRIVER = 0,
        .BROKEN_LINKER = 0,
        .cf_cv_enable_reentrant = 0,
        .NCURSES_TPARM_VARARGS = "intptr_t",
        .NCURSES_EXT_COLORS = 1,
    });

    const termHeader = AwkStep.create(b, .{
        .name = "term.h",
        .script = mkTermAwk.getOutput(),
        .inputs = &.{
            source.path("include/Caps-ncurses"),
            source.path("include/Caps"),
        },
    });

    const unctrlHeader = b.addConfigHeader(.{
        .style = .{
            .cmake = source.path("include/unctrl.h.in"),
        },
        .include_path = "unctrl.h",
    }, .{
        .NCURSES_MAJOR = 6,
        .NCURSES_MINOR = 4,
        .NCURSES_SP_FUNCS = 1,
    });

    const cursesHeaderHead = b.addConfigHeader(.{
        .style = .{
            .cmake = source.path("include/curses.h.in"),
        },
        .include_path = "curse.h",
    }, .{
        .NCURSES_MAJOR = 6,
        .NCURSES_MINOR = 4,
        .NCURSES_PATCH = 20221231,
        .NCURSES_MOUSE_VERSION = 2,
        .HAVE_STDINT_H = 1,
        .HAVE_STDNORETURN_H = 0,
        .cf_cv_header_stdbool_h = 1,
        .NCURSES_CONST = "const",
        .NCURSES_INLINE = "inline",
        .NCURSES_OPAQUE = 0,
        .NCURSES_OPAQUE_FORM = 0,
        .NCURSES_OPAQUE_MENU = 0,
        .NCURSES_OPAQUE_PANEL = 0,
        .NCURSES_WATTR_MACROS = 0,
        .cf_cv_enable_reentrant = 0,
        .BROKEN_LINKER = 0,
        .NCURSES_INTEROP_FUNCS = 1,
        .NCURSES_SIZE_T = "size_t",
        .NCURSES_TPARM_VARARGS = 1,
        .NCURSES_TPARM_ARG = "intptr_t",
        .NCURSES_WCWIDTH_GRAPHICS = 1,
        .NCURSES_CH_T = "cchar_t",
        .cf_cv_enable_lp64 = 1,
        .cf_cv_type_of_bool = "unsigned char",
        .cf_cv_typeof_chtype = "uint32_t",
        .cf_cv_typeof_mmask_t = "uint32_t",
        .cf_cv_1UL = "1UL",
        .USE_CXX_BOOL = "defined(__cplusplus)",
        .NCURSES_LIBUTF8 = 0,
        .NEED_WCHAR_H = 1,
        .NCURSES_WCHAR_T = 0,
        .NCURSES_WINT_T = 0,
        .NCURSES_CCHARW_MAX = 5,
        .NCURSES_EXT_COLORS = 1,
        .NCURSES_SP_FUNCS = 1,
        .HAVE_VSSCANF = 1,
        .NCURSES_EXT_FUNCS = 1,
    });

    const cursesHeader = GenerateHeader.create(b, .{
        .head = cursesHeaderHead.getOutput(),
        .tail = source.path("include/curses.tail"),
        .keys = .{ .path = b.pathFromRoot("src/keys.h") },
        .wide = source.path("include/curses.wide"),
    });

    const headers = b.addWriteFiles();
    const ncursesDll = headers.addCopyFile(source.path("include/ncurses_dll.h.in"), "ncurses_dll.h");
    _ = headers.add("ncurses_cfg.h", b.fmt(
        \\#pragma once
        \\
        \\#define PACKAGE "ncurses"
        \\#define NCURSES_VERSION "6.4"
        \\#define NCURSES_VERSION_STRING "6.4.20221231"
        \\#define NCURSES_PATCHDATE 20221231
        \\#define SYSTEM_NAME "linux-expidus"
        \\#define HAVE_LONG_FILE_NAMES 1
        \\#define MIXEDCASE_FILENAMES 1
        \\#define TERMINFO_DIRS "{s}"
        \\#define TERMINFO "{s}"
        \\#define PURE_TERMINFO 1
        \\#define USE_HOME_TERMINFO 1
        \\#define HAVE_UNISTD_H 1
        \\#define HAVE_REMOVE 1
        \\#define HAVE_UNLINK 1
        \\#define HAVE_LINK 1
        \\#define HAVE_SYMLINK 1
        \\#define USE_LINKS 1
        \\#define HAVE_LANGINFO_CODESET 1
        \\#define USE_WIDEC_SUPPORT 1
        \\#define NCURSES_WIDECHAR 1
        \\#define HAVE_WCHAR_H 1
        \\#define HAVE_WCTYPE_H 1
        \\#define HAVE_PUTWC 1
        \\#define HAVE_BTWOC 1
        \\#define HAVE_WCTOB 1
        \\#define HAVE_WMEMCHR 1
        \\#define HAVE_MBTOWC 1
        \\#define HAVE_WCTOMB 1
        \\#define HAVE_MBLEN 1
        \\#define HAVE_MBRLEN 1
        \\#define HAVE_MBRTOWC 1
        \\#define HAVE_WCSRTOMBS 1
        \\#define HAVE_MBSRTOWCS 1
        \\#define HAVE_WCSTOMBS 1
        \\#define HAVE_MBSTOWCS 1
        \\#define NEED_WCHAR_H 1
        \\#define HAVE_FSEEKO 1
        \\#define RGB_PATH "{s}"
        \\#define STDC_HEADERS 1
        \\#define HAVE_SYS_TYPES_H 1
        \\#define HAVE_SYS_STAT_H 1
        \\#define HAVE_STDLIB_H 1
        \\#define HAVE_STRING_H 1
        \\#define HAVE_MEMORY_H 1
        \\#define HAVE_STRINGS_H 1
        \\#define HAVE_INTTYPES_H 1
        \\#define HAVE_STDINT_H 1
        \\#define HAVE_UNISTD_H 1
        \\#define SIZEOF_SIGNED_CHAR 1
        \\#define NCURSES_EXT_FUNCS 1
        \\#define HAVE_ASSUME_DEFAULT_COLORS 1
        \\#define HAVE_CURSES_VERSION 1
        \\#define HAVE_HAS_KEY 1
        \\#define HAVE_RESIZETERM 1
        \\#define HAVE_RESIZE_TERM 1
        \\#define HAVE_TERM_ENTRY_H 1
        \\#define HAVE_USE_DEFAULT_COLORS 1
        \\#define HAVE_USE_EXTENDED_NAMES 1
        \\#define HAVE_USE_SCREEN 1
        \\#define HAVE_USE_WINDOW 1
        \\#define HAVE_WRESIZE 1
        \\#define NCURSES_SP_FUNCS 1
        \\#define HAVE_TPUTS_SP 1
        \\#define NCURSES_EXT_COLORS 1
        \\#define HAVE_ALLOC_PAIR 1
        \\#define HAVE_INIT_EXTENDED_COLOR 1
        \\#define HAVE_RESET_COLOR_PAIRS 1
        \\#define NCURSES_EXT_PUTWIN 1
        \\#define NCURSES_NO_PADDING 1
        \\#define USE_SIGWINCH 1
        \\#define NCURSES_WRAP_PREFIX "_nc_"
        \\#define USE_ASSUMED_COLOR 1
        \\#define USE_HASHMAP 1
        \\#define GCC_SCANF 1
        \\#define GCC_SCANFLIKE(fmt,var) __attribute__((format(scanf,fmt,var)))
        \\#define GCC_PRINTF 1
        \\#define GCC_PRINTFLIKE(fmt,var) __attribute__((format(printf,fmt,var)))
        \\#define GCC_UNUSED __attribute__((unused))
        \\#define GCC_NORETURN __attribute__((noreturn))
        \\#define HAVE_NC_ALLOC_H 1
        \\#define HAVE_GETTIMEOFDAY 1
        \\#define HAVE_MATH_FUNCS 1
        \\#define STDC_HEADERS 1
        \\#define HAVE_DIRENT_H 1
        \\#define TIME_WITH_SYS_TIME 1
        \\#define HAVE_REGEX_H_FUNCS 1
        \\#define HAVE_FCNTL_H 1
        \\#define HAVE_GETOPT_H 1
        \\#define HAVE_LIMITS_H 1
        \\#define HAVE_LOCALE_H 1
        \\#define HAVE_MATH_H 1
        \\#define HAVE_POLL_H 1
        \\#define HAVE_SYS_IOCTL_H 1
        \\#define HAVE_SYS_PARAM_H 1
        \\#define HAVE_SYS_POLL_H 1
        \\#define HAVE_SYS_SELECT_H 1
        \\#define HAVE_SYS_TIME_H 1
        \\#define HAVE_SYS_TIMES_H 1
        \\#define HAVE_UNISTD_H 1
        \\#define HAVE_WCTYPE_H 1
        \\#define HAVE_UNISTD_H 1
        \\#define HAVE_GETOPT_H 1
        \\#define HAVE_GETOPT_HEADER 1
        \\#define DECL_ENVIRON 1
        \\#define HAVE_ENVIRON 1
        \\#define HAVE_PUTENV 1
        \\#define HAVE_SETENV 1
        \\#define HAVE_STRDUP 1
        \\#define HAVE_SYS_TIME_SELECT 1
        \\#define SIG_ATOMIC_T volatile sig_atomic_t
        \\#define HAVE_ERRNO 1
        \\#define HAVE_FPATHCONF 1
        \\#define HAVE_GETCWD 1
        \\#define HAVE_GETEGID 1
        \\#define HAVE_GETEUID 1
        \\#define HAVE_GETOPT 1
        \\#define HAVE_LOCALECONV 1
        \\#define HAVE_POLL 1
        \\#define HAVE_PUTENV 1
        \\#define HAVE_REMOVE 1
        \\#define HAVE_SELECT 1
        \\#define HAVE_SETBUF 1
        \\#define HAVE_SETBUFFER 1
        \\#define HAVE_SETENV 1
        \\#define HAVE_SETFSUID 1
        \\#define HAVE_SETVBUF 1
        \\#define HAVE_SIGACTION 1
        \\#define HAVE_SNPRINTF 1
        \\#define HAVE_STRDUP 1
        \\#define HAVE_STRSTR 1
        \\#define HAVE_SYSCONF 1
        \\#define HAVE_TCGETPGRP 1
        \\#define HAVE_TIMES 1
        \\#define HAVE_TSEARCH 1
        \\#define HAVE_VSNPRINTF 1
        \\#define HAVE_ISASCII 1
        \\#define HAVE_NANOSLEEP 1
        \\#define HAVE_TERMIO_H 1
        \\#define HAVE_TERMIOS_H 1
        \\#define HAVE_UNISTD_H 1
        \\#define HAVE_SYS_IOCTL_H 1
        \\#define HAVE_TCGETATTR 1
        \\#define HAVE_VSSCANF 1
        \\#define HAVE_UNISTD_H 1
        \\#define HAVE_MKSTEMP 1
        \\#define HAVE_SIZECHANGE 1
        \\#define HAVE_WORKING_POLL 1
        \\#define HAVE_VA_COPY 1
        \\#define HAVE_UNISTD_H 1
        \\#define HAVE_FORK 1
        \\#define HAVE_VFORK 1
        \\#define HAVE_WORKING_VFORK 1
        \\#define HAVE_WORKING_FORK 1
        \\#define USE_FOPEN_BIN_R 1
        \\#define USE_OPENPTY_HEADER <pty.h>
        \\#define USE_XTERM_PTY 1
        \\#define SIZEOF_BOOL 1
        \\#define CPP_HAS_OVERRIDE 1
        \\#define CPP_HAS_STATIC_CAST 1
        \\#define SIZEOF_WCHAR_T 4
        \\#define HAVE_SLK_COLOR 1
        \\#define HAVE_PANEL_H 1
        \\#define HAVE_LIBPANEL 1
        \\#define HAVE_MENU_H 1
        \\#define HAVE_LIBMENU 1
        \\#define HAVE_FORM_H 1
        \\#define HAVE_LIBFORM 1
        \\
        \\#define NCURSES_PATHSEP ':'
        \\#define NCURSES_OSPEED_COMPAT 1
        \\#define HAVE_CURSES_DATA_BOOLNAMES 1
        \\#define USE_XMC_SUPPORT 0
        \\#define TERMPATH "none"
        \\
        \\#ifdef __cplusplus
        \\#undef const
        \\#undef inline
        \\#endif
        \\
        \\#ifndef __cplusplus
        \\#ifdef NEED_MBSTATE_T_DEF
        \\#define mbstate_t int
        \\#endif
        \\#endif
    , .{
        b.getInstallPath(.prefix, "usr/share/terminfo"),
        b.getInstallPath(.prefix, "usr/share/terminfo"),
        b.getInstallPath(.lib, "X11/rgb.txt"),
    }));

    var libncurses: *std.Build.Step.Compile = undefined;
    inline for (@as([]const []const u8, &.{ "ncurses", "ncursesw" })) |name| {
        const lib = std.Build.Step.Compile.create(b, .{
            .name = name,
            .root_module = .{
                .target = target,
                .optimize = optimize,
                .link_libc = true,
            },
            .kind = .lib,
            .linkage = linkage,
            .version = .{
                .major = 6,
                .minor = 4,
                .patch = 0,
            },
        });

        lib.addIncludePath(source.path("include"));
        lib.addIncludePath(source.path("ncurses"));
        lib.addIncludePath(.{ .path = b.pathFromRoot("src") });
        lib.addIncludePath(headers.getDirectory());
        lib.addIncludePath(cursesHeader.getDirectory());
        lib.addConfigHeader(unctrlHeader);
        lib.addConfigHeader(termcapHeader);
        lib.addIncludePath(termHeader.getDirectory());

        lib.addCSourceFiles(.{
            .files = &.{
                source.path("ncurses/tty/hardscroll.c").getPath(source.builder),
                source.path("ncurses/tty/hashmap.c").getPath(source.builder),
                source.path("ncurses/base/lib_addch.c").getPath(source.builder),
                source.path("ncurses/base/lib_addstr.c").getPath(source.builder),
                source.path("ncurses/base/lib_beep.c").getPath(source.builder),
                source.path("ncurses/base/lib_bkgd.c").getPath(source.builder),
                source.path("ncurses/base/lib_box.c").getPath(source.builder),
                source.path("ncurses/base/lib_chgat.c").getPath(source.builder),
                source.path("ncurses/base/lib_clear.c").getPath(source.builder),
                source.path("ncurses/base/lib_clearok.c").getPath(source.builder),
                source.path("ncurses/base/lib_clrbot.c").getPath(source.builder),
                source.path("ncurses/base/lib_clreol.c").getPath(source.builder),
                source.path("ncurses/base/lib_color.c").getPath(source.builder),
                source.path("ncurses/base/lib_colorset.c").getPath(source.builder),
                source.path("ncurses/base/lib_delch.c").getPath(source.builder),
                source.path("ncurses/base/lib_delwin.c").getPath(source.builder),
                source.path("ncurses/base/lib_echo.c").getPath(source.builder),
                source.path("ncurses/base/lib_endwin.c").getPath(source.builder),
                source.path("ncurses/base/lib_erase.c").getPath(source.builder),
                source.path("ncurses/base/lib_flash.c").getPath(source.builder),
                b.pathFromRoot("src/lib_gen.c"),
                source.path("ncurses/base/lib_getch.c").getPath(source.builder),
                source.path("ncurses/base/lib_getstr.c").getPath(source.builder),
                source.path("ncurses/base/lib_hline.c").getPath(source.builder),
                source.path("ncurses/base/lib_immedok.c").getPath(source.builder),
                source.path("ncurses/base/lib_inchstr.c").getPath(source.builder),
                source.path("ncurses/base/lib_initscr.c").getPath(source.builder),
                source.path("ncurses/base/lib_insch.c").getPath(source.builder),
                source.path("ncurses/base/lib_insdel.c").getPath(source.builder),
                source.path("ncurses/base/lib_insnstr.c").getPath(source.builder),
                source.path("ncurses/base/lib_instr.c").getPath(source.builder),
                source.path("ncurses/base/lib_isendwin.c").getPath(source.builder),
                source.path("ncurses/base/lib_leaveok.c").getPath(source.builder),
                source.path("ncurses/base/lib_mouse.c").getPath(source.builder),
                source.path("ncurses/base/lib_move.c").getPath(source.builder),
                source.path("ncurses/tty/lib_mvcur.c").getPath(source.builder),
                source.path("ncurses/base/lib_mvwin.c").getPath(source.builder),
                source.path("ncurses/base/lib_newterm.c").getPath(source.builder),
                source.path("ncurses/base/lib_newwin.c").getPath(source.builder),
                source.path("ncurses/base/lib_nl.c").getPath(source.builder),
                source.path("ncurses/base/lib_overlay.c").getPath(source.builder),
                source.path("ncurses/base/lib_pad.c").getPath(source.builder),
                source.path("ncurses/base/lib_printw.c").getPath(source.builder),
                source.path("ncurses/base/lib_redrawln.c").getPath(source.builder),
                source.path("ncurses/base/lib_refresh.c").getPath(source.builder),
                source.path("ncurses/base/lib_restart.c").getPath(source.builder),
                source.path("ncurses/base/lib_scanw.c").getPath(source.builder),
                source.path("ncurses/base/lib_screen.c").getPath(source.builder),
                source.path("ncurses/base/lib_scroll.c").getPath(source.builder),
                source.path("ncurses/base/lib_scrollok.c").getPath(source.builder),
                source.path("ncurses/base/lib_scrreg.c").getPath(source.builder),
                source.path("ncurses/base/lib_set_term.c").getPath(source.builder),
                source.path("ncurses/base/lib_slk.c").getPath(source.builder),
                source.path("ncurses/base/lib_slkatr_set.c").getPath(source.builder),
                source.path("ncurses/base/lib_slkatrof.c").getPath(source.builder),
                source.path("ncurses/base/lib_slkatron.c").getPath(source.builder),
                source.path("ncurses/base/lib_slkatrset.c").getPath(source.builder),
                source.path("ncurses/base/lib_slkattr.c").getPath(source.builder),
                source.path("ncurses/base/lib_slkclear.c").getPath(source.builder),
                source.path("ncurses/base/lib_slkcolor.c").getPath(source.builder),
                source.path("ncurses/base/lib_slkinit.c").getPath(source.builder),
                source.path("ncurses/base/lib_slklab.c").getPath(source.builder),
                source.path("ncurses/base/lib_slkrefr.c").getPath(source.builder),
                source.path("ncurses/base/lib_slkset.c").getPath(source.builder),
                source.path("ncurses/base/lib_slktouch.c").getPath(source.builder),
                source.path("ncurses/base/lib_touch.c").getPath(source.builder),
                source.path("ncurses/trace/lib_tracedmp.c").getPath(source.builder),
                source.path("ncurses/trace/lib_tracemse.c").getPath(source.builder),
                source.path("ncurses/tty/lib_tstp.c").getPath(source.builder),
                source.path("ncurses/base/lib_ungetch.c").getPath(source.builder),
                source.path("ncurses/tty/lib_vidattr.c").getPath(source.builder),
                source.path("ncurses/base/lib_vline.c").getPath(source.builder),
                source.path("ncurses/base/lib_wattroff.c").getPath(source.builder),
                source.path("ncurses/base/lib_wattron.c").getPath(source.builder),
                source.path("ncurses/base/lib_winch.c").getPath(source.builder),
                source.path("ncurses/base/lib_window.c").getPath(source.builder),
                source.path("ncurses/base/nc_panel.c").getPath(source.builder),
                source.path("ncurses/base/safe_sprintf.c").getPath(source.builder),
                source.path("ncurses/tty/tty_update.c").getPath(source.builder),
                source.path("ncurses/trace/varargs.c").getPath(source.builder),
                source.path("ncurses/base/vsscanf.c").getPath(source.builder),
                source.path("ncurses/base/lib_freeall.c").getPath(source.builder),
                source.path("ncurses/widechar/charable.c").getPath(source.builder),
                source.path("ncurses/widechar/lib_add_wch.c").getPath(source.builder),
                source.path("ncurses/widechar/lib_box_set.c").getPath(source.builder),
                source.path("ncurses/widechar/lib_cchar.c").getPath(source.builder),
                source.path("ncurses/widechar/lib_erasewchar.c").getPath(source.builder),
                source.path("ncurses/widechar/lib_get_wch.c").getPath(source.builder),
                source.path("ncurses/widechar/lib_get_wstr.c").getPath(source.builder),
                source.path("ncurses/widechar/lib_hline_set.c").getPath(source.builder),
                source.path("ncurses/widechar/lib_in_wch.c").getPath(source.builder),
                source.path("ncurses/widechar/lib_in_wchnstr.c").getPath(source.builder),
                source.path("ncurses/widechar/lib_ins_wch.c").getPath(source.builder),
                source.path("ncurses/widechar/lib_inwstr.c").getPath(source.builder),
                source.path("ncurses/widechar/lib_key_name.c").getPath(source.builder),
                source.path("ncurses/widechar/lib_pecho_wchar.c").getPath(source.builder),
                source.path("ncurses/widechar/lib_slk_wset.c").getPath(source.builder),
                source.path("ncurses/widechar/lib_unget_wch.c").getPath(source.builder),
                source.path("ncurses/widechar/lib_vid_attr.c").getPath(source.builder),
                source.path("ncurses/widechar/lib_vline_set.c").getPath(source.builder),
                source.path("ncurses/widechar/lib_wacs.c").getPath(source.builder),
                source.path("ncurses/widechar/lib_wunctrl.c").getPath(source.builder),
                b.pathFromRoot("src/expanded.c"),
                source.path("ncurses/base/legacy_coding.c").getPath(source.builder),
                source.path("ncurses/base/lib_dft_fgbg.c").getPath(source.builder),
                source.path("ncurses/tinfo/lib_print.c").getPath(source.builder),
                source.path("ncurses/base/new_pair.c").getPath(source.builder),
                source.path("ncurses/base/resizeterm.c").getPath(source.builder),
                source.path("ncurses/trace/trace_xnames.c").getPath(source.builder),
                source.path("ncurses/tinfo/use_screen.c").getPath(source.builder),
                source.path("ncurses/base/use_window.c").getPath(source.builder),
                source.path("ncurses/base/wresize.c").getPath(source.builder),
                source.path("ncurses/tinfo/access.c").getPath(source.builder),
                source.path("ncurses/tinfo/add_tries.c").getPath(source.builder),
                source.path("ncurses/tinfo/alloc_ttype.c").getPath(source.builder),
                b.pathFromRoot("src/codes.c"),
                b.pathFromRoot("src/comp_captab.c"),
                source.path("ncurses/tinfo/comp_error.c").getPath(source.builder),
                source.path("ncurses/tinfo/comp_hash.c").getPath(source.builder),
                b.pathFromRoot("src/comp_userdefs.c"),
                source.path("ncurses/tinfo/db_iterator.c").getPath(source.builder),
                source.path("ncurses/tinfo/doalloc.c").getPath(source.builder),
                source.path("ncurses/tinfo/entries.c").getPath(source.builder),
                b.pathFromRoot("src/fallback.c"),
                source.path("ncurses/tinfo/free_ttype.c").getPath(source.builder),
                source.path("ncurses/tinfo/getenv_num.c").getPath(source.builder),
                source.path("ncurses/tinfo/home_terminfo.c").getPath(source.builder),
                source.path("ncurses/tinfo/init_keytry.c").getPath(source.builder),
                source.path("ncurses/tinfo/lib_acs.c").getPath(source.builder),
                source.path("ncurses/tinfo/lib_baudrate.c").getPath(source.builder),
                source.path("ncurses/tinfo/lib_cur_term.c").getPath(source.builder),
                source.path("ncurses/tinfo/lib_data.c").getPath(source.builder),
                source.path("ncurses/tinfo/lib_has_cap.c").getPath(source.builder),
                source.path("ncurses/tinfo/lib_kernel.c").getPath(source.builder),
                b.pathFromRoot("src/lib_keyname.c"),
                source.path("ncurses/tinfo/lib_longname.c").getPath(source.builder),
                source.path("ncurses/tinfo/lib_napms.c").getPath(source.builder),
                source.path("ncurses/tinfo/lib_options.c").getPath(source.builder),
                source.path("ncurses/tinfo/lib_raw.c").getPath(source.builder),
                source.path("ncurses/tinfo/lib_setup.c").getPath(source.builder),
                source.path("ncurses/tinfo/lib_termcap.c").getPath(source.builder),
                source.path("ncurses/tinfo/lib_termname.c").getPath(source.builder),
                source.path("ncurses/tinfo/lib_tgoto.c").getPath(source.builder),
                source.path("ncurses/tinfo/lib_ti.c").getPath(source.builder),
                source.path("ncurses/tinfo/lib_tparm.c").getPath(source.builder),
                source.path("ncurses/tinfo/lib_tputs.c").getPath(source.builder),
                source.path("ncurses/trace/lib_trace.c").getPath(source.builder),
                source.path("ncurses/trace/lib_traceatr.c").getPath(source.builder),
                source.path("ncurses/trace/lib_tracebits.c").getPath(source.builder),
                source.path("ncurses/trace/lib_tracechr.c").getPath(source.builder),
                source.path("ncurses/tinfo/lib_ttyflags.c").getPath(source.builder),
                source.path("ncurses/tty/lib_twait.c").getPath(source.builder),
                source.path("ncurses/tinfo/name_match.c").getPath(source.builder),
                b.pathFromRoot("src/names.c"),
                source.path("ncurses/tinfo/obsolete.c").getPath(source.builder),
                source.path("ncurses/tinfo/read_entry.c").getPath(source.builder),
                source.path("ncurses/tinfo/read_termcap.c").getPath(source.builder),
                source.path("ncurses/tinfo/strings.c").getPath(source.builder),
                source.path("ncurses/trace/trace_buf.c").getPath(source.builder),
                source.path("ncurses/trace/trace_tries.c").getPath(source.builder),
                source.path("ncurses/base/tries.c").getPath(source.builder),
                source.path("ncurses/tinfo/trim_sgr0.c").getPath(source.builder),
                b.pathFromRoot("src/unctrl.c"),
                source.path("ncurses/trace/visbuf.c").getPath(source.builder),
                source.path("ncurses/tinfo/alloc_entry.c").getPath(source.builder),
                source.path("ncurses/tinfo/captoinfo.c").getPath(source.builder),
                source.path("ncurses/tinfo/comp_expand.c").getPath(source.builder),
                source.path("ncurses/tinfo/comp_parse.c").getPath(source.builder),
                source.path("ncurses/tinfo/comp_scan.c").getPath(source.builder),
                source.path("ncurses/tinfo/parse_entry.c").getPath(source.builder),
                source.path("ncurses/tinfo/write_entry.c").getPath(source.builder),
                source.path("ncurses/base/define_key.c").getPath(source.builder),
                source.path("ncurses/tinfo/hashed_db.c").getPath(source.builder),
                source.path("ncurses/base/key_defined.c").getPath(source.builder),
                source.path("ncurses/base/keybound.c").getPath(source.builder),
                source.path("ncurses/base/keyok.c").getPath(source.builder),
                source.path("ncurses/base/version.c").getPath(source.builder),
            },
            .flags = &.{
                "-DHAVE_CONFIG_H",
                "-DBUILDING_NCURSES",
                "-D_GNU_SOURCE",
            },
        });
        b.installArtifact(lib);

        if (std.mem.eql(u8, name, "ncurses")) {
            libncurses = lib;
        }
    }

    libncurses.installHeader(source.path("form/form.h").getPath(b), "form.h");
    libncurses.installHeader(source.path("menu/menu.h").getPath(b), "menu.h");
    libncurses.installHeader(source.path("panel/panel.h").getPath(b), "panel.h");
    libncurses.installHeader(source.path("include/term_entry.h").getPath(b), "term_entry.h");

    {
        const install_file = b.addInstallFileWithDir(.{
            .generated = &cursesHeader.output_file,
        }, .header, "curses.h");
        b.getInstallStep().dependOn(&install_file.step);
        libncurses.installed_headers.append(&install_file.step) catch @panic("OOM");
    }

    {
        const install_file = b.addInstallFileWithDir(.{
            .generated = &cursesHeader.output_file,
        }, .header, "ncurses.h");
        b.getInstallStep().dependOn(&install_file.step);
        libncurses.installed_headers.append(&install_file.step) catch @panic("OOM");
    }

    {
        const install_file = b.addInstallFileWithDir(ncursesDll, .header, "ncurses_dll.h");
        b.getInstallStep().dependOn(&install_file.step);
        libncurses.installed_headers.append(&install_file.step) catch @panic("OOM");
    }

    {
        const install_file = b.addInstallFileWithDir(.{
            .generated = &termcapHeader.output_file,
        }, .header, "termcap.h");
        b.getInstallStep().dependOn(&install_file.step);
        libncurses.installed_headers.append(&install_file.step) catch @panic("OOM");
    }

    {
        const install_file = b.addInstallFileWithDir(.{
            .generated = &termHeader.output_file,
        }, .header, "term.h");
        b.getInstallStep().dependOn(&install_file.step);
        libncurses.installed_headers.append(&install_file.step) catch @panic("OOM");
    }

    {
        const install_file = b.addInstallFileWithDir(unctrlHeader.getOutput(), .header, "unctrl.h");
        b.getInstallStep().dependOn(&install_file.step);
        libncurses.installed_headers.append(&install_file.step) catch @panic("OOM");
    }
}
