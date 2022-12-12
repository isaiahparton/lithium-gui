package gui
import "vendor:raylib"
import "core:strings"
import "core:fmt"

Font::raylib.Font
Rectangle::raylib.Rectangle
Color::raylib.Color
KeyboardKey::raylib.KeyboardKey
Alignment :: enum {
	near,
	center,
	far,
}

FADE_SPEED :: 16.0

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
	mouse_point: [2]f32,
	drag_from: [2]f32,
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
	},
	// widget are containers
	widget_stack: [dynamic]int,
	active_widget: int,
	widget_count, widget_idx: int,
	widget_hover: bool,
	widget_drag: int,
	widget_rect: Rectangle,
	widget: [MAX_WIDGETS]Widget,
	widget_reserved: [MAX_WIDGETS]bool,
	widget_map: map[Id]int,
	// layout state
	layout_idx: int,
	layout: [MAX_LAYOUTS]Layout,
	set_rect: bool,
	// text entry
	buffer: [dynamic]u8,
	cursor: Cursor,
	hover_text: bool,
	text_offset: f32,
	text_offset_trg: f32,
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
	hide_cursor, popup: bool,
	// icon atlas
	icon_atlas: raylib.Texture,
	icon_cols: int,
	panel_tex: raylib.RenderTexture,
	tex_offset: [2]f32,
	max_panel_height: f32,
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
	}
}
init_default_style :: proc(){
	using ctx.style
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
	padding = 16
	spacing = 14
	corner_radius = 5
	icon_size = 24
	font = raylib.LoadFontEx("./fonts/Muli-SemiBold.ttf", 26, nil, 1024)
	raylib.SetTextureFilter(font.texture, .BILINEAR)
}

begin :: proc(){
	using ctx
	using raylib

	hide_cursor = false
	layout_idx = -1
	loc_offset = 0
	active_widget = -1

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

	if click {
		double_click_timer += GetFrameTime()
		if IsMouseButtonPressed(.LEFT) {
			double_click = true
			click = false
		}
		if double_click_timer >= DOUBLE_CLICK_TIME {
			click = false
		}
	} else {
		if IsMouseButtonPressed(.LEFT) {
			click = true
			double_click_timer = 0
		}
		if IsMouseButtonReleased(.LEFT) {
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
		if control.disabled[i] {
			continue
		}
		id := control.id[i]
		if id == hover_id {
			control.hover_time[i] += (1.0 - control.hover_time[i]) * FADE_SPEED * GetFrameTime()
		} else {
			control.hover_time[i] -= control.hover_time[i] * FADE_SPEED * GetFrameTime()
		}
		if id == focus_id {
			control.focus_time[i] += (1.0 - control.focus_time[i]) * FADE_SPEED * GetFrameTime()
		} else {
			control.focus_time[i] -= control.focus_time[i] * FADE_SPEED * GetFrameTime()
		}
		control.exists = false
	}
	if IsMouseButtonDown(.MIDDLE) {
		SetMouseCursor(MouseCursor.RESIZE_ALL)
	} else {
		if hover_id != 0 || focus_id != 0 {
			if hover_text {
				SetMouseCursor(.IBEAM)
			} else {
				SetMouseCursor(.POINTING_HAND)
			}
		} else {
			SetMouseCursor(.DEFAULT)
		}
	}

	for i := 0; i < MAX_WIDGETS; i += 1 {
		if !(widget_reserved[i] || widget[i].time > 0.01) {
			continue
		}
		using self := &widget[i]
		half_width, half_height := rect.width / 2, rect.height / 2
		rlPushMatrix()
		rlTranslatef(rect.x + half_width, rect.y + half_height, 0)
		if widget_reserved[i] {
			rlScalef(1.1 - time * 0.1, 1.1 - time * 0.1, 0)
			time += (1 - time) * FADE_SPEED * GetFrameTime()
		} else {
			rlScalef(0.9 + time * 0.1, 0.9 + time * 0.1, 0)
			time -= time * FADE_SPEED * GetFrameTime()
		}
		//draw_shadow(rect, style.corner_radius * 2, 24, {0, 0, 0, u8(self.time * 50)})
		radius := style.corner_radius * 2
		if .no_title_bar not_in opts {
			title_rect := Rectangle{-half_width, -half_height - TITLE_BAR_HEIGHT, rect.width, TITLE_BAR_HEIGHT}
			draw_rounded_rect_pro(title_rect, {radius, radius, 0, 0}, CORNER_VERTS, Fade(style.colors[.highlight], self.time))
			draw_aligned_string(style.font, title, {title_rect.x + style.spacing, title_rect.y + title_rect.height / 2}, cast(f32)style.font.baseSize, Fade(style.colors[.foreground], self.time), .near, .center)
			if CheckCollisionPointRec(GetMousePosition(), {rect.x, rect.y - TITLE_BAR_HEIGHT, rect.width, TITLE_BAR_HEIGHT}) {
				if IsMouseButtonPressed(.LEFT) {
					drag_from = {rect.x, rect.y} - mouse_point
					widget_drag = i
				}
				if i == widget_drag && IsMouseButtonDown(.LEFT) {
					rect.x = mouse_point.x + drag_from.x
					rect.y = mouse_point.y + drag_from.y 
				}
			}
		}
		draw_render_surface(panel_tex, {tex_offset.x, tex_offset.y, rect.width, rect.height}, {-half_width, -half_height, rect.width, rect.height}, Fade(WHITE, self.time))
		rlPopMatrix()
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