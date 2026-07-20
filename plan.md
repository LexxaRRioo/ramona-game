╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌
 Ramona — desktop cat for macOS

 Context

 Personal pet project (not commercial): a shimeji-style desktop cat that lives on top of the screen and windows while the user works. Recreates a real cat,
 Ramona (gray/white long-haired, green eyes), with her actual behavior: eats canned chicken wet food, plays with plastic cable ties, cable wires, and a small
 beaver doll-toy. Goal: a gift for the user's girlfriend, preserving memories of the cat. Second cat (Lola) added later — architecture must make that a content
 drop, not a code change.

 Hard requirement: the cat can never die, get sick, or show a neglected state. Needs affect mood only; mood floors at "grumpy". After long absence: happy
 greeting, never guilt.

 Locked decisions

 - Language/stack: Swift + SwiftUI (menu bar/settings) + SpriteKit (cat rendering). macOS 14+, Apple Silicon only. No game engine.
 - Window integration: transparent click-through overlay NSWindow (per-pixel events); Accessibility API (AXUIElement) for tracking window frames so the cat
 sits/walks on window top edges.
 - Interactivity: sits on windows, cursor stalking/typing awareness, pick-up/drag and cursor petting (cat pixels intercept clicks; rest of screen
 click-through).
 - Memes: as behaviors/animations/props only — no speech bubbles, no audio.
 - Art: pixel art, AI-generated from Ramona's photos + manual cleanup. Fixed "sprite contract" (named animation set every cat must provide).
 - V1 scope: living cat + feeding (canned chicken) + toys (cable ties, cable wire, beaver doll). Two-cat interactions deferred.
 - Distribution: unsigned .dmg via GitHub Releases, auto-update via Sparkle. Signing may be added later without codechanges.
 - Content language: Russian where text appears; UI minimal English.
 - Versioning: semver (MAJOR.MINOR.PATCH), tracked in the repo-root VERSION file - the single source of truth both build scripts read for
 CFBundleShortVersionString/CFBundleVersion, and what the Debug menu displays at runtime. Bump PATCH for any code change (bug fix, tweak, internal
 refactor - the default when in doubt). Bump MINOR for a backward-compatible addition (new feature, extends existing behavior). Bump MAJOR when it's not
 just an extension of the previous code (breaking change, rewrite of a subsystem).

 Architecture

 - Species/ramona.json — cat definition: sprite set reference, personality trait weights (playfulness, laziness, food-motivation, boldness, sociability), item
 preferences, schedule (sleep hours), meme-behavior list. Adding Lola = new JSON + sprite folder.
 - Items (Items/*.json) — food/toys/furniture declare afforded interactions; cat traits decide usage manner.
 - Behavior engine: utility AI over a state machine. Each candidate action scored = f(needs, mood, traits, time of day, nearby items); highest score wins. State
 machine executes the chosen action's animation sequence.
 - Needs (hunger, energy, play) decay over real time, clamp so worst outcome is grumpy mood. Cat is autonomous: self-feeds off-screen if unattended.
 - Persistence: state JSON in ~/Library/Application Support/Ramona/; sim time synced to wall clock.
 - Menu bar app: feed, offer toy, quiet mode, launch-at-login, quit.
 - Battery: pause sim on screen lock, cap frame rate, idle CPU ~0%.

 Phases

 1. Skeleton: overlay window, click-through, placeholder sprite walking on screen bottom edge + menu bar app.
 2. Window tracking: Accessibility permission flow, cat walks/sleeps on top edges of real windows, reacts to window
 move/close.
 3. Behavior engine: needs/mood/traits, utility scoring, state machine, persistence.
 4. Interaction: cursor stalking, petting, drag-and-drop.
 5. Content: Ramona sprite production (AI + cleanup), items (chicken can, cable tie, wire, beaver doll), meme
 behaviors.
 6. Release: .dmg packaging, GitHub Releases, Sparkle feed, README install instructions (right-click-Open note).

 Needed from user

 - Personality interview: Ramona's traits, quirks, daily routine, favorite spots — becomes ramona.json (good spot
 for user-written trait weights and scoring tweaks).
 - Meme-behavior list: signature poses/habits to turn into animations.
 - More reference photos if needed during sprite production.

 Verification

 - Run app: cat visible over other apps, clicks pass through empty areas, cat pixels catch clicks.
 - Move/resize a Finder window with cat on it: cat follows or jumps off.
 - Feed via menu bar: eating animation, hunger reset.
 - Set system clock forward days: cat alive, at worst grumpy, greets happily.
 - Activity Monitor: near-zero CPU when idle/locked.