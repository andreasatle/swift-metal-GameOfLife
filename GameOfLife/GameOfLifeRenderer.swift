import Metal
import MetalKit

/// A class responsible for rendering Conway's Game of Life using Metal.
@Observable
class GameOfLifeRenderer {
    // MARK: - Metal Properties
    private var device: MTLDevice!
    private var commandQueue: MTLCommandQueue!
    private var updateShader: MTLComputePipelineState!
    private var imageShader: MTLComputePipelineState!
    private var texture: MTLTexture!
    private var updatedTexture: MTLTexture!
    private var imageTexture: MTLTexture!

    // MARK: - Grid Properties
    private var gridX: Int = 512
    private var gridY: Int = 512
    private var isUsingTextureA = true
    private var pixelData: [UInt8] = []

    // MARK: - Initialization

    /// Initializes the renderer with the specified grid dimensions.
    func initialize(gridX: Int, gridY: Int) {
        self.gridX = gridX
        self.gridY = gridY

        setupMetal()
        createTextures()
        resetGrid()
        pixelData = [UInt8](repeating: 0, count: gridX * gridY)
    }

    // MARK: - Setup Methods

    /// Sets up the Metal device, command queue, and shaders.
    private func setupMetal() {
        device = MTLCreateSystemDefaultDevice()
        commandQueue = device.makeCommandQueue()

        guard let library = device.makeDefaultLibrary(),
              let updateFunction = library.makeFunction(name: "updateGameOfLife"),
              let imageFunction = library.makeFunction(name: "mapToGrayscale")
        else {
            fatalError("Unable to create Metal pipeline states.")
        }

        updateShader = try? device.makeComputePipelineState(function: updateFunction)
        imageShader = try? device.makeComputePipelineState(function: imageFunction)
    }

    /// Creates textures for the game grid and the grayscale output.
    private func createTextures() {
        let gridDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r8Sint, width: gridX, height: gridY, mipmapped: false
        )
        gridDescriptor.usage = [.shaderRead, .shaderWrite]

        let imageDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r8Uint, width: gridX, height: gridY, mipmapped: false
        )
        imageDescriptor.usage = [.shaderRead, .shaderWrite]

        texture = device.makeTexture(descriptor: gridDescriptor)
        updatedTexture = device.makeTexture(descriptor: gridDescriptor)
        imageTexture = device.makeTexture(descriptor: imageDescriptor)
    }

    /// Resets the grid to a random binary state.
    func resetGrid() {
        let randomGrid = (0..<(gridX * gridY)).map { _ in Int8.random(in: 0...1) }
        texture.replace(region: MTLRegionMake2D(0, 0, gridX, gridY), mipmapLevel: 0, withBytes: randomGrid, bytesPerRow: gridX)
    }

    // MARK: - Compute and Render Methods

    /// Updates the game grid by applying the compute shader and swapping textures.
    func updateGrid() {
        executeComputeShader { encoder in
            encoder.setComputePipelineState(updateShader)
            encoder.setTexture(texture, index: 0)
            encoder.setTexture(updatedTexture, index: 1)
        }
        swap(&texture, &updatedTexture)
    }

    /// Converts the current game grid texture to a grayscale `CGImage`.
    func textureToImage() -> CGImage? {
        executeComputeShader { encoder in
            encoder.setComputePipelineState(imageShader)
            encoder.setTexture(texture, index: 0)
            encoder.setTexture(imageTexture, index: 1)
        }
        return createGrayScaleImage(from: imageTexture)
    }

    // MARK: - Helper Methods

    /// Executes a compute shader with the specified textures.
    private func executeComputeShader(configure: (MTLComputeCommandEncoder) -> Void) {
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

    /// Creates a grayscale `CGImage` from a texture.
    private func createGrayScaleImage(from texture: MTLTexture) -> CGImage? {
        texture.getBytes(&pixelData, bytesPerRow: gridX, from: MTLRegionMake2D(0, 0, gridX, gridY), mipmapLevel: 0)

        let colorSpace = CGColorSpaceCreateDeviceGray()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
        guard let provider = CGDataProvider(data: Data(pixelData) as CFData) else { return nil }

        return CGImage(
            width: gridX, height: gridY, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: gridX,
            space: colorSpace, bitmapInfo: bitmapInfo, provider: provider,
            decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )
    }
}
