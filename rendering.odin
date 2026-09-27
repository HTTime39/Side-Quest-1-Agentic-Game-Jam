package main

import "core:fmt"
import "core:math"
import "core:strings"
import rl "vendor:raylib"

draw_game :: proc(player: Player, enemies: [MAX_ENEMIES]Enemy, beams: [MAX_BEAMS]Beam, elapsed: f32, score: int, game_over, win: bool) {
	rl.BeginDrawing()
	rl.ClearBackground(rl.Color{9, 13, 24, 255})

	// The grid makes movement and the arena boundary readable at a glance.
	for x := i32(ARENA_LEFT); x <= i32(ARENA_RIGHT); x += 32 { rl.DrawLine(x, i32(ARENA_TOP), x, i32(ARENA_BOTTOM), rl.Color{18, 27, 43, 255}) }
	for y := i32(ARENA_TOP); y <= i32(ARENA_BOTTOM); y += 32 { rl.DrawLine(i32(ARENA_LEFT), y, i32(ARENA_RIGHT), y, rl.Color{18, 27, 43, 255}) }
	rl.DrawRectangleLines(i32(ARENA_LEFT), i32(ARENA_TOP), i32(ARENA_RIGHT - ARENA_LEFT), i32(ARENA_BOTTOM - ARENA_TOP), rl.Color{50, 91, 122, 255})

	for enemy in enemies {
		if enemy.health <= 0 { continue }
		if enemy.kind == .Blue {
			rl.DrawRectangle(i32(enemy.position.x - enemy.radius - 3), i32(enemy.position.y - enemy.radius - 3), i32((enemy.radius + 3) * 2), i32((enemy.radius + 3) * 2), rl.Color{15, 54, 96, 255})
			rl.DrawRectangle(i32(enemy.position.x - enemy.radius), i32(enemy.position.y - enemy.radius), i32(enemy.radius * 2), i32(enemy.radius * 2), rl.Color{50, 157, 255, 255})
		} else {
			rl.DrawCircleV(enemy.position, enemy.radius + 3, rl.Color{95, 25, 54, 255})
			rl.DrawCircleV(enemy.position, enemy.radius, rl.Color{238, 77, 91, 255})
		}
	}
	for beam in beams {
		if beam.life > 0 {
			rl.DrawLineEx(beam.origin, beam.position, 9, rl.Color{255, 165, 58, 100})
			rl.DrawLineEx(beam.origin, beam.position, 4, rl.Color{255, 235, 145, 255})
		}
	}

	player_color := rl.Color{72, 211, 176, 255}
	if player.invulnerable > 0 && i32(player.invulnerable * 14) % 2 == 0 { player_color = rl.Color{255, 255, 255, 255} }
	rl.DrawCircleV(player.position, 17, rl.Color{18, 72, 76, 255})
	rl.DrawCircleV(player.position, 12, player_color)
	rl.DrawLineV(player.position, rl.Vector2{player.position.x + player.aim_direction.x * 42, player.position.y + player.aim_direction.y * 42}, rl.Color{98, 142, 159, 180})

	text := fmt.tprintf("EDGE//BREAK     SCORE %05d     TIME %05.1f / 90.0", score, elapsed)
	score_text, _ := strings.clone_to_cstring(text)
	rl.DrawText(score_text, 32, 26, 24, rl.Color{220, 235, 238, 255})
	rl.DrawRectangle(820, 29, 220, 16, rl.Color{35, 42, 54, 255})
	rl.DrawRectangle(820, 29, i32(math.max(0, player.health) * 2.2), 16, rl.Color{72, 211, 176, 255})
	hp_text, _ := strings.clone_to_cstring(fmt.tprintf("HP %03d", i32(math.max(0, player.health))))
	rl.DrawText(hp_text, 730, 26, 22, rl.Color{220, 235, 238, 255})
	rl.DrawText("WASD / ARROWS move     IJKL fire     SPACE dash (invulnerable)", 42, 675, 18, rl.Color{115, 145, 158, 255})

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
