// Copyright 2019-2023 WebGPU-Native developers
// 
// SPDX-License-Identifier: BSD-3-Clause
// 

//! **Important:** *This documentation is a Work In Progress.*
//! 
//! This is the home of WebGPU C API specification. We define here the standard
//! `webgpu.h` header that all implementations should provide.
//! 
//! For all details where behavior is not otherwise specified, `webgpu.h` has
//! the same behavior as the WebGPU specification for JavaScript on the Web.
//! The WebIDL-based Web specification is mapped into C as faithfully (and
//! bidirectionally) as practical/possible.
//! The working draft of WebGPU can be found at <https://www.w3.org/TR/webgpu/>.
//! 
//! The standard include directive for this header is `#include <webgpu/webgpu.h>`
//! (if it is provided in a system-wide or toolchain-wide include directory).
//! 

const std = @import("std");

///Indicates no array layer count is specified. For more info,
///see @ref SentinelValues and the places that use this sentinel value.
///
pub const array_layer_count_undefined = std.math.maxInt(u32);

///Indicates no copy stride is specified. For more info,
///see @ref SentinelValues and the places that use this sentinel value.
///
pub const copy_stride_undefined = std.math.maxInt(u32);

///Indicates no depth clear value is specified. For more info,
///see @ref SentinelValues and the places that use this sentinel value.
///
pub const depth_clear_value_undefined = std.zig.c_translation.builtins.nanf("");

///Indicates no depth slice is specified. For more info,
///see @ref SentinelValues and the places that use this sentinel value.
///
pub const depth_slice_undefined = std.math.maxInt(u32);

///For `uint32_t` limits, indicates no limit value is specified. For more info,
///see @ref SentinelValues and the places that use this sentinel value.
///
pub const limit_u32_undefined = std.math.maxInt(u32);

///For `uint64_t` limits, indicates no limit value is specified. For more info,
///see @ref SentinelValues and the places that use this sentinel value.
///
pub const limit_u64_undefined = std.math.maxInt(u64);

///Indicates no mip level count is specified. For more info,
///see @ref SentinelValues and the places that use this sentinel value.
///
pub const mip_level_count_undefined = std.math.maxInt(u32);

///Indicates no query set index is specified. For more info,
///see @ref SentinelValues and the places that use this sentinel value.
///
pub const query_set_index_undefined = std.math.maxInt(u32);

///Sentinel value used in @ref WGPUStringView to indicate that the pointer
///is to a null-terminated string, rather than an explicitly-sized string.
///
pub const strlen = std.math.maxInt(usize);

///Indicates a size extending to the end of the buffer. For more info,
///see @ref SentinelValues and the places that use this sentinel value.
///
pub const whole_map_size = std.math.maxInt(usize);

///Indicates a size extending to the end of the buffer. For more info,
///see @ref SentinelValues and the places that use this sentinel value.
///
pub const whole_size = std.math.maxInt(u64);

///TODO
///
pub const AdapterType = enum(u32) {
    __reserved0 = 0,
    

    /// TODO
    /// 
    discrete_GPU = 1,

    /// TODO
    /// 
    integrated_GPU = 2,

    /// TODO
    /// 
    CPU = 3,

    /// TODO
    /// 
    unknown = 4,
};

///TODO
///
pub const AddressMode = enum(u32) {
    /// Indicates no value is passed for this argument. See @ref SentinelValues.
    @"undefined" = 0,

    /// TODO
    /// 
    clamp_to_edge = 1,

    /// TODO
    /// 
    repeat = 2,

    /// TODO
    /// 
    mirror_repeat = 3,
};

///TODO
///
pub const BackendType = enum(u32) {
    /// Indicates no value is passed for this argument. See @ref SentinelValues.
    @"undefined" = 0,

    /// TODO
    /// 
    null = 1,

    /// TODO
    /// 
    WebGPU = 2,

    /// TODO
    /// 
    D3D11 = 3,

    /// TODO
    /// 
    D3D12 = 4,

    /// TODO
    /// 
    metal = 5,

    /// TODO
    /// 
    vulkan = 6,

    /// TODO
    /// 
    openGL = 7,

    /// TODO
    /// 
    openGLES = 8,
};

///TODO
///
pub const BlendFactor = enum(u32) {
    /// Indicates no value is passed for this argument. See @ref SentinelValues.
    @"undefined" = 0,

    /// TODO
    /// 
    zero = 1,

    /// TODO
    /// 
    one = 2,

    /// TODO
    /// 
    src = 3,

    /// TODO
    /// 
    one_minus_src = 4,

    /// TODO
    /// 
    src_alpha = 5,

    /// TODO
    /// 
    one_minus_src_alpha = 6,

    /// TODO
    /// 
    dst = 7,

    /// TODO
    /// 
    one_minus_dst = 8,

    /// TODO
    /// 
    dst_alpha = 9,

    /// TODO
    /// 
    one_minus_dst_alpha = 10,

    /// TODO
    /// 
    src_alpha_saturated = 11,

    /// TODO
    /// 
    constant = 12,

    /// TODO
    /// 
    one_minus_constant = 13,

    /// TODO
    /// 
    src1 = 14,

    /// TODO
    /// 
    one_minus_src1 = 15,

    /// TODO
    /// 
    src1_alpha = 16,

    /// TODO
    /// 
    one_minus_src1_alpha = 17,
};

///TODO
///
pub const BlendOperation = enum(u32) {
    /// Indicates no value is passed for this argument. See @ref SentinelValues.
    @"undefined" = 0,

    /// TODO
    /// 
    add = 1,

    /// TODO
    /// 
    subtract = 2,

    /// TODO
    /// 
    reverse_subtract = 3,

    /// TODO
    /// 
    min = 4,

    /// TODO
    /// 
    max = 5,
};

///TODO
///
pub const BufferBindingType = enum(u32) {
    /// Indicates that this @ref WGPUBufferBindingLayout member of
    /// its parent @ref WGPUBindGroupLayoutEntry is not used.
    /// (See also @ref SentinelValues.)
    /// 
    binding_not_used = 0,

    /// `1`. Indicates no value is passed for this argument. See @ref SentinelValues.
    /// 
    @"undefined" = 1,

    /// TODO
    /// 
    uniform = 2,

    /// TODO
    /// 
    storage = 3,

    /// TODO
    /// 
    read_only_storage = 4,
};

///TODO
///
pub const BufferMapState = enum(u32) {
    __reserved0 = 0,
    

    /// TODO
    /// 
    unmapped = 1,

    /// TODO
    /// 
    pending = 2,

    /// TODO
    /// 
    mapped = 3,
};

///The callback mode controls how a callback for an asynchronous operation may be fired. See @ref Asynchronous-Operations for how these are used.
pub const CallbackMode = enum(u32) {
    __reserved0 = 0,
    

    /// Callbacks created with `WGPUCallbackMode_WaitAnyOnly`:
    /// - fire when the asynchronous operation's future is passed to a call to @ref wgpuInstanceWaitAny
    ///   AND the operation has already completed or it completes inside the call to @ref wgpuInstanceWaitAny.
    /// 
    wait_any_only = 1,

    /// Callbacks created with `WGPUCallbackMode_AllowProcessEvents`:
    /// - fire for the same reasons as callbacks created with `WGPUCallbackMode_WaitAnyOnly`
    /// - fire inside a call to @ref wgpuInstanceProcessEvents if the asynchronous operation is complete.
    /// 
    allow_process_events = 2,

    /// Callbacks created with `WGPUCallbackMode_AllowSpontaneous`:
    /// - fire for the same reasons as callbacks created with `WGPUCallbackMode_AllowProcessEvents`
    /// - **may** fire spontaneously on an arbitrary or application thread, when the WebGPU implementations discovers that the asynchronous operation is complete.
    /// 
    ///   Implementations _should_ fire spontaneous callbacks as soon as possible.
    /// 
    /// @note Because spontaneous callbacks may fire at an arbitrary time on an arbitrary thread, applications should take extra care when acquiring locks or mutating state inside the callback. It undefined behavior to re-entrantly call into the webgpu.h API if the callback fires while inside the callstack of another webgpu.h function that is not `wgpuInstanceWaitAny` or `wgpuInstanceProcessEvents`.
    /// 
    allow_spontaneous = 3,
};

///TODO
///
pub const CompareFunction = enum(u32) {
    /// Indicates no value is passed for this argument. See @ref SentinelValues.
    @"undefined" = 0,

    /// TODO
    /// 
    never = 1,

    /// TODO
    /// 
    less = 2,

    /// TODO
    /// 
    equal = 3,

    /// TODO
    /// 
    less_equal = 4,

    /// TODO
    /// 
    greater = 5,

    /// TODO
    /// 
    not_equal = 6,

    /// TODO
    /// 
    greater_equal = 7,

    /// TODO
    /// 
    always = 8,
};

///TODO
///
pub const CompilationInfoRequestStatus = enum(u32) {
    __reserved0 = 0,
    

    /// TODO
    /// 
    success = 1,

    /// See @ref CallbackStatuses.
    /// 
    callback_cancelled = 2,
};

///TODO
///
pub const CompilationMessageType = enum(u32) {
    __reserved0 = 0,
    

    /// TODO
    /// 
    @"error" = 1,

    /// TODO
    /// 
    warning = 2,

    /// TODO
    /// 
    info = 3,
};

///TODO
///
pub const ComponentSwizzle = enum(u32) {
    /// Indicates no value is passed for this argument. See @ref SentinelValues.
    @"undefined" = 0,

    /// Force its value to 0.
    /// 
    zero = 1,

    /// Force its value to 1.
    /// 
    one = 2,

    /// Take its value from the red channel of the texture.
    /// 
    r = 3,

    /// Take its value from the green channel of the texture.
    /// 
    g = 4,

    /// Take its value from the blue channel of the texture.
    /// 
    b = 5,

    /// Take its value from the alpha channel of the texture.
    /// 
    a = 6,
};

///Describes how frames are composited with other contents on the screen when @ref wgpuSurfacePresent is called.
pub const CompositeAlphaMode = enum(u32) {
    /// Lets the WebGPU implementation choose the best mode (supported, and with the best performance) between @ref WGPUCompositeAlphaMode_Opaque or @ref WGPUCompositeAlphaMode_Inherit.
    auto = 0,

    /// The alpha component of the image is ignored and teated as if it is always 1.0.
    @"opaque" = 1,

    /// The alpha component is respected and non-alpha components are assumed to be already multiplied with the alpha component. For example, (0.5, 0, 0, 0.5) is semi-transparent bright red.
    premultiplied = 2,

    /// The alpha component is respected and non-alpha components are assumed to NOT be already multiplied with the alpha component. For example, (1.0, 0, 0, 0.5) is semi-transparent bright red.
    unpremultiplied = 3,

    /// The handling of the alpha component is unknown to WebGPU and should be handled by the application using system-specific APIs. This mode may be unavailable (for example on Wasm).
    inherit = 4,
};

///TODO
///
pub const CreatePipelineAsyncStatus = enum(u32) {
    __reserved0 = 0,
    

    /// TODO
    /// 
    success = 1,

    /// See @ref CallbackStatuses.
    /// 
    callback_cancelled = 2,

    /// TODO
    /// 
    validation_error = 3,

    /// TODO
    /// 
    internal_error = 4,
};

///TODO
///
pub const CullMode = enum(u32) {
    /// Indicates no value is passed for this argument. See @ref SentinelValues.
    @"undefined" = 0,

    /// TODO
    /// 
    none = 1,

    /// TODO
    /// 
    front = 2,

    /// TODO
    /// 
    back = 3,
};

///TODO
///
pub const DeviceLostReason = enum(u32) {
    __reserved0 = 0,
    

    /// TODO
    /// 
    unknown = 1,

    /// TODO
    /// 
    destroyed = 2,

    /// See @ref CallbackStatuses.
    /// 
    callback_cancelled = 3,

    /// TODO
    /// 
    failed_creation = 4,
};

///TODO
///
pub const ErrorFilter = enum(u32) {
    __reserved0 = 0,
    

    /// TODO
    /// 
    validation = 1,

    /// TODO
    /// 
    out_of_memory = 2,

    /// TODO
    /// 
    internal = 3,
};

///TODO
///
pub const ErrorType = enum(u32) {
    __reserved0 = 0,
    

    /// TODO
    /// 
    no_error = 1,

    /// TODO
    /// 
    validation = 2,

    /// TODO
    /// 
    out_of_memory = 3,

    /// TODO
    /// 
    internal = 4,

    /// TODO
    /// 
    unknown = 5,
};

///See @ref WGPURequestAdapterOptions::featureLevel.
///
pub const FeatureLevel = enum(u32) {
    /// Indicates no value is passed for this argument. See @ref SentinelValues.
    @"undefined" = 0,

    /// "Compatibility" profile which can be supported on OpenGL ES 3.1 and D3D11.
    /// 
    compatibility = 1,

    /// "Core" profile which can be supported on Vulkan/Metal/D3D12 (at least).
    /// 
    core = 2,
};

///TODO
///
pub const FeatureName = enum(u32) {
    __reserved0 = 0,
    

    /// TODO
    /// 
    core_features_and_limits = 1,

    /// TODO
    /// 
    depth_clip_control = 2,

    /// TODO
    /// 
    depth32_float_stencil8 = 3,

    /// TODO
    /// 
    texture_compression_BC = 4,

    /// TODO
    /// 
    texture_compression_BC_sliced_3D = 5,

    /// TODO
    /// 
    texture_compression_ETC2 = 6,

    /// TODO
    /// 
    texture_compression_ASTC = 7,

    /// TODO
    /// 
    texture_compression_ASTC_sliced_3D = 8,

    /// TODO
    /// 
    timestamp_query = 9,

    /// TODO
    /// 
    indirect_first_instance = 10,

    /// TODO
    /// 
    shader_f16 = 11,

    /// TODO
    /// 
    RG11B10_ufloat_renderable = 12,

    /// TODO
    /// 
    BGRA8_unorm_storage = 13,

    /// TODO
    /// 
    float32_filterable = 14,

    /// TODO
    /// 
    float32_blendable = 15,

    /// TODO
    /// 
    clip_distances = 16,

    /// TODO
    /// 
    dual_source_blending = 17,

    /// TODO
    /// 
    subgroups = 18,

    /// TODO
    /// 
    texture_formats_tier_1 = 19,

    /// TODO
    /// 
    texture_formats_tier_2 = 20,

    /// TODO
    /// 
    primitive_index = 21,

    /// TODO
    /// 
    texture_component_swizzle = 22,
};

///TODO
///
pub const FilterMode = enum(u32) {
    /// Indicates no value is passed for this argument. See @ref SentinelValues.
    @"undefined" = 0,

    /// TODO
    /// 
    nearest = 1,

    /// TODO
    /// 
    linear = 2,
};

///TODO
///
pub const FrontFace = enum(u32) {
    /// Indicates no value is passed for this argument. See @ref SentinelValues.
    @"undefined" = 0,

    /// TODO
    /// 
    CCW = 1,

    /// TODO
    /// 
    CW = 2,
};

///TODO
///
pub const IndexFormat = enum(u32) {
    /// Indicates no value is passed for this argument. See @ref SentinelValues.
    @"undefined" = 0,

    /// TODO
    /// 
    uint16 = 1,

    /// TODO
    /// 
    uint32 = 2,
};

///TODO
///
pub const InstanceFeatureName = enum(u32) {
    __reserved0 = 0,
    

    /// Enable use of ::wgpuInstanceWaitAny with `timeoutNS > 0`.
    /// 
    timed_wait_any = 1,

    /// Enable passing SPIR-V shaders to @ref wgpuDeviceCreateShaderModule,
    /// via @ref WGPUShaderSourceSPIRV.
    /// 
    shader_source_SPIRV = 2,

    /// Normally, a @ref WGPUAdapter can only create a single device. If this is
    /// available and enabled, then adapters won't immediately expire when they
    /// create a device, so can be reused to make multiple devices. They may
    /// still expire for other reasons.
    /// 
    multiple_devices_per_adapter = 3,
};

///TODO
///
pub const LoadOp = enum(u32) {
    /// Indicates no value is passed for this argument. See @ref SentinelValues.
    @"undefined" = 0,

    /// TODO
    /// 
    load = 1,

    /// TODO
    /// 
    clear = 2,
};

///TODO
///
pub const MapAsyncStatus = enum(u32) {
    __reserved0 = 0,
    

    /// TODO
    /// 
    success = 1,

    /// See @ref CallbackStatuses.
    /// 
    callback_cancelled = 2,

    /// TODO
    /// 
    @"error" = 3,

    /// TODO
    /// 
    aborted = 4,
};

///TODO
///
pub const MipmapFilterMode = enum(u32) {
    /// Indicates no value is passed for this argument. See @ref SentinelValues.
    @"undefined" = 0,

    /// TODO
    /// 
    nearest = 1,

    /// TODO
    /// 
    linear = 2,
};

///TODO
///
pub const OptionalBool = enum(u32) {
    /// TODO
    /// 
    false = 0,

    /// TODO
    /// 
    true = 1,

    /// TODO
    /// 
    @"undefined" = 2,
};

///TODO
///
pub const PopErrorScopeStatus = enum(u32) {
    __reserved0 = 0,
    

    /// The error scope stack was successfully popped and a result was reported.
    /// 
    success = 1,

    /// See @ref CallbackStatuses.
    /// 
    callback_cancelled = 2,

    /// The error scope stack could not be popped, because it was empty.
    /// 
    @"error" = 3,
};

///TODO
///
pub const PowerPreference = enum(u32) {
    /// No preference. (See also @ref SentinelValues.)
    @"undefined" = 0,

    /// TODO
    /// 
    low_power = 1,

    /// TODO
    /// 
    high_performance = 2,
};

///TODO
///
pub const PredefinedColorSpace = enum(u32) {
    __reserved0 = 0,
    

    /// TODO
    /// 
    SRGB = 1,

    /// TODO
    /// 
    display_p3 = 2,
};

///Describes when and in which order frames are presented on the screen when @ref wgpuSurfacePresent is called.
pub const PresentMode = enum(u32) {
    /// Present mode is not specified. Use the default.
    /// 
    @"undefined" = 0,

    /// The presentation of the image to the user waits for the next vertical blanking period to update in a first-in, first-out manner.
    /// Tearing cannot be observed and frame-loop will be limited to the display's refresh rate.
    /// This is the only mode that's always available.
    /// 
    fifo = 1,

    /// The presentation of the image to the user tries to wait for the next vertical blanking period but may decide to not wait if a frame is presented late.
    /// Tearing can sometimes be observed but late-frame don't produce a full-frame stutter in the presentation.
    /// This is still a first-in, first-out mechanism so a frame-loop will be limited to the display's refresh rate.
    /// 
    fifo_relaxed = 2,

    /// The presentation of the image to the user is updated immediately without waiting for a vertical blank.
    /// Tearing can be observed but latency is minimized.
    /// 
    immediate = 3,

    /// The presentation of the image to the user waits for the next vertical blanking period to update to the latest provided image.
    /// Tearing cannot be observed and a frame-loop is not limited to the display's refresh rate.
    /// 
    mailbox = 4,
};

///TODO
///
pub const PrimitiveTopology = enum(u32) {
    /// Indicates no value is passed for this argument. See @ref SentinelValues.
    @"undefined" = 0,

    /// TODO
    /// 
    point_list = 1,

    /// TODO
    /// 
    line_list = 2,

    /// TODO
    /// 
    line_strip = 3,

    /// TODO
    /// 
    triangle_list = 4,

    /// TODO
    /// 
    triangle_strip = 5,
};

///TODO
///
pub const QueryType = enum(u32) {
    __reserved0 = 0,
    

    /// TODO
    /// 
    occlusion = 1,

    /// TODO
    /// 
    timestamp = 2,
};

///TODO
///
pub const QueueWorkDoneStatus = enum(u32) {
    __reserved0 = 0,
    

    /// TODO
    /// 
    success = 1,

    /// See @ref CallbackStatuses.
    /// 
    callback_cancelled = 2,

    /// There was some deterministic error. (Note this is currently never used,
    /// but it will be relevant when it's possible to create a queue object.)
    /// 
    @"error" = 3,
};

///TODO
///
pub const RequestAdapterStatus = enum(u32) {
    __reserved0 = 0,
    

    /// TODO
    /// 
    success = 1,

    /// See @ref CallbackStatuses.
    /// 
    callback_cancelled = 2,

    /// TODO
    /// 
    unavailable = 3,

    /// TODO
    /// 
    @"error" = 4,
};

///TODO
///
pub const RequestDeviceStatus = enum(u32) {
    __reserved0 = 0,
    

    /// TODO
    /// 
    success = 1,

    /// See @ref CallbackStatuses.
    /// 
    callback_cancelled = 2,

    /// TODO
    /// 
    @"error" = 3,
};

///TODO
///
pub const SType = enum(u32) {
    __reserved0 = 0,
    

    /// TODO
    /// 
    shader_source_SPIRV = 1,

    /// TODO
    /// 
    shader_source_WGSL = 2,

    /// TODO
    /// 
    render_pass_max_draw_count = 3,

    /// TODO
    /// 
    surface_source_metal_layer = 4,

    /// TODO
    /// 
    surface_source_windows_HWND = 5,

    /// TODO
    /// 
    surface_source_xlib_window = 6,

    /// TODO
    /// 
    surface_source_wayland_surface = 7,

    /// TODO
    /// 
    surface_source_android_native_window = 8,

    /// TODO
    /// 
    surface_source_XCB_window = 9,

    /// TODO
    /// 
    surface_color_management = 10,

    /// TODO
    /// 
    request_adapter_WebXR_options = 11,

    /// TODO
    /// 
    texture_component_swizzle_descriptor = 12,

    /// TODO
    /// 
    external_texture_binding_layout = 13,

    /// TODO
    /// 
    external_texture_binding_entry = 14,
};

///TODO
///
pub const SamplerBindingType = enum(u32) {
    /// Indicates that this @ref WGPUSamplerBindingLayout member of
    /// its parent @ref WGPUBindGroupLayoutEntry is not used.
    /// (See also @ref SentinelValues.)
    /// 
    binding_not_used = 0,

    /// `1`. Indicates no value is passed for this argument. See @ref SentinelValues.
    /// 
    @"undefined" = 1,

    /// TODO
    /// 
    filtering = 2,

    /// TODO
    /// 
    non_filtering = 3,

    /// TODO
    /// 
    comparison = 4,
};

///Status code returned (synchronously) from many operations. Generally
///indicates an invalid input like an unknown enum value or @ref OutStructChainError.
///Read the function's documentation for specific error conditions.
///
pub const Status = enum(u32) {
    __reserved0 = 0,
    

    /// 
    success = 1,

    /// 
    @"error" = 2,
};

///TODO
///
pub const StencilOperation = enum(u32) {
    /// Indicates no value is passed for this argument. See @ref SentinelValues.
    @"undefined" = 0,

    /// TODO
    /// 
    keep = 1,

    /// TODO
    /// 
    zero = 2,

    /// TODO
    /// 
    replace = 3,

    /// TODO
    /// 
    invert = 4,

    /// TODO
    /// 
    increment_clamp = 5,

    /// TODO
    /// 
    decrement_clamp = 6,

    /// TODO
    /// 
    increment_wrap = 7,

    /// TODO
    /// 
    decrement_wrap = 8,
};

///TODO
///
pub const StorageTextureAccess = enum(u32) {
    /// Indicates that this @ref WGPUStorageTextureBindingLayout member of
    /// its parent @ref WGPUBindGroupLayoutEntry is not used.
    /// (See also @ref SentinelValues.)
    /// 
    binding_not_used = 0,

    /// `1`. Indicates no value is passed for this argument. See @ref SentinelValues.
    /// 
    @"undefined" = 1,

    /// TODO
    /// 
    write_only = 2,

    /// TODO
    /// 
    read_only = 3,

    /// TODO
    /// 
    read_write = 4,
};

///TODO
///
pub const StoreOp = enum(u32) {
    /// Indicates no value is passed for this argument. See @ref SentinelValues.
    @"undefined" = 0,

    /// TODO
    /// 
    store = 1,

    /// TODO
    /// 
    discard = 2,
};

///The status enum for @ref wgpuSurfaceGetCurrentTexture.
pub const SurfaceGetCurrentTextureStatus = enum(u32) {
    __reserved0 = 0,
    

    /// Yay! Everything is good and we can render this frame.
    success_optimal = 1,

    /// Still OK - the surface can present the frame, but in a suboptimal way. The surface may need reconfiguration.
    success_suboptimal = 2,

    /// Some operation timed out while trying to acquire the frame.
    timeout = 3,

    /// The surface is too different to be used, compared to when it was originally created.
    outdated = 4,

    /// The connection to whatever owns the surface was lost, or generally needs to be fully reinitialized.
    lost = 5,

    /// There was some deterministic error (for example, the surface is not configured, or there was an @ref OutStructChainError). Should produce @ref ImplementationDefinedLogging containing details.
    @"error" = 6,
};

///TODO
///
pub const TextureAspect = enum(u32) {
    /// Indicates no value is passed for this argument. See @ref SentinelValues.
    @"undefined" = 0,

    /// TODO
    /// 
    all = 1,

    /// TODO
    /// 
    stencil_only = 2,

    /// TODO
    /// 
    depth_only = 3,
};

///TODO
///
pub const TextureDimension = enum(u32) {
    /// Indicates no value is passed for this argument. See @ref SentinelValues.
    @"undefined" = 0,

    /// TODO
    /// 
    @"1D" = 1,

    /// TODO
    /// 
    @"2D" = 2,

    /// TODO
    /// 
    @"3D" = 3,
};

///TODO
///
pub const TextureFormat = enum(u32) {
    /// Indicates no value is passed for this argument. See @ref SentinelValues.
    @"undefined" = 0,

    /// TODO
    /// 
    R8_unorm = 1,

    /// TODO
    /// 
    R8_snorm = 2,

    /// TODO
    /// 
    R8_uint = 3,

    /// TODO
    /// 
    R8_sint = 4,

    /// TODO
    /// 
    R16_unorm = 5,

    /// TODO
    /// 
    R16_snorm = 6,

    /// TODO
    /// 
    R16_uint = 7,

    /// TODO
    /// 
    R16_sint = 8,

    /// TODO
    /// 
    R16_float = 9,

    /// TODO
    /// 
    RG8_unorm = 10,

    /// TODO
    /// 
    RG8_snorm = 11,

    /// TODO
    /// 
    RG8_uint = 12,

    /// TODO
    /// 
    RG8_sint = 13,

    /// TODO
    /// 
    R32_float = 14,

    /// TODO
    /// 
    R32_uint = 15,

    /// TODO
    /// 
    R32_sint = 16,

    /// TODO
    /// 
    RG16_unorm = 17,

    /// TODO
    /// 
    RG16_snorm = 18,

    /// TODO
    /// 
    RG16_uint = 19,

    /// TODO
    /// 
    RG16_sint = 20,

    /// TODO
    /// 
    RG16_float = 21,

    /// TODO
    /// 
    RGBA8_unorm = 22,

    /// TODO
    /// 
    RGBA8_unorm_srgb = 23,

    /// TODO
    /// 
    RGBA8_snorm = 24,

    /// TODO
    /// 
    RGBA8_uint = 25,

    /// TODO
    /// 
    RGBA8_sint = 26,

    /// TODO
    /// 
    BGRA8_unorm = 27,

    /// TODO
    /// 
    BGRA8_unorm_srgb = 28,

    /// TODO
    /// 
    RGB10_A2_uint = 29,

    /// TODO
    /// 
    RGB10_A2_unorm = 30,

    /// TODO
    /// 
    RG11_B10_ufloat = 31,

    /// TODO
    /// 
    RGB9_E5_ufloat = 32,

    /// TODO
    /// 
    RG32_float = 33,

    /// TODO
    /// 
    RG32_uint = 34,

    /// TODO
    /// 
    RG32_sint = 35,

    /// TODO
    /// 
    RGBA16_unorm = 36,

    /// TODO
    /// 
    RGBA16_snorm = 37,

    /// TODO
    /// 
    RGBA16_uint = 38,

    /// TODO
    /// 
    RGBA16_sint = 39,

    /// TODO
    /// 
    RGBA16_float = 40,

    /// TODO
    /// 
    RGBA32_float = 41,

    /// TODO
    /// 
    RGBA32_uint = 42,

    /// TODO
    /// 
    RGBA32_sint = 43,

    /// TODO
    /// 
    stencil8 = 44,

    /// TODO
    /// 
    depth16_unorm = 45,

    /// TODO
    /// 
    depth24_plus = 46,

    /// TODO
    /// 
    depth24_plus_stencil8 = 47,

    /// TODO
    /// 
    depth32_float = 48,

    /// TODO
    /// 
    depth32_float_stencil8 = 49,

    /// TODO
    /// 
    BC1_RGBA_unorm = 50,

    /// TODO
    /// 
    BC1_RGBA_unorm_srgb = 51,

    /// TODO
    /// 
    BC2_RGBA_unorm = 52,

    /// TODO
    /// 
    BC2_RGBA_unorm_srgb = 53,

    /// TODO
    /// 
    BC3_RGBA_unorm = 54,

    /// TODO
    /// 
    BC3_RGBA_unorm_srgb = 55,

    /// TODO
    /// 
    BC4_R_unorm = 56,

    /// TODO
    /// 
    BC4_R_snorm = 57,

    /// TODO
    /// 
    BC5_RG_unorm = 58,

    /// TODO
    /// 
    BC5_RG_snorm = 59,

    /// TODO
    /// 
    BC6H_RGB_ufloat = 60,

    /// TODO
    /// 
    BC6H_RGB_float = 61,

    /// TODO
    /// 
    BC7_RGBA_unorm = 62,

    /// TODO
    /// 
    BC7_RGBA_unorm_srgb = 63,

    /// TODO
    /// 
    ETC2_RGB8_unorm = 64,

    /// TODO
    /// 
    ETC2_RGB8_unorm_srgb = 65,

    /// TODO
    /// 
    ETC2_RGB8A1_unorm = 66,

    /// TODO
    /// 
    ETC2_RGB8A1_unorm_srgb = 67,

    /// TODO
    /// 
    ETC2_RGBA8_unorm = 68,

    /// TODO
    /// 
    ETC2_RGBA8_unorm_srgb = 69,

    /// TODO
    /// 
    EAC_R11_unorm = 70,

    /// TODO
    /// 
    EAC_R11_snorm = 71,

    /// TODO
    /// 
    EAC_RG11_unorm = 72,

    /// TODO
    /// 
    EAC_RG11_snorm = 73,

    /// TODO
    /// 
    ASTC_4x4_unorm = 74,

    /// TODO
    /// 
    ASTC_4x4_unorm_srgb = 75,

    /// TODO
    /// 
    ASTC_5x4_unorm = 76,

    /// TODO
    /// 
    ASTC_5x4_unorm_srgb = 77,

    /// TODO
    /// 
    ASTC_5x5_unorm = 78,

    /// TODO
    /// 
    ASTC_5x5_unorm_srgb = 79,

    /// TODO
    /// 
    ASTC_6x5_unorm = 80,

    /// TODO
    /// 
    ASTC_6x5_unorm_srgb = 81,

    /// TODO
    /// 
    ASTC_6x6_unorm = 82,

    /// TODO
    /// 
    ASTC_6x6_unorm_srgb = 83,

    /// TODO
    /// 
    ASTC_8x5_unorm = 84,

    /// TODO
    /// 
    ASTC_8x5_unorm_srgb = 85,

    /// TODO
    /// 
    ASTC_8x6_unorm = 86,

    /// TODO
    /// 
    ASTC_8x6_unorm_srgb = 87,

    /// TODO
    /// 
    ASTC_8x8_unorm = 88,

    /// TODO
    /// 
    ASTC_8x8_unorm_srgb = 89,

    /// TODO
    /// 
    ASTC_10x5_unorm = 90,

    /// TODO
    /// 
    ASTC_10x5_unorm_srgb = 91,

    /// TODO
    /// 
    ASTC_10x6_unorm = 92,

    /// TODO
    /// 
    ASTC_10x6_unorm_srgb = 93,

    /// TODO
    /// 
    ASTC_10x8_unorm = 94,

    /// TODO
    /// 
    ASTC_10x8_unorm_srgb = 95,

    /// TODO
    /// 
    ASTC_10x10_unorm = 96,

    /// TODO
    /// 
    ASTC_10x10_unorm_srgb = 97,

    /// TODO
    /// 
    ASTC_12x10_unorm = 98,

    /// TODO
    /// 
    ASTC_12x10_unorm_srgb = 99,

    /// TODO
    /// 
    ASTC_12x12_unorm = 100,

    /// TODO
    /// 
    ASTC_12x12_unorm_srgb = 101,
};

///TODO
///
pub const TextureSampleType = enum(u32) {
    /// Indicates that this @ref WGPUTextureBindingLayout member of
    /// its parent @ref WGPUBindGroupLayoutEntry is not used.
    /// (See also @ref SentinelValues.)
    /// 
    binding_not_used = 0,

    /// `1`. Indicates no value is passed for this argument. See @ref SentinelValues.
    /// 
    @"undefined" = 1,

    /// TODO
    /// 
    float = 2,

    /// TODO
    /// 
    unfilterable_float = 3,

    /// TODO
    /// 
    depth = 4,

    /// TODO
    /// 
    sint = 5,

    /// TODO
    /// 
    uint = 6,
};

///TODO
///
pub const TextureViewDimension = enum(u32) {
    /// Indicates no value is passed for this argument. See @ref SentinelValues.
    @"undefined" = 0,

    /// TODO
    /// 
    @"1D" = 1,

    /// TODO
    /// 
    @"2D" = 2,

    /// TODO
    /// 
    @"2D_array" = 3,

    /// TODO
    /// 
    cube = 4,

    /// TODO
    /// 
    cube_array = 5,

    /// TODO
    /// 
    @"3D" = 6,
};

///TODO
///
pub const ToneMappingMode = enum(u32) {
    __reserved0 = 0,
    

    /// TODO
    /// 
    standard = 1,

    /// TODO
    /// 
    extended = 2,
};

///TODO
///
pub const VertexFormat = enum(u32) {
    __reserved0 = 0,
    

    /// TODO
    /// 
    uint8 = 1,

    /// TODO
    /// 
    uint8x2 = 2,

    /// TODO
    /// 
    uint8x4 = 3,

    /// TODO
    /// 
    sint8 = 4,

    /// TODO
    /// 
    sint8x2 = 5,

    /// TODO
    /// 
    sint8x4 = 6,

    /// TODO
    /// 
    unorm8 = 7,

    /// TODO
    /// 
    unorm8x2 = 8,

    /// TODO
    /// 
    unorm8x4 = 9,

    /// TODO
    /// 
    snorm8 = 10,

    /// TODO
    /// 
    snorm8x2 = 11,

    /// TODO
    /// 
    snorm8x4 = 12,

    /// TODO
    /// 
    uint16 = 13,

    /// TODO
    /// 
    uint16x2 = 14,

    /// TODO
    /// 
    uint16x4 = 15,

    /// TODO
    /// 
    sint16 = 16,

    /// TODO
    /// 
    sint16x2 = 17,

    /// TODO
    /// 
    sint16x4 = 18,

    /// TODO
    /// 
    unorm16 = 19,

    /// TODO
    /// 
    unorm16x2 = 20,

    /// TODO
    /// 
    unorm16x4 = 21,

    /// TODO
    /// 
    snorm16 = 22,

    /// TODO
    /// 
    snorm16x2 = 23,

    /// TODO
    /// 
    snorm16x4 = 24,

    /// TODO
    /// 
    float16 = 25,

    /// TODO
    /// 
    float16x2 = 26,

    /// TODO
    /// 
    float16x4 = 27,

    /// TODO
    /// 
    float32 = 28,

    /// TODO
    /// 
    float32x2 = 29,

    /// TODO
    /// 
    float32x3 = 30,

    /// TODO
    /// 
    float32x4 = 31,

    /// TODO
    /// 
    uint32 = 32,

    /// TODO
    /// 
    uint32x2 = 33,

    /// TODO
    /// 
    uint32x3 = 34,

    /// TODO
    /// 
    uint32x4 = 35,

    /// TODO
    /// 
    sint32 = 36,

    /// TODO
    /// 
    sint32x2 = 37,

    /// TODO
    /// 
    sint32x3 = 38,

    /// TODO
    /// 
    sint32x4 = 39,

    /// TODO
    /// 
    unorm10__10__10__2 = 40,

    /// TODO
    /// 
    unorm8x4_B_G_R_A = 41,
};

///TODO
///
pub const VertexStepMode = enum(u32) {
    /// Indicates no value is passed for this argument. See @ref SentinelValues.
    @"undefined" = 0,

    /// TODO
    /// 
    vertex = 1,

    /// TODO
    /// 
    instance = 2,
};

///Status returned from a call to ::wgpuInstanceWaitAny.
pub const WaitStatus = enum(u32) {
    __reserved0 = 0,
    

    /// At least one WGPUFuture completed successfully.
    success = 1,

    /// The wait operation succeeded, but no WGPUFutures completed within the timeout.
    timed_out = 2,

    /// The call was invalid for some reason (see @ref Wait-Any).
    /// Should produce @ref ImplementationDefinedLogging containing details.
    /// 
    @"error" = 3,
};

///TODO
///
pub const WGSLLanguageFeatureName = enum(u32) {
    __reserved0 = 0,
    

    /// TODO
    /// 
    readonly_and_readwrite_storage_textures = 1,

    /// TODO
    /// 
    packed4x8_integer_dot_product = 2,

    /// TODO
    /// 
    unrestricted_pointer_parameters = 3,

    /// TODO
    /// 
    pointer_composite_access = 4,

    /// TODO
    /// 
    uniform_buffer_standard_layout = 5,

    /// TODO
    /// 
    subgroup_id = 6,
};

///TODO
///
pub const BufferUsage = enum(u32) {
    /// This function allows you to set multiple flags at once.
    /// Example:
    /// ```zig
    /// const flags: BufferUsage = .all(.{ .a, .b });
    /// ```
    pub fn all(values: []const @This()) @This() {
        var result: u32 = 0;
        for (values) |value| {
            result |= @intFromEnum(value);
        }
        return @enumFromInt(result);
    }
    
    /// This function allows you to set multiple flags at once.
    /// Example:
    /// ```zig
    /// const flags: BufferUsage = .a.plus(.b).plus(.c);
    ///```
    pub fn plus(lhs: @This(), rhs: @This()) @This() {
        return @enumFromInt(@intFromEnum(lhs) & @intFromEnum(rhs));
    }
};

///TODO
///
pub const ColorWriteMask = enum(u32) {
    /// This function allows you to set multiple flags at once.
    /// Example:
    /// ```zig
    /// const flags: ColorWriteMask = .all(.{ .a, .b });
    /// ```
    pub fn all(values: []const @This()) @This() {
        var result: u32 = 0;
        for (values) |value| {
            result |= @intFromEnum(value);
        }
        return @enumFromInt(result);
    }
    
    /// This function allows you to set multiple flags at once.
    /// Example:
    /// ```zig
    /// const flags: ColorWriteMask = .a.plus(.b).plus(.c);
    ///```
    pub fn plus(lhs: @This(), rhs: @This()) @This() {
        return @enumFromInt(@intFromEnum(lhs) & @intFromEnum(rhs));
    }
};

///TODO
///
pub const MapMode = enum(u32) {
    /// This function allows you to set multiple flags at once.
    /// Example:
    /// ```zig
    /// const flags: MapMode = .all(.{ .a, .b });
    /// ```
    pub fn all(values: []const @This()) @This() {
        var result: u32 = 0;
        for (values) |value| {
            result |= @intFromEnum(value);
        }
        return @enumFromInt(result);
    }
    
    /// This function allows you to set multiple flags at once.
    /// Example:
    /// ```zig
    /// const flags: MapMode = .a.plus(.b).plus(.c);
    ///```
    pub fn plus(lhs: @This(), rhs: @This()) @This() {
        return @enumFromInt(@intFromEnum(lhs) & @intFromEnum(rhs));
    }
};

///TODO
///
pub const ShaderStage = enum(u32) {
    /// This function allows you to set multiple flags at once.
    /// Example:
    /// ```zig
    /// const flags: ShaderStage = .all(.{ .a, .b });
    /// ```
    pub fn all(values: []const @This()) @This() {
        var result: u32 = 0;
        for (values) |value| {
            result |= @intFromEnum(value);
        }
        return @enumFromInt(result);
    }
    
    /// This function allows you to set multiple flags at once.
    /// Example:
    /// ```zig
    /// const flags: ShaderStage = .a.plus(.b).plus(.c);
    ///```
    pub fn plus(lhs: @This(), rhs: @This()) @This() {
        return @enumFromInt(@intFromEnum(lhs) & @intFromEnum(rhs));
    }
};

///TODO
///
pub const TextureUsage = enum(u32) {
    /// This function allows you to set multiple flags at once.
    /// Example:
    /// ```zig
    /// const flags: TextureUsage = .all(.{ .a, .b });
    /// ```
    pub fn all(values: []const @This()) @This() {
        var result: u32 = 0;
        for (values) |value| {
            result |= @intFromEnum(value);
        }
        return @enumFromInt(result);
    }
    
    /// This function allows you to set multiple flags at once.
    /// Example:
    /// ```zig
    /// const flags: TextureUsage = .a.plus(.b).plus(.c);
    ///```
    pub fn plus(lhs: @This(), rhs: @This()) @This() {
        return @enumFromInt(@intFromEnum(lhs) & @intFromEnum(rhs));
    }
};

