package gui
import "core:strings"
import "core:unicode/utf8"
import "vendor:raylib"

insert_string_to_buffer :: proc(data: ^[dynamic]u8, str: string){
	if ctx.cursor.length > 0 {
		remove_range(data, ctx.cursor.index, ctx.cursor.index + ctx.cursor.length)
		ctx.cursor.length = 0
	}
	inject_at_elem_string(data, ctx.cursor.index, str)
	ctx.cursor.index += len(str)
}


insert_runes_to_buffer :: proc(data: ^[dynamic]u8, runes: []rune){
	insert_string_to_buffer(data, utf8.runes_to_string(runes))
}


backspace_buffer :: proc(data: ^[dynamic]u8){
	using ctx
	if cursor.length == 0 {
		if cursor.index > 0 {
			end := cursor.index
			_, size := utf8.decode_last_rune_in_bytes(data[:cursor.index])
			cursor.index -= size
			remove_range(data, cursor.index, end)
		}
	} else {
		remove_range(data, cursor.index, cursor.index + cursor.length)
		cursor.length = 0
	}
}


erase_from_buffer :: proc(data: ^[dynamic]u8){
	using ctx
	if cursor.length == 0 {
		ordered_remove(data, cursor.index)
	} else {
		remove_range(data, cursor.index, cursor.index + cursor.length)
		cursor.length = 0
	}
}

quick_seek_buffer :: proc(data: ^[dynamic]u8, from: int, back: bool) -> int{
	m := back ? -1 : 1
	i := from
	w := false
	for {
		im := i + m
		if im < 0 || im >= len(data) {
			return i
		}
		rn := data[im]
		if i == from && rn == '\n' {
			return back ? im : i
		}
		if rn == ' ' || rn == ',' || rn == '/' || rn == '\\' {
			if w {
				return i
			} else if i == from {
				w = true
			}
		} else {
			w = true
			if (rn == '\n') {
				return i
			}
		}
		i += m
	}
}