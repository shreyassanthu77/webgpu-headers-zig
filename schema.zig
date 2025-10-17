const WebGPUHeadersYaml = struct {
    copyright: []const u8,
    name: []const u8,
    enum_prefix: []const u8,
    constants: []Constant,
    typedefs: []Typedef,
    enums: []Enum,
    bitflags: []Bitflag,
    callbacks: []Callback,
    structs: []Struct,
    functions: []Function,
    objects: []Object,

    pub const Constant = struct {
        name: []const u8,
        value: Value64,
        doc: []const u8,
    };

    pub const Typedef = struct {
        name: []const u8,
        doc: []const u8,
        type: PrimitiveType,
    };

    pub const Enum = struct {
        name: []const u8,
        doc: []const u8,
        extended: ?bool = null,
        entries: []Entry,

        pub const Entry = struct {
            name: []const u8,
            doc: []const u8,
            value: ?u16 = null,
        };
    };

    pub const Bitflag = struct {
        name: []const u8,
        doc: []const u8,
        extended: ?bool = null,
        entries: []Entry,

        pub const Entry = struct {
            name: []const u8,
            doc: []const u8,
            value: ?Value64 = null,
            value_combination: ?[]const []const u8 = null,
        };
    };

    pub const Callback = struct {
        name: []const u8,
        doc: []const u8,
        style: CallbackStyle,
        args: []ParameterType,

        pub const CallbackStyle = enum {
            callback_mode,
            immediate,
        };
    };

    const Struct = struct {
        name: []const u8,
        doc: []const u8,
        type: StructType,
        extends: ?[]const []const u8 = null,
        free_members: ?bool = null,
        members: []ParameterType,

        pub const StructType = enum {
            base_in,
            base_out,
            base_in_or_out,
            extension_in,
            extension_out,
            extension_in_or_out,
            standalone,
        };
    };

    pub const Function = struct {
        name: []const u8,
        doc: []const u8,
        returns: ?Return = null,
        callback: ?[]const u8 = null,
        args: []ParameterType,

        pub const Return = struct {
            doc: []const u8,
            type: Type,
            passed_with_ownership: ?bool = null,
            pointer: ?Pointer = null,
        };

        pub const Pointer = enum {
            immutable,
            mutable,
        };
    };

    pub const Object = struct {
        name: []const u8,
        doc: []const u8,
        extended: ?bool = null,
        namespace: ?[]const u8 = null,
        methods: []Function,
    };

    pub const ParameterType = struct {
        name: []const u8,
        doc: []const u8,
        type: Type,
        ownership: ?Ownership = null,
        pointer: ?Pointer = null,
        optional: ?bool = null,
        namespace: ?[]const u8 = null,

        pub const Ownership = enum {
            with,
            without,
        };

        pub const Pointer = enum {
            immutable,
            mutable,
        };
    };

    pub const Type = union(enum) {
        primitive: PrimitiveType,
        complex: []const u8,
        callback: []const u8,
    };

    pub const PrimitiveType = enum {
        c_void,
        bool,
        nullable_string,
        string_with_def,
        out_string,
        uint16,
        uint32,
        uint64,
        usize,
        int16,
        int32,
        float32,
        float64,
        @"array<bool>",
        @"array<string>",
        @"array<uint16>",
        @"array<uint32>",
        @"array<uint64>",
        @"array<usize>",
        @"array<int16>",
        @"array<int32>",
        @"array<float32>",
        @"array<float64>",
    };

    pub const Value64 = union(enum) {
        number: u64,
        usize_max,
        uint32_max,
        uint64_max,
    };
};
