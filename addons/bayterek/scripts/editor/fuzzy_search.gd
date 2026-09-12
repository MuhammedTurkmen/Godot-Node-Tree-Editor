@tool
class_name BayterekFuzzySearch
extends RefCounted
## Godot'un core fuzzy_search portu.
## TODO: Orijinal yggdrasil'deki implementasyonu buraya taşı.

var tokens: Array = []
var case_sensitive: bool = false
var start_offset: int = 0
var max_results: int = 100
var max_misses: int = 2
var allow_subsequences: bool = true

func set_query(_query: String, _case_sensitive: bool = false) -> void:
	# TODO
	pass

func search(_target: String, _result) -> bool:
	# TODO
	return false

func search_all(_targets: PackedStringArray, _results: Array) -> void:
	# TODO
	pass
