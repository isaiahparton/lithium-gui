package gui
import "vendor:raylib"
import "core:fmt"
import "core:strings"
import "core:unicode/utf8"
import "core:math"
import "core:runtime"
import "core:strconv"

MAX_CONTROLS :: 128
CORNER_VERTS :: 5


Option :: enum {
	disabled,
	highlighted,
	hold_focus,
	draggable,
	inner,
	closed,
	uniform,
	subtle,
	popup,
	topmost,
	auto_resize,
	align_center,
	align_far,
}
Option_Set :: bit_set[Option;u16]

Result :: enum {
	hover,
	just_hovered,
	focus,
	just_focused,
	change,
	submit,
}
Result_Set :: bit_set[Result;u8]

ControlData :: struct {
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
get_id_string :: #force_inline proc(str: string) -> Id { 
	return get_id_bytes(transmute([]byte) str) 
}
get_id_rawptr :: #force_inline proc(data: rawptr, size: int) -> Id { 
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
	id := Id(2166136261)
	hash(&id, bytes)
	return id
}

get_loc_id :: proc(loc: runtime.Source_Code_Location) -> Id{
	loc := loc
	loc.column += i32(ctx.loc_offset)
	return get_id(rawptr(&loc), size_of(loc))
}
check_control_clip :: proc(rect: Rectangle) -> bool {
	return raylib.CheckCollisionRecs(rect, ctx.widget_rect)
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
update_control :: proc() {
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
		hover_text = false
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
			dragging = true
		} else if (.hold_focus not_in opts) {
			focus_id = 0
		}
	}
}

begin_control :: proc(_opts: Option_Set, loc: runtime.Source_Code_Location) -> bool {
	using ctx.control_state
	opts = _opts
	rect = get_control_rect(opts)
	if !check_control_clip(rect) {
		return false
	}
	res = {}
	id = get_loc_id(loc)
	idx = reserve_control(id)
	return !(idx < 0)
}
begin_free_control :: proc(my_rect: Rectangle, _opts: Option_Set, loc: runtime.Source_Code_Location) -> bool {
	using ctx.control_state
	opts = _opts
	rect = my_rect
	if !check_control_clip(rect) {
		return false
	}
	res = {}
	id = get_loc_id(loc)
	idx = reserve_control(id)
	return !(idx < 0)
}
begin_static_control :: proc(_opts: Option_Set) -> bool {
	using ctx.control_state
	opts = _opts
	rect = get_control_rect(opts)
	if !check_control_clip(rect) {
		return false
	}
	return !(idx < 0)
}
end_control :: proc() -> Result_Set {
	using ctx
	ly := &layout_data[layout_idx]
	ly.size = {control_state.rect.width, control_state.rect.height}
	if ly.column {
		ly.offset.y += ly.size.y
		ly.offset.x = max(ly.offset.x, ly.size.x)
	} else {
		ly.offset.x += ly.size.x
		ly.offset.y = max(ly.offset.y, ly.size.y)
	}
	ly.rect = control_state.rect
	return control_state.res
}
end_free_control :: proc() -> Result_Set {
	return ctx.control_state.res
}

// get's the next control's rectangle
get_control_rect :: proc(opts: Option_Set) -> Rectangle {
	using ctx
	ly := &layout_data[layout_idx]
	rect := Rectangle{0, 0, ly.size.x, ly.size.y}
	if ly.column {
		if ly.rect != {} {
			ly.offset.y += ly.spacing
		}
		if ly.opposite {
			rect.y = ly.origin.y - ly.offset.y - ly.size.y
			rect.x = ly.origin.x
		} else {
			rect.y = ly.origin.y + ly.offset.y
			rect.x = ly.origin.x
		}
	} else {
		if ly.rect != {} {
			ly.offset.x += ly.spacing
		}
		if ly.opposite {
			rect.x = ly.origin.x - ly.offset.x - ly.size.x
			rect.y = ly.origin.y
		} else {
			rect.x = ly.origin.x + ly.offset.x
			rect.y = ly.origin.y
		}
	}
	return rect
}


// basic control frame
@private
draw_rect :: proc(rect: Rectangle, fill: Color){
	using ctx
	raylib.DrawTextureNPatch(rect_tex, rect_npatch, rect, {}, 0, fill)
}

@private
draw_folding_arrow :: proc(origin: [2]f32, time: f32, fill: Color) {
	using raylib
	if time > 0.01 {
		DrawLineEx({origin.x - 7, origin.y - 3 * time}, {origin.x + 1, origin.y + 5 * time}, 2, fill)
		DrawLineEx({origin.x + 8, origin.y - 4 * time}, {origin.x, origin.y + 4 * time}, 2, fill)
	} else {
		DrawRectangleRec({origin.x - 7, origin.y - 1, 15, 2}, fill)
	}
}

// text input
mutable_text :: proc(rect: Rectangle, res: ^Result_Set, content: ^string) {
	using ctx
	if .hover in res {
		hover_text = true
	}
	using raylib
	if .just_focused in res {
		cursor.index = -1
		cursor.length = 0
		text_offset = 0
		clear(&buffer)
		append_elem_string(&buffer, content^)
	}
	font := &style.font
	font_height := f32(font.baseSize)
	// if data was altered this step
	changed := false
	// Draw text to find lines
	y := rect.y + rect.height / 2 - font_height / 2
	x := rect.x + style.text_padding
	max_offset := f32(0)
	cursor_min_x, cursor_max_x := f32(0), f32(0)
	if .focus in res {
		x -= text_offset
	}
	min_dist := rect.width
	mouse_index := len(content)
	for i := 0; i <= len(content); {
		bytecount := 1
		codepoint : rune = 0
		if i < len(content) {
			codepoint, bytecount = utf8.decode_rune_in_string(content[i:])
		}
        index := GetGlyphIndex(font^, codepoint)
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
        dist := abs(f32(GetMouseX()) - x)
        if dist < min_dist {
        	min_dist = dist
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
			draw_rune_pro(font^, codepoint, {x, y}, {rect.x, rect.y, (rect.x + rect.width) - x, rect.height}, font_height, style.colors[.fill] if highlight else style.colors[.text])
        }
		x += rune_width
		i += bytecount
	}
	if .focus not_in res {
		return
	}
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
		cursor.drag_from = clamp(cursor.drag_from, 0, len(content))
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
		} else if mouse_x > rect.x + rect.width {
			text_offset += (mouse_x - (rect.x + rect.width)) * 0.01
		}
	}
	if cursor_move > 0 {
		limit := rect.width - style.text_padding * 2
		if cursor_max_x > text_offset + limit {
			text_offset = cursor_max_x - limit
		}
	} else if cursor_move < 0 {
		if cursor_min_x < text_offset + style.text_padding {
			text_offset = cursor_min_x - style.text_padding
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
		res^ += {.change}
		content^ = strings.clone_from_bytes(buffer[:])
	}
	text_offset = max(text_offset, 0)
	limit := rect.width - style.text_padding
	if text_offset + max_offset >= limit {
		text_offset = min(text_offset, max_offset - limit)
	}
	if max_offset < limit {
		text_offset = 0
	}
}
text_box :: proc(content: ^string, opts: Option_Set, loc := #caller_location) -> Result_Set {
	using ctx
	using raylib
	layout_data[layout_idx].size.y = f32(style.font.baseSize) + style.text_padding * 2
	if begin_control(opts + {.hold_focus}, loc) {
		using control_state
		update_control()
		fill := blend_colors(style.colors[.fill], BLACK, min(1, control.hover_time[idx] + control.focus_time[idx]) * 0.1)
		draw_rect(rect, fill)
		mutable_text(rect, &res, content)
	}
	return end_control()
}
FANCY_TEXT_BOX_HEIGHT :: 55
fancy_text_box :: proc(content: ^string, title: string, opts: Option_Set, loc := #caller_location) -> Result_Set {
	using ctx
	using raylib
	ctx.layout_data[ctx.layout_idx].size.y = FANCY_TEXT_BOX_HEIGHT
	if begin_control(opts + {.hold_focus}, loc) {
		update_control()
		using control_state
		font := &style.font
		font_height := f32(font.baseSize)
		focus_time := control.focus_time[idx]
		label_offset := style.text_padding - 3
		fill := blend_colors(style.colors[.fill], BLACK, min(1, control.hover_time[idx] + focus_time) * 0.1)
		draw_rounded_rect_pro(rect, {style.corner_radius, style.corner_radius, 0, 0}, CORNER_VERTS, fill)
		DrawRectangleRec({rect.x, rect.y + rect.height - 2, rect.width, 2}, style.colors[.accent])
		size := rect.width * focus_time
		if .focus in res {
			DrawRectangleRec({rect.x + rect.width / 2 - size / 2, rect.y + rect.height - 2, size, 2}, blend_colors(style.colors[.accent], style.colors[.highlight], focus_time))
		} else {
			DrawRectangleRec({rect.x, rect.y + rect.height - 2, rect.width, 2}, blend_colors(style.colors[.accent], style.colors[.highlight], focus_time))
		}
		if len(content) == 0 {
			draw_aligned_string(font^, title, {rect.x + style.text_padding, rect.y + label_offset + (rect.height / 2 - font_height / 2 - label_offset) * (1 - focus_time)}, cast(f32)style.font.baseSize * (1 - focus_time * 0.2), {0, 0, 0, 200}, .near, .near)
		} else {
			draw_aligned_string(font^, title, {rect.x + style.text_padding, rect.y + label_offset}, cast(f32)style.font.baseSize * 0.8, {0, 0, 0, 200}, .near, .near)
		}
		text_height := font_height + style.text_padding * 2
		mutable_text({rect.x, rect.y + rect.height - text_height, rect.width, text_height}, &res, content)
	}
	return end_control()
}

number_box :: proc(num: ^f32, opts: Option_Set, loc := #caller_location) -> Result_Set {
	using ctx
	using raylib
	ctx.layout_data[ctx.layout_idx].size.y = f32(style.font.baseSize) + style.text_padding * 2
	if begin_control(opts + {.hold_focus}, loc) {
		using control_state
		update_control()
		fill := blend_colors(style.colors[.fill], BLACK, min(1, control.hover_time[idx] + control.focus_time[idx]) * 0.1)
		draw_rect(rect, fill)
		num_text := fmt.aprint(num^)
		if .just_focused in res {
			ctx.number_text = num_text
			clear(&ctx.buffer)
			append_elem_string(&ctx.buffer, ctx.number_text)
		}
		mutable_text(rect, &res, &ctx.number_text if (.focus in res) else &num_text)
		if .change in res {
			new_num, ok := strconv.parse_f32(ctx.number_text)
			if ok {
				num^ = new_num
			} else if len(ctx.number_text) == 0 {
				num^ = 0
			}
		}
	}
	return end_control()
}

// submited when hovered, clicked then released
BUTTON_HEIGHT :: 30
button :: proc(title: string, opts: Option_Set, loc := #caller_location) -> Result_Set {
	using ctx
	using raylib
	layout_data[layout_idx].size.y = BUTTON_HEIGHT
	if begin_control(opts, loc) {
		using control_state
		update_control()
		text_color := Color{}
		if .subtle in opts {
			draw_rect(rect, Fade(BLACK, control.hover_time[idx] * 0.1))
			scale := control.focus_time[idx]
			if .focus in res {
				draw_rect({rect.x + (rect.width / 2) * (1 - scale), rect.y + (rect.height / 2) * (1 - scale), rect.width * scale, rect.height * scale}, Fade(BLACK, scale * 0.1))
			} else {
				draw_rect(rect, Fade(BLACK, scale * 0.1))
			}
			text_color = style.colors[.text]
		} else {
			draw_rect(rect, blend_colors(style.colors[.highlight], WHITE, control.hover_time[idx] * 0.1))
			scale := control.focus_time[idx]
			if .focus in res {
				draw_rect({rect.x + (rect.width / 2) * (1 - scale), rect.y + (rect.height / 2) * (1 - scale), rect.width * scale, rect.height * scale}, Fade(WHITE, scale * 0.1))
			} else {
				draw_rect(rect, Fade(WHITE, scale * 0.1))
			}
			text_color = style.colors[.foreground]
		}
		align := Alignment(.near)
		if .align_center in opts {
			align = .center
		} else if .align_far in opts {
			align = .far
		}
		draw_bound_string(style.font, title, rect, cast(f32)style.font.baseSize, text_color, align, .center)
	}
	return end_control()
}

// menus
menu :: proc(title: string, opts: Option_Set, loc := #caller_location) -> Result_Set {
	using ctx
	using raylib
	layout_data[layout_idx].size.y = BUTTON_HEIGHT
	if begin_control(opts, loc) {
		using control_state
		update_control()
		draw_rect(rect, blend_colors(style.colors[.highlight], WHITE, control.hover_time[idx] * 0.1))
		DrawRectangleRec({rect.x + rect.width - 31, rect.y, 2, rect.height}, WHITE)
		draw_folding_arrow({rect.x + rect.width - 15, rect.y + rect.height / 2}, control.hover_time[idx], style.colors[.foreground])
		scale := control.focus_time[idx]
		if .focus in res {
			draw_rect({rect.x + (rect.width / 2) * (1 - scale), rect.y + (rect.height / 2) * (1 - scale), rect.width * scale, rect.height * scale}, Fade(WHITE, scale * 0.1))
		} else {
			draw_rect(rect, Fade(WHITE, scale * 0.1))
		}
		draw_aligned_string(style.font, title, {rect.x + style.text_padding, rect.y + rect.height / 2}, cast(f32)style.font.baseSize, style.colors[.foreground], .near, .center)
	}
	res := end_control()
	if .submit in res {
		open_child_popup(title, .down, {}, {})
	}
	return res
}

// on/off control
CHECKBOX_SIZE :: 24
HALF_CHECKBOX_SIZE :: CHECKBOX_SIZE / 2
checkbox :: proc(value: ^bool, title: string, opts: Option_Set, loc := #caller_location) -> Result_Set {
	using ctx
	using raylib
	layout_data[layout_idx].size = {CHECKBOX_SIZE, CHECKBOX_SIZE}
	if begin_control(opts, loc) {
		using control_state
		rect.width = CHECKBOX_SIZE
		text_width := measure_string(style.font, title, cast(f32)style.font.baseSize).x
		if title != {} {
			text_width += style.text_padding * 2
			rect.width += text_width
		}
		update_control()
		state_time := &control.state_time[idx]
		draw_rounded_rect(rect, style.corner_radius, CORNER_VERTS, Fade(BLACK, control.hover_time[idx] * 0.1))
		if .focus in res {
			draw_rounded_rect({rect.x, rect.y, CHECKBOX_SIZE + text_width * control.focus_time[idx], rect.height}, style.corner_radius, CORNER_VERTS, Fade(BLACK, control.focus_time[idx] * 0.1))
		} else {
			draw_rounded_rect(rect, style.corner_radius, CORNER_VERTS, Fade(BLACK, control.focus_time[idx] * 0.1))
		}
		if value^ {
			draw_rounded_rect({rect.x, rect.y, CHECKBOX_SIZE, CHECKBOX_SIZE}, style.corner_radius, CORNER_VERTS, blend_colors(style.colors[.highlight], WHITE, (control.hover_time[idx] + control.focus_time[idx]) * 0.1))
			time := state_time^
			if time > 0.4 && time < 0.5 {
				time = 0.4
			}
			time1 := min(time, 0.4) * 2.25
			time2 := clamp(time - 0.5, 0, 0.5) * 2
			DrawLineEx({rect.x + 4, rect.y + 12}, {rect.x + 4 + (6 * time1), rect.y + 12 + (6 * time1)}, 2.0, style.colors[.foreground])
			DrawLineEx({rect.x + 9, rect.y + 18}, {rect.x + 9 + (11 * time2), rect.y + 18 - (11 * time2)}, 2.0, style.colors[.foreground])
			state_time^ += 4 * GetFrameTime()
		} else {
			draw_rounded_rect_lines({rect.x + 2, rect.y + 2, CHECKBOX_SIZE - 4, CHECKBOX_SIZE - 4}, style.corner_radius, CORNER_VERTS, 2, style.colors[.highlight])
			state_time^ = 0
		}
		state_time^ = clamp(state_time^, 0, 1)
		draw_aligned_string(style.font, title, {rect.x + CHECKBOX_SIZE + style.text_padding, rect.y + rect.height / 2}, cast(f32)style.font.baseSize, style.colors[.text], .near, .center)
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
slider :: proc(value: ^f64, lo, hi: f64, title: string, opts: Option_Set, loc := #caller_location) -> Result_Set {
	using ctx
	using raylib
	layout_data[layout_idx].size.y = 20
	if begin_control(opts + {.draggable}, loc){
		using control_state
		update_control()
		baseline := rect.y + 10
		draw_rect(rect, style.colors[.fill])
		//DrawRectangleRec({rect.x, baseline - 5, rect.width, 10}, style.colors[.fill])
		range := hi - lo
		value_point := rect.x + rect.width * f32(clamp(((value^ - lo) / range), 0, 1))
		hover_time := control.hover_time[idx]
		fill := blend_colors(style.colors[.fill], BLACK, hover_time * 0.1 + 0.2)
		{
			npatch := rect_npatch
			npatch.right = 0
			npatch.source.width -= 5
			left := value_point - rect.x
			limit := rect.width - 5
			if left >= limit {
				diff := left - limit
				npatch.source.width += diff
				npatch.right += i32(diff)
			}
			DrawTextureNPatch(rect_tex, npatch, {rect.x, rect.y, value_point - rect.x, rect.height}, {}, 0, fill)
		}
		draw_aligned_string(style.font, title, {rect.x + rect.width / 2, baseline}, cast(f32)style.font.baseSize, style.colors[.text], .center, .center)
		hover_value := clamp(lo + f64((f32(GetMouseX()) - rect.x) / rect.width) * range, lo, hi)
		if .focus in res {
			//hide_cursor = true
			//lock_mouse_to_slider(rect.x + 5, rect.x + 6 + inner_size, baseline)
			prev_value := value^
			value^ = hover_value
			if value^ != prev_value {
				res += {.change}
			}
		}
	}
	return end_control()
}
u8_slider :: proc(value: ^u8, lo, hi: u8, title: string, opts: Option_Set, loc := #caller_location) -> Result_Set {
	f_value, f_lo, f_hi := f64(value^), f64(lo), f64(hi)
	res := slider(&f_value, f_lo, f_hi, fmt.aprintf("%s: %i", title, value^), {}, loc)
	if .change in res {
		value^ = u8(f_value)
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
	if layout_data[layout_idx].column {
		control_state.rect.height = size.y
	} else {
		control_state.rect.width = size.x
	}
	end_control()
}
