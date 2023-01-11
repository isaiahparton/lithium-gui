package gui
import "vendor:raylib"

MAX_CONTAINERS :: 32
Container :: struct {
	rect, used_space: Rectangle,
	scroll, scroll_target, space: [2]f32,
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

	//--- update scrolling/panning ---//
	self.scroll += (self.scroll_target - self.scroll) * 20 * raylib.GetFrameTime()
	if widget_hover {
		delta := raylib.GetMouseWheelMove() * 77
		if raylib.IsKeyDown(.LEFT_SHIFT) {
			self.scroll_target.x -= delta
		} else {
			self.scroll_target.y -= delta
		}
		if raylib.IsMouseButtonPressed(.MIDDLE) {
			drag_from = mouse_point + self.scroll
		}
		if raylib.IsMouseButtonDown(.MIDDLE) {
			self.scroll = drag_from - mouse_point
			self.scroll_target = self.scroll
		}
	}
	self.space += style.padding
	max_x, max_y := max(0, self.space.x - rect.width), max(0, self.space.y - rect.height)
	self.scroll.x = clamp(self.scroll.x, 0, max_x)
	self.scroll_target.x = clamp(self.scroll_target.x, 0, max_x)
	self.scroll.y = clamp(self.scroll.y, 0, max_y)
	self.scroll_target.y = clamp(self.scroll_target.y, 0, max_y)

	raylib.BeginScissorMode(i32(tex_offset.x), i32(tex_offset.y), i32(rect.width), i32(rect.height))
	//push_layout()
}
pop_container :: proc(){
	using ctx
	assert(cnt_idx >= 0, "push_container(): Container stack is empty")

	self := &cnt_data[cnt_idx]

	//pop_layout()
	raylib.EndScissorMode()
	raylib.rlPopMatrix()
	raylib.EndTextureMode()
	cnt_idx -= 1
}