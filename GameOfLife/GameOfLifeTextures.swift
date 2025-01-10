//
//  GameOfLifeTextures.swift
//  GameOfLife
//
//  Created by Andreas Atle on 12/31/24.
//
import MetalKit

class GameOfLifeTextures {
    let gridX: Int
    let gridY: Int

    var game: MTLTexture!
    var updated: MTLTexture!
    var image: MTLTexture!
    
    init(gridX: Int, gridY: Int, shader: ShaderLib) {
        self.gridX = gridX
        self.gridY = gridY
        
        let gridDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r8Sint, width: gridX, height: gridY, mipmapped: false
        )
        gridDescriptor.usage = [.shaderRead, .shaderWrite]

        let imageDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r8Uint, width: gridX, height: gridY, mipmapped: false
        )
        imageDescriptor.usage = [.shaderRead, .shaderWrite]

        game = shader.device.makeTexture(descriptor: gridDescriptor)
        updated = shader.device.makeTexture(descriptor: gridDescriptor)
        image = shader.device.makeTexture(descriptor: imageDescriptor)
    }
    
    func resetGame() {
        let randomGrid = (0..<(gridX * gridY)).map { _ in Int8.random(in: 0...1) }
        game.replace(region: MTLRegionMake2D(0, 0, gridX, gridY), mipmapLevel: 0, withBytes: randomGrid, bytesPerRow: gridX)
    }
}
