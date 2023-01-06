package gui
import "vendor:raylib"
import "core:fmt"

MAX_WIDGETS :: 16
TITLE_BAR_HEIGHT :: 40
SHADOW_SPACE :: 32

WidgetIndex :: u8

Widget :: struct {
	exists, hidden: bool,
	time: f32,
	title: string,
	contents: map[Id]int,
	rect, inner_rect: Rectangle,
	space, tex_offset: [2]f32,
	z: int,
	id: Id,
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
	//--- not found, init a new one ---//
	for i := 0; i < MAX_WIDGETS; i += 1 {
		if !widget_reserved[i] {
			idx = i
			widget[i] = {id = id, exists = true, hidden = (.hidden in opts)}
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

toggle_widget :: proc(name: string){
	widget := _get_widget(name, {})
	widget.hidden = !widget.hidden
}
set_widget_hidden :: proc(name: string, hidden: bool) {
	_get_widget(name, {}).hidden = hidden
}

begin_widget :: proc(rect: Rectangle, title: string, opts: Option_Set, loc := #caller_location) -> bool {
	using ctx
	assert(title != "", "begin_widget(): Missing widget title")
	assert(widget_count + 1 < MAX_WIDGETS, "begin_widget(): Widget stack overflow")
	idx := _get_widget_idx(title, opts)
	if idx < 0 {
		return false
	}
	self := &widget[idx]
	//--- check if the widget exists and is open ---//
	if (self == nil) || (self.hidden) {
		return false
	}
	//--- update widget data ---//
	self.exists = true
	self.title = title
	self.opts = opts
	self.rect = rect
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
	widget_hover = (active_widget == idx)
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
	expanded_rect := expand_rect(self.rect, 41)
	raylib.DrawTextureNPatch(shadow_tex, widget_npatch, expanded_rect, {}, 0, raylib.WHITE)
	raylib.DrawTextureNPatch(widget_tex, widget_npatch, expanded_rect, {}, 0, style.colors[.foreground])
	push_layout()
	return true
}
end_widget :: proc(){
	using ctx
	pop_layout()
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

begin_popup :: proc(name: string, opts: Option_Set, loc := #caller_location) -> bool {

	return true
}
end_popup :: proc(){

}