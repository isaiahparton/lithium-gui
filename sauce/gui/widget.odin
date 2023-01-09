package gui
import "vendor:raylib"
import "core:fmt"

MAX_WIDGETS :: 16
TITLE_BAR_HEIGHT :: 40
SHADOW_SPACE :: 32

WidgetIndex :: u8

Widget :: struct {
	exists, closing: bool,
	time, opacity: f32,
	title: string,
	contents: map[Id]int,
	rect, inner_rect: Rectangle,
	space, tex_offset: [2]f32,
	id: Id,
	z: int,
	opts: Option_Set,
}

@private
_get_widget_idx :: proc(title: string, opts: Option_Set) -> int {
	using ctx
	//--- hash the caller location and lookup ---//
	id := get_id_string(title)
	idx, ok := widget_map[id]
	if ok {
		return idx
	}
	//--- if the widget is supposed to be closed initially, don't create it ---//
	if .closed in opts {
		return -1
	}
	//--- not found, init a new one ---//
	for i := 0; i < MAX_WIDGETS; i += 1 {
		if !widget_reserved[i] {
			idx = i
			widget[i] = {id = id, exists = true}
			widget_map[id] = idx
			widget_reserved[idx] = true
			append(&widget_stack, i)
			return idx
		}
	}
	return -1
}
@private
_get_widget :: proc(title: string, opts: Option_Set) -> ^Widget {
	return &ctx.widget[_get_widget_idx(title, opts)]
}
@private
_bring_to_top :: proc(idx: int) {
	using ctx
	top := len(widget_stack) - 1
	top_idx := widget_stack[top]
	copy(widget_stack[top:], widget_stack[top + 1:])
	widget_stack[idx] = top_idx
}

@private
_create_widget :: proc(id: Id) -> int {
	using ctx
	for i := 0; i < MAX_WIDGETS; i += 1 {
		if !widget_reserved[i] {
			widget[i] = {id = id, exists = true}
			widget_map[id] = i
			widget_reserved[i] = true
			append(&widget_stack, i)
			return i
		}
	}
	return -1
}
@private
_destroy_widget :: proc(idx: int) {
	using ctx
	
}

begin_widget :: proc(a_rect, r_rect: Rectangle, title: string, opts: Option_Set) -> bool {
	using ctx
	assert(title != "", "begin_widget(): Missing widget title")
	assert(widget_count + 1 < MAX_WIDGETS, "begin_widget(): Widget stack overflow")
	idx := _get_widget_idx(title, opts)
	if idx < 0 {
		return false
	}
	self := &widget[idx]
	//--- check if the widget exists and is open ---//
	if (self == nil) {
		return false
	}
	//--- update widget data ---//
	self.exists = true
	self.title = title
	self.opts = opts
	self.rect = {
		a_rect.x + r_rect.x * width,
		a_rect.y + r_rect.y * height,
		a_rect.width + r_rect.width * width,
		a_rect.height + r_rect.height * height,
	}
	self.inner_rect = {
		self.rect.x + style.padding,
		self.rect.y + style.padding,
		self.rect.width - style.padding * 2,
		self.rect.height - style.padding * 2,
	}
	self.space = {}
	widget_rect = self.rect
	//--- current widget state ---//
	widget_count += 1
	widget_idx = idx
	widget_hover = (active_widget == idx && widget_stack[len(widget_stack) - 1] == idx)
	//--- setup surface area for drawing ---//
	raylib.BeginTextureMode(panel_tex)
	if widget_count == 1 {
		raylib.ClearBackground({})
		tex_offset = {}
		max_panel_height = 0
	}
	raylib.rlPushMatrix()
	raylib.rlTranslatef(tex_offset.x - self.rect.x + SHADOW_SPACE, tex_offset.y - self.rect.y + SHADOW_SPACE, 0)
	self.tex_offset = tex_offset
	if tex_offset.x + self.rect.width > f32(panel_tex.texture.width) {
		tex_offset.x = 0
		tex_offset.y += max_panel_height + SHADOW_SPACE * 2
	} else {
		tex_offset.x += self.rect.width + SHADOW_SPACE * 2
	}
	max_panel_height = max(max_panel_height, self.rect.height)
	radius := style.corner_radius * 2
	expanded_rect := expand_rect(self.rect, 32)
	raylib.DrawTextureNPatch(shadow_tex, widget_npatch, expanded_rect, {}, 0, raylib.WHITE)
	raylib.DrawTextureNPatch(widget_tex, widget_npatch, expanded_rect, {}, 0, style.colors[.foreground])
	push_layout()
	return true
}
end_widget :: proc(){
	using ctx
	using raylib
	pop_layout()
	expanded_rect := expand_rect(widget[widget_idx].rect, 32)
	raylib.DrawTextureNPatch(widget_tex, widget_npatch, expanded_rect, {}, 0, Fade(WHITE, (1.0 - widget[widget_idx].opacity) * 0.35))
	raylib.rlPopMatrix()
	raylib.EndTextureMode()

	self := &widget[widget_idx]
	
	//--- delete entries for controls that don't exist ---//
	for id, idx in self.contents {
		if !control.exists[idx] {
			delete_key(&self.contents, id)
			control.reserved[idx] = false
		}
	}
}

open_popup :: proc(idx: int) {

}
close_popup :: proc(idx: int) {
	ctx.widget[idx].closing = true
}
toggle_popup :: proc(name: string) {
	using ctx
	id := get_id_string(name)
	idx, ok := widget_map[id]
	if ok {
		widget[idx].closing = true
	} else {
		_create_widget(id)
	}
}

begin_popup :: proc(a_rect, r_rect: Rectangle, name: string, opts: Option_Set) -> bool {
	return begin_widget(a_rect, r_rect, name, opts + {.closed, .popup, .topmost})
}
end_popup :: proc(){
	end_widget()
}