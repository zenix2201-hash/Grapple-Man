# Grapple-Man
SGLODS GAMING.

## Controls
| Key | Action |
| --- | --- |
| WASD | Move |
| Space | Jump (buffered, coyote time) |
| Shift | Sprint |
| Ctrl | Slide on the ground / ground slam in the air (jump right after a slam lands to bounce) |
| E / Mouse 4 | Dash (brief invincibility, dash-jump keeps the speed) |
| Q (hold) | Lasso: swing off walls, yank light enemies to you, zip to heavy ones. Jump to let go with a boost |
| LMB / RMB | Fire / alt-fire |
| F | Punch. Punch an enemy shot right before it hits to parry it back (heals you) |
| 1-3, wheel | Switch weapon |
| Esc | Pause + options |

## Layout
- `autoload/` – `GameState` (run, parts, style meter, settings), `Sfx` (generated placeholder sounds), `Fx` (shake, hitstop, sparks, explosions)
- `Player/` – movement controller + procedural robot cowboy model
- `Weapon Systems/` – `Weapon` base, `WeaponManager` (viewmodel + punch arm), Revolver, Shotgun, Dynamite
- `Enemies/` – `Enemy` base + Hound, Gunslinger, Buzzard, Deadeye, Powder Keg, Boilerplate, The Marshal (boss), and an `enemy_spawner.tscn` to drop into test levels
- `Parts/parts_db.gd` – every swappable part (HEAD / ARM / CORE / LEGS). Add new ones there.
  Nothing opens the part picker yet: add `UpgradeScreen.new()` as a child of the player's HUD
  (e.g. from a level-exit trigger) to show it
- `UI/` – HUD, menus, upgrade screen
- `shaders/` – PS1 vertex wobble + pixelate/dither post filter
