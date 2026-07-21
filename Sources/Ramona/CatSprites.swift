import AppKit
import SpriteKit

/// One named piece of animation: an ordered list of frame textures, how long
/// each frame holds, and whether it repeats. A single texture with `loops`
/// irrelevant is a static pose.
struct CatClip {
    let textures: [SKTexture]
    let timePerFrame: TimeInterval
    let loops: Bool
    /// Per-frame measured ground-contact anchor, parallel to `textures`. nil
    /// (the common case, or a nil element within a non-nil array) uses
    /// CatSprites.footAnchorY - i.e. no correction - for that frame. Only
    /// frames whose pose occupies a different vertical slice of the 64px
    /// cell than the walk/sit baseline need an explicit value - e.g.
    /// lieDown, where she progressively curls up and occupies less cell
    /// height, so anchoring at the walk/sit fraction left a growing gap
    /// under her ("floating" instead of settling onto the surface); or the
    /// run cycle's single mid-leap frame, whose paws lift briefly above the
    /// baseline while every other frame in that same clip sits right at it.
    let groundAnchors: [CGFloat?]?
    /// Extra hold, after playing through once, before a looping clip repeats
    /// - a beat of stillness between cycles instead of an unbroken loop. 0
    /// (the default) repeats immediately.
    let loopPause: TimeInterval

    init(textures: [SKTexture], timePerFrame: TimeInterval, loops: Bool, groundAnchors: [CGFloat?]? = nil, loopPause: TimeInterval = 0) {
        self.textures = textures
        self.timePerFrame = timePerFrame
        self.loops = loops
        self.groundAnchors = groundAnchors
        self.loopPause = loopPause
    }

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
    /// Front-facing settle pose, played once as she comes to rest before
    /// handing off to sitIdle's breathing loop (both are the same front-sit
    /// pose family, so they connect without a pop). Per the pack's labeled
    /// reference sheet this is actually "Yawn (sit, front)", not a sit-down
    /// motion - she's sitting still throughout and just yawns - but it reads
    /// fine as a settle-in beat, so it's kept for that role.
    static let sitDown = CatClip(textures: frames(row: 43, cols: 0..<7), timePerFrame: 0.09, loops: false)
    /// Front-facing sitting idle - a gentle breathing loop, what she does when
    /// she's just hanging out and not walking anywhere.
    static let sitIdle = CatClip(textures: frames(row: 19, cols: 0..<5), timePerFrame: 0.28, loops: true)
    /// Side-facing sit statics (row 0, cols 2/3 - "Sit (left)"/"Sit (right)"
    /// on the reference sheet) - used when she stops right after walking, so
    /// she settles facing the direction she was headed instead of always
    /// snapping to the front-facing sitDown/sitIdle pair.
    static let sitLeft = CatClip(textures: [frame(row: 0, col: 2)], timePerFrame: 1, loops: false)
    static let sitRight = CatClip(textures: [frame(row: 0, col: 3)], timePerFrame: 1, loops: false)
    /// Row 6's 10 lie-down/curl frames (cols 0-9) mix two different curl
    /// directions rather than forming one continuous transition: cols 0-3
    /// (sit-down-into-loaf) face right, cols 4-6 flip to facing left, and
    /// cols 7-9 (the tightly curled ball) alternate right/left/right frame
    /// to frame. Playing all 10 in order visibly flips her mid-settle.
    /// Fixed by filtering to two internally-consistent frame sets - one per
    /// side, in original column order - and picking a side at random each
    /// time she settles down to sleep, instead of playing the mixed
    /// original sequence. Ground anchors are per-column measurements
    /// (lowest opaque pixel row per frame, converted via 1 - bottomRow/64),
    /// reused unchanged from the original per-column table since filtering
    /// doesn't change any individual frame's geometry.
    static let lieDownRightGroundAnchors: [CGFloat?] = [0.297, 0.297, 0.297, 0.297, 0.3594, 0.375]
    static let lieDownRight = CatClip(
        textures: [0, 1, 2, 3, 7, 9].map { frame(row: 6, col: $0) },
        timePerFrame: 0.10, loops: false, groundAnchors: lieDownRightGroundAnchors
    )
    static let lieDownLeftGroundAnchors: [CGFloat?] = [0.3125, 0.3125, 0.3594, 0.375]
    static let lieDownLeft = CatClip(
        textures: [4, 5, 6, 8].map { frame(row: 6, col: $0) },
        timePerFrame: 0.10, loops: false, groundAnchors: lieDownLeftGroundAnchors
    )
    /// The final curled pose, held static - the adjacent row-6 frames differ
    /// too much to loop (they read as the cat rotating), so sleep holds this
    /// one frame and CatScene layers a gentle vertical "breath" scale over it.
    /// groundAnchors matches the corresponding lieDown clip's last frame, so
    /// there's no pop at the hand-off.
    static let sleepRight = CatClip(textures: [frame(row: 6, col: 9)], timePerFrame: 1, loops: false, groundAnchors: [0.375])
    static let sleepLeft = CatClip(textures: [frame(row: 6, col: 8)], timePerFrame: 1, loops: false, groundAnchors: [0.375])
    /// Two more curled sleeping poses ("Sleep 2"/"Sleep 3" per the pack's
    /// labeled reference sheet, rows 48-51) - measured at the same 38pt
    /// visible height above their ground line as the row-6 curl above, so
    /// swapping between all three at the lie-down transition's hand-off
    /// reads as "she settled into a slightly different curl" rather than a
    /// pop (see randomCurledRestPose). Anchors measured the same way as
    /// sleepRight/Left's (lowest opaque pixel row).
    static let sleep2Right = CatClip(textures: [frame(row: 49, col: 0)], timePerFrame: 1, loops: false, groundAnchors: [0.3594])
    static let sleep2Left = CatClip(textures: [frame(row: 48, col: 0)], timePerFrame: 1, loops: false, groundAnchors: [0.3594])
    static let sleep3Right = CatClip(textures: [frame(row: 51, col: 0)], timePerFrame: 1, loops: false, groundAnchors: [0.3594])
    static let sleep3Left = CatClip(textures: [frame(row: 50, col: 0)], timePerFrame: 1, loops: false, groundAnchors: [0.3594])
    /// Picks a random compact curled pose facing the given side - roughly
    /// half a sit/stand pose's vertical footprint (38pt vs. ~62pt above the
    /// ground line). Used both by CatAction.sleep's held pose (for variety,
    /// once the lie-down transition finishes) and CatScene's occlusion
    /// fallback (see FloorTracking.perchLeavesHerOccluded) - a standing/
    /// sitting pose substituted here whenever the current perch doesn't
    /// leave enough headroom before the menu bar. Both needs are the same:
    /// "as short as possible, aware of which way she's facing."
    static func randomCurledRestPose(right: Bool) -> CatClip {
        let pool: [(right: CatClip, left: CatClip)] = [
            (sleepRight, sleepLeft),
            (sleep2Right, sleep2Left),
            (sleep3Right, sleep3Left)
        ]
        let pose = pool.randomElement()!
        return right ? pose.right : pose.left
    }
    /// Front-facing self-grooming (row 12, paw wipes across the face/cheek) -
    /// "cleans herself", a content resting activity she does between walks.
    /// Row 17 looks similar at a glance but the paw raises well above her
    /// head each cycle, reading as a wave/reach rather than a wash - row 12
    /// keeps the paw at face height throughout, the actual grooming motion.
    /// loopPause holds her still between wash cycles instead of an unbroken
    /// loop - felt too frantic/continuous otherwise.
    static let groom = CatClip(textures: frames(row: 12, cols: 0..<8), timePerFrame: 0.12, loops: true, loopPause: 1.2)
    /// Lying self-grooming (row 13, "Lick paw lie front") - the same wash
    /// motion as `groom`, for when she grooms right after waking rather than
    /// sitting up first. Measured bottom row is 45-46 across all 8 frames vs.
    /// the walk/sit baseline's 47 (she's lying, so sits a hair lower in the
    /// cell) - small and uniform enough for one shared anchor rather than a
    /// per-frame table.
    static let groomLying = CatClip(textures: frames(row: 13, cols: 0..<8), timePerFrame: 0.12, loops: true, groundAnchors: [CGFloat?](repeating: 0.29, count: 8), loopPause: 1.2)
    /// Measured off the sheet (rows 10/11, cols 0-4): frame 1 is a mid-leap
    /// pose whose lowest opaque pixel is row 42, 5px above the walk/sit/other-
    /// run-frames baseline (row 47) - every other frame in the cycle already
    /// sits right at the baseline, so only that one frame needs a correction.
    static let runGroundAnchors: [CGFloat?] = [nil, 0.3438, nil, nil, nil]
    /// Full-speed run/leap, facing right (row 10) - what "seeking attention"
    /// (long-neglected, "может в два раза быстрее обычного пробегать из
    /// одного угла квартиры в другой") plays instead of a sped-up walk cycle.
    static let runRight = CatClip(textures: frames(row: 10, cols: 0..<5), timePerFrame: 0.08, loops: true, groundAnchors: runGroundAnchors)
    /// Faces left; native art (row 11), not a mirror of runRight.
    static let runLeft = CatClip(textures: frames(row: 11, cols: 0..<5), timePerFrame: 0.08, loops: true, groundAnchors: runGroundAnchors)
    /// Held mid-air during playJumpToCurrentSurface - the same col-1 mid-leap
    /// frame runRight/runLeft already single out for a ground-anchor
    /// correction, but as a static pose instead of cycling the run clip's
    /// legs while she's airborne (which reads as sprinting in place rather
    /// than leaping).
    static let leapRight = CatClip(textures: [frame(row: 10, col: 1)], timePerFrame: 1, loops: false, groundAnchors: [0.3438])
    static let leapLeft = CatClip(textures: [frame(row: 11, col: 1)], timePerFrame: 1, loops: false, groundAnchors: [0.3438])
    /// Front-facing paw-to-ear scratch (row 17) - this is what row 17 actually
    /// is, per the source pack's labeled reference sheet (cat_pack/black cat
    /// with text.png: row 17 = "Scratch (sit, left)"). Originally mistaken for
    /// grooming (the paw raising above her head reads as a wave at a glance)
    /// and used as `groom` in 0.1.2; reassigned once the real label turned up.
    static let scratch = CatClip(textures: frames(row: 17, cols: 0..<8), timePerFrame: 0.12, loops: true)
    /// Front-facing meow (row 14, "Meow sit front") - the rare "sits in a
    /// far corner and meows" seekAttention variant, in place of the usual
    /// run/leap across the screen. loopPause is longer than groom's - a
    /// meow is a quick vocal beat, not continuous motion, so it reads odd
    /// looping back-to-back with no pause.
    static let meowSit = CatClip(textures: frames(row: 14, cols: 0..<3), timePerFrame: 0.15, loops: true, loopPause: 2.0)
    /// Two more meow postures (rows 15/16, "Meow lie front"/"Meow stand
    /// front") - picked alongside meowSit for variety instead of always the
    /// same one, per BACKLOG's "use rows 14-16" entry. Same loopPause
    /// reasoning as meowSit - a quick vocal beat, not continuous motion.
    static let meowLie = CatClip(textures: frames(row: 15, cols: 0..<3), timePerFrame: 0.15, loops: true, loopPause: 2.0)
    static let meowStand = CatClip(textures: frames(row: 16, cols: 0..<3), timePerFrame: 0.15, loops: true, loopPause: 2.0)
    /// Rear-view climbing reach (row 62, "Jump (back)") - one paw stretching
    /// up along the spine while she ascends to a window, in place of reusing
    /// the walk cycle (see CatScene.applyCurrentAction's old shared
    /// `.walk, .climb:` case - "a distinct climbing animation is a later
    /// art thing").
    static let climb = CatClip(textures: frames(row: 62, cols: 0..<3), timePerFrame: 0.15, loops: true, loopPause: 0.3)
    /// Paw-swipe/batting family (BACKLOG's "future playing with an object"
    /// entry, rows 29-30/32-37/39-42) - verified against the labeled
    /// reference sheet the same way groom/scratch/climb were: row labels'
    /// left/right don't reliably match actual on-screen facing (see the
    /// walk row 4/5 mislabeling found earlier), so these three were picked
    /// by eye. Front-facing (row 29, "Right paw swipe stand front") for a
    /// toy directly in front of her; side-view facing left (row 32) / right
    /// (row 34) for a toy off to that side - a standing swipe/bat motion,
    /// not the row 10/11 run cycle.
    static let pawSwipeFront = CatClip(textures: frames(row: 29, cols: 0..<11), timePerFrame: 0.09, loops: true)
    static let pawSwipeLeft = CatClip(textures: frames(row: 32, cols: 0..<11), timePerFrame: 0.09, loops: true)
    static let pawSwipeRight = CatClip(textures: frames(row: 34, cols: 0..<11), timePerFrame: 0.09, loops: true)
    /// Startled hiss crouch (rows 60/61, "Hiss (front, left/right)", first
    /// frame only) - held while she's being dragged, instead of freezing on
    /// whatever frame she happened to be on when picked up.
    static let heldLeft = CatClip(textures: [frame(row: 60, col: 0)], timePerFrame: 1, loops: false)
    static let heldRight = CatClip(textures: [frame(row: 61, col: 0)], timePerFrame: 1, loops: false)
}
