@group(0) @binding(0) var<uniform> screenSize: vec2<f32>;
struct Output {
     @builtin(position) pos: vec4<f32>,
     @location(0) screenSize: vec2<f32>,
};


fn sdfCircle(p: vec2<f32>, radius: f32) -> f32 {
    return length(p) - radius;
}

fn sdRoundedBox(p: vec2<f32>, b: vec2<f32>, r: vec4<f32>) -> f32 {
    var x = r.x;
    var y = r.y;
    x = select(r.z, r.x, p.x > 0.);
    y = select(r.w, r.y, p.x > 0.);
    x = select(y, x, p.y > 0.);
    let q = abs(p) - b + x;
    return min(max(q.x, q.y), 0.) + length(max(q, vec2f(0.))) - x;
}

@vertex 
fn vertex_main(
    @location(0) pos: vec2<f32>,
    @builtin(instance_index) instance: u32
) -> Output {
    var output: Output;
    output.pos = vec4(pos, 0, 1);
    output.screenSize = screenSize;
    return output;
}

@fragment
fn frag_main(@location(0) screenSize: vec2<f32>, @builtin(position)pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = ((pos.xy + 0.5) - screenSize) / (min(screenSize.x, screenSize.y));
    let d = sdfCircle(uv, 0.8);
    //let d = sdRoundedBox(p, vec2<f32>(.5,.5), vec4<f32>(0.2, 0.2, 0.2, 0.2));


    var col = vec3<f32>(1.0) - sign(d) * vec3<f32>(0.5, 0.5, 0.5);
    //col *= 1.0 - exp(-2.0 * abs(d));
    //col *= 0.8 + 0.2 * cos(120.0 * d);
    //col = mix(col, vec3<f32>(1.0), 1.0 - vec3<f32>(smoothstep(0.0, 0.01, abs(d))));
    return vec4(col, 0);
}
