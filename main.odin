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
MAX_BULLETS :: 256

Player :: struct {
	position: rl.Vector2,
	health: f32,
	cooldown: f32,
	invulnerable: f32,
	dash_cooldown: f32,
	dash_time: f32,
	aim_direction: rl.Vector2,
}

Enemy :: struct {
	position: rl.Vector2,
	speed: f32,
	health: f32,
	radius: f32,
}

Bullet :: struct {
	position: rl.Vector2,
	velocity: rl.Vector2,
	life: f32,
}

main :: proc() {
	rl.InitWindow(SCREEN_W, SCREEN_H, "EDGE//BREAK - Survival Protocol")
	rl.SetTargetFPS(60)
	defer rl.CloseWindow()

	player: Player
	enemies: [MAX_ENEMIES]Enemy
	bullets: [MAX_BULLETS]Bullet
	reset_game(&player, &enemies, &bullets)

	game_over := false
	win := false
	time_alive: f32 = 0
	score := 0
	spawn_timer: f32 = 0

	for !rl.WindowShouldClose() {
		dt := math.min(rl.GetFrameTime(), 0.05)

		if game_over || win {
			if rl.IsKeyPressed(rl.KeyboardKey.ENTER) || rl.IsKeyPressed(rl.KeyboardKey.SPACE) {
				reset_game(&player, &enemies, &bullets)
				game_over = false
				win = false
				time_alive = 0
				score = 0
				spawn_timer = 0
			}
		} else {
			time_alive += dt
			update_player(&player, &bullets, dt)

			spawn_timer -= dt
			spawn_delay := math.max(0.18, 0.85 - time_alive * 0.008)
			if spawn_timer <= 0 {
				spawn_enemy(&enemies, time_alive)
				spawn_timer = spawn_delay
			}

			update_bullets(&bullets, &enemies, &score, dt)
			update_enemies(&enemies, &player, &score, dt)

			if player.health <= 0 {
				game_over = true
			} else if time_alive >= 90 {
				win = true
			}
		}

		draw_game(player, enemies, bullets, time_alive, score, game_over, win)
	}
}
