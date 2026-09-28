package main

import "core:fmt"
import "core:math"
import "core:strings"
import rl "vendor:raylib"

MAX_LIT_BEAMS :: 8

LIGHTING_FRAGMENT_SHADER :: `#version 330
in vec2 fragTexCoord;
in vec4 fragColor;
uniform sampler2D texture0;
uniform vec2 playerPosition;
uniform vec2 screenSize;
uniform vec4 beamSegments[8];
uniform int beamCount;
out vec4 finalColor;

void main() {
	vec2 pixelPosition = vec2(gl_FragCoord.x, screenSize.y - gl_FragCoord.y);
	float distanceFromPlayer = distance(pixelPosition, playerPosition);
	float light = 1.0 - smoothstep(70.0, 165.0, distanceFromPlayer);
	for (int i = 0; i < 8; i++) {
		if (i >= beamCount) break;
		vec4 segment = beamSegments[i];
		vec2 segmentVector = segment.zw - segment.xy;
		float segmentLengthSquared = dot(segmentVector, segmentVector);
		float projection = clamp(dot(pixelPosition - segment.xy, segmentVector) / max(segmentLengthSquared, 0.001), 0.0, 1.0);
		float distanceFromBeam = length(pixelPosition - (segment.xy + projection * segmentVector));
		light = max(light, 1.0 - smoothstep(22.0, 70.0, distanceFromBeam));
	}
	float illumination = mix(0.06, 1.0, light);
	vec4 sceneColor = texture(texture0, fragTexCoord) * fragColor;
	finalColor = vec4(sceneColor.rgb * illumination, sceneColor.a);
}`

draw_game :: proc(player: Player, enemies: [MAX_ENEMIES]Enemy, beams: [MAX_BEAMS]Beam, elapsed: f32, score: int, game_over, win: bool, lighting_target: rl.RenderTexture2D, lighting_shader: rl.Shader, player_light_location, screen_size_location, beam_segments_location, beam_count_location: i32) {
	rl.BeginTextureMode(lighting_target)
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
		} else if enemy.kind == .Triangle {
			direction_length := math.sqrt(enemy.direction.x * enemy.direction.x + enemy.direction.y * enemy.direction.y)
			direction := rl.Vector2{enemy.direction.x / direction_length, enemy.direction.y / direction_length}
			perpendicular := rl.Vector2{-direction.y, direction.x}
			tip := rl.Vector2{enemy.position.x + direction.x * enemy.radius * 1.4, enemy.position.y + direction.y * enemy.radius * 1.4}
			base_left := rl.Vector2{enemy.position.x - direction.x * enemy.radius * 0.8 + perpendicular.x * enemy.radius, enemy.position.y - direction.y * enemy.radius * 0.8 + perpendicular.y * enemy.radius}
			base_right := rl.Vector2{enemy.position.x - direction.x * enemy.radius * 0.8 - perpendicular.x * enemy.radius, enemy.position.y - direction.y * enemy.radius * 0.8 - perpendicular.y * enemy.radius}
			rl.DrawTriangle(tip, base_right, base_left, rl.Color{255, 219, 102, 255})
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
	rl.EndTextureMode()

	rl.BeginDrawing()
	rl.ClearBackground(rl.Color{9, 13, 24, 255})
	player_position := player.position
	rl.SetShaderValue(lighting_shader, player_light_location, rawptr(&player_position), .VEC2)
	screen_size := rl.Vector2{f32(SCREEN_W), f32(SCREEN_H)}
	rl.SetShaderValue(lighting_shader, screen_size_location, rawptr(&screen_size), .VEC2)
	beam_segments: [MAX_LIT_BEAMS]rl.Vector4
	beam_count: i32 = 0
	for beam in beams {
		if beam.life > 0 && beam_count < MAX_LIT_BEAMS {
			beam_segments[beam_count] = rl.Vector4{beam.origin.x, beam.origin.y, beam.position.x, beam.position.y}
			beam_count += 1
		}
	}
	rl.SetShaderValueV(lighting_shader, beam_segments_location, rawptr(&beam_segments), .VEC4, MAX_LIT_BEAMS)
	rl.SetShaderValue(lighting_shader, beam_count_location, rawptr(&beam_count), .INT)
	rl.BeginShaderMode(lighting_shader)
	rl.DrawTextureRec(lighting_target.texture, rl.Rectangle{0, 0, f32(SCREEN_W), -f32(SCREEN_H)}, rl.Vector2{}, rl.Color{255, 255, 255, 255})
	rl.EndShaderMode()
	rl.BeginBlendMode(rl.BlendMode.ADDITIVE)
	for enemy in enemies {
		if enemy.health <= 0 || enemy.flash_timer <= 0 { continue }
		if enemy.kind == .Blue {
			rl.DrawCircleGradient(enemy.position, 20, rl.Color{50, 157, 255, 210}, rl.Color{50, 157, 255, 0})
		} else if enemy.kind == .Triangle {
			rl.DrawCircleGradient(enemy.position, 20, rl.Color{255, 219, 102, 210}, rl.Color{255, 219, 102, 0})
		}
	}
	rl.EndBlendMode()

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
