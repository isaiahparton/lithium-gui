package gui
import "vendor:raylib"
import "core:fmt"
import "core:strings"
import "core:math"
import "core:os"
import "core:math/rand"

main :: proc(){
	using raylib

	vals := [3]bool{false, false, false}
	amogus := 0
	text1, text2 := "", ""
	clr := [4]f32{}

	SetConfigFlags({.WINDOW_RESIZABLE})//, .MSAA_4X_HINT})
	InitWindow(1400, 900, "lithium-gui demo")
	SetTargetFPS(300)

	init_context()

	for !WindowShouldClose() {
		ctx.width = cast(f32)GetScreenWidth()
		ctx.height = cast(f32)GetScreenHeight()
		ctx.mouse_point = transmute([2]f32)GetMousePosition()

		BeginDrawing()
		ClearBackground(ctx.style.colors[.background])

		begin()

		if begin_widget({50, 50, ctx.width / 2 - 75, ctx.height - 100}, "Main Stuff", {}) {
			text("fancy text input", .near, .near, {})
			fancy_text_box(&text1, "Type something here", {})
			text("regular text input", .near, .near, {})
			text_box(&text2, {})
			push_layout()
			checkbox(&vals[0], "first", {})
			layout_set_side(.right)
			checkbox(&vals[1], "second", {})
			checkbox(&vals[2], "third", {})
			pop_layout()
			button("CLICK ME", {})
			button("SUBTLE", {.subtle})
			end_widget()
		}
		if begin_widget({ctx.width / 2 + 25, 50, ctx.width / 2 - 75, ctx.height - 100}, "Other Stuff", {}) {
			res := Result_Set{}
			res += slider(&clr.r, 0, 1, "R", {})
			res += slider(&clr.g, 0, 1, "G", {})
			res += slider(&clr.b, 0, 1, "B", {})
			res += slider(&clr.a, 0, 1, "A", {})
			res += f32_box(&clr.r, {})
			res += f32_box(&clr.g, {})
			res += f32_box(&clr.b, {})
			res += f32_box(&clr.a, {})
			if .change in res {
				ctx.style.colors[.background] = {u8(clr.r * 255), u8(clr.g * 255), u8(clr.b * 255), u8(clr.a * 255)}
			}
			//knob(&ctx.style.corner_radius, 0, 10, "hi",  {})
			end_widget()
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
