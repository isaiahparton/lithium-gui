package gui
import "vendor:raylib"
import "core:fmt"

MAX_WIDGETS :: 16
TITLE_BAR_HEIGHT :: 40
WidgetIndex :: u8

Widget :: struct {
	exists: bool,
	time: f32,
	title: string,
	contents: map[Id]int,
	rect, inner_rect: Rectangle,
	space, tex_offset: [2]f32,
	z: int,
	id: Id,
	opts: Option_Set,
}

begin_widget :: proc(rect: Rectangle, title: string, opts: Option_Set, loc := #caller_location) -> bool {
	using ctx
	assert(widget_count + 1 < MAX_WIDGETS, "begin_widget(): Widget stack overflow")
	//--- hash the caller location and lookup ---//
	id := get_loc_id(loc)
	idx, ok := widget_map[id]
	//--- if none is found reserve one ---//
	if !ok {
		for i := 0; i < MAX_WIDGETS; i += 1 {
			if !widget_reserved[i] {
				idx = i
				widget[i] = {id=id}
				append(&widget_stack, i)
				break
			}
			if i == MAX_WIDGETS - 1 {
				return false
			}
		}
	}
	widget_reserved[idx] = true
	widget_map[id] = idx
	//--- update widget data ---//
	self := &widget[idx]
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
	raylib.rlTranslatef(tex_offset.x - self.rect.x, tex_offset.y - self.rect.y, 0)
	self.tex_offset = tex_offset
	if tex_offset.x + self.rect.width > f32(panel_tex.texture.width) {
		tex_offset.x = 0
		tex_offset.y += max_panel_height
	} else {
		tex_offset.x += self.rect.width
	}
	max_panel_height = max(max_panel_height, self.rect.height)
	radius := style.corner_radius * 2
	//draw_rounded_rect(self.rect, radius, CORNER_VERTS, style.colors[.foreground])
	raylib.DrawRectangleRec(self.rect, style.colors[.foreground])
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