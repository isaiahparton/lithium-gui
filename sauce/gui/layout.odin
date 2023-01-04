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
	if layout_idx > 0 {
		layout[layout_idx].last_rect = layout[layout_idx - 1].last_rect
	}
}
pop_layout :: proc() -> Rectangle {
	assert(ctx.layout_idx >= 0, "pop_layout(): Layout stack is already empty")
	self := &ctx.layout[ctx.layout_idx]
	using widget := &ctx.widget[ctx.widget_idx]
	ctx.layout_idx -= 1
	if ctx.layout_idx >= 0 {
		ctx.layout[ctx.layout_idx].last_rect = self.full_rect
	}
	return self.full_rect
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
layout_set_width :: proc(width: f32, relative: bool) {
	layout := &ctx.layout[ctx.layout_idx]
	layout.size.x = width
	if relative {
		layout.size.x *= layout.full_rect.width
	}
	layout.size.x -= ctx.style.padding
}
layout_set_side :: proc(side: Rect_Side){
	ctx.layout[ctx.layout_idx].side = side
}
layout_set_last :: proc(rect: Rectangle){
	using self := &ctx.layout[ctx.layout_idx]
	last_rect = rect
	size = {rect.width, rect.height}
}