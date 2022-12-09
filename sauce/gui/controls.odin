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

get_loc_id :: proc(loc: runtime.Source_Code_Location) -> Id{
	loc := loc
	loc.column += i32(ctx.loc_offset)
	return get_id(rawptr(&loc), size_of(loc))
}
check_control_clip :: proc(rect: Rectangle) -> bool {
	space := &ctx.widget.space[ctx.widget_idx]
	widget_rect := ctx.widget.rect[ctx.widget_idx]
	space.x = max(space.x, (rect.x + ctx.widget.offset[ctx.widget_idx].x - widget_rect.x) + rect.width)
	space.y = max(space.y, (rect.y + ctx.widget.offset[ctx.widget_idx].y - widget_rect.y) + rect.height)
	return raylib.CheckCollisionRecs(rect, widget_rect)
}
reserve_control :: proc(id: Id) -> int {
	using ctx
	//--- lookup control in parent widget by id ---//
	parent_wdg := &widget[widget_count - 1]
	idx, ok := parent_wdg.contents[id]
	//--- if not found, reserve a new one ---//
	if !ok {
		idx = -1
		for i := 0; i < MAX_CONTROLS; i += 1 {
			if !control.reserved[i] {
				idx = i
				control[i] = {}
				break
			}
		}
		if idx < 0 {
			return idx
		}
		parent_wdg.contents[id] = idx
	}
	control[idx].id = id
	control[idx].exists = true
	control[idx].reserved = true
	control_count += 1
	return idx
}
update_control :: proc(opts: Option_Set) {
	using ctx
	using control_state
	if focus_id == id {
		if prev_focus_id != id {
			res += {.just_focused}
		}
		res += {.focus}
		if raylib.IsMouseButtonReleased(.LEFT) && (.hold_focus not_in opts) {
			res += {.submit}
			focus_id = 0
		}
	}
	if widget_hover && raylib.CheckCollisionPointRec(raylib.GetMousePosition(), rect) {
		if prev_hover_id != id {
			res += {.just_hovered}
		}
		res += {.hover}
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
}

begin_control :: proc(opts: Option_Set, loc: runtime.Source_Code_Location) -> bool {
	using ctx.control_state
	rect = get_control_rect()
	if !check_control_clip(rect) {
		return false
	}
	res = {}
	id = get_loc_id(loc)
	idx = reserve_control(id)
	return !(idx < 0)
}
begin_free_control :: proc(my_rect: Rectangle, opts: Option_Set, loc: runtime.Source_Code_Location) -> bool {
	using ctx.control_state
	rect = my_rect
	if !check_control_clip(rect) {
		return false
	}
	res = {}
	id = get_loc_id(loc)
	idx = reserve_control(id)
	return !(idx < 0)
}
begin_static_control :: proc(opts: Option_Set) -> bool {
	using ctx.control_state
	rect = get_control_rect()
	if !check_control_clip(rect) {
		return false
	}
	return !(idx < 0)
}
end_control :: proc() -> Result_Set {
	using ctx.control_state
	layout_set_last(rect)
	return res
}

// get's the next control's rectangle
get_control_rect :: proc() -> Rectangle {
	layout := &ctx.layout[ctx.layout_index]
	if ctx.set_rect {
		ctx.set_rect = false
		layout.first_rect.x -= ctx.widget[ctx.widget_idx].offset.x
		layout.first_rect.y -= ctx.widget[ctx.widget_idx].offset.y
		return layout.first_rect
	}
	spacing := layout.spacing
	rect := layout.last_rect
	rect.width, rect.height = layout.size.x, layout.size.y
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
@private
draw_control_frame :: proc(rect: Rectangle, radius: f32, fill: Color){
	using ctx
	using raylib
	draw_rounded_rect(rect, radius, style.corner_verts, fill)
}

// text input
text_box :: proc(content: ^string, opts: Option_Set, loc := #caller_location) -> Result_Set {
	using ctx
	using raylib
	if begin_control(opts, loc) {
		update_control(opts + {.hold_focus})
		using control_state
		if .just_focused in res {
			cursor.index = -1
			cursor.length = 0
			text_offset = 0
			text_offset_trg = 0
			clear(&buffer)
			append_elem_string(&buffer, content^)
		}

		draw_control_frame(rect, style.corner_radius, blend_colors(style.colors[.fill], BLACK, (control.hover_time[idx] + control.focus_time[idx]) * 0.1))
		
		text_offset += (text_offset_trg - text_offset) * 20 * GetFrameTime()

		font := style.font
		font_height := f32(font.baseSize)
		// if data was altered this step
		changed := false
		// Draw text to find lines
		x := rect.x + style.text_padding
		max_offset := f32(0)
		cursor_min_x, cursor_max_x := f32(0), f32(0)
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
	        if i == cursor.index {
	        	cursor_min_x, cursor_max_x = max_offset, max_offset
	        } else if i == cursor.index + cursor.length {
	        	cursor_max_x = max_offset
	        }
	        if x + rune_width < rect.x {
	        	i += bytecount
	        	x += rune_width
	        	max_offset += rune_width
	        	continue
	        }

	        diff := abs(f32(GetMouseX()) - x)
	        if diff < min_diff {
	        	min_diff = diff
	        	mouse_index = i
	        }

	        max_offset += rune_width

	        // Draw cursor
	        highlight := false
	        if .focus in res {
	        	if cursor.length == 0 && x > rect.x && x < rect.x + rect.width {
		    		if i == cursor.index {
		    			h := font_height * (0.5 + abs(math.sin_f32(f32(GetTime() * 7))) * 0.5)
		    			DrawRectangleRec({x - 1, y + font_height / 2 - h / 2, 2, h}, style.colors[.text])
		    		}
		    	} else if i >= cursor.index && i < cursor.index + cursor.length {
		        	DrawRectangleRec({max(x, rect.x), y, min(rect.width - (x - rect.x), rune_width + 1), font_height}, style.colors[.text])
		        	highlight = true
		        }
	        } else {
	        	if x > rect.x + rect.width {
					break
				}
	        }

	        if i == len(content) {
	        	break
	        }

	        if x < rect.x + rect.width {
				draw_rune_pro(font, codepoint, {x, y}, {rect.x, rect.y, (rect.x + rect.width) - x, rect.height}, font_height, style.colors[.fill] if highlight else style.colors[.text])
	        }
			x += rune_width
			i += bytecount
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
				}
			}

			if IsMouseButtonDown(.LEFT) {
				if mouse_index < cursor.drag_from {
					cursor.index = mouse_index
					cursor.length = cursor.drag_from - cursor.index
				} else {
					cursor.index = cursor.drag_from
					cursor.length = mouse_index - cursor.index
				}
				mouse_x := f32(GetMouseX())
				if mouse_x < rect.x {
					text_offset += (mouse_x - rect.x) * 0.01
					text_offset_trg = text_offset
				} else if mouse_x > rect.x + rect.width {
					text_offset += (mouse_x - (rect.x + rect.width)) * 0.01
					text_offset_trg = text_offset
				}
			}
			if cursor_move > 0 {
				if cursor_max_x > text_offset + rect.width / 2 {
					text_offset_trg = cursor_max_x - rect.width / 2
				}
			} else if cursor_move < 0 {
				if cursor_min_x < text_offset + style.text_padding {
					text_offset_trg = cursor_min_x - style.text_padding
				}
			}
			cursor_move = 0
			if get_key_held(.LEFT) {
				cursor_move = -1
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
				cursor_move = 1
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
				cursor_move = 1
			}
			if len(buffer) != 0 {
				at_end := (len(buffer) == cursor.index)

				if get_key_held(.DELETE) && !at_end {
					erase_from_buffer(&buffer)
					changed = true
					cursor_move = -1
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
					cursor_move = -1
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
						cursor_move = 1
					}
				}
				if IsKeyPressed(.C) {
					SetClipboardText(strings.clone_to_cstring(cast(string)buffer[cursor.index:cursor.index + cursor.length]))
				}
				if IsKeyPressed(.X) {
					SetClipboardText(strings.clone_to_cstring(cast(string)buffer[cursor.index:cursor.index + cursor.length]))
					erase_from_buffer(&buffer)
					changed = true
					cursor_move = -1
				}
			}
			if changed {
				res += {.change}
				content^ = strings.clone_from_bytes(buffer[:])
			}
		}
		
		if max_offset < rect.width / 2 {
			text_offset_trg = 0
		}
		if text_offset < 0 {
			text_offset = 0
		} else if max_offset > rect.width && text_offset + rect.width / 2 > max_offset {
			text_offset = max_offset - rect.width / 2
		}
	}
	return end_control()
}

// submited when hovered, clicked then released
button :: proc(title: string, opts: Option_Set, loc := #caller_location) -> Result_Set {
	using ctx
	using raylib
	if begin_control(opts, loc) {
		using control_state
		update_control(opts)
		draw_control_frame(rect, style.corner_radius, blend_colors(blend_colors(style.colors[.fill], BLACK, control.hover_time[idx] * 0.1), style.colors[.highlight], control.focus_time[idx]))
		draw_aligned_string(style.font, title, {rect.x + rect.width / 2, rect.y + rect.height / 2}, cast(f32)style.font.baseSize, style.colors[.text], .center, .center)
	}
	return end_control()
}

// on/off control
CHECKBOX_SIZE :: 24
HALF_CHECKBOX_SIZE :: CHECKBOX_SIZE / 2
checkbox :: proc(value: ^bool, title: string, opts: Option_Set, loc := #caller_location) -> Result_Set {
	using ctx
	using raylib
	if begin_control(opts, loc) {
		using control_state
		rect.y += rect.height / 2 - HALF_CHECKBOX_SIZE
		rect.width, rect.height = CHECKBOX_SIZE, CHECKBOX_SIZE
		if title != {} {
			rect.width += measure_string(style.font, title, cast(f32)style.font.baseSize).x + style.text_padding
		}
		update_control(opts)
		state_time := &control.state_time[idx]
		fill := ColorAlphaBlend(Fade(style.colors[.text], state_time^), BLACK, Fade(WHITE, (control.hover_time[idx] + control.focus_time[idx]) * 0.1))
		draw_rounded_rect({rect.x, rect.y, CHECKBOX_SIZE, CHECKBOX_SIZE}, style.corner_radius, 7, fill)
		draw_rounded_rect_lines({rect.x + 2, rect.y + 2, CHECKBOX_SIZE - 4, CHECKBOX_SIZE - 4}, style.corner_radius, 7, 2, style.colors[.outline])
		if value^ {
			time1 := min(state_time^, 0.5) * 2
			time2 := max(min(state_time^ - 0.5, 0.5), 0.0) * 2
			DrawLineEx({rect.x + 4, rect.y + 12}, {rect.x + 4 + (6 * time1), rect.y + 12 + (6 * time1)}, 3.0, style.colors[.foreground])
			DrawLineEx({rect.x + 9, rect.y + 18}, {rect.x + 9 + (11 * time2), rect.y + 18 - (11 * time2)}, 3.0, style.colors[.foreground])
			state_time^ += (1.0 - state_time^) * 15 * GetFrameTime()
		} else {
			if (state_time^ > 0.01) {
				time2 := min(state_time^, 0.5) * 2
				time1 := max(min(state_time^ - 0.5, 0.5), 0.0) * 2
				DrawLineEx({rect.x + 10, rect.y + 18}, {rect.x + 10 - (6 * time1), rect.y + 18 - (6 * time1)}, 3.0, style.colors[.foreground])
				DrawLineEx({rect.x + 20, rect.y + 7}, {rect.x + 20 - (11 * time2), rect.y + 7 + (11 * time2)}, 3.0, style.colors[.foreground])
			}
			state_time^ -= state_time^ * 15 * GetFrameTime()
		}
		draw_aligned_string(style.font, title, {rect.x + rect.width, rect.y + rect.height / 2}, cast(f32)style.font.baseSize, style.colors[.text], .far, .center)
		if .submit in res {
			value^ = !value^
		}
	}
	return end_control()
}

// lock the mouse to a horizontal line
@private
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
	if begin_control(opts, loc){
		using control_state
		rect.height = 20
		update_control(opts)
		baseline := rect.y + 10
		draw_rounded_rect({rect.x, baseline - 5, rect.width, 10}, 5, 7, style.colors[.backing])
		inner_size := rect.width - 20
		value_point := Vector2{rect.x + 10 + inner_size * ((value^ - min) / (max - min)), baseline}
		draw_rounded_rect({rect.x, baseline - 5, value_point.x - rect.x, 10}, 5, 7, style.colors[.highlight])
		draw_control_frame({value_point.x - 10, value_point.y - 10, 20, 20}, 10, blend_colors(blend_colors(style.colors[.fill], BLACK, control.hover_time[idx] * 0.1), style.colors[.highlight], control.focus_time[idx]))
		if .focus in res {
			hide_cursor = true
			lock_mouse_to_slider(rect.x + 10, rect.x + 11 + inner_size, baseline)
			prev_value := value^
			value^ = clamp(min + ((f32(GetMouseX()) - (rect.x + 10)) / inner_size) * (max - min), min, max)
			if value^ != prev_value {
				res += {.change}
			}
		}
	}
	return end_control()
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
	high_point := Vector2{rect.x + 10 + inner_size * (high^ / (max - min)), baseline}
	DrawRectangleRec({low_point.x, baseline - 5, (high_point.x - low_point.x), 10}, style.colors[.highlight])
	low_rect := Rectangle{low_point.x - 10, low_point.y - 10, 20, 20}
	if begin_free_control(low_rect, opts + {.draggable}, loc) {
		using control_state
		draw_control_frame(rect, 10, blend_colors(blend_colors(style.colors[.fill], BLACK, control.hover_time[idx] * 0.1), style.colors[.highlight], control.focus_time[idx]))
	}
	low_knob := end_control()

	loc.column += 1

	high_rect := Rectangle{high_point.x - 10, high_point.y - 10, 20, 20}
	if begin_free_control(high_rect, opts + {.draggable}, loc) {
		using control_state
		draw_control_frame(rect, 10, blend_colors(blend_colors(style.colors[.fill], BLACK, control.hover_time[idx] * 0.1), style.colors[.highlight], control.focus_time[idx]))
	}
	high_knob := Result_Set{}

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
	size := [2]f32{}
	if begin_static_control(opts) {
		using control_state
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
		size = draw_aligned_string(style.font, text, origin, cast(f32)style.font.baseSize, style.colors[.text], align_x, align_y)
	} else {
		size = measure_string(style.font, text, cast(f32)style.font.baseSize)
	}
	side := layout[layout_index].side
	if side == .bottom || side == .top {
		control_state.rect.height = size.y
	} else if side == .left || side == .right {
		control_state.rect.width = size.x
	}
	layout_set_last(ctx.control_state.rect)
}