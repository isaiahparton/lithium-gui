package gui
import "vendor:raylib"
import "core:fmt"
import "core:strings"
import "core:math"
import "core:os"
import "core:math/rand"

main :: proc(){
	using raylib

	frame := 0
	title := ""
	text := ""
	{
		data, ok := os.read_entire_file("title.txt")
		if ok {
			title = string(data)
		}
	}
	val := false
	lo, hi := f32(0), f32(100)
	num := f32(0)

	SetConfigFlags({.WINDOW_RESIZABLE})//, .MSAA_4X_HINT})
	InitWindow(1400, 900, strings.clone_to_cstring(title))
	SetTargetFPS(300)

	init_context()

	for !WindowShouldClose() {
		ctx.width = cast(f32)GetScreenWidth()
		ctx.height = cast(f32)GetScreenHeight()
		ctx.mouse_point = transmute([2]f32)GetMousePosition()

		BeginDrawing()
		ClearBackground(ctx.style.colors[.background])

		begin()

		if begin_widget({ctx.width / 2 + 50, ctx.height / 2 - 300, 400, 600}, title, {} if val else {.no_title_bar}) {
			text_box(&title, "Window title", {})
			if .submit in button("Open Menu", {}) {

			}
			end_widget()
		}
		if begin_widget({ctx.width / 2 - 450, ctx.height / 2 - 300, 400, 600}, title, {} if val else {.no_title_bar}) {
			checkbox(&val, "Menu bars", {})
			slider(&ctx.style.corner_radius, 0, 10, {})
			text(fmt.aprintf(ctx.style.corner_radius), .near, .near, {})
			end_widget()
		}

		draw_string(ctx.style.font, fmt.aprintf("%i fps", GetFPS()), {0, 0}, 26, BLACK)
		draw_string(ctx.style.font, count_noun(ctx.control_count, "control"), {0, 26}, 26, BLACK)
		draw_string(ctx.style.font, count_noun(ctx.widget_count, "widget"), {0, 54}, 26, BLACK)

		end()

		frame += 1
		//fmt.println(frame)
		
		//DrawFPS(0, 0)

		EndDrawing()
	}

	os.write_entire_file("title.txt", transmute([]u8)title, true)
}	