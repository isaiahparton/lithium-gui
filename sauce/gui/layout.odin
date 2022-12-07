package gui
import "vendor:raylib"

Rect_Side :: enum {
	top,
	bottom,
	left,
	right,
}

MAX_LAYOUTS :: 8
Layout :: struct {
	size: [2]f32,
	side: Rect_Side,
	spacing: f32,
	first_rect, last_rect, full_rect: Rectangle,
}

push_layout :: proc(){
	using ctx
	layout_index += 1
	assert(layout_index < MAX_LAYOUTS, "uh...")
	layout[layout_index] = {}
}
push_attached_layout :: proc(side: Rect_Side){
	using ctx
	assert(layout_index >= 0)
	push_layout()
	layout_set_side(side)
	layout[layout_index].last_rect = layout[layout_index - 1].last_rect
}
pop_layout :: proc(){
	using ctx
	layout_index -= 1
}

layout_set_size :: proc(width, height: f32){
	ctx.layout[ctx.layout_index].size = {width, height}
}
layout_set_side :: proc(side: Rect_Side){
	ctx.layout[ctx.layout_index].side = side
}
layout_place_at :: proc(relative: Rectangle, absolute: Rectangle, opts: Option_Set){
	using ctx
	inner_rect := &ctx.widget[ctx.widget_count - 1].inner_rect
	rect := Rectangle{
		inner_rect.x + inner_rect.width * relative.x + absolute.x,
		inner_rect.y + inner_rect.height * relative.y + absolute.y,
		inner_rect.width * relative.width + absolute.width,
		inner_rect.height * relative.height + absolute.height,
	}
	set_rect = true
	ctx.layout[ctx.layout_index].first_rect = rect
}
layout_set_last :: proc(rect: Rectangle){
	ctx.layout[ctx.layout_index].last_rect = rect
}