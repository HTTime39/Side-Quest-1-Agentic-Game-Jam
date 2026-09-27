package main

import "core:math"
import rl "vendor:raylib"

reset_game :: proc(player: ^Player, enemies: ^[MAX_ENEMIES]Enemy, bullets: ^[MAX_BULLETS]Bullet) {
	player^ = Player{
		position = rl.Vector2{SCREEN_W / 2, SCREEN_H / 2},
		health = 100,
		aim_direction = rl.Vector2{1, 0},
	}
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

	shoot_direction := rl.Vector2{}
	if rl.IsKeyDown(rl.KeyboardKey.I) { shoot_direction.y -= 1 }
	if rl.IsKeyDown(rl.KeyboardKey.K) { shoot_direction.y += 1 }
	if rl.IsKeyDown(rl.KeyboardKey.J) { shoot_direction.x -= 1 }
	if rl.IsKeyDown(rl.KeyboardKey.L) { shoot_direction.x += 1 }
	shoot_length := math.sqrt(shoot_direction.x * shoot_direction.x + shoot_direction.y * shoot_direction.y)

	player.cooldown = math.max(0, player.cooldown - dt)
	if shoot_length > 0 && player.cooldown <= 0 {
		shoot_direction.x /= shoot_length
		shoot_direction.y /= shoot_length
		player.aim_direction = shoot_direction
		spawn_bullet(bullets, player.position, rl.Vector2{shoot_direction.x * 680, shoot_direction.y * 680})
		player.cooldown = 0.13
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
		}
	}
}
