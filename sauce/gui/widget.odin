package gui
import "vendor:raylib"
import "core:fmt"

MAX_WIDGETS :: 32
Widget :: struct {
	reserved: bool,
	contents: map[Id]int,
	rect: Rectangle,
	inner_rect: Rectangle,
	offset: [2]f32,
}

begin_widget :: proc(rect: Rectangle, loc := #caller_location){
	using ctx
	id := get_loc_id(loc)
	idx, ok = widget_map[id]
	if !ok {
		for i := 0; i < MAX_CONTROLS; i += 1 {
			if !widget.reserved[i] {
				idx = i
				widget[i] = {}
			}
		}
	}
	widget[idx].reserved = true
	widget[idx].rect = rect
	widget[idx].inner_rect = {
		rect.x + style.padding,
		rect.y + style.padding,
		rect.width - style.padding * 2,
		rect.height - style.padding * 2,
	}
	widget_count += 1
	draw_rounded_rect(rect, style.corner_radius * 2, 7, style.colors[.foreground])
	raylib.BeginScissorMode(i32(rect.x), i32(rect.y), i32(rect.width), i32(rect.height))
}
end_widget :: proc(){
	using ctx
	raylib.EndScissorMode()
	widget_count -= 1
	contents := &widget[widget_count].contents
	for id, idx in contents {
		if !control.exists[idx] {
			delete_key(contents, id)
			control.reserved[idx] = false
		}
	}
}