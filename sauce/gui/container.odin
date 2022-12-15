package gui
import "vendor:raylib"

MAX_CONTAINERS :: 32
Container :: struct {
	rect, used_space: Rectangle,
	tex_offset: [2]f32,
}

push_container :: proc(rect: Rectangle, opts: Option_Set, loc := #caller_location) {
	using ctx

	cnt_idx += 1
	assert(cnt_idx < MAX_CONTAINERS, "push_container(): Container stack overflow")
	//--- hash the caller location and lookup ---//
	id := get_loc_id(loc)
	idx, ok := cnt_pool[id]
	//--- if none is found reserve one ---//
	if !ok {
		for q := 0; q < MAX_CONTAINERS; q += 1 {
			if !cnt_exist[q] {
				idx = q
				cnt_data[idx] = {}
				cnt_pool[id] = idx
				break
			}
		}
	}
	cnt_exist[idx] = true
	self := &cnt_data[idx]
	self.rect = rect
	self.used_space = {}

	raylib.BeginTextureMode(panel_tex)
	if widget_count == 1 {
		raylib.ClearBackground({})
		tex_offset = {}
		max_panel_height = 0
	}
	raylib.rlPushMatrix()
	raylib.rlTranslatef(tex_offset.x - self.rect.x, tex_offset.y - self.rect.y, 0)
	raylib.BeginScissorMode(i32(tex_offset.x), i32(tex_offset.y), i32(self.rect.width), i32(self.rect.height))
	self.tex_offset = tex_offset
	if tex_offset.x + self.rect.width > f32(panel_tex.texture.width) {
		tex_offset.x = 0
		tex_offset.y += max_panel_height
	} else {
		tex_offset.x += self.rect.width
	}
	max_panel_height = max(max_panel_height, self.rect.height)
	radius := style.corner_radius * 2
	push_layout()
}
pop_container :: proc(){
	using ctx
	assert(cnt_idx >= 0, "push_container(): Container stack is empty")

	pop_layout()
	raylib.EndScissorMode()
	raylib.rlPopMatrix()
	raylib.EndTextureMode()
	cnt_idx -= 1
}