import MetalKit

/// A class responsible for rendering Conway's Game of Life using Metal.
@Observable
class GameOfLifeRenderer {
    private var shader: ShaderLib!
    private var textures: GameOfLifeTextures!

    private var gridX: Int = 512
    private var gridY: Int = 512
    private var isUsingTextureA = true
    private var pixelData: [UInt8] = []

    /// Initializes the renderer with the specified grid dimensions.
    func initialize(gridX: Int = 512, gridY: Int = 512) {
        self.gridX = gridX
        self.gridY = gridY

        shader = ShaderLib()
        textures = GameOfLifeTextures(gridX: gridX, gridY: gridY, shader: shader)
        resetGrid()
        pixelData = [UInt8](repeating: 0, count: gridX * gridY)
    }


    /// Resets the grid to a random binary state.
    func resetGrid() {
        textures.resetGame()
    }

    /// Updates the game grid by applying the compute shader and swapping textures.
    func updateGrid() {
        shader.execute(gridX, gridY) { encoder in
            encoder.setComputePipelineState(shader.updateGameOfLife)
            encoder.setTexture(textures.game, index: 0)
            encoder.setTexture(textures.updated, index: 1)
        }
        swap(&textures.game, &textures.updated)
    }

    /// Converts the current game grid texture to a grayscale `CGImage`.
    func textureToImage() -> CGImage? {
        shader.execute(gridX, gridY) { encoder in
            encoder.setComputePipelineState(shader.mapToGrayscale)
            encoder.setTexture(textures.game, index: 0)
            encoder.setTexture(textures.image, index: 1)
        }
        return createGrayScaleImage(from: textures.image)
    }

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
