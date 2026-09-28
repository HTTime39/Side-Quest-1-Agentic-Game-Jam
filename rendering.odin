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

crab_point :: proc(center, right, forward: rl.Vector2, radius, local_x, local_y: f32) -> rl.Vector2 {
	return rl.Vector2{
		center.x + (right.x * local_x - forward.x * local_y) * radius,
		center.y + (right.y * local_x - forward.y * local_y) * radius,
	}
}

squid_point :: proc(center, right, forward: rl.Vector2, radius, local_x, local_y: f32) -> rl.Vector2 {
	return rl.Vector2{
		center.x + (right.x * local_x - forward.x * local_y) * radius,
		center.y + (right.y * local_x - forward.y * local_y) * radius,
	}
}

draw_game :: proc(player: Player, enemies: [MAX_ENEMIES]Enemy, beams: [MAX_BEAMS]Beam, elapsed: f32, score: int, title_screen, game_over, win: bool, background_texture: rl.Texture2D, lighting_target: rl.RenderTexture2D, lighting_shader: rl.Shader, player_light_location, screen_size_location, beam_segments_location, beam_count_location: i32) {
	rl.BeginTextureMode(lighting_target)
	rl.ClearBackground(rl.Color{9, 13, 24, 255})
	rl.DrawTexturePro(background_texture, rl.Rectangle{0, 0, f32(background_texture.width), f32(background_texture.height)}, rl.Rectangle{0, 0, SCREEN_W, SCREEN_H}, rl.Vector2{}, 0, rl.Color{255, 255, 255, 255})

	// The grid makes movement and the arena boundary readable at a glance.
	for x := i32(ARENA_LEFT); x <= i32(ARENA_RIGHT); x += 32 { rl.DrawLine(x, i32(ARENA_TOP), x, i32(ARENA_BOTTOM), rl.Color{18, 27, 43, 255}) }
	for y := i32(ARENA_TOP); y <= i32(ARENA_BOTTOM); y += 32 { rl.DrawLine(i32(ARENA_LEFT), y, i32(ARENA_RIGHT), y, rl.Color{18, 27, 43, 255}) }
	rl.DrawRectangleLines(i32(ARENA_LEFT), i32(ARENA_TOP), i32(ARENA_RIGHT - ARENA_LEFT), i32(ARENA_BOTTOM - ARENA_TOP), rl.Color{50, 91, 122, 255})

	for enemy in enemies {
		if enemy.health <= 0 { continue }
		if enemy.kind == .Blue {
			p := enemy.position
			r := enemy.radius
			forward := enemy.direction
			right := rl.Vector2{-forward.y, forward.x}
			leg_shadow := rl.Color{15, 54, 96, 255}
			leg_color := rl.Color{50, 157, 255, 255}
			for side := f32(-1); side <= 1; side += 2 {
				rl.DrawLineEx(crab_point(p, right, forward, r, side * 0.55, -0.35), crab_point(p, right, forward, r, side * 1.45, -0.9), 5, leg_shadow)
				rl.DrawLineEx(crab_point(p, right, forward, r, side * 0.55, -0.35), crab_point(p, right, forward, r, side * 1.45, -0.9), 2.5, leg_color)
				rl.DrawLineEx(crab_point(p, right, forward, r, side * 0.7, 0), crab_point(p, right, forward, r, side * 1.55, 0), 5, leg_shadow)
				rl.DrawLineEx(crab_point(p, right, forward, r, side * 0.7, 0), crab_point(p, right, forward, r, side * 1.55, 0), 2.5, leg_color)
				rl.DrawLineEx(crab_point(p, right, forward, r, side * 0.55, 0.35), crab_point(p, right, forward, r, side * 1.45, 0.9), 5, leg_shadow)
				rl.DrawLineEx(crab_point(p, right, forward, r, side * 0.55, 0.35), crab_point(p, right, forward, r, side * 1.45, 0.9), 2.5, leg_color)
				rl.DrawLineEx(crab_point(p, right, forward, r, side * 0.5, -0.35), crab_point(p, right, forward, r, side, -0.95), 4, leg_shadow)
				rl.DrawCircleV(crab_point(p, right, forward, r, side, -0.95), 4, leg_color)
				rl.DrawCircleV(crab_point(p, right, forward, r, side, -0.95), 2, rl.Color{131, 213, 255, 255})
				rl.DrawLineEx(crab_point(p, right, forward, r, side * 0.28, -0.55), crab_point(p, right, forward, r, side * 0.35, -0.95), 3, leg_color)
				rl.DrawCircleV(crab_point(p, right, forward, r, side * 0.35, -0.95), 3, rl.Color{220, 245, 255, 255})
				rl.DrawCircleV(crab_point(p, right, forward, r, side * 0.35, -0.95), 1.5, rl.Color{9, 13, 24, 255})
			}
			rl.DrawCircleV(p, r + 2, leg_shadow)
			rl.DrawCircleV(p, r * 0.82, leg_color)
			rl.DrawLineEx(crab_point(p, right, forward, r, -0.55, -0.25), crab_point(p, right, forward, r, 0.55, -0.25), 2, rl.Color{131, 213, 255, 255})
		} else if enemy.kind == .Triangle {
			direction_length := math.sqrt(enemy.direction.x * enemy.direction.x + enemy.direction.y * enemy.direction.y)
			direction := rl.Vector2{enemy.direction.x / direction_length, enemy.direction.y / direction_length}
			perpendicular := rl.Vector2{-direction.y, direction.x}
			radius := enemy.radius * 1.35
			position := enemy.position
			for side := f32(-1); side <= 1; side += 2 {
				rl.DrawLineEx(squid_point(position, perpendicular, direction, radius, side * 0.2, 0.4), squid_point(position, perpendicular, direction, radius, side * 0.35, 0.85), 4, rl.Color{154, 113, 37, 255})
				rl.DrawLineEx(squid_point(position, perpendicular, direction, radius, side * 0.35, 0.85), squid_point(position, perpendicular, direction, radius, side * 0.2, 1.25), 4, rl.Color{154, 113, 37, 255})
				rl.DrawLineEx(squid_point(position, perpendicular, direction, radius, side * 0.2, 0.4), squid_point(position, perpendicular, direction, radius, side * 0.35, 0.85), 2, rl.Color{255, 219, 102, 255})
				rl.DrawLineEx(squid_point(position, perpendicular, direction, radius, side * 0.35, 0.85), squid_point(position, perpendicular, direction, radius, side * 0.2, 1.25), 2, rl.Color{255, 219, 102, 255})
				rl.DrawLineEx(squid_point(position, perpendicular, direction, radius, side * 0.4, 0.25), squid_point(position, perpendicular, direction, radius, side * 1.0, 0.6), 4, rl.Color{154, 113, 37, 255})
				rl.DrawLineEx(squid_point(position, perpendicular, direction, radius, side * 0.4, 0.25), squid_point(position, perpendicular, direction, radius, side * 1.0, 0.6), 2, rl.Color{255, 219, 102, 255})
			}
			for side := f32(-1); side <= 1; side += 2 {
				rl.DrawTriangle(
					squid_point(position, perpendicular, direction, radius, side * 0.45, 0.05),
					squid_point(position, perpendicular, direction, radius, side * 1.0, 0.55),
					squid_point(position, perpendicular, direction, radius, side * 0.35, 0.5),
					rl.Color{210, 157, 56, 255},
				)
			}
			rl.DrawTriangle(
				squid_point(position, perpendicular, direction, radius, 0, -1.55),
				squid_point(position, perpendicular, direction, radius, 1.0, 0.45),
				squid_point(position, perpendicular, direction, radius, -1.0, 0.45),
				rl.Color{154, 113, 37, 255},
			)
			rl.DrawTriangle(
				squid_point(position, perpendicular, direction, radius, 0, -1.35),
				squid_point(position, perpendicular, direction, radius, 0.78, 0.3),
				squid_point(position, perpendicular, direction, radius, -0.78, 0.3),
				rl.Color{255, 219, 102, 255},
			)
			rl.DrawCircleV(position, radius * 0.78, rl.Color{154, 113, 37, 255})
			rl.DrawCircleV(position, radius * 0.62, rl.Color{255, 219, 102, 255})
			mantle_tip := squid_point(position, perpendicular, direction, radius, 0, -0.8)
			rl.DrawCircleV(mantle_tip, radius * 0.42, rl.Color{154, 113, 37, 255})
			rl.DrawCircleV(mantle_tip, radius * 0.3, rl.Color{255, 219, 102, 255})
			for side := f32(-1); side <= 1; side += 2 {
				eye_position := squid_point(position, perpendicular, direction, radius, side * 0.38, -0.15)
				rl.DrawCircleV(eye_position, 3, rl.Color{255, 248, 207, 255})
				rl.DrawCircleV(rl.Vector2{eye_position.x + direction.x, eye_position.y + direction.y}, 1.4, rl.Color{48, 41, 27, 255})
			}
		} else {
			position := enemy.position
			radius := enemy.radius
			tentacle_shadow := rl.Color{95, 25, 54, 255}
			tentacle_color := rl.Color{255, 126, 145, 255}
			for side := f32(-1); side <= 1; side += 2 {
				rl.DrawLineEx(rl.Vector2{position.x + side * radius * 0.25, position.y + radius * 0.45}, rl.Vector2{position.x + side * radius * 0.4, position.y + radius * 1.05}, 4, tentacle_shadow)
				rl.DrawLineEx(rl.Vector2{position.x + side * radius * 0.4, position.y + radius * 1.05}, rl.Vector2{position.x + side * radius * 0.25, position.y + radius * 1.55}, 4, tentacle_shadow)
				rl.DrawLineEx(rl.Vector2{position.x + side * radius * 0.25, position.y + radius * 0.45}, rl.Vector2{position.x + side * radius * 0.4, position.y + radius * 1.05}, 2, tentacle_color)
				rl.DrawLineEx(rl.Vector2{position.x + side * radius * 0.4, position.y + radius * 1.05}, rl.Vector2{position.x + side * radius * 0.25, position.y + radius * 1.55}, 2, tentacle_color)
				rl.DrawLineEx(rl.Vector2{position.x + side * radius * 0.65, position.y + radius * 0.4}, rl.Vector2{position.x + side * radius * 0.85, position.y + radius * 0.9}, 4, tentacle_shadow)
				rl.DrawLineEx(rl.Vector2{position.x + side * radius * 0.85, position.y + radius * 0.9}, rl.Vector2{position.x + side * radius * 0.7, position.y + radius * 1.35}, 4, tentacle_shadow)
				rl.DrawLineEx(rl.Vector2{position.x + side * radius * 0.65, position.y + radius * 0.4}, rl.Vector2{position.x + side * radius * 0.85, position.y + radius * 0.9}, 2, tentacle_color)
				rl.DrawLineEx(rl.Vector2{position.x + side * radius * 0.85, position.y + radius * 0.9}, rl.Vector2{position.x + side * radius * 0.7, position.y + radius * 1.35}, 2, tentacle_color)
			}
			bell_position := rl.Vector2{position.x, position.y - radius * 0.15}
			rl.DrawCircleV(bell_position, radius + 3, tentacle_shadow)
			rl.DrawCircleV(bell_position, radius * 0.82, rl.Color{238, 77, 91, 255})
			rl.DrawCircleV(rl.Vector2{position.x - radius * 0.28, position.y - radius * 0.42}, radius * 0.16, rl.Color{255, 180, 190, 255})
			for side := f32(-1); side <= 1; side += 2 {
				eye_position := rl.Vector2{position.x + side * radius * 0.3, position.y + radius * 0.12}
				rl.DrawCircleV(eye_position, 2.5, rl.Color{255, 235, 220, 255})
				rl.DrawCircleV(rl.Vector2{eye_position.x + side * 0.5, eye_position.y + 0.2}, 1.2, rl.Color{70, 20, 36, 255})
			}
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
	fish_forward := player.aim_direction
	fish_right := rl.Vector2{-fish_forward.y, fish_forward.x}
	fish_radius: f32 = 17
	rl.DrawTriangle(
		squid_point(player.position, fish_right, fish_forward, fish_radius, 0, 1.15),
		squid_point(player.position, fish_right, fish_forward, fish_radius, 0.4, 0.55),
		squid_point(player.position, fish_right, fish_forward, fish_radius, -0.4, 0.55),
		rl.Color{50, 157, 140, 255},
	)
	rl.DrawTriangle(
		squid_point(player.position, fish_right, fish_forward, fish_radius, 0, -1.0),
		squid_point(player.position, fish_right, fish_forward, fish_radius, -1.25, 0.35),
		squid_point(player.position, fish_right, fish_forward, fish_radius, 1.25, 0.35),
		rl.Color{50, 157, 140, 255},
	)
	rl.DrawCircleV(player.position, fish_radius * 0.78, player_color)
	rl.DrawLineEx(
		squid_point(player.position, fish_right, fish_forward, fish_radius, 0, -0.58),
		squid_point(player.position, fish_right, fish_forward, fish_radius, 0, -0.88),
		2,
		rl.Color{9, 35, 43, 255},
	)
	for side := f32(-1); side <= 1; side += 2 {
		eye_position := squid_point(player.position, fish_right, fish_forward, fish_radius, side * 0.36, -0.28)
		rl.DrawCircleV(eye_position, 3, rl.Color{230, 248, 220, 255})
		rl.DrawCircleV(rl.Vector2{eye_position.x + fish_forward.x, eye_position.y + fish_forward.y}, 1.3, rl.Color{9, 35, 43, 255})
	}
	lure_base := squid_point(player.position, fish_right, fish_forward, fish_radius, 0, -0.7)
	lure_bend := squid_point(player.position, fish_right, fish_forward, fish_radius, 0, -1.05)
	lure_tip := squid_point(player.position, fish_right, fish_forward, fish_radius, 0, -1.15)
	rl.DrawLineEx(lure_base, lure_bend, 2, rl.Color{72, 211, 176, 255})
	rl.DrawLineEx(lure_bend, lure_tip, 2, rl.Color{72, 211, 176, 255})
	rl.DrawCircleV(lure_tip, 5, rl.Color{255, 219, 102, 255})
	rl.DrawCircleV(lure_tip, 2.5, rl.Color{255, 248, 207, 255})
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
	if title_screen {
		rl.DrawRectangle(0, 0, SCREEN_W, SCREEN_H, rl.Color{4, 7, 15, 240})
		rl.DrawText("EDGE//BREAK", 335, 180, 64, rl.Color{72, 211, 176, 255})
		rl.DrawText("SURVIVE THE SIGNAL", 396, 270, 24, rl.Color{150, 180, 190, 255})
		rl.DrawText("MOVE   WASD / ARROWS", SCREEN_W / 2 - rl.MeasureText("MOVE   WASD / ARROWS", 32) / 2, 365, 32, rl.Color{220, 235, 238, 255})
		rl.DrawText("FIRE   I / J / K / L", SCREEN_W / 2 - rl.MeasureText("FIRE   I / J / K / L", 32) / 2, 420, 32, rl.Color{220, 235, 238, 255})
		rl.DrawText("DASH   SPACE", SCREEN_W / 2 - rl.MeasureText("DASH   SPACE", 32) / 2, 475, 32, rl.Color{220, 235, 238, 255})
		rl.DrawText("PRESS ANY KEY TO BEGIN", 375, 585, 24, rl.Color{255, 219, 102, 255})
	}
	rl.EndDrawing()
}
