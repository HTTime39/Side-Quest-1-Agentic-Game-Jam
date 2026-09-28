package main

import "core:math"
import rl "vendor:raylib"

reset_game :: proc(player: ^Player, enemies: ^[MAX_ENEMIES]Enemy, beams: ^[MAX_BEAMS]Beam) {
	player^ = Player{
		position = rl.Vector2{SCREEN_W / 2, SCREEN_H / 2},
		health = 100,
		aim_direction = rl.Vector2{1, 0},
	}
	for &enemy in enemies {
		enemy = Enemy{}
	}
	for &beam in beams {
		beam = Beam{}
	}
}

update_player :: proc(player: ^Player, beams: ^[MAX_BEAMS]Beam, dt: f32) {
	direction := rl.Vector2{}
	if rl.IsKeyDown(rl.KeyboardKey.W) || rl.IsKeyDown(rl.KeyboardKey.UP) { direction.y -= 1 }
	if rl.IsKeyDown(rl.KeyboardKey.S) || rl.IsKeyDown(rl.KeyboardKey.DOWN) { direction.y += 1 }
	if rl.IsKeyDown(rl.KeyboardKey.A) || rl.IsKeyDown(rl.KeyboardKey.LEFT) { direction.x -= 1 }
	if rl.IsKeyDown(rl.KeyboardKey.D) || rl.IsKeyDown(rl.KeyboardKey.RIGHT) { direction.x += 1 }

	length := math.sqrt(direction.x * direction.x + direction.y * direction.y)
	if length > 0 {
		direction.x /= length
		direction.y /= length
	}

	player.dash_cooldown = math.max(0, player.dash_cooldown - dt)
	player.dash_time = math.max(0, player.dash_time - dt)
	player.invulnerable = math.max(0, player.invulnerable - dt)
	if rl.IsKeyPressed(rl.KeyboardKey.SPACE) && player.dash_cooldown <= 0 && length > 0 {
		player.dash_time = 0.16
		player.dash_cooldown = 1.8
		player.invulnerable = 0.2
	}

	speed: f32 = 250
	if player.dash_time > 0 { speed = 760 }
	player.position.x += direction.x * speed * dt
	player.position.y += direction.y * speed * dt
	player.position.x = math.clamp(player.position.x, ARENA_LEFT + 18, ARENA_RIGHT - 18)
	player.position.y = math.clamp(player.position.y, ARENA_TOP + 18, ARENA_BOTTOM - 18)

	shoot_direction := rl.Vector2{}
	if rl.IsKeyDown(rl.KeyboardKey.I) { shoot_direction.y -= 1 }
	if rl.IsKeyDown(rl.KeyboardKey.K) { shoot_direction.y += 1 }
	if rl.IsKeyDown(rl.KeyboardKey.J) { shoot_direction.x -= 1 }
	if rl.IsKeyDown(rl.KeyboardKey.L) { shoot_direction.x += 1 }
	shoot_length := math.sqrt(shoot_direction.x * shoot_direction.x + shoot_direction.y * shoot_direction.y)
	if shoot_length > 0 {
		shoot_direction.x /= shoot_length
		shoot_direction.y /= shoot_length
		player.aim_direction = shoot_direction
	}

	player.cooldown = math.max(0, player.cooldown - dt)
	if shoot_length > 0 && player.cooldown <= 0 {
		spawn_beam(beams, player.position, rl.Vector2{shoot_direction.x * BEAM_SPEED, shoot_direction.y * BEAM_SPEED})
		player.cooldown = 0.5
	}
}

spawn_beam :: proc(beams: ^[MAX_BEAMS]Beam, position, velocity: rl.Vector2) {
	for &beam in beams {
		if beam.life <= 0 {
			beam = Beam{origin = position, position = position, velocity = velocity, life = 3}
			break
		}
	}
}

update_beams :: proc(beams: ^[MAX_BEAMS]Beam, enemies: ^[MAX_ENEMIES]Enemy, player: ^Player, score: ^int, dt: f32) {
	for &beam in beams {
		if beam.life <= 0 { continue }

		tip_start := beam.position
		player_delta_x := player.position.x - beam.origin.x
		player_delta_y := player.position.y - beam.origin.y
		step_x := beam.velocity.x * dt + player_delta_x
		step_y := beam.velocity.y * dt + player_delta_y
		travel_fraction: f32 = 1
		reached_edge := false

		if step_x > 0 && tip_start.x + step_x >= SCREEN_W {
			travel_fraction = math.min(travel_fraction, (f32(SCREEN_W) - tip_start.x) / step_x)
			reached_edge = true
		} else if step_x < 0 && tip_start.x + step_x <= 0 {
			travel_fraction = math.min(travel_fraction, -tip_start.x / step_x)
			reached_edge = true
		}
		if step_y > 0 && tip_start.y + step_y >= SCREEN_H {
			travel_fraction = math.min(travel_fraction, (f32(SCREEN_H) - tip_start.y) / step_y)
			reached_edge = true
		} else if step_y < 0 && tip_start.y + step_y <= 0 {
			travel_fraction = math.min(travel_fraction, -tip_start.y / step_y)
			reached_edge = true
		}

		step_x *= travel_fraction
		step_y *= travel_fraction
		beam.position.x += step_x
		beam.position.y += step_y
		beam.origin = player.position
		beam.life -= dt

		segment_start := beam.origin
		segment_x := beam.position.x - segment_start.x
		segment_y := beam.position.y - segment_start.y
		segment_length_sq := segment_x * segment_x + segment_y * segment_y
		if segment_length_sq > 0 {
			for beam.hits < 3 {
				closest_enemy: ^Enemy = nil
				closest_projection: f32 = 2
				for &enemy in enemies {
					if enemy.health <= 0 { continue }
					dx := enemy.position.x - segment_start.x
					dy := enemy.position.y - segment_start.y
					projection := (dx * segment_x + dy * segment_y) / segment_length_sq
					projection = math.clamp(projection, 0, 1)
					closest_x := segment_start.x + segment_x * projection
					closest_y := segment_start.y + segment_y * projection
					distance_x := enemy.position.x - closest_x
					distance_y := enemy.position.y - closest_y
					if distance_x * distance_x + distance_y * distance_y < (enemy.radius + 5) * (enemy.radius + 5) && projection < closest_projection {
						closest_enemy = &enemy
						closest_projection = projection
					}
				}
				if closest_enemy == nil { break }
				closest_enemy^.health = 0
				beam.hits += 1
				score^ += 10
			}
		}

		if reached_edge || beam.life <= 0 || beam.hits >= 3 {
			beam.life = 0
		}
	}
}

spawn_enemy :: proc(enemies: ^[MAX_ENEMIES]Enemy, elapsed: f32, spawn_count: ^int) {
	for &enemy in enemies {
		if enemy.health > 0 { continue }
		spawn_side := rl.GetRandomValue(0, 3)
		x: f32 = 0
		y: f32 = 0
		switch spawn_side {
		case 0: x = ARENA_LEFT - 24; y = f32(rl.GetRandomValue(i32(ARENA_TOP), i32(ARENA_BOTTOM)))
		case 1: x = ARENA_RIGHT + 24; y = f32(rl.GetRandomValue(i32(ARENA_TOP), i32(ARENA_BOTTOM)))
		case 2: x = f32(rl.GetRandomValue(i32(ARENA_LEFT), i32(ARENA_RIGHT))); y = ARENA_TOP - 24
		case 3: x = f32(rl.GetRandomValue(i32(ARENA_LEFT), i32(ARENA_RIGHT))); y = ARENA_BOTTOM + 24
		}
		enemy_type := Enemy_Type.Red
		if spawn_count^ % 4 == 0 {
			enemy_type = .Triangle
		} else if rl.GetRandomValue(0, 2) == 0 {
			enemy_type = .Blue
		}
		speed := 54 + elapsed * 1.2 + f32(rl.GetRandomValue(0, 22))
		if enemy_type == .Blue {
			speed *= 2.0
		} else if enemy_type == .Triangle {
			speed *= 2.2
		}
		enemy = Enemy{position = rl.Vector2{x, y}, speed = speed, health = 1, radius = 12, kind = enemy_type}
		spawn_count^ += 1
		break
	}
}

update_enemies :: proc(enemies: ^[MAX_ENEMIES]Enemy, player: ^Player, score: ^int, dt: f32) {
	for &enemy in enemies {
		if enemy.health <= 0 { continue }
		dx := player.position.x - enemy.position.x
		dy := player.position.y - enemy.position.y
		length := math.sqrt(dx * dx + dy * dy)
		if length > 0 {
			if enemy.kind == .Blue {
				if math.abs(dx) > math.abs(dy) {
					if dx > 0 { enemy.position.x += enemy.speed * dt } else { enemy.position.x -= enemy.speed * dt }
				} else {
					if dy > 0 { enemy.position.y += enemy.speed * dt } else { enemy.position.y -= enemy.speed * dt }
				}
			} else if enemy.kind == .Triangle {
				if enemy.direction_lock <= 0 {
					diagonal_x: f32 = 1
					diagonal_y: f32 = 1
					if dx < 0 { diagonal_x = -1 }
					if dy < 0 { diagonal_y = -1 }
					enemy.direction = rl.Vector2{diagonal_x, diagonal_y}
					enemy.direction_lock = 0.5
				} else {
					enemy.direction_lock = math.max(0, enemy.direction_lock - dt)
				}
				diagonal_scale := enemy.speed * dt * 0.70710678
				enemy.position.x += enemy.direction.x * diagonal_scale
				enemy.position.y += enemy.direction.y * diagonal_scale
			} else {
				enemy.position.x += dx / length * enemy.speed * dt
				enemy.position.y += dy / length * enemy.speed * dt
			}
		}
		if length < enemy.radius + 16 && player.invulnerable <= 0 {
			player.health -= 12
			player.invulnerable = 0.7
		}
	}
}
