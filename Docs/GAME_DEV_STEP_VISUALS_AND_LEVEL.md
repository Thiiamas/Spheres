# Game Dev Step: Visuals & First Level

## Context
The prototype has core mechanics in place: movement, attacks, and enemies.
This guide covers the next step — adding visuals and building a first level — in the most efficient order.

---

## Guiding Principle

```
Feel good → Look good → Sound good → More content
```

Do NOT polish art or build many levels before the game feels fun. One solid vertical slice first.

---

## Step 1 — Placeholder Art Pass

**Goal:** Make the game readable, not beautiful.

- Replace invisible/debug shapes with simple colored sprites (1–2 colors, minimal detail)
- No animations yet — static sprites only
- Distinguish key entities visually: player, enemies, projectiles, terrain
- Time-box this to **1–2 days max**

> Art polish comes after the vertical slice confirms the game is fun.

---

## Step 2 — Build ONE Level (Vertical Slice)

**Goal:** A single complete level that tests everything.

### Must include:
- A clear start and end
- All existing enemy types
- A win condition and a lose condition
- At least one moment that uses each core mechanic (movement, attack)

### Level design rules:
- **Design for your mechanics** — if there's a dash, build a gap that requires it
- **Enemy placement IS level design** — it's encounter design, not just decoration
- **Hand-place everything** for this first level (faster than setting up a full editor/tilemap pipeline)

### Structure suggestion:
1. Safe opening area — let the player get comfortable with controls
2. First enemy encounter — easy, teaches the combat loop
3. Mid-level challenge — combine movement and combat
4. Final encounter or boss moment
5. Clear win state

---

## Step 3 — Playtest Loop

**Before adding anything else, playtest obsessively.**

Ask after every run:
- Is movement satisfying?
- Do enemies feel fair and readable?
- Is pacing boring or overwhelming?
- Is the win/lose condition clear?

**Fix feel before adding features.** Broken feel is cheap to fix now, expensive later.

---

## Step 4 — Sound & Juice (High ROI)

Once the level feels good mechanically:

- Hit sounds, footsteps, ambient music
- Screen shake on impact
- Hit flash (enemy flashes white when hit)
- Simple particles on death or attack

> These are cheap to implement but dramatically improve perceived quality — often more than better art.

---

## Step 5 — Level Expansion

Now that you know what's fun, build more levels.
Each new level should introduce one new mechanic, enemy, or challenge — not everything at once.

---

## Implementation Notes for Claude Code

- Ask the user which engine/framework is being used before writing any code
- For sprites: create a simple `assets/` folder structure — `assets/sprites/`, `assets/sounds/`
- For the level: prefer a data-driven approach (JSON or simple text file) so layout can be tweaked without code changes
- Add a basic scene/state manager if one doesn't exist — needed to separate game, menu, and win/lose screens
- Keep a `TODO.md` updated with what's been done and what's next

---

## Out of Scope for This Step

- Multiple levels
- Animated sprites / spritesheets
- Full UI / HUD polish
- Save system
- Audio mixer / settings
