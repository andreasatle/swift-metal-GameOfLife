import Metal

/// A utility class to manage Metal shaders and compute pipeline states.
class ShaderLib {
    // The Metal device representing the GPU.
    var device: MTLDevice!
    // The command queue used to schedule Metal commands for execution on the GPU.
    private var commandQueue: MTLCommandQueue!
    // Compute pipeline state for the "updateGameOfLife" Metal shader.
    var updateGameOfLife: MTLComputePipelineState!
    // Compute pipeline state for the "mapToGrayscale" Metal shader.
    var mapToGrayscale: MTLComputePipelineState!

    /// Initializes the ShaderLib by creating the Metal device, command queue,
    /// and compute pipeline states for the shaders.
    init() {
        // Create the default Metal device (usually the GPU).
        device = MTLCreateSystemDefaultDevice()
        // Create a command queue for scheduling GPU commands.
        commandQueue = device.makeCommandQueue()

        // Load the default shader library and retrieve the required shader functions.
        guard let library = device.makeDefaultLibrary(),
              let updateGameOfLife_ = library.makeFunction(name: "updateGameOfLife"),
              let mapToGrayscale_ = library.makeFunction(name: "mapToGrayscale")
        else {
            // If the shaders cannot be loaded, terminate with an error.
            fatalError("Unable to create Metal pipeline states.")
        }

        // Create compute pipeline states for the loaded shader functions.
        updateGameOfLife = try? device.makeComputePipelineState(function: updateGameOfLife_)
        mapToGrayscale = try? device.makeComputePipelineState(function: mapToGrayscale_)
    }

    /// Executes a compute shader with the specified grid dimensions and a configuration block.
    /// - Parameters:
    ///   - gridX: The number of horizontal cells in the grid.
    ///   - gridY: The number of vertical cells in the grid.
    ///   - configure: A closure to configure the compute command encoder with specific settings.
    func execute(_ gridX: Int, _ gridY: Int, configure: (MTLComputeCommandEncoder) -> Void) {
        // Create a command buffer to hold GPU commands.
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              // Create a compute command encoder for encoding compute commands.
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else { return }

        // Allow the caller to configure the compute encoder (e.g., set textures and pipelines).
        configure(computeEncoder)

        // Define the size of the thread groups (e.g., 16x16 threads per group).
        let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
        // Calculate the number of thread groups needed to cover the entire grid.
        let threadGroups = MTLSize(width: (gridX + 15) / 16, height: (gridY + 15) / 16, depth: 1)

        // Dispatch the compute shader with the specified thread groups and thread group size.
        computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        // End the encoding of the compute commands.
        computeEncoder.endEncoding()
        // Commit the command buffer to execute the commands on the GPU.
        commandBuffer.commit()
        // Wait for the command buffer to complete execution before proceeding.
        commandBuffer.waitUntilCompleted()
    }
}
