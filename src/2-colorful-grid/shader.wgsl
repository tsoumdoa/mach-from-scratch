struct VertexInput {
    @location(0) pos: vec2<f32>,
    @location(1) color: vec3<f32>,
    @builtin(instance_index) instance: u32
};
struct VertexOutput {
     @builtin(position) pos: vec4<f32>,
     @location(0) color: vec3<f32>,
     @location(1) cell: vec2<f32>,
};

@group(0) @binding(0) var<uniform> grid: vec2<f32>;
@vertex 
fn vertex_main(
    input: VertexInput
) -> VertexOutput {
    var output: VertexOutput;

    let cell = vec2<f32>(
        f32(input.instance) % grid.x,
        floor(f32(input.instance) / grid.x)
    );
    let cellOffset = cell / grid * 2;
    let gridPos = (input.pos + 1) / grid - 1 + cellOffset;

    output.pos = vec4(gridPos, 0, 1);
    output.color = input.color;
    output.cell = cell;
    return output;
}

@fragment
fn frag_main(input:VertexOutput) -> @location(0) vec4<f32> {
    let c = input.cell/grid;

    return vec4(c, 1-c.x, 1);
}
