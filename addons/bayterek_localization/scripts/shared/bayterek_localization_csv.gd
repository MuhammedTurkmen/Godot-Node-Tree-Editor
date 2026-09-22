@tool
class_name BayterekLocalizationCSV
extends RefCounted
## CSV parser + serializer for the localization plugin.
##
## Format:
##   key,<locale1>,<locale2>,...
##   <key>,<value1>,<value2>,...
##
## Values containing comma, quote, newline, or leading/trailing whitespace
## are wrapped in double quotes with embedded quotes doubled per RFC 4180.
##
## All static.

const DELIMITER := ","
const QUOTE := "\""
const LINE_TERMINATOR := "\n"

# ============================================================
# SERIALIZE
# ============================================================

## Serializes a table into CSV text.
##   - locale_codes: PackedStringArray of column headers (in order).
##   - rows: Array[Dictionary] — each dict maps key -> { locale -> value }.
##
## Actually rows are simpler: each row is a Dictionary where the first key
## is "key" (the translation key) and the rest are locale -> value pairs.
##
## Example input:
##   ["en-US", "tr-TR"]
##   [
##     {"key": "greetings", "en-US": "Hello", "tr-TR": "Merhaba"},
##     {"key": "menu_play", "en-US": "Play",  "tr-TR": "Oyna"},
##   ]
##
## Returns the CSV as a String.
static func serialize(locale_codes: PackedStringArray, rows: Array) -> String:
	var out: String = ""

	# Header
	out += _escape_field("key")
	for loc in locale_codes:
		out += DELIMITER + _escape_field(loc)
	out += LINE_TERMINATOR

	# Rows
	for row in rows:
		if not row is Dictionary:
			continue
		var d: Dictionary = row
		out += _escape_field(String(d.get("key", "")))
		for loc in locale_codes:
			out += DELIMITER + _escape_field(String(d.get(loc, "")))
		out += LINE_TERMINATOR

	return out

# ============================================================
# PARSE
# ============================================================

## Parses CSV text into a Dictionary:
##   {
##     "locale_codes": PackedStringArray,   # column headers except "key"
##     "rows": Array[Dictionary],           # each has "key" + locale -> value
##   }
##
## Returns an empty Dictionary on failure.
static func parse(text: String) -> Dictionary:
	if text.strip_edges().is_empty():
		return {}

	var records: Array = _split_records(text)
	if records.is_empty():
		return {}

	# First record is the header.
	var header: Array = records[0]
	if header.size() < 2:
		push_warning("CSV: header must have at least 2 columns (key + 1 locale).")
		return {}

	# Normalise header[0] to "key"
	var first_col: String = String(header[0]).strip_edges().to_lower()
	if first_col != "key":
		push_warning("CSV: first column must be 'key' (got '%s')." % first_col)
		return {}

	var locale_codes: PackedStringArray = []
	for i in range(1, header.size()):
		var code: String = String(header[i]).strip_edges()
		if not code.is_empty():
			locale_codes.append(code)

	if locale_codes.is_empty():
		return {}

	var rows: Array = []
	for ri in range(1, records.size()):
		var rec: Array = records[ri]
		if rec.is_empty():
			continue

		var row: Dictionary = {}
		row["key"] = String(rec[0]).strip_edges()

		# Skip rows where the key is empty.
		if String(row["key"]).is_empty():
			continue

		# Fill each locale (or "" if missing columns).
		for i in range(locale_codes.size()):
			var col_idx: int = i + 1
			var val: String = ""
			if col_idx < rec.size():
				val = String(rec[col_idx])
			row[locale_codes[i]] = val

		rows.append(row)

	return {
		"locale_codes": locale_codes,
		"rows": rows,
	}

# ============================================================
# INTERNAL — CSV PARSING (RFC 4180-ish)
# ============================================================

## Splits the text into records (arrays of fields).
## Handles quoted fields with embedded commas, quotes, and newlines.
static func _split_records(text: String) -> Array:
	var records: Array = []
	var current_record: Array = []
	var current_field: String = ""
	var in_quotes: bool = false
	var i: int = 0
	var n: int = text.length()

	while i < n:
		var c: String = text[i]

		if in_quotes:
			if c == QUOTE:
				# Doubled quote inside a quoted field → literal quote.
				if i + 1 < n and text[i + 1] == QUOTE:
					current_field += QUOTE
					i += 2
					continue
				# Closing quote.
				in_quotes = false
				i += 1
				continue
			current_field += c
			i += 1
			continue

		# Not in quotes.
		match c:
			QUOTE:
				in_quotes = true
				i += 1
			DELIMITER:
				current_record.append(current_field)
				current_field = ""
				i += 1
			"\r":
				# Handle CRLF: skip the \r, the \n will finish the record.
				i += 1
			"\n":
				current_record.append(current_field)
				current_field = ""
				records.append(current_record)
				current_record = []
				i += 1
			_:
				current_field += c
				i += 1

	# Flush any pending field/record.
	if not current_field.is_empty() or not current_record.is_empty():
		current_record.append(current_field)
		records.append(current_record)

	return records

# ============================================================
# INTERNAL — CSV SERIALIZATION
# ============================================================

## Escapes a field per RFC 4180.
##   - Wrap in quotes if the field contains , " \n or starts/ends with space.
##   - Double any embedded quotes.
static func _escape_field(value: String) -> String:
	var needs_quotes: bool = false

	if value.find(DELIMITER) != -1:
		needs_quotes = true
	elif value.find(QUOTE) != -1:
		needs_quotes = true
	elif value.find("\n") != -1 or value.find("\r") != -1:
		needs_quotes = true
	elif value != value.strip_edges():
		needs_quotes = true

	if not needs_quotes:
		return value

	var escaped: String = value.replace(QUOTE, QUOTE + QUOTE)
	return QUOTE + escaped + QUOTE