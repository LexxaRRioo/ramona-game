import AppKit
import SpriteKit

/// One named piece of animation: an ordered list of frame textures, how long
/// each frame holds, and whether it repeats. A single texture with `loops`
/// irrelevant is a static pose.
struct CatClip {
    let textures: [SKTexture]
    let timePerFrame: TimeInterval
    let loops: Bool

    var isStatic: Bool { textures.count <= 1 }
}

/// Slices the flat Ramona sheet into the named animations the behaviour engine
/// asks for. The sheet is one 896×4608 image laid out as a 14×72 grid of 64px
/// cells; frame `(row, col)` lives at pixel `(col*64, row*64)` counting from the
/// top-left. The whole sheet is uploaded once as a parent SKTexture and every
/// frame is a sub-rectangle of it, so there's a single GPU texture behind the
/// entire cat. Row/column choices here are the "sprite contract" from plan.md -
/// a second cat is a different sheet with the same rows filled in.
enum CatSprites {
    static let cols = 14
    static let rows = 72
    /// Pixels below the paws inside each 64px cell for the walk/sit poses: the
    /// art's feet sit at y≈47, leaving 16px of empty cell beneath them. Placing
    /// the sprite node's anchor here drops her feet exactly onto the ground line.
    static let footAnchorY: CGFloat = 0.25

    /// The full sheet, uploaded once. `.nearest` keeps the pixels crisp instead
    /// of blurring them when the scene scales. Loaded via CGImageSource rather
    /// than `NSImage` so the texture is exactly 896×4608 with no Retina @2x
    /// reinterpretation of the file.
    static let sheet: SKTexture = {
        guard let url = Bundle.module.url(forResource: "ramona_sheet", withExtension: "png", subdirectory: "Sprites"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cg = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            fatalError("Missing or unreadable bundled resource Sprites/ramona_sheet.png")
        }
        let texture = SKTexture(cgImage: cg)
        texture.filteringMode = .nearest
        return texture
    }()

    /// SpriteKit texture rects are normalized 0...1 with the origin at the
    /// bottom-left, but the sheet is authored top-left, so row `r` flips to
    /// `y = 1 - (r+1)/rows`.
    static func frame(row: Int, col: Int) -> SKTexture {
        let w = 1.0 / CGFloat(cols)
        let h = 1.0 / CGFloat(rows)
        let rect = CGRect(x: CGFloat(col) * w, y: 1.0 - CGFloat(row + 1) * h, width: w, height: h)
        let texture = SKTexture(rect: rect, in: sheet)
        texture.filteringMode = .nearest
        return texture
    }

    private static func frames(row: Int, cols columns: Range<Int>) -> [SKTexture] {
        columns.map { frame(row: row, col: $0) }
    }

    // MARK: - Named clips (verified against the recolored sheet)

    /// Faces left; native art, not a mirror, so her one white leg stays correct.
    static let walkLeft = CatClip(textures: frames(row: 4, cols: 0..<6), timePerFrame: 0.11, loops: true)
    /// Faces right; the sheet ships this as its own row rather than a flip.
    static let walkRight = CatClip(textures: frames(row: 5, cols: 0..<6), timePerFrame: 0.11, loops: true)
    /// Front-facing sit-down settle - plays once as she comes to rest, then
    /// hands off to sitIdle's breathing loop (both are the same front-sit pose
    /// family, so they connect without a pop).
    static let sitDown = CatClip(textures: frames(row: 43, cols: 0..<7), timePerFrame: 0.09, loops: false)
    /// Front-facing sitting idle - a gentle breathing loop, what she does when
    /// she's just hanging out and not walking anywhere.
    static let sitIdle = CatClip(textures: frames(row: 19, cols: 0..<5), timePerFrame: 0.28, loops: true)
    /// Lie-down-and-curl transition (row 6, cols 0–9: loaf → flatten → curl;
    /// cols 10–13 are a run cycle sharing the row, excluded) - plays once as
    /// she settles down to sleep.
    static let lieDown = CatClip(textures: frames(row: 6, cols: 0..<10), timePerFrame: 0.10, loops: false)
    /// Slow breathing inside the exact curl lieDown ends on (same row 6, cols
    /// 8–9) so the sleep loop continues without a pop. A tight curl reads as
    /// asleep, unlike the head-up loaf rows.
    static let sleep = CatClip(textures: frames(row: 6, cols: 8..<10), timePerFrame: 0.9, loops: true)
}
