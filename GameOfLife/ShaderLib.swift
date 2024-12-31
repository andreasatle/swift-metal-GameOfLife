import Metal

class ShaderLib {
    var device: MTLDevice!
    private var commandQueue: MTLCommandQueue!
    var updateGameOfLife: MTLComputePipelineState!
    var mapToGrayscale: MTLComputePipelineState!


    init() {
        device = MTLCreateSystemDefaultDevice()
        commandQueue = device.makeCommandQueue()

        guard let library = device.makeDefaultLibrary(),
              let updateGameOfLife_ = library.makeFunction(name: "updateGameOfLife"),
              let mapToGrayscale_ = library.makeFunction(name: "mapToGrayscale")
        else {
            fatalError("Unable to create Metal pipeline states.")
        }

        updateGameOfLife = try? device.makeComputePipelineState(function: updateGameOfLife_)
        mapToGrayscale = try? device.makeComputePipelineState(function: mapToGrayscale_)
    }

    /// Executes a compute shader with the specified textures.
    func execute(_ gridX: Int, _ gridY: Int, configure: (MTLComputeCommandEncoder) -> Void) {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else { return }

        configure(computeEncoder)

        let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadGroups = MTLSize(width: (gridX + 15) / 16, height: (gridY + 15) / 16, depth: 1)

        computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        computeEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }

}
