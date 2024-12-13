import SwiftUI

/// A SwiftUI view for simulating and visualizing Conway's Game of Life.
///
/// The `GameOfLifeView` displays a grid representing the game state, which updates
/// dynamically according to the rules of Conway's Game of Life. It allows the user
/// to start, pause, and reset the simulation.
///
/// The game state is managed using a `GameOfLifeRenderer`, and the grid is rendered
/// as a texture (`CGImage`) updated on a regular interval using a timer.
struct GameOfLifeView: View {
    /// The width of the game board in points.
    let width: CGFloat
    /// The height of the game board in points.
    let height: CGFloat
    /// The number of horizontal cells in the game grid.
    let gridX: Int
    /// The number of vertical cells in the game grid.
    let gridY: Int

    /// The renderer responsible for managing the game state and generating the texture.
    @State private var gameRenderer = GameOfLifeRenderer()
    /// The texture representing the current game grid as an image.
    @State private var gameTextureImage: CGImage?
    /// A flag indicating whether the game simulation is running.
    @State private var isRunning = false

    /// A timer that triggers game updates at regular intervals (every 0.01 seconds).
    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    /// The body of the view, containing the game board and control buttons.
    var body: some View {
        VStack {
            gameBoard
                .frame(width: width, height: height)
                .border(Color.gray)

            controls
        }
        .padding()
        .onAppear(perform: setupGame)
        .onReceive(timer) { _ in updateGame() }
    }

    /// A computed property representing the game board.
    /// Displays the game grid as an image or a placeholder text if the texture is unavailable.
    private var gameBoard: some View {
        Group {
            if let image = gameTextureImage {
                Image(decorative: image, scale: 1.0, orientation: .up)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .colorMultiply(.yellow)
            } else {
                Text("Texture not available")
            }
        }
    }

    /// A computed property representing the control buttons.
    /// Provides buttons to start/pause the simulation and reset the game grid.
    private var controls: some View {
        HStack {
            Button(action: toggleRunning) {
                Text(isRunning ? "Pause" : "Start")
            }
            .padding()

            Button(action: resetGame) {
                Text("Reset")
            }
            .padding()
        }
    }

    /// Sets up the game by initializing the grid and rendering the initial texture.
    private func setupGame() {
        gameRenderer.initialize(gridX: gridX, gridY: gridY)
        renderTexture()
    }

    /// Updates the game state and renders the updated texture.
    /// This is triggered by the timer when the simulation is running.
    private func updateGame() {
        guard isRunning else { return }
        gameRenderer.updateGrid()
        renderTexture()
    }

    /// Toggles the running state of the simulation.
    private func toggleRunning() {
        isRunning.toggle()
    }

    /// Resets the game grid to its initial state and re-renders the texture.
    private func resetGame() {
        gameRenderer.resetGrid()
        renderTexture()
    }

    /// Renders the game grid as a texture and updates the `gameTextureImage` property.
    private func renderTexture() {
        gameTextureImage = gameRenderer.textureToImage()
    }
}
