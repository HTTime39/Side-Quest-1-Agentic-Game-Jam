package main

import "core:fmt"
import "core:math"
import "core:strings"
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

reset_game :: proc(player: ^Player, enemies: ^[MAX_ENEMIES]Enemy, bullets: ^[MAX_BULLETS]Bullet) {
	player^ = Player{position = rl.Vector2{SCREEN_W / 2, SCREEN_H / 2}, health = 100}
	for &enemy in enemies {
		enemy = Enemy{}
	}
	for &bullet in bullets {
		bullet = Bullet{}
	}
}

update_player :: proc(player: ^Player, bullets: ^[MAX_BULLETS]Bullet, dt: f32) {
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

	player.cooldown = math.max(0, player.cooldown - dt)
	if rl.IsMouseButtonDown(rl.MouseButton.LEFT) && player.cooldown <= 0 {
		mouse := rl.GetMousePosition()
		dx := mouse.x - player.position.x
		dy := mouse.y - player.position.y
		shot_length := math.sqrt(dx * dx + dy * dy)
		if shot_length > 0 {
			spawn_bullet(bullets, player.position, rl.Vector2{dx / shot_length * 680, dy / shot_length * 680})
			player.cooldown = 0.13
		}
	}
}

spawn_bullet :: proc(bullets: ^[MAX_BULLETS]Bullet, position, velocity: rl.Vector2) {
	for &bullet in bullets {
		if bullet.life <= 0 {
			bullet = Bullet{position = position, velocity = velocity, life = 1.3}
			break
		}
	}
}

update_bullets :: proc(bullets: ^[MAX_BULLETS]Bullet, enemies: ^[MAX_ENEMIES]Enemy, score: ^int, dt: f32) {
	for &bullet in bullets {
		if bullet.life <= 0 { continue }
		bullet.position.x += bullet.velocity.x * dt
		bullet.position.y += bullet.velocity.y * dt
		bullet.life -= dt
		if bullet.position.x < ARENA_LEFT || bullet.position.x > ARENA_RIGHT || bullet.position.y < ARENA_TOP || bullet.position.y > ARENA_BOTTOM {
			bullet.life = 0
			continue
		}
		for &enemy in enemies {
			if enemy.health <= 0 { continue }
			dx := bullet.position.x - enemy.position.x
			dy := bullet.position.y - enemy.position.y
			if dx * dx + dy * dy < (enemy.radius + 5) * (enemy.radius + 5) {
				enemy.health = 0
				bullet.life = 0
				score^ += 10
				break
			}
		}
	}
}

spawn_enemy :: proc(enemies: ^[MAX_ENEMIES]Enemy, elapsed: f32) {
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
		enemy = Enemy{position = rl.Vector2{x, y}, speed = 54 + elapsed * 1.2 + f32(rl.GetRandomValue(0, 22)), health = 1, radius = 12}
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
			enemy.position.x += dx / length * enemy.speed * dt
			enemy.position.y += dy / length * enemy.speed * dt
		}
		if length < enemy.radius + 16 && player.invulnerable <= 0 {
			player.health -= 12
			player.invulnerable = 0.7
			player.position.x -= dx / math.max(length, 1) * 28
			player.position.y -= dy / math.max(length, 1) * 28
		}
	}
}

draw_game :: proc(player: Player, enemies: [MAX_ENEMIES]Enemy, bullets: [MAX_BULLETS]Bullet, elapsed: f32, score: int, game_over, win: bool) {
	rl.BeginDrawing()
	rl.ClearBackground(rl.Color{9, 13, 24, 255})

	// The grid makes movement and the arena boundary readable at a glance.
	for x := i32(ARENA_LEFT); x <= i32(ARENA_RIGHT); x += 32 { rl.DrawLine(x, i32(ARENA_TOP), x, i32(ARENA_BOTTOM), rl.Color{18, 27, 43, 255}) }
	for y := i32(ARENA_TOP); y <= i32(ARENA_BOTTOM); y += 32 { rl.DrawLine(i32(ARENA_LEFT), y, i32(ARENA_RIGHT), y, rl.Color{18, 27, 43, 255}) }
	rl.DrawRectangleLines(i32(ARENA_LEFT), i32(ARENA_TOP), i32(ARENA_RIGHT - ARENA_LEFT), i32(ARENA_BOTTOM - ARENA_TOP), rl.Color{50, 91, 122, 255})

	for bullet in bullets { if bullet.life > 0 { rl.DrawCircleV(bullet.position, 4, rl.Color{255, 219, 102, 255}) } }
	for enemy in enemies { if enemy.health > 0 { rl.DrawCircleV(enemy.position, enemy.radius + 3, rl.Color{95, 25, 54, 255}); rl.DrawCircleV(enemy.position, enemy.radius, rl.Color{238, 77, 91, 255}) } }

	player_color := rl.Color{72, 211, 176, 255}
	if player.invulnerable > 0 && i32(player.invulnerable * 14) % 2 == 0 { player_color = rl.Color{255, 255, 255, 255} }
	rl.DrawCircleV(player.position, 17, rl.Color{18, 72, 76, 255})
	rl.DrawCircleV(player.position, 12, player_color)
	mouse := rl.GetMousePosition()
	rl.DrawLineV(player.position, mouse, rl.Color{98, 142, 159, 180})

	text := fmt.tprintf("EDGE//BREAK     SCORE %05d     TIME %05.1f / 90.0", score, elapsed)
	score_text, _ := strings.clone_to_cstring(text)
	rl.DrawText(score_text, 32, 26, 24, rl.Color{220, 235, 238, 255})
	rl.DrawRectangle(820, 29, 220, 16, rl.Color{35, 42, 54, 255})
	rl.DrawRectangle(820, 29, i32(math.max(0, player.health) * 2.2), 16, rl.Color{72, 211, 176, 255})
	hp_text, _ := strings.clone_to_cstring(fmt.tprintf("HP %03d", i32(math.max(0, player.health))))
	rl.DrawText(hp_text, 730, 26, 22, rl.Color{220, 235, 238, 255})
	rl.DrawText("WASD / ARROWS move     LMB fire     SPACE dash (invulnerable)", 42, 675, 18, rl.Color{115, 145, 158, 255})

	if game_over || win {
		rl.DrawRectangle(0, 0, SCREEN_W, SCREEN_H, rl.Color{4, 7, 15, 190})
		if win {
			rl.DrawText("90 SECONDS. PROTOCOL COMPLETE.", 250, 270, 32, rl.Color{72, 211, 176, 255})
		} else {
			rl.DrawText("SIGNAL LOST", 415, 270, 42, rl.Color{238, 77, 91, 255})
		}
		final_score_text, _ := strings.clone_to_cstring(fmt.tprintf("FINAL SCORE  %05d", score))
		rl.DrawText(final_score_text, 430, 335, 25, rl.Color{230, 235, 235, 255})
		rl.DrawText("PRESS ENTER OR SPACE TO RESTART", 350, 395, 20, rl.Color{255, 219, 102, 255})
	}
	rl.EndDrawing()
}