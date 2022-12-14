package gui
import "vendor:raylib"
import "core:math"
import "core:fmt"

Icon :: enum {
    glyphs,
    undo,
    redo,
    heart,
    star,
}
draw_icon :: proc(origin: [2]f32, icon: Icon, align_x, align_y: Alignment, tint: Color){
    using ctx
    origin := origin
    size := f32(style.icon_size)
    if align_x == .center {
        origin.x -= size / 2
    } else if align_x == .far {
        origin.x -= size
    }
    if align_y == .center {
        origin.y -= size / 2
    } else if align_y == .far {
        origin.y -= size
    }
    raylib.DrawTexturePro(icon_atlas, {f32(int(icon) % icon_cols) * size, f32(int(icon) / icon_cols) * size, size, size}, {origin.x, origin.y, size, size}, {0, 0}, 0, tint)
}

expand_rect :: proc(rect: Rectangle, scale: f32) -> Rectangle {
    return {rect.x - scale, rect.y - scale, rect.width + scale * 2, rect.height + scale * 2}
}

draw_circle_gradient :: proc(x, y, radius, start, end: f32, color1, color2: Color) {
    using raylib
    rlBegin(RL_TRIANGLES)
    for i := start; i < end; i += 10 {
        rlColor4ub(color1.r, color1.g, color1.b, color1.a)
        rlVertex2f(x, y)
        rlColor4ub(color2.r, color2.g, color2.b, color2.a)
        rlVertex2f(x + math.sin(DEG2RAD * i) * radius, y + math.cos(DEG2RAD * i) * radius)
        rlColor4ub(color2.r, color2.g, color2.b, color2.a)
        rlVertex2f(x + math.sin(DEG2RAD * (i + 10)) * radius, y + math.cos(DEG2RAD * (i + 10)) * radius)
    }
    rlEnd()
}

draw_render_surface :: proc(surf: raylib.RenderTexture, src, dst: Rectangle, tint: Color) {
    raylib.DrawTexturePro(surf.texture, { src.x, -src.y - src.height, src.width, -src.height }, dst, { 0, 0 }, -0.01, tint)
}

blend_colors :: proc(dst: Color, src: Color, val: f32) -> Color{
    return raylib.ColorAlphaBlend(dst, src, raylib.Fade(raylib.WHITE, val))
}


draw_rounded_rect_pro :: proc(rec: Rectangle, radii: [4]f32, segments: int, color: Color) {
    using raylib
    // Not a rounded rectangle
    if (radii == {}) || (rec.width < 1) || (rec.height < 1 ) {
        DrawRectangleRec(rec, color);
        return;
    }

    // Calculate number of segments to use for the corners
    stepLength := 90.0 / f32(segments)

    /*
    Quick sketch to make sense of all of this,
    there are 9 parts to draw, also mark the 12 points we'll use

          P0____________________P1
          /|                    |\
         /1|          2         |3\
     P7 /__|____________________|__\ P2
       |   |P8                P9|   |
       | 8 |          9         | 4 |
       | __|____________________|__ |
     P6 \  |P11              P10|  / P3
         \7|          6         |5/
          \|____________________|/
          P5                    P4
    */
    // Coordinates of the 12 points that define the rounded rect
    point := [12]Vector2 {
        {rec.x + radii[0], rec.y}, {(rec.x + rec.width) - radii[1], rec.y}, { rec.x + rec.width, rec.y + radii[1] },     // PO, P1, P2
        {rec.x + rec.width, (rec.y + rec.height) - radii[2]}, {(rec.x + rec.width) - radii[2], rec.y + rec.height},           // P3, P4
        {rec.x + radii[3], rec.y + rec.height}, { rec.x, (rec.y + rec.height) - radii[3]}, {rec.x, rec.y + radii[0]},    // P5, P6, P7
        {rec.x + radii[0], rec.y + radii[0]}, {(rec.x + rec.width) - radii[1], rec.y + radii[1]},                   // P8, P9
        {(rec.x + rec.width) - radii[2], (rec.y + rec.height) - radii[2]}, {rec.x + radii[3], (rec.y + rec.height) - radii[3]}, // P10, P11
    }

    centers := [4]Vector2 { point[8], point[9], point[10], point[11] }
    angles := [4]f32 { 180.0, 90.0, 0.0, 270.0 }

    rlBegin(RL_TRIANGLES)

        // Draw all of the 4 corners: [1] Upper Left Corner, [3] Upper Right Corner, [5] Lower Right Corner, [7] Lower Left Corner
        for k := 0; k < 4; k += 1 // Hope the compiler is smart enough to unroll this loop
        {
            radius := radii[k]
            segments := segments
            if radius == 0 {
                radius *= math.SQRT_TWO
                segments = 1
            }
            angle := angles[k]
            center := centers[k]
            for i := 0; i < segments; i += 1
            {
                rlColor4ub(color.r, color.g, color.b, color.a)
                rlVertex2f(center.x, center.y)
                rlVertex2f(center.x + math.sin_f32(DEG2RAD * angle) * radius, center.y + math.cos_f32(DEG2RAD*angle) * radius)
                rlVertex2f(center.x + math.sin_f32(DEG2RAD * (angle + stepLength)) * radius, center.y + math.cos_f32(DEG2RAD*(angle + stepLength)) * radius)
                angle += stepLength
            }
        }

        // [2] Upper Rectangle
        rlColor4ub(color.r, color.g, color.b, color.a)
        rlVertex2f(point[0].x, point[0].y)
        rlVertex2f(point[8].x, point[8].y)
        rlVertex2f(point[9].x, point[9].y)
        rlVertex2f(point[1].x, point[1].y)
        rlVertex2f(point[0].x, point[0].y)
        rlVertex2f(point[9].x, point[9].y)

        // [4] Right Rectangle
        rlColor4ub(color.r, color.g, color.b, color.a)
        rlVertex2f(point[9].x, point[9].y)
        rlVertex2f(point[10].x, point[10].y)
        rlVertex2f(point[3].x, point[3].y)
        rlVertex2f(point[2].x, point[2].y)
        rlVertex2f(point[9].x, point[9].y)
        rlVertex2f(point[3].x, point[3].y)

        // [6] Bottom Rectangle
        rlColor4ub(color.r, color.g, color.b, color.a)
        rlVertex2f(point[11].x, point[11].y)
        rlVertex2f(point[5].x, point[5].y)
        rlVertex2f(point[4].x, point[4].y)
        rlVertex2f(point[10].x, point[10].y)
        rlVertex2f(point[11].x, point[11].y)
        rlVertex2f(point[4].x, point[4].y)

        // [8] Left Rectangle
        rlColor4ub(color.r, color.g, color.b, color.a)
        rlVertex2f(point[7].x, point[7].y)
        rlVertex2f(point[6].x, point[6].y)
        rlVertex2f(point[11].x, point[11].y)
        rlVertex2f(point[8].x, point[8].y)
        rlVertex2f(point[7].x, point[7].y)
        rlVertex2f(point[11].x, point[11].y)

        // [9] Middle Rectangle
        rlColor4ub(color.r, color.g, color.b, color.a)
        rlVertex2f(point[8].x, point[8].y)
        rlVertex2f(point[11].x, point[11].y)
        rlVertex2f(point[10].x, point[10].y)
        rlVertex2f(point[9].x, point[9].y)
        rlVertex2f(point[8].x, point[8].y)
        rlVertex2f(point[10].x, point[10].y)
    rlEnd()
}

draw_rounded_rect :: proc(rec: Rectangle, radius: f32, segments: int, color: Color) {
	using raylib
    // Not a rounded rectangle
    if (radius <= 0.0) || (rec.width < 1) || (rec.height < 1 ) {
        DrawRectangleRec(rec, color);
        return;
    }

    // Calculate number of segments to use for the corners
    stepLength := 90.0 / f32(segments)

    /*
    Quick sketch to make sense of all of this,
    there are 9 parts to draw, also mark the 12 points we'll use

          P0____________________P1
          /|                    |\
         /1|          2         |3\
     P7 /__|____________________|__\ P2
       |   |P8                P9|   |
       | 8 |          9         | 4 |
       | __|____________________|__ |
     P6 \  |P11              P10|  / P3
         \7|          6         |5/
          \|____________________|/
          P5                    P4
    */
    // Coordinates of the 12 points that define the rounded rect
    point := [12]Vector2 {
        {rec.x + radius, rec.y}, {(rec.x + rec.width) - radius, rec.y}, { rec.x + rec.width, rec.y + radius },     // PO, P1, P2
        {rec.x + rec.width, (rec.y + rec.height) - radius}, {(rec.x + rec.width) - radius, rec.y + rec.height},           // P3, P4
        {rec.x + radius, rec.y + rec.height}, { rec.x, (rec.y + rec.height) - radius}, {rec.x, rec.y + radius},    // P5, P6, P7
        {rec.x + radius, rec.y + radius}, {(rec.x + rec.width) - radius, rec.y + radius},                   // P8, P9
        {(rec.x + rec.width) - radius, (rec.y + rec.height) - radius}, {rec.x + radius, (rec.y + rec.height) - radius}, // P10, P11
    }

    centers := [4]Vector2 { point[8], point[9], point[10], point[11] }
    angles := [4]f32 { 180.0, 90.0, 0.0, 270.0 }

    rlBegin(RL_TRIANGLES)

        // Draw all of the 4 corners: [1] Upper Left Corner, [3] Upper Right Corner, [5] Lower Right Corner, [7] Lower Left Corner
        for k := 0; k < 4; k += 1 // Hope the compiler is smart enough to unroll this loop
        {
            angle := angles[k]
            center := centers[k]
            for i := 0; i < segments; i += 1
            {
                rlColor4ub(color.r, color.g, color.b, color.a)
                rlVertex2f(center.x, center.y)
                rlVertex2f(center.x + math.sin_f32(DEG2RAD * angle) * radius, center.y + math.cos_f32(DEG2RAD*angle) * radius)
                rlVertex2f(center.x + math.sin_f32(DEG2RAD * (angle + stepLength)) * radius, center.y + math.cos_f32(DEG2RAD*(angle + stepLength)) * radius)
                angle += stepLength
            }
        }

        // [2] Upper Rectangle
        rlColor4ub(color.r, color.g, color.b, color.a)
        rlVertex2f(point[0].x, point[0].y)
        rlVertex2f(point[8].x, point[8].y)
        rlVertex2f(point[9].x, point[9].y)
        rlVertex2f(point[1].x, point[1].y)
        rlVertex2f(point[0].x, point[0].y)
        rlVertex2f(point[9].x, point[9].y)

        // [4] Right Rectangle
        rlColor4ub(color.r, color.g, color.b, color.a)
        rlVertex2f(point[9].x, point[9].y)
        rlVertex2f(point[10].x, point[10].y)
        rlVertex2f(point[3].x, point[3].y)
        rlVertex2f(point[2].x, point[2].y)
        rlVertex2f(point[9].x, point[9].y)
        rlVertex2f(point[3].x, point[3].y)

        // [6] Bottom Rectangle
        rlColor4ub(color.r, color.g, color.b, color.a)
        rlVertex2f(point[11].x, point[11].y)
        rlVertex2f(point[5].x, point[5].y)
        rlVertex2f(point[4].x, point[4].y)
        rlVertex2f(point[10].x, point[10].y)
        rlVertex2f(point[11].x, point[11].y)
        rlVertex2f(point[4].x, point[4].y)

        // [8] Left Rectangle
        rlColor4ub(color.r, color.g, color.b, color.a)
        rlVertex2f(point[7].x, point[7].y)
        rlVertex2f(point[6].x, point[6].y)
        rlVertex2f(point[11].x, point[11].y)
        rlVertex2f(point[8].x, point[8].y)
        rlVertex2f(point[7].x, point[7].y)
        rlVertex2f(point[11].x, point[11].y)

        // [9] Middle Rectangle
        rlColor4ub(color.r, color.g, color.b, color.a)
        rlVertex2f(point[8].x, point[8].y)
        rlVertex2f(point[11].x, point[11].y)
        rlVertex2f(point[10].x, point[10].y)
        rlVertex2f(point[9].x, point[9].y)
        rlVertex2f(point[8].x, point[8].y)
        rlVertex2f(point[10].x, point[10].y)
    rlEnd()
}

draw_rounded_rect_lines :: proc(rec: Rectangle, radius: f32, segments: int, lineThick: f32, color: Color) {
	using raylib
	if lineThick <= 0 {
        return
    }

    // Not a rounded rectangle
    if (radius <= 0.0)
    {
        DrawRectangleLinesEx((Rectangle){rec.x-lineThick, rec.y-lineThick, rec.width+2*lineThick, rec.height+2*lineThick}, lineThick, color);
        return;
    }

    // Calculate number of segments to use for the corners
    stepLength := 90.0 / f32(segments)
    outerRadius := radius + lineThick
    innerRadius := radius

    /*
    Quick sketch to make sense of all of this,
    marks the 16 + 4(corner centers P16-19) points we'll use

           P0 ================== P1
          // P8                P9 \\
         //                        \\
     P7 // P15                  P10 \\ P2
       ||   *P16             P17*    ||
       ||                            ||
       || P14                   P11  ||
     P6 \\  *P19             P18*   // P3
         \\                        //
          \\ P13              P12 //
           P5 ================== P4
    */
    point := [16]Vector2 {
        {rec.x + innerRadius, rec.y - lineThick}, {(rec.x + rec.width) - innerRadius, rec.y - lineThick}, { rec.x + rec.width + lineThick, rec.y + innerRadius }, // PO, P1, P2
        {rec.x + rec.width + lineThick, (rec.y + rec.height) - innerRadius}, {(rec.x + rec.width) - innerRadius, rec.y + rec.height + lineThick}, // P3, P4
        {rec.x + innerRadius, rec.y + rec.height + lineThick}, { rec.x - lineThick, (rec.y + rec.height) - innerRadius}, {rec.x - lineThick, rec.y + innerRadius}, // P5, P6, P7
        {rec.x + innerRadius, rec.y}, {(rec.x + rec.width) - innerRadius, rec.y}, // P8, P9
        { rec.x + rec.width, rec.y + innerRadius }, {rec.x + rec.width, (rec.y + rec.height) - innerRadius}, // P10, P11
        {(rec.x + rec.width) - innerRadius, rec.y + rec.height}, {rec.x + innerRadius, rec.y + rec.height}, // P12, P13
        { rec.x,(rec.y + rec.height) - innerRadius}, {rec.x, rec.y + innerRadius}, // P14, P15
    };

    centers := [4]Vector2{
        {rec.x + innerRadius, rec.y + innerRadius}, {(rec.x + rec.width) - innerRadius, rec.y + innerRadius}, // P16, P17
        {(rec.x + rec.width) - innerRadius, (rec.y + rec.height) - innerRadius}, {rec.x + innerRadius, (rec.y + rec.height) - innerRadius}, // P18, P19
    };

    angles := [4]f32 { 180.0, 90.0, 0.0, 270.0 }

    if lineThick > 1 {
        rlBegin(RL_TRIANGLES)

            // Draw all of the 4 corners first: Upper Left Corner, Upper Right Corner, Lower Right Corner, Lower Left Corner
            for k := 0; k < 4; k += 1 // Hope the compiler is smart enough to unroll this loop
            {
                angle := angles[k]
                center := centers[k]

                for i := 0; i < segments; i += 1 {
                    rlColor4ub(color.r, color.g, color.b, color.a)

                    rlVertex2f(center.x + math.sin_f32(DEG2RAD*angle)*innerRadius, center.y + math.cos_f32(DEG2RAD*angle)*innerRadius)
                    rlVertex2f(center.x + math.sin_f32(DEG2RAD*angle)*outerRadius, center.y + math.cos_f32(DEG2RAD*angle)*outerRadius)
                    rlVertex2f(center.x + math.sin_f32(DEG2RAD*(angle + stepLength))*innerRadius, center.y + math.cos_f32(DEG2RAD*(angle + stepLength))*innerRadius)

                    rlVertex2f(center.x + math.sin_f32(DEG2RAD*(angle + stepLength))*innerRadius, center.y + math.cos_f32(DEG2RAD*(angle + stepLength))*innerRadius)
                    rlVertex2f(center.x + math.sin_f32(DEG2RAD*angle)*outerRadius, center.y + math.cos_f32(DEG2RAD*angle)*outerRadius)
                    rlVertex2f(center.x + math.sin_f32(DEG2RAD*(angle + stepLength))*outerRadius, center.y + math.cos_f32(DEG2RAD*(angle + stepLength))*outerRadius)

                    angle += stepLength
                }
            }

            // Upper rectangle
            rlColor4ub(color.r, color.g, color.b, color.a)
            rlVertex2f(point[0].x, point[0].y)
            rlVertex2f(point[8].x, point[8].y)
            rlVertex2f(point[9].x, point[9].y)
            rlVertex2f(point[1].x, point[1].y)
            rlVertex2f(point[0].x, point[0].y)
            rlVertex2f(point[9].x, point[9].y)

            // Right rectangle
            rlColor4ub(color.r, color.g, color.b, color.a)
            rlVertex2f(point[10].x, point[10].y)
            rlVertex2f(point[11].x, point[11].y)
            rlVertex2f(point[3].x, point[3].y)
            rlVertex2f(point[2].x, point[2].y)
            rlVertex2f(point[10].x, point[10].y)
            rlVertex2f(point[3].x, point[3].y)

            // Lower rectangle
            rlColor4ub(color.r, color.g, color.b, color.a)
            rlVertex2f(point[13].x, point[13].y)
            rlVertex2f(point[5].x, point[5].y)
            rlVertex2f(point[4].x, point[4].y)
            rlVertex2f(point[12].x, point[12].y)
            rlVertex2f(point[13].x, point[13].y)
            rlVertex2f(point[4].x, point[4].y)

            // Left rectangle
            rlColor4ub(color.r, color.g, color.b, color.a)
            rlVertex2f(point[7].x, point[7].y)
            rlVertex2f(point[6].x, point[6].y)
            rlVertex2f(point[14].x, point[14].y)
            rlVertex2f(point[15].x, point[15].y)
            rlVertex2f(point[7].x, point[7].y)
            rlVertex2f(point[14].x, point[14].y)
        rlEnd();
    } else {
        // Use LINES to draw the outline
        rlBegin(RL_LINES)

            // Draw all of the 4 corners first: Upper Left Corner, Upper Right Corner, Lower Right Corner, Lower Left Corner
            for k := 0; k < 4; k += 1 // Hope the compiler is smart enough to unroll this loop
            {
                angle := angles[k];
                center := centers[k];

                for i := 0; i < segments; i += 1
                {
                    rlColor4ub(color.r, color.g, color.b, color.a)
                    rlVertex2f(center.x + math.sin_f32(DEG2RAD*angle)*outerRadius, center.y + math.cos_f32(DEG2RAD*angle)*outerRadius)
                    rlVertex2f(center.x + math.sin_f32(DEG2RAD*(angle + stepLength))*outerRadius, center.y + math.cos_f32(DEG2RAD*(angle + stepLength))*outerRadius)
                    angle += stepLength
                }
            }

            // And now the remaining 4 lines
            for i := 0; i < 8; i += 2
            {
                rlColor4ub(color.r, color.g, color.b, color.a)
                rlVertex2f(point[i].x, point[i].y)
                rlVertex2f(point[i + 1].x, point[i + 1].y)
            }

        rlEnd()
    }
}