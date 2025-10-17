type Name = string;

type Value64 = number | "usize_max" | "uint32_max" | "uint64_max";

type Value16 = number;

type PrimitiveType =
  | "c_void"
  | "bool"
  | "nullable_string"
  | "string_with_default_empty"
  | "out_string"
  | "uint16"
  | "uint32"
  | "uint64"
  | "usize"
  | "int16"
  | "int32"
  | "float32"
  | "float64"
  | "array<bool>"
  | "array<string>"
  | "array<uint16>"
  | "array<uint32>"
  | "array<uint64>"
  | "array<usize>"
  | "array<int16>"
  | "array<int32>"
  | "array<float32>"
  | "array<float64>";

type ComplexType = string;

type CallbackType = string;

type Type = PrimitiveType | ComplexType | CallbackType;

type Pointer = "immutable" | "mutable";

type CallbackStyle = "callback_mode" | "immediate";

interface Callback {
  name: Name;
  doc: string;
  style: CallbackStyle;
  args?: FunctionParameterType[];
}

interface ParameterType {
  name: Name;
  doc: string;
  type: Type;
  ownership?: "with" | "without";
  pointer?: Pointer;
  optional?: boolean;
  namespace?: string;
}

interface FunctionParameterType extends ParameterType {
  doc: string;
}

interface Function {
  name: Name;
  doc: string;
  returns?: {
    doc: string;
    type: Type;
    passed_with_ownership?: boolean;
    pointer?: Pointer;
  };
  callback?: CallbackType;
  args?: FunctionParameterType[];
}

interface Typedef {
  name: Name;
  doc: string;
  type: PrimitiveType;
}

interface Constant {
  name: Name;
  value: Value64;
  doc: string;
}

interface EnumEntry {
  name: Name;
  doc: string;
  value?: Value16;
}

interface Enum {
  name: Name;
  doc: string;
  extended?: boolean;
  entries?: (EnumEntry | null)[];
}

interface BitflagEntry {
  name: Name;
  doc: string;
  value?: Value64;
  value_combination?: Name[];
}

interface Bitflag {
  name: Name;
  doc: string;
  extended?: boolean;
  entries: BitflagEntry[];
}

interface Struct {
  name: Name;
  doc: string;
  type:
    | "base_in"
    | "base_out"
    | "base_in_or_out"
    | "extension_in"
    | "extension_out"
    | "extension_in_or_out"
    | "standalone";
  extends?: string[];
  free_members?: boolean;
  members?: ParameterType[];
}

interface Object {
  name: Name;
  doc: string;
  extended?: boolean;
  namespace?: string;
  methods: Function[];
}

interface Schema {
  copyright: string;
  name: Name;
  enum_prefix: string;
  constants: Constant[];
  typedefs: Typedef[];
  enums: Enum[];
  bitflags: Bitflag[];
  callbacks: Callback[];
  structs: Struct[];
  functions: Function[];
  objects: Object[];
}
