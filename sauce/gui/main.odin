package gui
import "vendor:raylib"
import "core:fmt"
import "core:strings"
import "core:math"
import "core:os"

main :: proc(){
	using raylib

	frame := 0
	title := ""
	{
		data, ok := os.read_entire_file("title.txt")
		if ok {
			title = string(data)
		}
	}
	val := false

	SetConfigFlags({.WINDOW_RESIZABLE, .MSAA_4X_HINT})
	InitWindow(1000, 800, strings.clone_to_cstring(title))
	SetTargetFPS(300)

	init_context()

	for !WindowShouldClose() {
		ctx.width = cast(f32)GetScreenWidth()
		ctx.height = cast(f32)GetScreenHeight()
		ctx.mouse_point = transmute([2]f32)GetMousePosition()

		BeginDrawing()
		ClearBackground(ctx.style.colors[.background])

		begin()

		if begin_widget({ctx.width / 2 - 400, ctx.height / 2 - 300, 800, 600}) {
			push_layout()

			layout_place_at({width=1}, {0, 0, 0, 55}, {})
			if .change in text_box(&title, "Window title", {}) {
				SetWindowTitle(strings.clone_to_cstring(title))
			}
			layout_set_size(120, 30)
			layout_set_side(.bottom)

			if .submit in button("Open Menu", {}) {

			}
			push_attached_layout(.right)
			checkbox(&val, "On" if val else "Off", {})

			pop_layout()
			end_widget()
		}

		if begin_widget({ctx.width / 2 - 200, ctx.height / 2 - 200, 400, 400}){
			push_layout()
			layout_place_at({}, {0, 0, 200, 30}, {})
			if .submit in button("bring to front", {}) {

			}
			pop_layout()
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