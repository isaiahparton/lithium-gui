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
	section: bool,
	name: string,
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
	if (side == .top) || (side == .bottom) {
		if .align_center in opts {
			rect.x += prev.width / 2 - size.x / 2
		} else if .align_far in opts {
			rect.x += prev.width - size.x
		}
	} else if (side == .left) || (side == .right) {
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
pop_layout :: proc() -> Rectangle {
	assert(ctx.layout_idx >= 0, "pop_layout(): Layout stack is already empty")
	self := &ctx.layout[ctx.layout_idx]
	using widget := &ctx.widget[ctx.widget_idx]
	if self.section {
		self.full_rect.x -= ctx.style.spacing
		self.full_rect.y -= ctx.style.spacing
		self.full_rect.width += ctx.style.spacing * 2
		self.full_rect.height += ctx.style.spacing * 2
	}
	ctx.layout_idx -= 1
	if ctx.layout_idx >= 0 {
		ctx.layout[ctx.layout_idx].last_rect = self.full_rect
	}
	return self.full_rect
}

begin_section :: proc(name: string) {
	push_layout()
	ctx.layout[ctx.layout_idx].section = true
	ctx.layout[ctx.layout_idx].name = name
}
end_section :: proc() {
	using ctx

	pop_layout()
	section := &layout[layout_idx + 1]
	raylib.DrawRectangleLinesEx(section.full_rect, 2, style.colors[.text])
	title_size := measure_string(style.font, section.name, f32(style.font.baseSize))
	raylib.DrawRectangleRec({section.full_rect.x + style.spacing - style.text_padding, section.full_rect.y - title_size.y / 2, title_size.x + style.text_padding * 2, title_size.y}, style.colors[.foreground])
	draw_string(style.font, section.name, {section.full_rect.x + style.spacing, section.full_rect.y - title_size.y / 2}, f32(style.font.baseSize), style.colors[.text])
}

layout_set_spacing :: proc(spacing: f32){
	ctx.layout[ctx.layout_idx].spacing = spacing
}
layout_reset_spacing :: proc(){
	layout_set_spacing(ctx.style.spacing)
}
set_size :: proc(width, height: f32){
	ctx.layout[ctx.layout_idx].size = {width, height}
}
divide_size :: proc(num: int) {
	using ctx 
	layout[layout_idx].size.x = widget[widget_idx].inner_rect.width / f32(num) - style.spacing / 2
}
layout_set_width :: proc(width: f32, relative: bool) {
	layout := &ctx.layout[ctx.layout_idx]
	layout.size.x = width
	if relative {
		layout.size.x *= layout.full_rect.width
	}
	layout.size.x -= ctx.style.padding
}
set_side :: proc(side: Rect_Side){
	ctx.layout[ctx.layout_idx].side = side
}
layout_set_last :: proc(rect: Rectangle){
	using self := &ctx.layout[ctx.layout_idx]
	last_rect = rect
	size = {rect.width, rect.height}
}