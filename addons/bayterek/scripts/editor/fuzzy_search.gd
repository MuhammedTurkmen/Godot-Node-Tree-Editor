@tool
class_name BayterekFuzzySearch
extends RefCounted
## Simple, original fuzzy search utility.
##
## Checks if the query characters appear in the target string in sequence,
## case-insensitive, with word-boundary bonuses.
##
## Example matches:
##   "war"  → "Warrior"        (exact substring)
##   "wsr"  → "Warrior"        (subsequence)
##   "atk"  → "Attack Speed"   (word start)
##   "asp"  → "Attack Speed"   (initials)
##
## This is a lightweight alternative to a full port of Godot's core
## fuzzy_search — sufficient for filtering trees, attributes, and prefabs.


## Case sensitivity for matching (default: false).
var case_sensitive: bool = false

## When true, matching requires the query to be a subsequence.
## When false, only an exact substring match is required.
var allow_subsequences: bool = true

## Bonus scores for nicer sorting (optional).
const SCORE_EXACT: int = 100
const SCORE_WORD_START: int = 50
const SCORE_SUBSTRING: int = 30
const SCORE_SUBSEQUENCE: int = 10


## Returns true if `query` matches `target`.
func matches(query: String, target: String) -> bool:
	if query.is_empty():
		return true
	if target.is_empty():
		return false

	var q := query if case_sensitive else query.to_lower()
	var t := target if case_sensitive else target.to_lower()

	# Fast path: exact substring
	if t.find(q) != -1:
		return true

	if not allow_subsequences:
		return false

	# Subsequence check
	var q_idx: int = 0
	for i in range(t.length()):
		if t[i] == q[q_idx]:
			q_idx += 1
			if q_idx >= q.length():
				return true
	return false


## Returns a score indicating how good the match is.
## Higher is better. Returns 0 if no match.
func score(query: String, target: String) -> int:
	if query.is_empty():
		return 1
	if target.is_empty():
		return 0

	var q := query if case_sensitive else query.to_lower()
	var t := target if case_sensitive else target.to_lower()

	# Exact full match
	if q == t:
		return SCORE_EXACT * 10

	# Exact substring
	var substr_idx := t.find(q)
	if substr_idx != -1:
		# Bonus if substring starts at a word boundary
		if substr_idx == 0 or _is_word_boundary(t, substr_idx - 1):
			return SCORE_EXACT + SCORE_WORD_START
		return SCORE_EXACT

	if not allow_subsequences:
		return 0

	# Subsequence
	var q_idx: int = 0
	var last_match: int = -1
	var score: int = 0
	for i in range(t.length()):
		if t[i] == q[q_idx]:
			# Word boundary bonus
			if _is_word_boundary(t, i - 1):
				score += 3
			# Consecutive bonus
			if last_match == i - 1:
				score += 2
			score += 1
			last_match = i
			q_idx += 1
			if q_idx >= q.length():
				return SCORE_SUBSEQUENCE + score
	return 0


## Returns the indices of matching targets, sorted by score (descending).
## `targets` is a PackedStringArray; returns a PackedInt32Array of indices.
func filter_indices(targets: PackedStringArray, query: String) -> PackedInt32Array:
	if query.is_empty():
		var all: PackedInt32Array = []
		for i in range(targets.size()):
			all.append(i)
		return all

	# Collect (index, score) pairs
	var scored: Array = []
	for i in range(targets.size()):
		var s := score(query, targets[i])
		if s > 0:
			scored.append({"index": i, "score": s})

	# Sort by score descending
	scored.sort_custom(func(a, b): return a["score"] > b["score"])

	var result: PackedInt32Array = []
	for entry in scored:
		result.append(entry["index"])
	return result


## Returns the matching targets themselves, sorted by score (descending).
func filter(targets: PackedStringArray, query: String) -> PackedStringArray:
	var indices := filter_indices(targets, query)
	var result: PackedStringArray = []
	for i in indices:
		result.append(targets[i])
	return result


# ============================================================
# PRIVATE
# ============================================================

func _is_word_boundary(s: String, index: int) -> bool:
	if index < 0 or index >= s.length():
		return true
	var c := s[index]
	# Word boundaries: space, underscore, hyphen, dot, slash, backslash
	return c == " " or c == "_" or c == "-" or c == "." or c == "/" or c == "\\"