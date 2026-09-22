@tool
class_name BayterekLocalizationPlaceholderHighlighter
extends SyntaxHighlighter
## SyntaxHighlighter that colours two kinds of placeholders in a TextEdit:
##
##   {name}       → soft blue    (runtime argument)
##   {@key}       → soft purple  (nested translation reference)
##
## Detects `{@key}` on the fly by looking at the first character after the
## opening brace.

const ARG_COLOR := Color("8eb4ff")
const KEY_COLOR := Color("c68eff")
const BOLD := true

func _get_line_syntax_highlighting(line: int) -> Dictionary:
	var te: TextEdit = get_text_edit()
	if not te:
		return {}

	var line_text: String = te.get_line(line)
	var result: Dictionary = {}

	var i: int = 0
	var n: int = line_text.length()
	var default_color: Color = te.get_theme_color("font_color")

	while i < n:
		var c: String = line_text[i]

		if c == "{":
			var close_idx: int = line_text.find("}", i + 1)
			if close_idx == -1:
				break

			var inner: String = line_text.substr(i + 1, close_idx - i - 1).strip_edges()
			if inner.is_empty():
				i = close_idx + 1
				continue

			var is_key_ref: bool = inner.begins_with("@")
			var color: Color = KEY_COLOR if is_key_ref else ARG_COLOR

			var region: Dictionary = {"color": color}
			if BOLD:
				region["bold"] = true
			result[i] = region

			var reset_at: int = close_idx + 1
			if reset_at < n:
				result[reset_at] = {"color": default_color}

			i = close_idx + 1
		else:
			i += 1

	return result