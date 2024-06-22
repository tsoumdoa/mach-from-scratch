@group(0) @binding(0) var<uniform> screenSize: vec2<f32>;

struct VertexInput {
    @location(0) position: vec3<f32>,
    @location(1) normal: vec3<f32>,
    @builtin(vertex_index) vertex_index: u32,
};

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) normal: vec3<f32>,
    @location(1) color: vec3<f32>,
};

@vertex 
fn vertex_main(in: VertexInput) -> VertexOutput {
    var out: VertexOutput;

    let vertexSize: u32 = 128 * 2;
    let repeat = 100;

    // let remainder = in.vertex_index % vertexSize;
    let index = in.vertex_index / vertexSize;

    let color = vec3<f32>( f32(index)/ 25);

    let uv = ((in.position.xy + 0.5) - screenSize) / (min(screenSize.x, screenSize.y));
    out.position = vec4<f32>(in.position / vec3(uv, 1), 1.0) ;
    out.normal = in.normal;
    out.color = color;
    return out;
}

struct FragmentOutput {
    @location(0) pixel_color: vec4<f32>
};

@fragment
fn frag_main(in: VertexOutput) -> FragmentOutput {
    var out: FragmentOutput;
    out.pixel_color = vec4<f32>(in.color, 1.0);
    return out;
}
