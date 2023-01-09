package gui
import "vendor:raylib"
import "core:fmt"
import "core:strings"
import "core:math"
import "core:os"
import "core:math/rand"

main :: proc(){
	using raylib

	SetConfigFlags({.WINDOW_RESIZABLE})//, .MSAA_4X_HINT})
	InitWindow(1400, 900, "lithium-gui demo")
	SetTargetFPS(300)

	init_context()

	vals := [3]bool{false, false, false}
	amogus := 0
	text1, text2 := "", ""

	for !WindowShouldClose() {
		ctx.width = cast(f32)GetScreenWidth()
		ctx.height = cast(f32)GetScreenHeight()
		ctx.mouse_point = transmute([2]f32)GetMousePosition()

		BeginDrawing()
		ClearBackground(ctx.style.colors[.background])

		begin()

		if begin_widget({-300, -300, 600, 600}, {0.5, 0.5, 0, 0}, "main", {}) {
			text("fancy text input", .near, .near, {})
			fancy_text_box(&text1, "Type something here", {})
			text("regular text input", .near, .near, {})
			text_box(&text2, {})
			push_layout()
			set_side(.right)
			checkbox(&vals[0], "first", {})
			checkbox(&vals[1], "second", {})
			checkbox(&vals[2], "third", {})
			pop_layout()
			if (.submit in button("toggle color picker", {})) || IsKeyPressed(.F) {
				toggle_popup("color")
			}
			end_widget()
		}
		if begin_popup({-200, 20, 400, 400}, {0.5, 0.5, 0, 0}, "color", {.expand_down}) {
			u8_slider(&ctx.style.colors[.background].r, 0, 255, "R", {})
			u8_slider(&ctx.style.colors[.background].g, 0, 255, "G", {})
			u8_slider(&ctx.style.colors[.background].b, 0, 255, "B", {})
			u8_slider(&ctx.style.colors[.background].a, 0, 255, "A", {})
			end_popup()
		}
		

		draw_string(ctx.style.font, fmt.aprintf("%i fps", GetFPS()), {0, 0}, 26, BLACK)
		draw_string(ctx.style.font, count_noun(ctx.control_count, "control"), {0, 26}, 26, BLACK)
		draw_string(ctx.style.font, count_noun(ctx.widget_count, "widget"), {0, 54}, 26, BLACK)

		end()

		//fmt.println(frame)
		
		//DrawFPS(0, 0)

		EndDrawing()
	}
}	
