import AppKit
import SpriteKit

/// A physical, throwable on-screen object (the cable tie, to start) that
/// Ramona can play with. Wraps the sprite node plus the extra state a toy
/// carries that the cat doesn't - its own independent surface (see
/// FloorTracking.Surface) and hold/rest flags - since CatScene's existing
/// per-cat state (currentSurface, isDragging, ...) is specifically hers.
final class ToyNode {
    let item: ItemDefinition
    let node: SKSpriteNode
    /// Independent of the cat's currentSurface - reused via the same
    /// FloorTracking.groundBounds/nextSurface pure functions, just with its
    /// own value, so a thrown toy can land somewhere the cat isn't and falls
    /// on its own if that surface later disappears. Known limitation: the
    /// live window tracker only ever reports the single frontmost window,
    /// so a toy resting on some other (non-frontmost) window has no way to
    /// react if THAT window moves or closes - same single-window scope the
    /// rest of the app already has.
    var surface: Surface
    /// True while the user is actively dragging it - position is pinned
    /// directly (bypassing physics), the same way CatScene.setHeld pins the
    /// cat, so physics doesn't fight the cursor.
    var isHeld = false
    /// True once the toy has settled onto its surface's ground line and
    /// isn't currently airborne. While resting, its position is pinned to
    /// the ground line every frame (see CatScene.updateToyGroundClamp) so it
    /// stays glued to a moving surface (a dragged window, the Dock
    /// appearing/hiding) the same way the cat's own re-settle does -
    /// gravity is switched off so it doesn't need fighting every frame.
    var isResting = true

    init(item: ItemDefinition, at position: CGPoint, surface: Surface) {
        self.item = item
        self.surface = surface

        let texture = Self.texture(for: item.id)
        let node = SKSpriteNode(texture: texture)
        node.anchorPoint = CGPoint(x: 0.5, y: 0)
        node.position = position
        // Always in front of the cat (z-order) - simplest reading for a
        // small object she's actively engaging with, not worth the extra
        // complexity of depth-sorting by relative position.
        node.zPosition = 10

        let body = SKPhysicsBody(rectangleOf: node.size)
        body.affectedByGravity = false // starts resting - see isResting
        // Live playtesting found the first pass (4, plus -900 gravity) felt
        // heavy overall, not just a strong fall - eased alongside gravity.
        body.linearDamping = 2
        body.restitution = 0.15
        body.allowsRotation = false // keep it upright; no rotated art frames
        node.physicsBody = body

        self.node = node
    }

    /// Loads Resources/Sprites/<itemID>.png the same way CatSprites.sheet
    /// loads the cat's sheet - via CGImageSource rather than NSImage, so the
    /// texture is exactly the file's pixel size with no Retina @2x
    /// reinterpretation, and `.nearest` filtering keeps pixel art crisp.
    /// Only cable_tie has art today; other toy items stay on the older
    /// instant-restore path (see AppDelegate.offerToy) until they do.
    private static func texture(for itemID: String) -> SKTexture {
        guard let url = Bundle.module.url(forResource: itemID, withExtension: "png", subdirectory: "Sprites"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cg = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            fatalError("Missing or unreadable bundled resource Sprites/\(itemID).png")
        }
        let texture = SKTexture(cgImage: cg)
        texture.filteringMode = .nearest
        return texture
    }
}
