package gui
import "vendor:raylib"
import "core:fmt"

Rect_Side :: enum {
	bottom = 0,
	left,
	top,
	right,
}

MAX_LAYOUTS :: 8
Layout :: struct {
	size: [2]f32,
	side: Rect_Side,
	spacing: f32,
	first_rect, last_rect, full_rect: Rectangle,
}

get_next_rect :: proc(prev: Rectangle, size: [2]f32, side: Rect_Side, opts: Option_Set) -> Rectangle {
	using ctx
	rect := Rectangle{}
	if .inner in opts {
		if side == .top {
			rect = {prev.x, prev.y + style.spacing, size.x, size.y}
		} else if side == .bottom {
			rect = {prev.x, prev.y + prev.height - size.y - style.spacing, size.x, size.y}
		} else if side == .left {
			rect = {prev.x + style.spacing, prev.y, size.x, size.y}
		} else if side == .right {
			rect = {prev.x + prev.width - size.x - style.spacing, prev.y, size.x, size.y}
		}
	} else {
		if side == .top {
			rect = {prev.x, prev.y - size.y - style.spacing, size.x, size.y}
		} else if side == .bottom {
			rect = {prev.x, prev.y + prev.height + style.spacing, size.x, size.y}
		} else if side == .left {
			rect = {prev.x - size.x - style.spacing, prev.y, size.x, size.y}
		} else if side == .right {
			rect = {prev.x + prev.width + style.spacing, prev.y, size.x, size.y}
		}
	}
	if side == .top | .bottom {
		if .align_center in opts {
			rect.x += prev.width / 2 - size.x / 2
		} else if .align_far in opts {
			rect.x += prev.width - size.x
		}
	} else if side == .left | .right {
		if .align_center in opts {
			rect.y += prev.height / 2 - size.y / 2
		} else if .align_far in opts {
			rect.y += prev.height - size.y
		}
	}
	return rect
}

push_layout :: proc(){
	using ctx
	assert(layout_idx < MAX_LAYOUTS, "push_layout(): Layout stack overflow")
	layout_idx += 1
	layout[layout_idx] = {
		spacing = style.spacing,
		full_rect = {width, height, 0, 0},
	}
}
push_attached_layout :: proc(side: Rect_Side){
	using ctx
	push_layout()
	layout[layout_idx] = layout[layout_idx - 1]
	layout[layout_idx].side = side
}
pop_layout :: proc(){
	assert(ctx.layout_idx >= 0, "pop_layout(): Layout stack is already empty")
	self := &ctx.layout[ctx.layout_idx]
	//raylib.DrawRectangleRec(self.full_rect, {0, 0, 255, 25})
	using widget := &ctx.widget[ctx.widget_idx]
	space.x = max(space.x, (self.full_rect.width + self.full_rect.x) - rect.x + offset.x)
	space.y = max(space.y, (self.full_rect.height + self.full_rect.y) - rect.y + offset.y)
	ctx.layout_idx -= 1
}

layout_set_spacing :: proc(spacing: f32){
	ctx.layout[ctx.layout_idx].spacing = spacing
}
layout_reset_spacing :: proc(){
	layout_set_spacing(ctx.style.spacing)
}
layout_set_size :: proc(width, height: f32){
	ctx.layout[ctx.layout_idx].size = {width, height}
}
layout_set_side :: proc(side: Rect_Side){
	ctx.layout[ctx.layout_idx].side = side
}
layout_place_at :: proc(relative: Rectangle, absolute: Rectangle, opts: Option_Set){
	using ctx
	inner_rect := &ctx.widget[ctx.widget_idx].inner_rect
	rect := Rectangle{
		inner_rect.x + inner_rect.width * relative.x + absolute.x,
		inner_rect.y + inner_rect.height * relative.y + absolute.y,
		inner_rect.width * relative.width + absolute.width,
		inner_rect.height * relative.height + absolute.height,
	}
	set_rect = true
	ctx.layout[ctx.layout_idx].size = {rect.width, rect.height}
	ctx.layout[ctx.layout_idx].first_rect = rect
}
layout_set_last :: proc(rect: Rectangle){
	using self := &ctx.layout[ctx.layout_idx]
	last_rect = rect
	size = {rect.width, rect.height}
}