package gui
import "vendor:raylib"
import "core:fmt"

MAX_WIDGETS :: 32
Widget :: struct {
	contents: map[Id]int,
	rect: Rectangle,
	inner_rect: Rectangle,
}

begin_widget :: proc(rect: Rectangle){
	using ctx
	widget[widget_count].rect = rect
	widget[widget_count].inner_rect = {
		rect.x + style.padding,
		rect.y + style.padding,
		rect.width - style.padding * 2,
		rect.height - style.padding * 2,
	}
	widget_count += 1
	draw_rounded_rect(rect, style.corner_radius * 2, 7, style.colors[.foreground])
}
end_widget :: proc(){
	using ctx
	widget_count -= 1
	contents := &widget[widget_count].contents
	for id, idx in contents {
		if !control.exists[idx] {
			delete_key(contents, id)
			control.reserved[idx] = false
		}
	}
}