package gui
import "vendor:raylib"
import "core:fmt"
import "core:strings"

main :: proc(){
	using raylib

	title := "GUI Demo"
	val := false

	SetConfigFlags({.WINDOW_RESIZABLE, .MSAA_4X_HINT})
	InitWindow(1000, 800, strings.clone_to_cstring(title))
	SetTargetFPS(300)

	init_context()

	for !WindowShouldClose() {
		ctx.width = cast(f32)GetScreenWidth()
		ctx.height = cast(f32)GetScreenHeight()

		BeginDrawing()
		ClearBackground(ctx.style.colors[.background])

		begin()

		begin_widget({ctx.width / 2 - 400, ctx.height / 2 - 300, 800, 600})

		push_layout()

		layout_place_at({}, {0, 0, 300, 40}, {})
		if .change in text_box(&title, {}) {
			SetWindowTitle(strings.clone_to_cstring(title))
		}
		layout_set_size(300, 30)
		layout_set_side(.bottom)

		text("Corner roundness", .near, .near, {})
		slider(&ctx.style.corner_radius, 0, 12, {})
		push_attached_layout(.right)
		text(fmt.aprint(ctx.style.corner_radius), .near, .center, {})
		pop_layout()

		text("Padding", .near, .near, {})
		slider(&ctx.style.padding, 0, 30, {})
		push_attached_layout(.right)
		text(fmt.aprint(ctx.style.padding), .near, .center, {})
		pop_layout()

		text("Spacing", .near, .near, {})
		slider(&ctx.style.spacing, 0, 20, {})
		push_attached_layout(.right)
		text(fmt.aprint(ctx.style.spacing), .near, .center, {})
		pop_layout()

		text("Depth", .near, .near, {})
		slider(&ctx.style.depth, 0, 20, {})
		push_attached_layout(.right)
		text(fmt.aprint(ctx.style.depth), .near, .center, {})
		pop_layout()

		text("Outline thickness", .near, .near, {})
		slider(&ctx.style.outline_thick, 0, 3, {})
		push_attached_layout(.right)
		text(fmt.aprint(ctx.style.outline_thick), .near, .center, {})
		pop_layout()

		tick_box(&val, "On" if val else "Off", {})

		pop_layout()

		push_layout()
		layout_set_size(200, 30)
		layout_set_side(.bottom)
		layout_place_at({x=1}, {-200, 0, 200, 40}, {})
		for i in 0..=15 {
			ctx.loc_offset = i
			button(fmt.aprint("button", i), {.in_loop})
		}
		ctx.loc_offset = 0;
		pop_layout()

		end_widget()

		end()

		draw_icon({0, 0}, .star, .near, .near, DARKGRAY)
		
		//DrawFPS(0, 0)

		EndDrawing()
	}
}	