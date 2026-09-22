@tool
class_name BayterekLocalizationFuzzy
extends RefCounted
## Fuzzy string matching utility for the Localization editor.
##
## Matches a query against a target string using subsequence matching
## with word-boundary and consecutive-character bonuses.
##
## Examples:
##   "mnp"  matches "menu_play"
##   "grt"  matches "greeting_with_name"
##   "menu" matches "menu_options"
##
## Scoring (higher is better):
##   - Exact full match        → huge bonus
##   - Substring match         → large bonus
##   - Word start (camel/snake) → medium bonus
##   - Subsequence             → small bonus + per-character bonuses

## Returns true if `query` matches `target` (case-insensitive).
static func matches(query: String, target: String) -> bool:
	return score(query, target) > 0

## Returns a score (0 = no match, higher = better match).
static func score(query: String, target: String) -> int:
	if query.is_empty():
		return 1
	if target.is_empty():
		return 0

	var q: String = query.to_lower()
	var t: String = target.to_lower()

	# Exact full match.
	if q == t:
		return 100000

	# Exact substring match.
	var substr_idx: int = t.find(q)
	if substr_idx != -1:
		var bonus: int = 10000
		# Bonus if substring starts at word boundary.
		if substr_idx == 0 or _is_word_boundary(t, substr_idx - 1):
			bonus += 5000
		# Penalty for later occurrence.
		bonus -= substr_idx * 10
		return bonus

	# Subsequence matching with bonuses.
	return _subsequence_score(q, t)

## Returns matching targets, sorted by score (descending).
static func filter(targets: PackedStringArray, query: String) -> PackedStringArray:
	if query.strip_edges().is_empty():
		return targets

	var scored: Array = []
	for i in range(targets.size()):
		var s: int = score(query, targets[i])
		if s > 0:
			scored.append({"text": targets[i], "score": s})

	# Sort by score descending, then alphabetically ascending.
	scored.sort_custom(func(a, b):
		if a["score"] != b["score"]:
			return a["score"] > b["score"]
		return a["text"] < b["text"]
	)

	var out: PackedStringArray = []
	for entry in scored:
		out.append(entry["text"])
	return out

# ============================================================
# INTERNAL
# ============================================================

static func _subsequence_score(q: String, t: String) -> int:
	var q_idx: int = 0
	var t_idx: int = 0
	var total_score: int = 0
	var last_match_idx: int = -2
	var q_len: int = q.length()
	var t_len: int = t.length()

	while q_idx < q_len and t_idx < t_len:
		if q[q_idx] == t[t_idx]:
			# Base per-character score.
			var char_score: int = 10

			# Word boundary bonus (start of word).
			if _is_word_boundary(t, t_idx - 1):
				char_score += 20

			# Consecutive bonus (previous char also matched).
			if last_match_idx == t_idx - 1:
				char_score += 15

			# Camel-case boundary bonus (uppercase after lowercase).
			if t_idx > 0 and t[t_idx] != t[t_idx].to_lower() and t[t_idx - 1] == t[t_idx - 1].to_lower():
				char_score += 10

			total_score += char_score
			last_match_idx = t_idx
			q_idx += 1

		t_idx += 1

	# All query chars consumed? Then it's a match.
	if q_idx == q_len:
		# Bonus for shorter targets (matches are denser).
		total_score += max(0, 50 - t_len)
		return total_score

	return 0

static func _is_word_boundary(s: String, index: int) -> bool:
	if index < 0 or index >= s.length():
		return true
	var c: String = s[index]
	return c == " " or c == "_" or c == "-" or c == "." or c == "/"