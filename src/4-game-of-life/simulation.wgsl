@group(0) @binding(0) var<uniform> grid: vec2<f32>;
@group(0) @binding(1) var<storage,read> cellStateIn: array<u32>;
@group(0) @binding(2) var<storage, read_write> cellStateOut: array<u32>;

fn cellIndex(cell: vec2<u32>) -> u32 {
    return (cell.y % u32(grid.y)) * u32(grid.x) + (cell.x % u32(grid.x));
}

fn cellActive(x: u32, y: u32) -> u32 {
    return cellStateIn[cellIndex(vec2(x, y))];
}

@compute @workgroup_size (8,8)
fn main(@builtin(global_invocation_id) cell: vec3<u32>) {
    let top = cell.y + 1;
    let right = cell.x + 1;
    let bottom = cell.y-1;
    let left = cell.x-1;
    let activeNeighbors = cellActive(cell.x, top) + cellActive(right, top) + cellActive(right, cell.y) + cellActive(right, bottom) + cellActive(cell.x, bottom) + cellActive(left, bottom) + cellActive(left, cell.y) + cellActive(left, top);


    let i = cellIndex(cell.xy);

      // Conway's game of life rules:
    switch activeNeighbors {
        case 2: {
            cellStateOut[i] = cellStateIn[i];
        }
        case 3: {
            cellStateOut[i] = 1;
        }
        default: {
            cellStateOut[i] = 0;
        }
      }
}
