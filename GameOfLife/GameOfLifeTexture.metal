#include <metal_stdlib>
using namespace metal;

// Kernel function to update the Game of Life grid
kernel void updateGameOfLife(texture2d<int, access::read_write> inputTexture [[texture(0)]],
                             texture2d<int, access::read_write> outputTexture [[texture(1)]],
                             uint2 gid [[thread_position_in_grid]]) {
    uint width = inputTexture.get_width();
    uint height = inputTexture.get_height();
    
    if (gid.x >= width || gid.y >= height) return;
    
    // Read the state of the current cell
    int currentState = inputTexture.read(gid).r;
    
    // Count live neighbors
    int liveNeighbors = 0;
    for (int dy = -1; dy <= 1; ++dy) {
        for (int dx = -1; dx <= 1; ++dx) {
            if (dx == 0 && dy == 0) continue; // Skip the cell itself
            uint2 neighborCoord = uint2((gid.x + dx + width) % width, (gid.y + dy + height) % height);
            liveNeighbors += inputTexture.read(neighborCoord).r;
        }
    }
    
    // Apply the rules of Conway's Game of Life
    int newState = (currentState > 0 && (liveNeighbors == 2 || liveNeighbors == 3)) ||
        (currentState == 0 && liveNeighbors == 3) ? 1 : 0;
    
    // Write the new state to the output texture
    outputTexture.write(newState, gid);
}

kernel void mapToGrayscale(texture2d<int, access::read> inputTexture [[texture(0)]],
                           texture2d<uint, access::write> outputTexture [[texture(1)]],
                           uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) return;

    outputTexture.write(inputTexture.read(gid).r * 255, gid);
}
