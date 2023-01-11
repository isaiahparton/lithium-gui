package gui
import "vendor:raylib"
import "core:fmt"
import "core:runtime"
import "core:strings"
import "core:math"
import "core:os"
import "core:math/rand"

main :: proc(){
	using raylib

	SetConfigFlags({.WINDOW_RESIZABLE})
	InitWindow(1400, 900, "lithium-gui demo")
	SetTargetFPS(300)

	init_context()

	vals := [3]bool{false, false, false}
	something := ""

	for !WindowShouldClose() {
		ctx.width = cast(f32)GetScreenWidth()
		ctx.height = cast(f32)GetScreenHeight()
		ctx.mouse_point = transmute([2]f32)GetMousePosition()

		BeginDrawing()
		ClearBackground(ctx.style.colors[.background])

		begin()

		if begin_widget({-200, -200, 400, 400}, {0.5, 0.5, 0, 0}, "main", {}) {
			defer end_widget()

			menu("menu", {})
		}

		if begin_popup("menu", {.auto_resize}) {
			set_height(30)
			set_spacing(0)
			for i in 0..=3 {
				ctx.loc_offset = i
				if .submit in button(fmt.aprintf("Button %i", i), {.subtle}) {
					close_widget()
				}
			}
			set_spacing(12)
			checkbox(&vals[0], "Option", {})
			end_popup()
		}

		draw_string(ctx.style.font, fmt.aprintf("%i fps", GetFPS()), {0, 0}, 26, BLACK)
		draw_string(ctx.style.font, count_noun(ctx.control_count, "control"), {0, 26}, 26, BLACK)
		draw_string(ctx.style.font, count_noun(ctx.widget_count, "widget"), {0, 54}, 26, BLACK)

		end()

		EndDrawing()
	}

	uninit_context()
	CloseWindow()
}	
