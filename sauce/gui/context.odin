package gui
import "vendor:raylib"
import "core:strings"
import "core:fmt"

Font::raylib.Font
Rectangle::raylib.Rectangle
Color::raylib.Color
KeyboardKey::raylib.KeyboardKey
Alignment :: enum u8 {
	near,
	center,
	far,
}

FADE_SPEED :: 12.0

ColorIndex :: enum {
	background,
	foreground,
	accent,
	backing,
	fill,
	outline,
	highlight,
	text,
}
Style :: struct {
	font: Font,
	corner_radius, padding, spacing, text_padding, outline_thick: f32,
	icon_size: int,
	colors: [ColorIndex]Color,
}
Cursor :: struct{
	index, length, drag_from: int,
}

Id :: distinct u32
MAX_RUNES :: 32
KEY_HOLD_DELAY :: 0.5
KEY_HOLD_PULSE :: 0.025
DOUBLE_CLICK_TIME :: 0.275
Context :: struct {
	// input
	mouse_point, drag_from: [2]f32,
	dragging: bool,
	// uh
	hover_id, prev_hover_id, focus_id, prev_focus_id: Id,
	click, double_click: bool,
	double_click_timer: f32,
	loc_offset: int,
	// controls are things you interact with
	control_count: int,
	control: #soa[MAX_CONTROLS]ControlData,
	// current control state
	control_state: struct{
		idx: int, 
		id: Id, 
		rect: Rectangle, 
		res: Result_Set,
		opts: Option_Set,
	},
	// containers are containers
	cnt_pool: map[Id]int,
	cnt_data: [MAX_CONTAINERS]Container,
	cnt_exist: [MAX_CONTAINERS]bool,
	cnt_idx: int,
	// widget are containers
	widget_stack: [dynamic]int,
	active_widget: int,
	widget_count, widget_idx: int,
	widget_hover: bool,
	widget_rect: Rectangle,
	widget: [MAX_WIDGETS]Widget,
	widget_reserved: [MAX_WIDGETS]bool,
	widget_map: map[Id]int,
	// layout state
	layout_idx: int,
	layout_data: [MAX_LAYOUTS]Layout,
	// text entry
	number_text: string,
	buffer: [dynamic]u8,
	cursor: Cursor,
	hover_text: bool,
	text_offset: f32,
	cursor_move: int,
	// key input
	first_key, prev_first_key: KeyboardKey,
	key_hold_timer, key_pulse_timer: f32,
	key_pulse: bool,
	runes: [MAX_RUNES]rune,
	rune_count: int,
	// style
	style: Style,
	// screen size
	width, height: f32,
	// focus control
	hide_cursor: bool,
	// icon atlas
	icon_atlas: raylib.Texture,
	icon_cols: int,
	panel_tex: raylib.RenderTexture,
	tex_offset: [2]f32,
	max_panel_height: f32,
	widget_tex, shadow_tex, rect_tex: raylib.Texture,
	widget_npatch, shadow_npatch, rect_npatch: raylib.NPatchInfo,
}
ctx : Context = {}

uninit_context :: proc(){
	using ctx
	raylib.UnloadRenderTexture(panel_tex)
}
init_context :: proc(){
	using ctx
	init_default_style()
	{
		panel_tex = raylib.LoadRenderTexture(4096, 4096)
		icon_atlas = raylib.LoadTexture("./icons/atlas.png")
		icon_cols = cast(int)icon_atlas.width / style.icon_size
		widget_tex = raylib.LoadTexture("./widget.png")
		widget_npatch = { { 0, 0, cast(f32)widget_tex.width, cast(f32)widget_tex.height }, 9, 9, 9, 9, .NINE_PATCH }
		shadow_tex = raylib.LoadTexture("./shadow.png")
		shadow_npatch = { { 0, 0, cast(f32)shadow_tex.width, cast(f32)shadow_tex.height }, 40, 40, 40, 40, .NINE_PATCH }
		rect_tex = raylib.LoadTexture("./rect.png")
		rect_npatch = { { 0, 0, cast(f32)rect_tex.width, cast(f32)rect_tex.height }, 5, 5, 5, 5, .NINE_PATCH }
	}
}
init_default_style :: proc(){
	using ctx.style
	/*
	colors[.fill] = {30, 30, 30, 255}
	colors[.backing] = {5, 5, 5, 255}
	colors[.outline] = {0, 0, 0, 255}
	colors[.highlight] = {35, 35, 35, 255}
	colors[.foreground] = {20, 20, 20, 255}
	colors[.background] = {10, 10, 10, 255}
	colors[.text] = {255, 255, 255, 255}
	colors[.accent] = {17, 173, 163, 255}
	*/
	
	colors[.fill] = {230, 230, 230, 255}
	colors[.backing] = {180, 180, 180, 255}
	colors[.outline] = {0, 0, 0, 255}
	colors[.highlight] = {50, 50, 50, 255}
	colors[.foreground] = {255, 255, 255, 255}
	colors[.background] = {192, 233, 227, 255}
	colors[.text] = {0, 0, 0, 255}
	colors[.accent] = {17, 173, 163, 255}
	
	text_padding = 6
	outline_thick = 1.1
	padding = 14
	spacing = 10
	corner_radius = 0
	icon_size = 2
	font = raylib.LoadFontEx("./fonts/Muli-SemiBold.ttf", 26, nil, 1024)
	raylib.SetTextureFilter(font.texture, .BILINEAR)
}

begin :: proc(){
	using ctx
	using raylib

	hide_cursor = false
	layout_idx = -1
	loc_offset = 0

	rune_count = 0
	rn := GetCharPressed()
	for rn != 0 {
		runes[rune_count] = rn
		rune_count += 1
		rn = GetCharPressed()
	}

	first_key = GetKeyPressed()
	if first_key == prev_first_key {
		key_hold_timer += GetFrameTime()
	}
	else do key_hold_timer = 0.0
	prev_first_key = first_key

	if key_pulse_timer > 0.0 {
		key_pulse_timer -= GetFrameTime()
		key_pulse = false
	}
	else if key_hold_timer > KEY_HOLD_DELAY {
		key_pulse_timer = KEY_HOLD_PULSE
		key_pulse = true
	}

	double_click = false
	if click {
		if double_click_timer >= DOUBLE_CLICK_TIME {
			click = false
		}
		if IsMouseButtonReleased(.LEFT) {
			double_click = true
			click = false
		}
		double_click_timer += GetFrameTime()
	} else {
		if IsMouseButtonReleased(.LEFT) {
			click = true
			double_click_timer = 0
			double_click = false
		}
	}

	if hover_id != prev_hover_id {
		prev_hover_id = hover_id
		click = false
	}
	if focus_id != prev_focus_id {
		prev_focus_id = focus_id
	}

	control_count = 0
	if IsMouseButtonPressed(.LEFT) {
		focus_id = hover_id
	}
	hover_id = 0
	hover_text = false
	dragging = false
}
end :: proc(){
	using ctx
	using raylib

	if hide_cursor {
		HideCursor()
	} else {
		ShowCursor()
	}

	for i := 0; i < MAX_CONTROLS; i += 1 {
		if control.disabled[i] || !control.reserved[i] {
			continue
		}
		id := control.id[i]
		delta := 7 * GetFrameTime()
		if id == hover_id || id == focus_id {
			control.hover_time[i] += delta
		} else {
			control.hover_time[i] -= delta
		}
		control.hover_time[i] = clamp(control.hover_time[i], 0, 1)
		if id == focus_id {
			control.focus_time[i] += delta
		} else {
			control.focus_time[i] -= delta
		}
		control.focus_time[i] = clamp(control.focus_time[i], 0, 1)
		control.exists = false
	}

	if hover_id != 0 || focus_id != 0 {
		if hover_text {
			SetMouseCursor(.IBEAM)
		} else {
			SetMouseCursor(.POINTING_HAND)
		}
	} else {
		SetMouseCursor(.DEFAULT)
	}

	active_widget = -1
	if len(widget_stack) != 0 {
		top := len(widget_stack) - 1
		prev_top := top
		for i, idx in widget_stack {
			if CheckCollisionPointRec(GetMousePosition(), widget[i].rect) {
				if IsMouseButtonPressed(.LEFT) {
					top = idx
				}
				active_widget = i
			} else if (prev_top == idx) && (.popup in widget[i].opts) && IsMouseButtonPressed(.LEFT) {
				widget[i].closing = true
			}
		}
		if top != prev_top && (.topmost not_in widget[widget_stack[prev_top]].opts) {
			idx := widget_stack[top]
			copy(widget_stack[top:], widget_stack[top + 1:])
			widget_stack[prev_top] = idx
		}
	}
	
	for i, idx in widget_stack {
		using self := &widget[i]
		z = idx
		if !self.exists {
			time = 0
			continue
		}
		dst := expand_rect(rect, SHADOW_SPACE)
		SPEED :: 6.5
		if closing {
			time -= SPEED * GetFrameTime()
		} else {
			time += SPEED * GetFrameTime()
		}
		time = clamp(time, 0, 1)
		if (.hold_focus in widget[_get_top_widget()].opts) && (idx != len(widget_stack) - 1) {
			opacity -= opacity * FADE_SPEED * GetFrameTime()
		} else {
			opacity += (1 - opacity) * FADE_SPEED * GetFrameTime()
		}
		src := Rectangle{tex_offset.x, tex_offset.y, dst.width, dst.height}
		draw_render_surface(panel_tex, src, dst, Fade(blend_colors({245, 245, 245, 255}, WHITE, opacity), time))
		if closing && time < 0.01 {
			self.exists = false
		}
		if !self.exists {
			ordered_remove(&widget_stack, idx)
			delete_key(&widget_map, self.id)
			widget_reserved[i] = false
		}
		self.exists = false
	}

	widget_count = 0
}

is_ctrl_down :: proc() -> bool {
	return raylib.IsKeyDown(.LEFT_CONTROL) || raylib.IsKeyDown(.RIGHT_CONTROL)
}
is_alt_down :: proc() -> bool {
	return raylib.IsKeyDown(.LEFT_ALT) || raylib.IsKeyDown(.RIGHT_ALT)
}
is_shift_down :: proc() -> bool {
	return raylib.IsKeyDown(.LEFT_SHIFT) || raylib.IsKeyDown(.RIGHT_SHIFT)
}
get_key_held :: proc(key: KeyboardKey) -> bool {
	return (raylib.IsKeyPressed(key) || (raylib.IsKeyDown(key) && ctx.key_pulse))
}
