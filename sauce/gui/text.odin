package gui
import "vendor:raylib"
import "core:strings"
import "core:fmt"

count_noun :: proc(count: int, noun: string) -> string {
    return fmt.aprintf("%i %s%s", count, noun, "" if count == 1 else "s")
}

TEXT_SPACING :: 1
get_rune :: proc(text: string, byte_count: ^int) -> rune {
    codepoint := rune(u8(0x3f))
    byte_count^ = 0
    
    // Get current codepoint and bytes processed
    if 0xf0 == (0xf8 & text[0]) {
        // 4 byte UTF-8 codepoint
        codepoint = rune(((0x07 & text[0]) << 18) | ((0x3f & text[1]) << 12) | ((0x3f & text[2]) << 6) | (0x3f & text[3]));
        byte_count^ = 4;
    }
    else if 0xe0 == (0xf0 & text[0]) {
        // 3 byte UTF-8 codepoint */
        codepoint = rune(((0x0f & text[0]) << 12) | ((0x3f & text[1]) << 6) | (0x3f & text[2]));
        byte_count^ = 3;
    } 
    else if 0xc0 == (0xe0 & text[0]) {
        // 2 byte UTF-8 codepoint
        codepoint = rune(((0x1f & text[0]) << 6) | (0x3f & text[1]));
        byte_count^ = 2;
    } 
    else {
        // 1 byte UTF-8 codepoint
        codepoint = rune(text[0]);
        byte_count^ = 1;
    }
    
    return codepoint;
}
draw_rune_pro :: proc(font: Font, rn: rune, point: [2]f32, rect: Rectangle, size: f32, tint: Color) {
    using raylib
    // Character index position in sprite font
    // NOTE: In case a codepoint is not available in the font, index returned points to '?'
    index := GetGlyphIndex(font, rn)
    scale_factor := size / cast(f32)font.baseSize     // Character quad scaling factor

    // Character destination rectangle on screen
    // NOTE: We consider glyphPadding on drawing
    dst := Rectangle{ point.x + cast(f32)font.chars[index].offsetX * scale_factor - cast(f32)font.charsPadding * scale_factor, point.y + cast(f32)font.chars[index].offsetY * scale_factor - cast(f32)font.charsPadding * scale_factor, (font.recs[index].width + 2.0 * cast(f32)font.charsPadding) * scale_factor, (font.recs[index].height + 2.0 * cast(f32)font.charsPadding) * scale_factor }

    // Character source rectangle from font texture atlas
    // NOTE: We consider chars padding when drawing, it could be required for outline/glow shader effects
    src := Rectangle{ font.recs[index].x - cast(f32)font.charsPadding, font.recs[index].y - cast(f32)font.charsPadding, font.recs[index].width + 2.0 * cast(f32)font.charsPadding, font.recs[index].height + 2.0 * cast(f32)font.charsPadding }
    if src.width > rect.width {
        src.width = rect.width
        dst.width = rect.width
    }
    if src.height > rect.height {
        src.height = rect.height
        dst.height = rect.height
    }
    if dst.x < rect.x {
        src.width += dst.x - rect.x
        dst.width += dst.x - rect.x
        src.x += rect.x - dst.x
        dst.x = rect.x
    }
    if dst.y < rect.y {
        src.height -= rect.y - src.y
        dst.height -= rect.y - dst.y
        src.x = rect.y
        dst.x = rect.y
    }

    // Draw the character texture on the screen
    DrawTexturePro(font.texture, src, dst, {0, 0}, 0, tint)
}

measure_string :: proc(font: Font, text: string, size: f32) -> [2]f32 {
	using raylib
	text_size := ([2]f32){0.0,0.0}
	if (font.texture.id == 0) || (text == {}) do return text_size

    length := len(text)
    temp_byte_counter := 0
    byte_counter := 0

    width := f32(0.0)
    temp_width := f32(0.0)

    height := f32(font.baseSize)
    scale_factor := size / f32(font.baseSize)

    letter := rune(0)
    index := i32(0)

    for i := 0; i < length; i += 1 {
        byte_counter += 1

        next := 0
        letter = get_rune(text[i:], &next)
        index = GetGlyphIndex(font, letter)

        if (letter == 0x3f) do next = 1
        i += next - 1

        if letter != '\n' {
            if (font.chars[index].advanceX != 0) do width += f32(font.chars[index].advanceX)
            else do width += font.recs[index].width + f32(font.chars[index].offsetX)
        }
        else {
            if temp_width < width do temp_width = width
            byte_counter = 0
            width = 0
            height += f32(font.baseSize) * 1.5
        }

        if (temp_byte_counter < byte_counter) do temp_byte_counter = byte_counter;
    }

    if (temp_width < width) do temp_width = width;

    text_size.x = temp_width * scale_factor + f32((temp_byte_counter - 1) * TEXT_SPACING)
    text_size.y = height * scale_factor

    return text_size
}
draw_string :: proc(font: Font, text: string, origin: [2]f32, scale: f32, tint: Color) -> [2]f32 {
	using raylib
	if font.texture.id == 0 do return {}

    length := len(text)

    offset := [2]f32{}

    scaleFactor := scale / f32(font.baseSize)

    for i := 0; i < length; {
        bytecount := 0;
        codepoint := get_rune(text[i:], &bytecount)
        index := GetGlyphIndex(font, codepoint)

        if codepoint == 0x3f do bytecount = 1

        if codepoint == '\n' {
            offset.y += (f32(font.baseSize + font.baseSize / 2) * scaleFactor)
            offset.x = 0.0
        } else {
            if (codepoint != ' ') && (codepoint != '\t') {
                DrawTextCodepoint(font, codepoint, { origin.x + offset.x, origin.y + offset.y }, scale, tint)
            }

            if font.chars[index].advanceX == 0 do offset.x += (f32(font.recs[index].width) * scaleFactor + TEXT_SPACING)
            else do offset.x += (f32(font.chars[index].advanceX) * scaleFactor + TEXT_SPACING)
        }

        i += bytecount
    }
    offset.y += f32(font.baseSize)
    return offset
}
draw_aligned_string :: proc(font: Font, text: string, origin: [2]f32, scale: f32, tint: Color, align_x, align_y: Alignment) -> [2]f32 {
    if text == "" {
        return {}
    }
	text_size := measure_string(font, text, scale)
	offset : [2]f32 = 0.0
	if align_x == .center do offset.x -= text_size.x / 2
	else if align_x == .far do offset.x -= text_size.x
	if align_y == .center do offset.y -= text_size.y / 2
	else if align_y == .far do offset.y -= text_size.y
	return draw_string(font, text, origin + offset, scale, tint)
}
draw_bound_string :: proc(font: Font, text: string, rect: Rectangle, scale: f32, tint: Color, align_x, align_y: Alignment) -> [2]f32 {
    if text == "" {
        return {}
    }
    origin := [2]f32{rect.x, rect.y}
    if align_x == .near {
        origin.x += ctx.style.text_padding
    } else if align_x == .center {
        origin.x += rect.width / 2
    } else if align_x == .far {
        origin.x += rect.width - ctx.style.text_padding
    }
    if align_y == .near {
        origin.y += ctx.style.text_padding
    } else if align_y == .center {
        origin.y += rect.height / 2
    } else if align_y == .far {
        origin.y += rect.height - ctx.style.text_padding
    }
    return draw_aligned_string(font, text, origin, scale, tint, align_x, align_y)
}