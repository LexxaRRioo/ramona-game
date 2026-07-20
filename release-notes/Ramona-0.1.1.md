## Fixed
- Sleeping Ramona no longer floats above the surface she's on. The curled-up sleep pose sits lower in its sprite frame than the walk/sit poses, and the fixed anchor point didn't account for that — now each frame of the lie-down animation (and the held sleep pose) carries its own measured ground-contact offset, so she settles onto the surface instead of hovering a few pixels above it.

## Test note
This release exists to verify the in-app update mechanism introduced in 0.1.0 actually works end to end (check → download → verify → install → relaunch), not just the update *check*.
