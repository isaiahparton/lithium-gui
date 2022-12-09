package gui
import "vendor:raylib"
import "core:fmt"

MAX_WIDGETS :: 16
Widget :: struct {
	reserved: bool,
	contents: map[Id]int,
	rect, inner_rect, used_rect: Rectangle,
	offset, offset_target, space, tex_offset: [2]f32,
}

begin_widget :: proc(rect: Rectangle, loc := #caller_location) -> bool {
	using ctx

	//--- hash the caller location and lookup ---//
	id := get_loc_id(loc)
	idx, ok := widget_map[id]
	//--- if none is found reserve one ---//
	if !ok {
		for i := 0; i < MAX_WIDGETS; i += 1 {
			if !widget.reserved[i] {
				idx = i
				widget[i] = {}
				break
			}
			if i == MAX_WIDGETS - 1 {
				return false
			}
		}
	}
	//--- update widget data ---//
	widget_idx = idx
	widget_map[id] = idx
	widget.reserved[idx] = true
	widget.rect[idx] = rect
	widget.inner_rect[idx] = {
		rect.x + style.padding,
		rect.y + style.padding,
		rect.width - style.padding * 2,
		rect.height - style.padding * 2,
	}
	widget_count += 1
	widget_hover = raylib.CheckCollisionPointRec(raylib.GetMousePosition(), rect)
	widget.space[idx] = {rect.width, rect.height}

	//--- setup surface area for drawing ---//
	raylib.BeginTextureMode(panel_tex)
	if widget_count == 1 {
		raylib.ClearBackground({})
		tex_offset = {}
		max_panel_height = 0
	}
	raylib.rlPushMatrix()
	raylib.rlTranslatef(tex_offset.x - rect.x, tex_offset.y - rect.y, 0)
	raylib.BeginScissorMode(i32(tex_offset.x), i32(tex_offset.y), i32(rect.width), i32(rect.height))
	widget.tex_offset[idx] = tex_offset
	if tex_offset.x + rect.width > f32(panel_tex.texture.width) {
		tex_offset.x = 0
		tex_offset.y += max_panel_height
	} else {
		tex_offset.x += rect.width
	}
	max_panel_height = max(max_panel_height, rect.height)
	draw_rounded_rect(rect, style.corner_radius * 2, 7, style.colors[.foreground])
	//raylib.DrawTriangle({rect.x + rect.width, rect.y + rect.height - 30}, {rect.x + rect.width - 30, rect.y + rect.height}, {rect.x + rect.width, rect.y + rect.height}, raylib.BLACK)
	return true
}
end_widget :: proc(){
	using ctx
	raylib.EndScissorMode()
	raylib.rlPopMatrix()
	raylib.EndTextureMode()

	//--- update scrolling/panning ---//
	offset := &widget.offset[widget_idx]
	offset_target := &widget.offset_target[widget_idx]
	offset^ += (offset_target^ - offset^) * 20 * raylib.GetFrameTime()
	if widget_hover {
		widget_hover = true
		delta := raylib.GetMouseWheelMove() * 77
		if raylib.IsKeyDown(.LEFT_SHIFT) {
			offset_target.x -= delta
		} else {
			offset_target.y -= delta
		}
		if raylib.IsMouseButtonPressed(.MIDDLE) {
			drag_from = mouse_point + offset^
		}
		if raylib.IsMouseButtonDown(.MIDDLE) {
			offset^ = drag_from - mouse_point
			offset_target^ = offset^
		}
	}
	widget.space[widget_idx].y -= style.padding
	offset.x = clamp(offset.x, 0, widget.space[widget_idx].x - widget.rect[widget_idx].width)
	offset.y = clamp(offset.y, 0, widget.space[widget_idx].y - widget.inner_rect[widget_idx].height)
	offset_target.x = clamp(offset_target.x, 0, widget.space[widget_idx].x - widget.rect[widget_idx].width)
	offset_target.y = clamp(offset_target.y, 0, widget.space[widget_idx].y - widget.inner_rect[widget_idx].height)

	//--- delete entries for controls that don't exist ---//
	contents := &widget[widget_idx].contents
	for id, idx in contents {
		if !control.exists[idx] {
			delete_key(contents, id)
			control.reserved[idx] = false
		}
	}
}