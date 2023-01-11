package gui
import "vendor:raylib"
import "core:fmt"

Direction :: enum {
	down = 0,
	left,
	up,
	right,
}

MAX_LAYOUTS :: 8
Layout :: struct {
	origin, offset, size: [2]f32,
	column, opposite, section: bool,
	rect: Rectangle,
	spacing: f32,
	tag: string,
}

get_next_rect :: proc(prev: Rectangle, size: [2]f32, spacing: f32, dir: Direction, opts: Option_Set) -> Rectangle {
	using ctx
	rect := Rectangle{}
	if .inner in opts {
		if dir == .up {
			rect = {prev.x, prev.y + spacing, size.x, size.y}
		} else if dir == .down {
			rect = {prev.x, prev.y + prev.height - size.y - spacing, size.x, size.y}
		} else if dir == .left {
			rect = {prev.x + spacing, prev.y, size.x, size.y}
		} else if dir == .right {
			rect = {prev.x + prev.width - size.x - spacing, prev.y, size.x, size.y}
		}
	} else {
		if dir == .up {
			rect = {prev.x, prev.y - size.y - spacing, size.x, size.y}
		} else if dir == .down {
			rect = {prev.x, prev.y + prev.height + spacing, size.x, size.y}
		} else if dir == .left {
			rect = {prev.x - size.x - spacing, prev.y, size.x, size.y}
		} else if dir == .right {
			rect = {prev.x + prev.width + spacing, prev.y, size.x, size.y}
		}
	}
	if (dir == .up) || (dir == .down) {
		if .align_center in opts {
			rect.x += prev.width / 2 - size.x / 2
		} else if .align_far in opts {
			rect.x += prev.width - size.x
		}
	} else if (dir == .left) || (dir == .right) {
		if .align_center in opts {
			rect.y += prev.height / 2 - size.y / 2
		} else if .align_far in opts {
			rect.y += prev.height - size.y
		}
	}
	return rect
}

push_layout :: proc(opposite: bool) {
	using ctx
	assert(layout_idx < MAX_LAYOUTS, "push_layout(): Layout stack overflow")
	parent := &layout_data[layout_idx]
	origin := parent.origin
	column := !parent.column
	if column {
		origin.x += parent.offset.x
	} else {
		origin.y += parent.offset.y
	}
	layout_idx += 1
	layout_data[layout_idx] = {
		spacing = style.spacing,
		origin = origin,
		column = column,
		opposite = opposite,
	}
}
pop_layout :: proc() {
	using ctx
	assert(ctx.layout_idx >= 0, "pop_layout(): Layout stack is already empty")
	prev_ly := &layout_data[layout_idx]
	layout_idx -= 1
	ly := &layout_data[layout_idx]
	if prev_ly.column {
		ly.offset.x += prev_ly.offset.x + style.spacing
		ly.offset.y = max(ly.offset.y, prev_ly.offset.y)
	} else {
		ly.offset.y += prev_ly.offset.y
		ly.offset.x = max(ly.offset.x, prev_ly.offset.x)
	}
}

set_size :: proc(x, y: f32){
	using ctx
	layout_data[layout_idx].size = {x, y}
}
set_height :: proc(height: f32){
	using ctx
	layout_data[layout_idx].size.y = height
}
set_spacing :: proc(spacing: f32){
	using ctx
	layout_data[layout_idx].spacing = spacing
}
reset_spacing :: proc(){
	using ctx
	set_spacing(style.spacing)
}