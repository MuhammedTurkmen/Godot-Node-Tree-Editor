@tool
class_name BayterekLocalizationFormatString
extends RefCounted
## Parser + replacer for two placeholder syntaxes:
##
##   {name}   → runtime argument (from args Dictionary)
##   {@key}   → nested translation key reference
##
## Resolution rule (used by GameLocalization):
##   {name}   → try args first, then fall back to key lookup
##   {@key}   → always a key lookup, never args
##
## Escaping: "{{" -> "{", "}}" -> "}"
##
## Stateless — all methods are static.

const OPEN := "{"
const CLOSE := "}"
const KEY_MARKER := "@"

const MAX_NESTING_DEPTH := 8

# ============================================================
# EXTRACTION
# ============================================================

static func extract_placeholders(text: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var seen: Dictionary = {}
	var i: int = 0
	var n: int = text.length()

	while i < n:
		var c: String = text[i]
		if c == OPEN:
			if i + 1 < n and text[i + 1] == OPEN:
				i += 2
				continue
			var close_idx: int = text.find(CLOSE, i + 1)
			if close_idx == -1:
				break
			var raw: String = text.substr(i + 1, close_idx - i - 1).strip_edges()
			var name: String = _strip_key_marker(raw)
			if not name.is_empty() and not seen.has(name):
				seen[name] = true
				out.append(name)
			i = close_idx + 1
		else:
			i += 1

	return out

## Returns placeholders that look like plain args ({name}, no @).
static func extract_args(text: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var seen: Dictionary = {}
	var i: int = 0
	var n: int = text.length()

	while i < n:
		var c: String = text[i]
		if c == OPEN:
			if i + 1 < n and text[i + 1] == OPEN:
				i += 2
				continue
			var close_idx: int = text.find(CLOSE, i + 1)
			if close_idx == -1:
				break
			var raw: String = text.substr(i + 1, close_idx - i - 1).strip_edges()
			if not raw.begins_with(KEY_MARKER):
				if not raw.is_empty() and not seen.has(raw):
					seen[raw] = true
					out.append(raw)
			i = close_idx + 1
		else:
			i += 1

	return out

## Returns nested key references ({@key}), stripped of @.
static func extract_key_references(text: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var seen: Dictionary = {}
	var i: int = 0
	var n: int = text.length()

	while i < n:
		var c: String = text[i]
		if c == OPEN:
			if i + 1 < n and text[i + 1] == OPEN:
				i += 2
				continue
			var close_idx: int = text.find(CLOSE, i + 1)
			if close_idx == -1:
				break
			var raw: String = text.substr(i + 1, close_idx - i - 1).strip_edges()
			if raw.begins_with(KEY_MARKER):
				var name: String = raw.substr(KEY_MARKER.length()).strip_edges()
				if not name.is_empty() and not seen.has(name):
					seen[name] = true
					out.append(name)
			i = close_idx + 1
		else:
			i += 1

	return out

# ============================================================
# FORMAT (args only)
# ============================================================

## Replaces {name} with args[name]. {@key} references are left untouched.
static func format(text: String, args: Dictionary) -> String:
	if args.is_empty():
		return text

	var out: String = ""
	var i: int = 0
	var n: int = text.length()

	while i < n:
		var c: String = text[i]
		if c == OPEN:
			if i + 1 < n and text[i + 1] == OPEN:
				out += OPEN
				i += 2
				continue
			var close_idx: int = text.find(CLOSE, i + 1)
			if close_idx == -1:
				out += text.substr(i)
				break
			var raw: String = text.substr(i + 1, close_idx - i - 1).strip_edges()
			if args.has(raw):
				out += str(args[raw])
			else:
				out += text.substr(i, close_idx - i + 1)
			i = close_idx + 1
		elif c == CLOSE:
			if i + 1 < n and text[i + 1] == CLOSE:
				out += CLOSE
				i += 2
			else:
				out += CLOSE
				i += 1
		else:
			out += c
			i += 1

	return out

## Same as format() but missing args become "[name]" markers.
static func format_visible(text: String, args: Dictionary) -> String:
	var out: String = ""
	var i: int = 0
	var n: int = text.length()

	while i < n:
		var c: String = text[i]
		if c == OPEN:
			if i + 1 < n and text[i + 1] == OPEN:
				out += OPEN
				i += 2
				continue
			var close_idx: int = text.find(CLOSE, i + 1)
			if close_idx == -1:
				out += text.substr(i)
				break
			var raw: String = text.substr(i + 1, close_idx - i - 1).strip_edges()
			if not raw.begins_with(KEY_MARKER):
				if args.has(raw):
					out += str(args[raw])
				else:
					out += "[%s]" % raw
			else:
				out += text.substr(i, close_idx - i + 1)
			i = close_idx + 1
		elif c == CLOSE:
			if i + 1 < n and text[i + 1] == CLOSE:
				out += CLOSE
				i += 2
			else:
				out += CLOSE
				i += 1
		else:
			out += c
			i += 1

	return out

# ============================================================
# RESOLVE — args + nested {@key}
# ============================================================

static func resolve(text: String, args: Dictionary, lookup: Callable) -> String:
	return _resolve_inner(text, args, lookup, 0, false)

static func resolve_visible(text: String, args: Dictionary, lookup: Callable) -> String:
	return _resolve_inner(text, args, lookup, 0, true)

# ============================================================
# INTERNAL
# ============================================================

static func _strip_key_marker(raw: String) -> String:
	if raw.begins_with(KEY_MARKER):
		return raw.substr(KEY_MARKER.length()).strip_edges()
	return raw

static func _resolve_inner(
	text: String,
	args: Dictionary,
	lookup: Callable,
	depth: int,
	visible_missing: bool
) -> String:
	if depth > MAX_NESTING_DEPTH:
		return text

	var out: String = ""
	var i: int = 0
	var n: int = text.length()

	while i < n:
		var c: String = text[i]

		if c == OPEN:
			if i + 1 < n and text[i + 1] == OPEN:
				out += OPEN
				i += 2
				continue

			var close_idx: int = text.find(CLOSE, i + 1)
			if close_idx == -1:
				out += text.substr(i)
				break

			var raw: String = text.substr(i + 1, close_idx - i - 1).strip_edges()

			if raw.begins_with(KEY_MARKER):
				var key_name: String = raw.substr(KEY_MARKER.length()).strip_edges()
				var nested: String = ""
				if not key_name.is_empty() and lookup.is_valid():
					var res = lookup.call(key_name)
					nested = "" if res == null else String(res)

				if nested.is_empty():
					out += text.substr(i, close_idx - i + 1)
				else:
					out += _resolve_inner(nested, args, lookup, depth + 1, visible_missing)
			else:
				if args.has(raw):
					var v = args[raw]
					out += str(v) if v != null else ""
				else:
					var from_key: String = ""
					if lookup.is_valid():
						var res2 = lookup.call(raw)
						from_key = "" if res2 == null else String(res2)

					if not from_key.is_empty():
						out += _resolve_inner(from_key, args, lookup, depth + 1, visible_missing)
					elif visible_missing:
						out += "[%s]" % raw
					else:
						out += text.substr(i, close_idx - i + 1)

			i = close_idx + 1

		elif c == CLOSE:
			if i + 1 < n and text[i + 1] == CLOSE:
				out += CLOSE
				i += 2
			else:
				out += CLOSE
				i += 1
		else:
			out += c
			i += 1

	return out

# ============================================================
# VALIDATION
# ============================================================

static func has_placeholders(text: String) -> bool:
	return not extract_placeholders(text).is_empty()

## Compares two strings' ARGUMENT placeholder sets.
## Key references ({@key}) are NOT compared here — they are validated
## separately by the Editor (broken reference / cycle detection).
##
## Returns { "missing": [...], "extra": [...] }
static func compare_placeholders(original: String, translation: String) -> Dictionary:
	var orig_set: PackedStringArray = extract_args(original)
	var trans_set: PackedStringArray = extract_args(translation)

	var missing: PackedStringArray = []
	var extra: PackedStringArray = []

	for p in orig_set:
		if not trans_set.has(p):
			missing.append(p)
	for p in trans_set:
		if not orig_set.has(p):
			extra.append(p)

	return {"missing": missing, "extra": extra}