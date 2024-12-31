import MetalKit

/// A class responsible for rendering Conway's Game of Life using Metal.
@Observable
class GameOfLifeRenderer {
    // MARK: - Metal Properties
    private var shader: ShaderLib!
    private var gameTexture: MTLTexture!
    private var updatedTexture: MTLTexture!
    private var imageTexture: MTLTexture!

    // MARK: - Grid Properties
    private var gridX: Int = 512
    private var gridY: Int = 512
    private var isUsingTextureA = true
    private var pixelData: [UInt8] = []

    // MARK: - Initialization

    /// Initializes the renderer with the specified grid dimensions.
    func initialize(gridX: Int = 512, gridY: Int = 512) {
        self.gridX = gridX
        self.gridY = gridY

        //setupMetal()
        shader = ShaderLib()
        createTextures()
        resetGrid()
        pixelData = [UInt8](repeating: 0, count: gridX * gridY)
    }

    // MARK: - Setup Methods

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

        gameTexture = shader.device.makeTexture(descriptor: gridDescriptor)
        updatedTexture = shader.device.makeTexture(descriptor: gridDescriptor)
        imageTexture = shader.device.makeTexture(descriptor: imageDescriptor)
    }


    // MARK: - Compute and Render Methods

    /// Resets the grid to a random binary state.
    func resetGrid() {
        let randomGrid = (0..<(gridX * gridY)).map { _ in Int8.random(in: 0...1) }
        gameTexture.replace(region: MTLRegionMake2D(0, 0, gridX, gridY), mipmapLevel: 0, withBytes: randomGrid, bytesPerRow: gridX)
    }

    /// Updates the game grid by applying the compute shader and swapping textures.
    func updateGrid() {
        shader.execute(gridX, gridY) { encoder in
            encoder.setComputePipelineState(shader.updateGameOfLife)
            encoder.setTexture(gameTexture, index: 0)
            encoder.setTexture(updatedTexture, index: 1)
        }
        swap(&gameTexture, &updatedTexture)
    }

    /// Converts the current game grid texture to a grayscale `CGImage`.
    func textureToImage() -> CGImage? {
        shader.execute(gridX, gridY) { encoder in
            encoder.setComputePipelineState(shader.mapToGrayscale)
            encoder.setTexture(gameTexture, index: 0)
            encoder.setTexture(imageTexture, index: 1)
        }
        return createGrayScaleImage(from: imageTexture)
    }

    // MARK: - Helper Methods


    /// Creates a grayscale `CGImage` from a texture.
    private func createGrayScaleImage(from texture: MTLTexture) -> CGImage? {
        // Avoid allocating pixelData every time by making it class variable
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
