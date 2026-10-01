package main

import "core:math"
import rl "vendor:raylib"

reset_game :: proc(player: ^Player, enemies: ^[MAX_ENEMIES]Enemy, beams: ^[MAX_BEAMS]Beam) {
	player^ = Player{
		position = rl.Vector2{SCREEN_W / 2, SCREEN_H / 2},
		health = 100,
		aim_direction = rl.Vector2{1, 0},
		light_radius = 165,
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
		spawn_beam(beams, player.position, rl.Vector2{shoot_direction.x * BEAM_SPEED, shoot_direction.y * BEAM_SPEED}, false)
		for spread_index := 1; spread_index <= player.front_spread_levels; spread_index += 1 {
			angle := f32(spread_index) * 0.20943951
			for side := f32(-1); side <= 1; side += 2 {
				rotated := rotate_direction(shoot_direction, angle * side)
				spawn_beam(beams, player.position, rl.Vector2{rotated.x * BEAM_SPEED, rotated.y * BEAM_SPEED}, false)
			}
		}
		if player.rear_laser_level > 0 {
			rear_direction := rl.Vector2{-shoot_direction.x, -shoot_direction.y}
			spawn_beam(beams, player.position, rl.Vector2{rear_direction.x * BEAM_SPEED, rear_direction.y * BEAM_SPEED}, true)
			if player.rear_laser_level >= 2 {
				left_direction := rl.Vector2{-shoot_direction.y, shoot_direction.x}
				spawn_beam(beams, player.position, rl.Vector2{left_direction.x * BEAM_SPEED, left_direction.y * BEAM_SPEED}, false)
			}
			if player.rear_laser_level >= 3 {
				right_direction := rl.Vector2{shoot_direction.y, -shoot_direction.x}
				spawn_beam(beams, player.position, rl.Vector2{right_direction.x * BEAM_SPEED, right_direction.y * BEAM_SPEED}, false)
			}
			for spread_index := 4; spread_index <= player.rear_laser_level; spread_index += 1 {
				angle := f32(spread_index - 3) * 0.20943951
				for side := f32(-1); side <= 1; side += 2 {
					rotated := rotate_direction(rear_direction, angle * side)
					spawn_beam(beams, player.position, rl.Vector2{rotated.x * BEAM_SPEED, rotated.y * BEAM_SPEED}, false)
				}
			}
		}
		player.cooldown = 0.5
	}
}

rotate_direction :: proc(direction: rl.Vector2, angle: f32) -> rl.Vector2 {
	cosine := math.cos(angle)
	sine := math.sin(angle)
	return rl.Vector2{direction.x * cosine - direction.y * sine, direction.x * sine + direction.y * cosine}
}

apply_upgrade :: proc(player: ^Player, upgrade: Upgrade_Type) {
	switch upgrade {
	case .Restore_Health:
		player.health = math.min(100, player.health + 50)
	case .Front_Spread:
		player.front_spread_levels += 1
	case .Rear_Laser:
		player.rear_laser_level += 1
	case .Extra_Piercing:
		player.extra_laser_hits += 1
	case .Larger_Light:
		player.light_radius += 20
	}
}

spawn_beam :: proc(beams: ^[MAX_BEAMS]Beam, position, velocity: rl.Vector2, sweeping: bool) {
	for &beam in beams {
		if beam.life <= 0 {
			beam = Beam{origin = position, position = position, velocity = velocity, life = 3, sweeping = sweeping, sweep_angle = -REAR_SWEEP_LIMIT, sweep_direction = 1}
			if sweeping {
				beam.velocity = rotate_direction(beam.velocity, -REAR_SWEEP_LIMIT)
				beam.velocity.x *= 2.5
				beam.velocity.y *= 2.5
			}
			break
		}
	}
}

update_beams :: proc(beams: ^[MAX_BEAMS]Beam, enemies: ^[MAX_ENEMIES]Enemy, player: ^Player, score: ^int, dt: f32) {
	for &beam in beams {
		if beam.life <= 0 { continue }

		tip_start := beam.position
		reached_edge := false
		if beam.sweeping {
			previous_angle := beam.sweep_angle
			beam.sweep_angle = math.min(REAR_SWEEP_LIMIT, beam.sweep_angle + REAR_SWEEP_SPEED * dt)
			if beam.sweep_angle >= REAR_SWEEP_LIMIT {
				beam.sweep_complete = true
			}
			angle_delta := beam.sweep_angle - previous_angle
			beam.velocity = rotate_direction(beam.velocity, angle_delta)
			velocity_length := math.sqrt(beam.velocity.x * beam.velocity.x + beam.velocity.y * beam.velocity.y)
			beam.sweep_distance += velocity_length * dt
			direction := rl.Vector2{beam.velocity.x / velocity_length, beam.velocity.y / velocity_length}
			distance_to_edge: f32 = f32(SCREEN_W + SCREEN_H)
			if direction.x > 0 {
				distance_to_edge = math.min(distance_to_edge, (f32(SCREEN_W) - player.position.x) / direction.x)
			} else if direction.x < 0 {
				distance_to_edge = math.min(distance_to_edge, -player.position.x / direction.x)
			}
			if direction.y > 0 {
				distance_to_edge = math.min(distance_to_edge, (f32(SCREEN_H) - player.position.y) / direction.y)
			} else if direction.y < 0 {
				distance_to_edge = math.min(distance_to_edge, -player.position.y / direction.y)
			}
			ray_distance := math.min(beam.sweep_distance, distance_to_edge)
			beam.position = rl.Vector2{player.position.x + direction.x * ray_distance, player.position.y + direction.y * ray_distance}
		} else {
			step_x := beam.velocity.x * dt + player.position.x - beam.origin.x
			step_y := beam.velocity.y * dt + player.position.y - beam.origin.y
			travel_fraction: f32 = 1
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
		}
		beam.origin = player.position
		if !beam.sweeping { beam.life -= dt }

		segment_start := beam.origin
		segment_x := beam.position.x - segment_start.x
		segment_y := beam.position.y - segment_start.y
		segment_length_sq := segment_x * segment_x + segment_y * segment_y
		if segment_length_sq > 0 {
			for beam.hits < 3 + player.extra_laser_hits {
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

		if (!beam.sweeping && (reached_edge || beam.life <= 0)) || beam.sweep_complete || beam.hits >= 3 + player.extra_laser_hits {
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
			speed *= 1.7
		} else if enemy_type == .Triangle {
			speed *= 1.9
		}
		speed *= 0.8
		enemy = Enemy{position = rl.Vector2{x, y}, speed = speed, health = 1, radius = 12, kind = enemy_type}
		spawn_count^ += 1
		break
	}
}

update_enemies :: proc(enemies: ^[MAX_ENEMIES]Enemy, player: ^Player, score: ^int, dt: f32) {
	for &enemy in enemies {
		if enemy.health <= 0 { continue }
		enemy.flash_timer = math.max(0, enemy.flash_timer - dt)
		dx := player.position.x - enemy.position.x
		dy := player.position.y - enemy.position.y
		length := math.sqrt(dx * dx + dy * dy)
		if length > 0 {
			if enemy.kind == .Blue {
				if enemy.direction_lock <= 0 {
					direction := rl.Vector2{}
					axis := Enemy_Axis.Vertical
					if math.abs(dx) > math.abs(dy) {
						axis = .Horizontal
						if dx > 0 { direction.x = 1 } else { direction.x = -1 }
					} else {
						if dy > 0 { direction.y = 1 } else { direction.y = -1 }
					}
					if enemy.movement_axis != .None && enemy.movement_axis != axis { enemy.flash_timer = 0.16 }
					enemy.movement_axis = axis
					enemy.direction = direction
					enemy.direction_lock = 0.3
				} else {
					enemy.direction_lock = math.max(0, enemy.direction_lock - dt)
				}
				enemy.position.x += enemy.direction.x * enemy.speed * dt
				enemy.position.y += enemy.direction.y * enemy.speed * dt
			} else if enemy.kind == .Triangle {
				if enemy.direction_lock <= 0 {
					diagonal_x: f32 = 1
					diagonal_y: f32 = 1
					if dx < 0 { diagonal_x = -1 }
					if dy < 0 { diagonal_y = -1 }
					if enemy.direction.x != 0 && (enemy.direction.x != diagonal_x || enemy.direction.y != diagonal_y) {
						enemy.flash_timer = 0.16
					}
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
