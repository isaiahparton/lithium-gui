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

	SetConfigFlags({.WINDOW_RESIZABLE})//, .MSAA_4X_HINT})
	InitWindow(1400, 900, "lithium-gui demo")
	SetTargetFPS(300)

	init_context()

	vals := [3]bool{false, false, false}
	amogus := 0
	something := ""
	name, company, address := "", "", ""

	for !WindowShouldClose() {
		ctx.width = cast(f32)GetScreenWidth()
		ctx.height = cast(f32)GetScreenHeight()
		ctx.mouse_point = transmute([2]f32)GetMousePosition()

		BeginDrawing()
		ClearBackground(ctx.style.colors[.background])

		begin()

		if begin_widget({-250, -300, 500, 600}, {0.5, 0.5, 0, 0}, "main", {}) {
			fancy_text_box(&something, "Type something here", {})
			begin_section("options")
			set_side(.right)
			checkbox(&vals[0], "first", {})
			checkbox(&vals[1], "second", {})
			checkbox(&vals[2], "third", {})
			end_section()
			divide_size(3)
			if (.submit in button("open popup", {})) {
				open_child_popup("my_popup", {0, 116}, {.align_center})
			}
			set_side(.right)
			button("hi", {})
			button("sup", {})
			end_widget()
		}
		if begin_popup("my_popup", {.expand_down}) {
			if (.submit in button("hey", {})) {
				open_child_popup("your_popup", {200, 300}, {})
			}
			if (.submit in button("bye", {})) {
				close_popup("my_popup")
			}
			end_popup()
		}
		if begin_popup("your_popup", {.expand_down}) {
			if (.submit in button("hey", {})) {
				break
			}
			if (.submit in button("bye", {})) {
				close_popup("your_popup")
			}
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

	uninit_context()
	CloseWindow()
}	
