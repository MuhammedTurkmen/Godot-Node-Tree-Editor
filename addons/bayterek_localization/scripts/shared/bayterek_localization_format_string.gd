@tool
class_name BayterekLocalizationFormatString
extends RefCounted
## Parser + replacer for "{placeholder}" syntax.
##
## Supported:
##   "Hello {player_name}!"                 -> { player_name: "Ahmet" }
##   "You have {count} coins in {world}."   -> { count: 5, world: "Bayterek" }
##
## Escaping: use "{{" for a literal "{" and "}}" for a literal "}".
## Missing keys are left untouched ("{unknown}" stays "{unknown}").
##
## This class is stateless — all methods are static.

const OPEN := "{"
const CLOSE := "}"

## Returns every placeholder found in `text`, in order of appearance.
## Duplicates are removed (returns unique names).
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
			var name: String = text.substr(i + 1, close_idx - i - 1).strip_edges()
			if not name.is_empty() and not seen.has(name):
				seen[name] = true
				out.append(name)
			i = close_idx + 1
		else:
			i += 1

	return out

## Replaces every placeholder with the corresponding value from `args`.
## Values are converted with str(). Missing keys stay as-is.
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

			var name: String = text.substr(i + 1, close_idx - i - 1).strip_edges()
			if args.has(name):
				out += str(args[name])
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

## Returns true if `text` contains at least one well-formed placeholder.
static func has_placeholders(text: String) -> bool:
	return not extract_placeholders(text).is_empty()

## Compares two strings' placeholder sets.
## Returns { "missing": [...], "extra": [...] }
##   - "missing" = placeholders in `original` that are NOT in `translation`
##   - "extra"   = placeholders in `translation` that are NOT in `original`
static func compare_placeholders(original: String, translation: String) -> Dictionary:
	var orig_set: PackedStringArray = extract_placeholders(original)
	var trans_set: PackedStringArray = extract_placeholders(translation)

	var missing: PackedStringArray = []
	var extra: PackedStringArray = []

	for p in orig_set:
		if not trans_set.has(p):
			missing.append(p)
	for p in trans_set:
		if not orig_set.has(p):
			extra.append(p)

	return {"missing": missing, "extra": extra}