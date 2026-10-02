package main

import "core:math"
import rl "vendor:raylib"

SCREEN_W :: 1100
SCREEN_H :: 700
ARENA_LEFT :: 32.0
ARENA_TOP :: 82.0
ARENA_RIGHT :: 1068.0
ARENA_BOTTOM :: 668.0
MAX_ENEMIES :: 256
MAX_BEAMS :: 256
BEAM_SPEED :: 1200
REAR_SWEEP_LIMIT :: 0.43633232
REAR_SWEEP_SPEED :: 2.4

Player :: struct {
	position: rl.Vector2,
	health: f32,
	cooldown: f32,
	invulnerable: f32,
	dash_cooldown: f32,
	dash_time: f32,
	aim_direction: rl.Vector2,
	front_spread_levels: int,
	rear_laser_level: int,
	extra_laser_hits: int,
	light_radius: f32,
}

Upgrade_Type :: enum {
	Restore_Health,
	Front_Spread,
	Rear_Laser,
	Extra_Piercing,
	Larger_Light,
}

Enemy_Type :: enum {
	Red,
	Blue,
	Triangle,
	Killer_Whale,
}

Enemy_Axis :: enum {
	None,
	Horizontal,
	Vertical,
}

Enemy :: struct {
	position: rl.Vector2,
	speed: f32,
	health: f32,
	radius: f32,
	kind: Enemy_Type,
	direction: rl.Vector2,
	direction_lock: f32,
	movement_axis: Enemy_Axis,
	flash_timer: f32,
	dash_cooldown: f32,
	dash_time: f32,
	dash_direction: rl.Vector2,
}

Beam :: struct {
	origin: rl.Vector2,
	position: rl.Vector2,
	velocity: rl.Vector2,
	life: f32,
	hits: int,
	sweeping: bool,
	sweep_angle: f32,
	sweep_direction: f32,
	sweep_distance: f32,
	sweep_complete: bool,
}

main :: proc() {
	rl.InitWindow(SCREEN_W, SCREEN_H, "EDGE//BREAK - Survival Protocol")
	rl.SetTargetFPS(60)
	defer rl.CloseWindow()
	background_texture := rl.LoadTexture("assets/background.png")
	defer rl.UnloadTexture(background_texture)
	lighting_target := rl.LoadRenderTexture(SCREEN_W, SCREEN_H)
	defer rl.UnloadRenderTexture(lighting_target)
	lighting_shader := rl.LoadShaderFromMemory(nil, LIGHTING_FRAGMENT_SHADER)
	defer rl.UnloadShader(lighting_shader)
	player_light_location := rl.GetShaderLocation(lighting_shader, "playerPosition")
	screen_size_location := rl.GetShaderLocation(lighting_shader, "screenSize")
	beam_segments_location := rl.GetShaderLocation(lighting_shader, "beamSegments[0]")
	beam_count_location := rl.GetShaderLocation(lighting_shader, "beamCount")
	player_light_radius_location := rl.GetShaderLocation(lighting_shader, "playerLightRadius")

	player: Player
	enemies: [MAX_ENEMIES]Enemy
	beams: [MAX_BEAMS]Beam
	reset_game(&player, &enemies, &beams)

	title_screen := true
	game_over := false
	win := false
	time_alive: f32 = 0
	score := 0
	spawn_timer: f32 = 0
	spawn_count: int = 0
	stage := 1
	stage_spawned := 0
	stage_enemy_target := 10
	upgrade_pending := false
	upgrade_choices: [2]Upgrade_Type
	upgrade_selection := 0

	for !rl.WindowShouldClose() {
		dt := math.min(rl.GetFrameTime(), 0.05)

		if title_screen {
			if rl.GetKeyPressed() != .KEY_NULL {
				title_screen = false
			}
		} else if game_over || win {
			if rl.IsKeyPressed(rl.KeyboardKey.ENTER) || rl.IsKeyPressed(rl.KeyboardKey.SPACE) {
				reset_game(&player, &enemies, &beams)
				title_screen = true
				game_over = false
				win = false
				time_alive = 0
				score = 0
				spawn_timer = 0
				spawn_count = 0
				stage = 1
				stage_spawned = 0
				stage_enemy_target = 10
				upgrade_pending = false
			}
		} else if upgrade_pending {
			if rl.IsKeyPressed(rl.KeyboardKey.LEFT) || rl.IsKeyPressed(rl.KeyboardKey.A) {
				upgrade_selection = 0
			} else if rl.IsKeyPressed(rl.KeyboardKey.RIGHT) || rl.IsKeyPressed(rl.KeyboardKey.D) {
				upgrade_selection = 1
			}
			if rl.IsKeyPressed(rl.KeyboardKey.ENTER) {
				apply_upgrade(&player, upgrade_choices[upgrade_selection])
				upgrade_pending = false
			}
		} else {
			time_alive += dt
			update_player(&player, &beams, dt)

			spawn_timer -= dt
			spawn_delay := math.max(0.18, 0.85 - time_alive * 0.008)
			if stage_spawned < stage_enemy_target && spawn_timer <= 0 {
				if stage == 6 {
					spawn_killer_whale(&enemies, time_alive)
				} else {
					spawn_enemy(&enemies, time_alive, &spawn_count)
				}
				stage_spawned += 1
				spawn_timer = spawn_delay
			}

			update_beams(&beams, &enemies, &player, &score, dt)
			update_enemies(&enemies, &player, &score, dt)

			if player.health <= 0 {
				game_over = true
			} else {
				active_enemies := 0
				for enemy in enemies {
					if enemy.health > 0 { active_enemies += 1 }
				}
				if stage_spawned == stage_enemy_target && active_enemies == 0 {
					if stage == 6 {
						win = true
					} else {
						stage += 1
						stage_spawned = 0
						if stage == 6 {
							stage_enemy_target = 1
						} else {
							stage_enemy_target *= 2
						}
						spawn_timer = 0
						choose_upgrade_options(&upgrade_choices)
						upgrade_selection = 0
						upgrade_pending = true
					}
				}
			}
		}

		draw_game(player, enemies, beams, time_alive, score, stage, stage_enemy_target, stage_spawned, upgrade_pending, upgrade_choices, upgrade_selection, title_screen, game_over, win, background_texture, lighting_target, lighting_shader, player_light_location, player_light_radius_location, screen_size_location, beam_segments_location, beam_count_location)
	}
}

choose_upgrade_options :: proc(options: ^[2]Upgrade_Type) {
	first := rl.GetRandomValue(0, 4)
	second := rl.GetRandomValue(0, 3)
	if second >= first { second += 1 }
	options[0] = Upgrade_Type(first)
	options[1] = Upgrade_Type(second)
}
