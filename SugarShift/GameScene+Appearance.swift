import SpriteKit

extension GameScene {
    /// Apply only the two background preferences. No board rebuild, animation
    /// cancellation, HUD text fading or footer change is needed for a slider drag.
    func applyGameplayTransparency() {
        let boardOpacity = CGFloat(1 - Persistence.boardTransparency)
        worldNode?.childNode(withName: "boardBackdrop")?.alpha = boardOpacity
        worldNode?.childNode(withName: "tileCornerFillers")?.alpha = boardOpacity
        for row in nodes {
            for node in row {
                node?.childNode(withName: "body")?.childNode(withName: "tileBackground")?.alpha = boardOpacity
            }
        }

        let cardOpacity = CGFloat(1 - Persistence.levelCardTransparency)
        headerCard?.childNode(withName: "levelCardBackground")?.alpha = cardOpacity
        headerCard?.childNode(withName: "movesInset")?.childNode(withName: "movesBackground")?.alpha = cardOpacity
    }
}
