# Game Design

Condensed from the Development Bible, Revision 2.0. The Bible wins on any conflict.

## North star

- 2D movement-heavy hack-and-slash platformer with exploratory, interconnected stages.
- Joyful, theatrical, colourful, kinetic, mischievous. Never grimdark.
- Enemy knockback is traversal, combat and environmental interaction at once.
- Camera stays wide enough to show several routes and the next landing.

## Core loop

Sprint, jump an enemy, strike down with the hammer, bounce, redirect into another enemy, launch it into a group, use the opening to cross a gap, keep moving.

## Hammer verbs (prototype)

| Verb | Input | Effect |
| --- | --- | --- |
| Side swing | Light | Launches forward and up |
| Upswing | Up + Light | Launches straight up |
| Pogo | Down + Light in air | Bounces off enemies, crates and spikes; restores air dash |
| Heavy | Heavy (hold to charge) | Bigger launch; charge scales launch up to 1.9x and adds damage |
| Vault | Down + Heavy on ground | Plant and launch up, or forward when holding a direction; 1.25x within 0.12 s of landing |

## Launch rules

- Each move has an authored launch vector, plus a share of the Jester's velocity, divided by target mass, clamped to a maximum speed.
- A launched enemy damages and transfers momentum to enemies it touches, smashes crates, ricochets off walls (max 2), bounces once off the floor, and is defeated by spikes.
- Chains are bounded: per-pair cooldown, speed loss on every transfer, minimum speed, maximum depth.

## World rules

- The Jester is an exceptional undead skeleton.
- Princess Seraphine, the King, guards, nobles and citizens are living humans. No skull faces for them.
- Ghosts, constructs, magical creatures and rare undead are separate, visually distinct categories.

## Level progression

Carnival Gate, Outer Walls, Royal Gardens, Grand Halls, Clockworks, Throne Spire. Each area needs: an intro traversal loop, a mastery shortcut, a combat physics showcase, a hidden collectible path, a miniboss or challenge room, and a visible exit.

## Prototype exit criteria (Bible section 16)

A tester can move continuously for 30 seconds, pogo at least twice, launch one enemy into another, understand where to go with the zoomed-out camera, and recover from a missed trick without restarting the room.

## Open creative questions (need the creative director)

1. Why was the Jester killed?
2. What caused his return?
3. Does the King know his identity?
4. Is Seraphine playable in the main campaign or DLC only?
5. How does the finale avoid reducing Seraphine to a prize?
6. Dash and air-dash: available from the start, or unlocked? (Prototype: available.)
7. Wall-slide and wall-kick: in or out? (Prototype: out.)
8. Should the player pass through enemies or be blocked by them? (Prototype: passes through; no contact damage yet.)
