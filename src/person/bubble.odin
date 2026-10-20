package person

import "core:fmt"
import "core:strings"
import rl "vendor:raylib"
import "../theme"

CREDITS_SPEECH_FONT :: 11
CREDITS_SPEECH_WRAP_WIDTH :: 132
CREDITS_SPEECH_LINE_GAP :: 2
CREDITS_BUBBLE_PAD :: 5
CREDITS_SPEECH_MAX_LINES :: 8
CREDITS_SPEECH_LINE_BUF :: 128

draw_speech_bubble :: proc(cx: f32, anchor_y: f32, w: f32, h: f32) {
	bx := cx - w * 0.5
	by := anchor_y - h
	rl.DrawRectangleRec({bx, by, w, h}, theme.BUBBLE_FILL)
	rl.DrawRectangleLinesEx({bx, by, w, h}, 1, theme.BUBBLE_BORDER)
}

draw_speech_bubble_text :: proc(cx: f32, anchor_y: f32, text: cstring, font: i32) {
	tw := f32(rl.MeasureText(text, font))
	bubble_w := tw + BUBBLE_PAD * 2
	bubble_h := f32(font) + BUBBLE_PAD * 2
	draw_speech_bubble(cx, anchor_y, bubble_w, bubble_h)
	rl.DrawText(
		text,
		i32(cx - tw * 0.5),
		i32(anchor_y - bubble_h + BUBBLE_PAD),
		font,
		theme.TEXT_INK,
	)
}

@(private = "file")
speech_line_set :: proc(
	buf: ^[CREDITS_SPEECH_LINE_BUF]u8,
	out_len: ^int,
	s: string,
) -> bool {
	n := len(s)
	if n >= CREDITS_SPEECH_LINE_BUF {
		return false
	}
	copy(buf[:n], s[:n])
	out_len^ = n
	buf[n] = 0
	return true
}

@(private = "file")
speech_wrap_words :: proc(
	text: cstring,
	font: i32,
	first_line_max: f32,
	line_max: f32,
	bufs: ^[CREDITS_SPEECH_MAX_LINES][CREDITS_SPEECH_LINE_BUF]u8,
	lens: ^[CREDITS_SPEECH_MAX_LINES]int,
) -> int {
	for i in 0 ..< CREDITS_SPEECH_MAX_LINES {
		lens[i] = 0
		bufs[i][0] = 0
	}

	words := strings.fields(string(text), context.temp_allocator)
	if len(words) == 0 {
		return 0
	}

	line_i := 0
	cur_max := first_line_max
	line: string = ""

	measure_line :: proc(s: string, font: i32) -> f32 {
		if s == "" {
			return 0
		}
		return f32(rl.MeasureText(strings.clone_to_cstring(s, context.temp_allocator), font))
	}

	for word in words {
		for {
			trial := word
			if line != "" {
				trial = fmt.tprintf("%s %s", line, word)
			}
			tw := measure_line(trial, font)
			if tw <= cur_max || line == "" {
				line = trial
				break
			}
			if line != "" {
				if !speech_line_set(&bufs[line_i], &lens[line_i], line) {
					return line_i + 1
				}
				line_i += 1
				if line_i >= CREDITS_SPEECH_MAX_LINES {
					return CREDITS_SPEECH_MAX_LINES
				}
				line = ""
				cur_max = line_max
				continue
			}
			if !speech_line_set(&bufs[line_i], &lens[line_i], word) {
				return line_i + 1
			}
			break
		}
	}
	if line != "" {
		if !speech_line_set(&bufs[line_i], &lens[line_i], line) {
			return line_i + 1
		}
		return line_i + 1
	}
	if lens[line_i] > 0 {
		return line_i + 1
	}
	return 0
}

draw_speech_bubble_named_wrap :: proc(
	cx: f32,
	anchor_y: f32,
	name: cstring,
	name_color: rl.Color,
	body: cstring,
	font: i32 = CREDITS_SPEECH_FONT,
	wrap_w: f32 = CREDITS_SPEECH_WRAP_WIDTH,
) {
	if body == "" {
		return
	}
	prefix := fmt.ctprintf("%s: ", name)
	prefix_w := f32(rl.MeasureText(prefix, font))
	inner_w := wrap_w - CREDITS_BUBBLE_PAD * 2
	first_max := inner_w - prefix_w
	if first_max < inner_w * 0.35 {
		first_max = inner_w * 0.35
	}

	bufs: [CREDITS_SPEECH_MAX_LINES][CREDITS_SPEECH_LINE_BUF]u8
	lens: [CREDITS_SPEECH_MAX_LINES]int
	n := speech_wrap_words(body, font, first_max, inner_w, &bufs, &lens)
	if n <= 0 {
		n = 1
		lens[0] = 0
		bufs[0][0] = 0
	}

	line_h := f32(font)
	bubble_w: f32 = 0
	for i in 0 ..< n {
		line_w := f32(rl.MeasureText(cstring(&bufs[i][0]), font))
		if i == 0 {
			line_w += prefix_w
		}
		bubble_w = max(bubble_w, line_w)
	}
	bubble_w += CREDITS_BUBBLE_PAD * 2
	bubble_w = max(bubble_w, wrap_w * 0.5)

	bubble_h :=
		CREDITS_BUBBLE_PAD * 2 + f32(n) * line_h + f32(max(n - 1, 0)) * CREDITS_SPEECH_LINE_GAP
	draw_speech_bubble(cx, anchor_y, bubble_w, bubble_h)

	bx := cx - bubble_w * 0.5
	by := anchor_y - bubble_h
	content_x := bx + CREDITS_BUBBLE_PAD
	ty := by + CREDITS_BUBBLE_PAD

	for i in 0 ..< n {
		if i == 0 {
			rl.DrawText(prefix, i32(content_x), i32(ty), font, name_color)
			body_x := content_x + prefix_w
			rl.DrawText(cstring(&bufs[0][0]), i32(body_x), i32(ty), font, theme.TEXT_INK)
		} else {
			rl.DrawText(cstring(&bufs[i][0]), i32(content_x), i32(ty), font, theme.TEXT_INK)
		}
		ty += line_h + CREDITS_SPEECH_LINE_GAP
	}
}
