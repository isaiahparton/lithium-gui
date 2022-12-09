package gui
import "vendor:raylib"
import "core:fmt"
import "core:strings"

main :: proc(){
	using raylib

	frame := 0
	title := "Glory to God in the highest, and on earth peace, goodwill toward men"
	val := false
	vals := [77]f32{}

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

			layout_place_at({}, {0, 0, 300, 40}, {})
			if .change in text_box(&title, {}) {
				SetWindowTitle(strings.clone_to_cstring(title))
			}
			layout_set_size(300, 30)
			layout_set_side(.bottom)

			for i in 0..=77 {
				ctx.loc_offset = i
				if .submit in button(fmt.aprintf("button %i", i), {}) {
					fmt.println(i)
				}
			}

			pop_layout()
			end_widget()
		}

		draw_string(ctx.style.font, fmt.aprintf("%i fps", GetFPS()), {0, 0}, 26, BLACK)
		draw_string(ctx.style.font, fmt.aprintf("%i controls", ctx.control_count), {0, 26}, 26, BLACK)
		draw_string(ctx.style.font, fmt.aprintf("%i widgets", ctx.widget_count), {0, 54}, 26, BLACK)

		end()

		frame += 1
		//fmt.println(frame)
		
		//DrawFPS(0, 0)

		EndDrawing()
	}
}	