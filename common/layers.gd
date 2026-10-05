@tool
class_name Layers
extends RefCounted
## Physics layer bit values. Names match project settings > Layer Names > 3D Physics.

const WORLD := 1             # layer 1: level geometry
const WALL := 2              # layer 2: "Wall"
const PLAYER := 4            # layer 3
const ENEMY := 8             # layer 4
const ENEMY_PROJECTILE := 16 # layer 5
const PLAYER_PROJECTILE := 32 # layer 6

const WORLD_MASK := WORLD | WALL
const HITSCAN_MASK := WORLD | WALL | ENEMY
