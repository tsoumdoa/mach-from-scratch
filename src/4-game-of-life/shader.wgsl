@group(0) @binding(0) var<uniform> grid: vec2<f32>;
@group(0) @binding(1) var<storage,read> cellState: array<u32>; 
struct Output {
     @builtin(position) pos: vec4<f32>,
     @location(0) color: vec3<f32>,
};

@vertex 
fn vertex_main(
    @location(0) pos: vec2<f32>,
    @location(1) color: vec3<f32>,
    @builtin(instance_index) instance: u32
) -> Output {
    var output: Output;

    let cell = vec2f(
        f32(instance) % grid.x,
        floor(f32(instance) / grid.x)
    );
    let state = f32(cellState[instance]);
    let cellOffset = cell / grid * 2;
    let gridPos = (pos * state + 1) / grid - 1 + cellOffset;

    output.pos = vec4(gridPos, 0, 1);
    output.color = color;
    return output;
}

@fragment
fn frag_main(@location(0) color: vec3<f32>) -> @location(0) vec4<f32> {
    return vec4(1, 1, 1, 1);
}
