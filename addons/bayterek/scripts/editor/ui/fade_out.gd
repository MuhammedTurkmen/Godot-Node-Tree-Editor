@tool
extends PanelContainer
## Fade-out bildirim paneli.

var _fade_after: float = 3.0
var _fading: bool = false
var _fade_duration: float = 1.0
var _fade_timer: float = 0.0
var _paused: bool = false
var interactable: bool = true
