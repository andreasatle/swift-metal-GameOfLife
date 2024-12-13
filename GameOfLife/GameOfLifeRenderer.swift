import Metal
import MetalKit

/// A class responsible for rendering Conway's Game of Life using Metal.
///
/// The `GameOfLifeRenderer` manages the Metal compute pipeline and textures
/// to simulate and render the Game of Life grid. It uses a Metal compute shader
/// to perform the updates on the game grid efficiently on the GPU.
@Observable
class GameOfLifeRenderer {
    /// The Metal device used for GPU computations.
    private var device: MTLDevice!
    /// The command queue used to submit work to the GPU.
    private var commandQueue: MTLCommandQueue!
    /// The compute pipeline state for the Game of Life kernel.
    private var updateShader: MTLComputePipelineState!
    /// The image pipeline state for the Game of Life kernel.
    private var imageShader: MTLComputePipelineState!
    /// The first texture used for the game grid.
    private var texture: MTLTexture!
    /// The second texture used for the game grid.
    private var updatedTexture: MTLTexture!
    private var imageTexture: MTLTexture!
    /// A flag indicating which texture is currently being used as the source.
    private var isUsingTextureA = true
    /// The number of cells in the horizontal direction of the grid.
    private var gridX: Int = 512
    /// The number of cells in the vertical direction of the grid.
    private var gridY: Int = 512
    /// Storage for colorvalues 0 - black, 255 - white
    private var pixelData: [UInt8] = []
    
    /// Initializes the Metal device, pipeline, and textures for the game.
    ///
    /// - Parameters:
    ///   - gridX: The number of horizontal cells in the grid.
    ///   - gridY: The number of vertical cells in the grid.
    func initialize(gridX: Int, gridY: Int) {
        self.gridX = gridX
        self.gridY = gridY
        
        device = MTLCreateSystemDefaultDevice()
        commandQueue = device.makeCommandQueue()
        
        guard let library = device.makeDefaultLibrary(),
              let updateFunction = library.makeFunction(name: "updateGameOfLife"),
            let imageFunction = library.makeFunction(name: "mapToGrayscale")
        else {
            fatalError("Unable to create compute pipeline")
        }
        
        updateShader = try? device.makeComputePipelineState(function: updateFunction)
        imageShader = try? device.makeComputePipelineState(function: imageFunction)
        createTextures()
        resetGrid()
        
        // Initialize the image data once
        pixelData = [UInt8](repeating: 0, count: gridX*gridY)

    }
    
    /// Creates the textures used for the game grid.
    ///
    /// This sets up two textures, one for the current grid state and another
    /// for the next grid state, enabling efficient computation.
    private func createTextures() {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r8Sint, width: gridX, height: gridY, mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]

        let descriptor2 = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r8Uint, width: gridX, height: gridY, mipmapped: false
        )
        descriptor2.usage = [.shaderRead, .shaderWrite]

        texture = device.makeTexture(descriptor: descriptor)
        updatedTexture = device.makeTexture(descriptor: descriptor)
        imageTexture = device.makeTexture(descriptor: descriptor2)
    }
    
    /// Resets the game grid to a random initial state.
    ///
    /// The cells are initialized with random binary values (alive or dead).
    func resetGrid() {
        let randomGrid = (0..<(gridX * gridY)).map { _ in Int8.random(in: 0...1) }
        texture.replace(region: MTLRegionMake2D(0, 0, gridX, gridY), mipmapLevel: 0, withBytes: randomGrid, bytesPerRow: gridX)
    }
    
    /// Updates the game grid using the compute shader.
    ///
    /// This method swaps the textures and dispatches the compute shader to
    /// calculate the next state of the grid based on the current state.
    func updateGrid() {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else { return }
        
        computeEncoder.setComputePipelineState(updateShader)
        computeEncoder.setTexture(texture, index: 0)
        computeEncoder.setTexture(updatedTexture, index: 1)
        
        let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadGroups = MTLSize(width: (gridX + 15) / 16, height: (gridY + 15) / 16, depth: 1)
        
        computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        computeEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        swap(&texture, &updatedTexture)
    }
    
    /// Converts the current game grid texture to a `CGImage`.
    ///
    /// - Returns: A `CGImage` representation of the current game grid, or `nil` if conversion fails.
    func textureToImage() -> CGImage? {
        let width = texture.width
        let height = texture.height

        // Run the image shader
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else { return nil }

        computeEncoder.setComputePipelineState(imageShader)
        computeEncoder.setTexture(texture, index: 0)
        computeEncoder.setTexture(imageTexture, index: 1)

        let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadGroups = MTLSize(
            width: (width + threadGroupSize.width - 1) / threadGroupSize.width,
            height: (height + threadGroupSize.height - 1) / threadGroupSize.height,
            depth: 1
        )
        computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        computeEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        // Create a CGImage from the output texture
        imageTexture.getBytes(&pixelData, bytesPerRow: width, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)

        let colorSpace = CGColorSpaceCreateDeviceGray()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
        let provider = CGDataProvider(data: Data(pixelData) as CFData)

        return CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: width,
            space: colorSpace, bitmapInfo: bitmapInfo, provider: provider!,
            decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )
    }

}
