@tool
extends Node
## Project-wide audio manager autoload.
##
## Provides a simple API for playing sound effects, loops and music
## from anywhere in the game (including the Bayterek editor UI and
## the runtime).
##
## Design:
##   - SFX pool: 8 AudioStreamPlayer nodes for one-shot sounds.
##   - Loop pool: up to 8 simultaneous looping sounds, each returns a
##     handle you can use to change pitch / volume / stop.
##   - Music player: 1 dedicated AudioStreamPlayer with fade in/out.
##
## Usage:
##     BayterekAudioManager.play_sfx(stream)
##     var h = BayterekAudioManager.play_loop(stream)
##     h.set_pitch(1.2)
##     h.stop(0.2)
##
## The manager is registered as an autoload by the Bayterek plugin and
## removed when the plugin is disabled. Games may also register it
## manually.

const SFX_POOL_SIZE := 8
const LOOP_POOL_SIZE := 8

# ============================================================
# HANDLE
# ============================================================

## Handle returned by `play_loop()`. Wraps an AudioStreamPlayer and
## exposes helpers for live pitch / volume / stop with optional fade.
class LoopHandle extends RefCounted:
	var player: AudioStreamPlayer
	var _manager: Node
	var _fade_tween: Tween

	func _init(p: AudioStreamPlayer, m: Node) -> void:
		player = p
		_manager = m

	func set_pitch(pitch: float) -> void:
		if is_instance_valid(player):
			player.pitch_scale = maxf(0.01, pitch)

	func set_volume_db(db: float) -> void:
		if is_instance_valid(player):
			player.volume_db = db

	func is_playing() -> bool:
		return is_instance_valid(player) and player.playing

	func stop(fade_time: float = 0.0) -> void:
		if not is_instance_valid(player):
			return
		if fade_time <= 0.0:
			player.stop()
			return
		_kill_fade()
		var start_db: float = player.volume_db
		_fade_tween = player.create_tween()
		_fade_tween.tween_method(
			func(v: float): 
				if is_instance_valid(player):
					player.volume_db = v,
			start_db, -80.0, fade_time
		)
		_fade_tween.finished.connect(func():
			if is_instance_valid(player):
				player.stop()
		)

	func _kill_fade() -> void:
		if _fade_tween and _fade_tween.is_valid():
			_fade_tween.kill()

# ============================================================
# STATE
# ============================================================

var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_index: int = 0

var _loop_players: Array[AudioStreamPlayer] = []
var _loop_handles: Dictionary = {}  # player -> LoopHandle

var _music_player: AudioStreamPlayer
var _music_tween: Tween

# ============================================================
# LIFECYCLE
# ============================================================

func _ready() -> void:
	# Ensure we keep running when the game is paused (SFX for UI
	# interactions should still play).
	process_mode = Node.PROCESS_MODE_ALWAYS

	_create_pools()

func _create_pools() -> void:
	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.name = "SFX_%d" % i
		p.bus = "Master"
		add_child(p)
		_sfx_players.append(p)

	for i in LOOP_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.name = "Loop_%d" % i
		p.bus = "Master"
		add_child(p)
		_loop_players.append(p)
		_loop_handles[p] = LoopHandle.new(p, self)

	_music_player = AudioStreamPlayer.new()
	_music_player.name = "Music"
	_music_player.bus = "Master"
	add_child(_music_player)

# ============================================================
# SFX API (one-shot)
# ============================================================

## Plays a one-shot sound effect. If the pool is exhausted, the oldest
## player is reused.
func play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not stream:
		return
	if _sfx_players.is_empty():
		_create_pools()

	var player: AudioStreamPlayer = _find_free_sfx_player()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = maxf(0.01, pitch)
	player.play()

func _find_free_sfx_player() -> AudioStreamPlayer:
	# Round-robin through the pool.
	var player: AudioStreamPlayer = _sfx_players[_sfx_index]
	_sfx_index = (_sfx_index + 1) % _sfx_players.size()
	return player

## Stops all currently-playing SFX.
func stop_all_sfx() -> void:
	for p in _sfx_players:
		if is_instance_valid(p):
			p.stop()

# ============================================================
# LOOP API
# ============================================================

## Starts a looping sound and returns a handle for live control.
## Returns null if the stream is invalid or the pool is full.
func play_loop(stream: AudioStream, volume_db: float = 0.0, pitch: float = 1.0) -> LoopHandle:
	if not stream:
		return null

	var player: AudioStreamPlayer = _find_free_loop_player()
	if not player:
		return null

	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = maxf(0.01, pitch)
	player.play()

	return _loop_handles.get(player, null)

func _find_free_loop_player() -> AudioStreamPlayer:
	for p in _loop_players:
		if not p.playing:
			return p
	return null

func stop_all_loops(fade_time: float = 0.0) -> void:
	for p in _loop_players:
		if not is_instance_valid(p):
			continue
		var h: LoopHandle = _loop_handles.get(p, null)
		if h:
			h.stop(fade_time)
		else:
			p.stop()

# ============================================================
# MUSIC API
# ============================================================

## Plays background music with optional fade-in.
func set_music(stream: AudioStream, fade_time: float = 0.0, volume_db: float = -6.0) -> void:
	if not stream:
		return
	if not _music_player:
		return

	_kill_music_tween()

	if _music_player.stream == stream and _music_player.playing:
		return  # already playing

	_music_player.stream = stream

	if fade_time <= 0.0:
		_music_player.volume_db = volume_db
		_music_player.play()
		return

	_music_player.volume_db = -80.0
	_music_player.play()

	_music_tween = _music_player.create_tween()
	_music_tween.tween_property(_music_player, "volume_db", volume_db, fade_time)

func stop_music(fade_time: float = 0.0) -> void:
	if not _music_player:
		return
	_kill_music_tween()

	if fade_time <= 0.0:
		_music_player.stop()
		return

	var start_db: float = _music_player.volume_db
	_music_tween = _music_player.create_tween()
	_music_tween.tween_method(
		func(v: float): 
			if is_instance_valid(_music_player):
				_music_player.volume_db = v,
		start_db, -80.0, fade_time
	)
	_music_tween.finished.connect(func():
		if is_instance_valid(_music_player):
			_music_player.stop()
	)

func _kill_music_tween() -> void:
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = null

# ============================================================
# CLEANUP
# ============================================================

## Called by the plugin when it's disabled. Stops everything and
## clears the pools so a future re-registration starts fresh.
func shutdown() -> void:
	stop_all_sfx()
	stop_all_loops(0.0)
	stop_music(0.0)