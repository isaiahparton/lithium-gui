package gui
import "vendor:raylib"
import "core:fmt"
import "core:strings"
import "core:unicode/utf8"
import "core:math"
import "core:runtime"

Option :: enum {
	disabled,
	highlighted,
	hold_focus,
	draggable,
	in_loop,
}
Option_Set :: bit_set[Option;u8]

Result :: enum {
	hover,
	just_hovered,
	focus,
	just_focused,
	change,
	submit,
}
Result_Set :: bit_set[Result;u8]

MAX_CONTROLS :: 128
Control :: struct {
	exists, reserved, disabled, state: bool,
	id: Id,
	hover_time, focus_time, state_time: f32,
}

get_id :: proc {
	get_id_string,
	get_id_bytes,
	get_id_rawptr,
	get_id_uintptr,
}
get_id_string  :: #force_inline proc(str: string) -> Id { 
	return get_id_bytes(transmute([]byte) str) 
}
get_id_rawptr  :: #force_inline proc(data: rawptr, size: int) -> Id { 
	return get_id_bytes(([^]u8)(data)[:size])  
}
get_id_uintptr :: #force_inline proc(ptr: uintptr) -> Id { 
	ptr := ptr
	return get_id_bytes(([^]u8)(&ptr)[:size_of(ptr)])  
}
get_id_bytes :: proc(bytes: []byte) -> Id {
	using ctx
	/* 32bit fnv-1a hash */
	hash :: proc(hash: ^Id, data: []byte) {
		size := len(data)
		cptr := ([^]u8)(raw_data(data))
		for ; size > 0; size -= 1 {
			hash^ = Id(u32(hash^) ~ u32(cptr[0])) * 16777619
			cptr = cptr[1:]
		}
	}
	res := Id(2166136261)
	hash(&res, bytes)
	return res
}

get_loc_id :: proc(loc: runtime.Source_Code_Location, loop: bool) -> Id{
	loc := loc
	loc.column += i32(ctx.loc_offset)
	return get_id(rawptr(&loc), size_of(loc))
}
push_control :: proc(id: Id) -> int {
	using ctx
	parent_wdg := &widget[widget_count - 1]
	idx, ok := parent_wdg.contents[id]
	if !ok {
		for i := 0; i < MAX_CONTROLS; i += 1 {
			if !control.reserved[i] {
				idx = i
				control[i] = {}
			}
		}
	}
	parent_wdg.contents[id] = idx
	control[idx].id = id
	control[idx].exists = true
	control[idx].reserved = true
	control_count += 1
	return idx
}
update_control :: proc(res: ^Result_Set, id: Id, rect: Rectangle, opts: Option_Set) -> int {
	using ctx
	if focus_id == id {
		if prev_focus_id != id {
			res^ += {.just_focused}
		}
		res^ += {.focus}
		if raylib.IsMouseButtonReleased(.LEFT) && (.hold_focus not_in opts) {
			res^ += {.submit}
			focus_id = 0
		}
	}
	if raylib.CheckCollisionPointRec(raylib.GetMousePosition(), rect) {
		if prev_hover_id != id {
			res^ += {.just_hovered}
		}
		res^ += {.hover}
		hover_id = id
	} else if focus_id == id {
		if (.draggable in opts) {
			if raylib.IsMouseButtonReleased(.LEFT){
				focus_id = 0
			}
		} else if (.hold_focus not_in opts) {
			focus_id = 0
		}
	}
	return push_control(id)
}

// aligns a rect according to frame
get_control_rect :: proc() -> Rectangle {
	layout := &ctx.layout[ctx.layout_index]
	if ctx.set_rect {
		ctx.set_rect = false
		return layout.first_rect
	}
	spacing := ctx.style.spacing
	spacing += layout.spacing
	layout.spacing = 0
	rect := layout.last_rect
	if layout.side == .top {
		rect.y -= layout.size.y + spacing
	} else if layout.side == .bottom {
		rect.y += layout.last_rect.height + spacing
	} else if layout.side == .left {
		rect.x -= layout.size.x + spacing
	} else if layout.side == .right {
		rect.x += layout.last_rect.width + spacing
	}
	return rect
}

// basic control frame
draw_control_frame :: proc(rect: Rectangle, radius: f32, depth: f32, fill: Color){
	using ctx
	using raylib
	if depth > 0 {
		draw_rounded_rect({rect.x, rect.y, rect.width, rect.height + depth}, radius, 7, style.colors[.outline])
	}
	draw_rounded_rect(rect, radius, 7, fill)
	draw_rounded_rect_lines({rect.x, rect.y, rect.width, rect.height + depth}, radius, 7, style.outline_thick, style.colors[.outline])
}

// text input
text_box :: proc(content: ^string, opts: Option_Set, loc := #caller_location) -> Result_Set {
	using ctx
	using raylib
	rect := get_control_rect()
	layout_set_last(rect)
	res := Result_Set{}
	loc := loc
	id := get_id(rawptr(&loc), size_of(loc))
	idx := update_control(&res, id, rect, {.hold_focus})

	if .just_focused in res {
		cursor.index = -1
		cursor.length = 0
		clear(&buffer)
		append_elem_string(&buffer, content^)
	}

	draw_control_frame(rect, style.corner_radius, 0, blend_colors(style.colors[.fill], BLACK, (control.hover_time[idx] + control.focus_time[idx]) * 0.1))

	font := style.font
	font_height := f32(font.baseSize)
	// if data was altered this step
	changed := false
	// Draw text to find lines
	x := rect.x + style.text_padding
	if .focus in res {
		x -= text_offset
	}
	min_diff := rect.width
	mouse_index := len(content)
	y := rect.y + rect.height / 2 - font_height / 2
	for i := 0; i <= len(content); {
		bytecount := 1
		codepoint : rune = 0
		if i < len(content) {
			codepoint, bytecount = utf8.decode_rune_in_string(content[i:])
		}
        index := GetGlyphIndex(font, codepoint)

        rune_width := f32(font.chars[index].advanceX) if (font.chars[index].advanceX != 0) else font.recs[index].width + f32(font.chars[index].offsetX)
        if x + rune_width < rect.x {
        	i += bytecount
        	x += rune_width
        	continue
        }

        diff := abs(f32(GetMouseX()) - x)
        if diff < min_diff {
        	min_diff = diff
        	mouse_index = i
        }

        // Draw cursor
        highlight := false
        if .focus in res {
        	if cursor.length == 0 {
	    		if i == cursor.index {
	    			h := font_height * (0.5 + abs(math.sin_f32(f32(GetTime() * 7))) * 0.5)
	    			DrawRectangleRec({x - 1, y + font_height / 2 - h / 2, 2, h}, style.colors[.text])
	    		}
	    	} else if i >= cursor.index && i < cursor.index + cursor.length {
	        	DrawRectangleRec({max(x, rect.x), y, min(rect.width - (x - rect.x), rune_width), font_height}, style.colors[.text])
	        	highlight = true
	        }
        }

        if i == len(content) {
        	break
        }

		draw_rune_pro(font, codepoint, {x, y}, {rect.x, rect.y, rect.width - (x - rect.x), rect.height}, font_height, style.colors[.fill] if highlight else style.colors[.text])
		x += rune_width
		i += bytecount

		if x > rect.x + rect.width {
			break
		}
	}

	if .hover in res {
		hover_text = true
	}

	if .focus in res {
		if .hover in res {
			if double_click {
				cursor.index = 0
				cursor.length = len(content)
			} else {
				if IsMouseButtonPressed(.LEFT) && mouse_index != -1 {
					cursor.drag_from = mouse_index
				}
				if IsMouseButtonDown(.LEFT) {
					if mouse_index < cursor.drag_from {
						cursor.index = mouse_index
						cursor.length = cursor.drag_from - cursor.index
					} else {
						cursor.index = cursor.drag_from
						cursor.length = mouse_index - cursor.index
					}
				}
			}
		}

		if get_key_held(.LEFT) {
			delta := 0
			if is_ctrl_down() {
				delta = quick_seek_buffer(&buffer, cursor.index, true) - cursor.index
			}
			else{
				_, delta = utf8.decode_last_rune_in_bytes(buffer[:cursor.index])
				delta = -delta
			}
			if is_shift_down() {
				cursor.index += delta
				if cursor.index >= 0 {
					cursor.length -= delta
				}
			} else {
				if cursor.length == 0 {
					cursor.index += delta
				}
				cursor.length = 0
			}
			if cursor.index < 0 do cursor.index = 0
		}
		if get_key_held(.RIGHT) {
			delta := 0
			if is_ctrl_down() {
				delta = quick_seek_buffer(&buffer, cursor.index + cursor.length, false) - cursor.index + 1
			}
			else{
				_, delta = utf8.decode_rune_in_bytes(buffer[cursor.index + cursor.length:])
			}
			if is_shift_down() {
				cursor.length += delta
			} else {
				if cursor.length > 0 {
					cursor.index += cursor.length
				} else {
					cursor.index += delta
				}
				cursor.length = 0
			}
			if cursor.length == 0 {
				if cursor.index > len(buffer) {
					cursor.index = len(buffer)
				}
			} else {
				if cursor.index + cursor.length > len(buffer) {
					cursor.length = len(buffer) - cursor.index
				}
			}
		}
		if rune_count > 0 {
			insert_runes_to_buffer(&buffer, runes[0:rune_count])
			changed = true
		}
		if len(buffer) != 0 {
			at_end := (len(buffer) == cursor.index)

			if get_key_held(.DELETE) && !at_end {
				erase_from_buffer(&buffer)
				changed = true
			}
			else if get_key_held(.BACKSPACE) {
				if is_ctrl_down() {
					idx := quick_seek_buffer(&buffer, cursor.index, true)
					remove_range(&buffer, idx, cursor.index)
					cursor.index = idx
				} else {
					backspace_buffer(&buffer)
				}
				changed = true
			}
		}
		if is_ctrl_down() {
			if IsKeyPressed(.A) {
				cursor.index = 0
				cursor.length = len(buffer)
			}
			if IsKeyPressed(.V) {
				str := strings.clone_from_cstring(GetClipboardText())
				if len(str) > 0 {
					insert_string_to_buffer(&buffer, str)
					changed = true
				}
			}
			if IsKeyPressed(.C) {
				SetClipboardText(strings.clone_to_cstring(cast(string)buffer[cursor.index:cursor.index + cursor.length]))
			}
			if IsKeyPressed(.X) {
				SetClipboardText(strings.clone_to_cstring(cast(string)buffer[cursor.index:cursor.index + cursor.length]))
				erase_from_buffer(&buffer)
				changed = true
			}
		}
		if changed {
			res += {.change}
			content^ = strings.clone_from_bytes(buffer[:])
		}
	}

	return res
}

// submited when hovered, clicked then released
button :: proc(title: string, opts: Option_Set, loc := #caller_location) -> Result_Set {
	using ctx
	using raylib
	rect := get_control_rect()
	layout_set_last(rect)
	res := Result_Set{}
	id := get_loc_id(loc, (.in_loop in opts))
	idx := update_control(&res, id, rect, {})
	offset := style.depth * control.focus_time[idx]
	rect.y += offset
	draw_control_frame(rect, style.corner_radius, style.depth - offset, blend_colors(blend_colors(style.colors[.fill], BLACK, control.hover_time[idx] * 0.1), style.colors[.highlight], control.focus_time[idx]))
	draw_aligned_string(style.font, title, {rect.x + rect.width / 2, rect.y + rect.height / 2}, cast(f32)style.font.baseSize, style.colors[.text], .center, .center)
	return res
}

// on/off control
tick_box :: proc(value: ^bool, title: string, opts: Option_Set, loc := #caller_location) -> Result_Set {
	using ctx
	using raylib
	rect := get_control_rect()
	rect.width, rect.height = 30, 30
	if title != {} {
		rect.width += measure_string(style.font, title, cast(f32)style.font.baseSize).x + style.spacing
	}
	layout_set_last(rect)
	res := Result_Set{}
	loc := loc
	id := get_id(rawptr(&loc), size_of(loc))
	idx := update_control(&res, id, rect, {})
	state_time := &control.state_time[idx]
	fill := ColorAlphaBlend(ColorAlphaBlend(style.colors[.fill], style.colors[.highlight], Fade(WHITE, state_time^)), BLACK, Fade(WHITE, (control.hover_time[idx] + control.focus_time[idx]) * 0.1))
	draw_rounded_rect({rect.x, rect.y, 30, 30}, style.corner_radius, 7, fill)
	draw_rounded_rect_lines({rect.x, rect.y, 30, 30}, style.corner_radius, 7, style.outline_thick, style.colors[.outline])
	if value^ {
		time1 := min(state_time^, 0.5) * 2
		time2 := max(min(state_time^ - 0.5, 0.5), 0.0) * 2
		DrawLineEx({rect.x + 5, rect.y + 15}, {rect.x + 5 + (8 * time1), rect.y + 15 + (8 * time1)}, 3.0, style.colors[.outline])
		DrawLineEx({rect.x + 12, rect.y + 22}, {rect.x + 12 + (14 * time2), rect.y + 22 - (14 * time2)}, 3.0, style.colors[.outline])
		state_time^ += (1.0 - state_time^) * 15 * GetFrameTime()
	} else {
		state_time^ -= state_time^ * 15 * GetFrameTime()
	}
	draw_aligned_string(style.font, title, {rect.x + rect.width, rect.y + rect.height / 2}, cast(f32)style.font.baseSize, style.colors[.text], .far, .center)
	if .submit in res {
		value^ = !value^
	}
	return res
}

// lock the mouse to a horizontal line
lock_mouse_to_slider :: proc(min, max, baseline: f32){
	using raylib
	mouse_x := f32(GetMouseX())
	SetMousePosition(GetMouseX(), i32(baseline))
	if mouse_x < min {
		SetMousePosition(i32(min), GetMouseY())
	} else if mouse_x > max {
		SetMousePosition(i32(max), GetMouseY())
	}
}

// slider
slider :: proc(value: ^f32, min, max: f32, opts: Option_Set, loc := #caller_location) -> Result_Set {
	using ctx
	using raylib
	rect := get_control_rect()
	rect.height = 20
	layout_set_last(rect)
	baseline := rect.y + 10
	res := Result_Set{}
	loc := loc
	id := get_id(rawptr(&loc), size_of(loc))
	idx := update_control(&res, id, rect, {.draggable})
	draw_rounded_rect_lines({rect.x, baseline - 5, rect.width, 10}, 5, 7, style.outline_thick, style.colors[.outline])
	inner_size := rect.width - 20
	value_point := Vector2{rect.x + 10 + inner_size * (value^ / (max - min)), baseline}
	draw_rounded_rect({rect.x, baseline - 5, value_point.x - rect.x, 10}, 5, 7, style.colors[.highlight])
	draw_control_frame({value_point.x - 10, value_point.y - 10, 20, 20}, 10, style.depth, blend_colors(blend_colors(style.colors[.fill], BLACK, control.hover_time[idx] * 0.1), style.colors[.highlight], control.focus_time[idx]))
	if .focus in res {
		hide_cursor = true
		lock_mouse_to_slider(rect.x + 10, rect.x + 10 + inner_size, baseline)
		value^ = clamp(min + ((f32(GetMouseX()) - (rect.x + 10)) / inner_size) * (max - min), min, max)
	}
	return res
}

range_slider :: proc(low, high: ^f32, min, max: f32, opts: Option_Set, loc := #caller_location) -> Result_Set {
	using ctx
	using raylib
	rect := get_control_rect()
	rect.height = 20
	layout_set_last(rect)
	baseline := rect.y + 10
	res := Result_Set{}
	loc := loc
	
	draw_rounded_rect_lines({rect.x, baseline - 5, rect.width, 10}, 5, 7, style.outline_thick, style.colors[.outline])
	inner_size := rect.width - 20

	low_point := Vector2{rect.x + 10 + inner_size * (low^ / (max - min)), baseline}
	low_knob := Result_Set{}
	low_id := get_id(rawptr(&loc), size_of(loc))
	low_idx := update_control(&low_knob, low_id, {low_point.x - 10, low_point.y - 10, 20, 20}, {.draggable})
	high_point := Vector2{rect.x + 10 + inner_size * (high^ / (max - min)), baseline}
	high_knob := Result_Set{}
	loc.column += 1
	high_id := get_id(rawptr(&loc), size_of(loc))
	high_idx := update_control(&high_knob, high_id, {high_point.x - 10, high_point.y - 10, 20, 20}, {.draggable})

	DrawRectangleRec({low_point.x, baseline - 5, (high_point.x - low_point.x), 10}, style.colors[.highlight])
	draw_control_frame({low_point.x - 10, low_point.y - 10, 20, 20}, 10, style.depth, blend_colors(blend_colors(style.colors[.fill], BLACK, control.hover_time[low_idx] * 0.1), style.colors[.highlight], control.focus_time[low_idx]))
	draw_control_frame({high_point.x - 10, high_point.y - 10, 20, 20}, 10, style.depth, blend_colors(blend_colors(style.colors[.fill], BLACK, control.hover_time[high_idx] * 0.1), style.colors[.highlight], control.focus_time[high_idx]))
	if .focus in low_knob {
		low^ = clamp(min + ((f32(GetMouseX()) - (rect.x + 10)) / inner_size) * (max - min), min, high^)
	}
	if .focus in high_knob {
		high^ = clamp(min + ((f32(GetMouseX()) - (rect.x + 10)) / inner_size) * (max - min), low^, max)
	}
	return res
}

text :: proc(text: string, align_x, align_y: Alignment, opts: Option_Set){
	using ctx
	using raylib
	rect := get_control_rect()
	origin := [2]f32{rect.x, rect.y}
	if align_x == .center {
		origin.x += rect.width / 2
	} else if align_x == .far {
		origin.x += rect.width
	}
	if align_y == .center {
		origin.y += rect.height / 2
	} else if align_y == .far {
		origin.y += rect.height
	}
	size := draw_aligned_string(style.font, text, origin, cast(f32)style.font.baseSize, style.colors[.text], align_x, align_y)
	side := layout[layout_index].side
	if side == .bottom || side == .top {
		rect.height = size.y
	} else if side == .left || side == .right {
		rect.width = size.x
	}
	layout_set_last(rect)
}