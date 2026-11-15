extends Node2D

@onready var player: CharacterBody2D = $LevelRoot/Player
@onready var darkness: ColorRect = $EcholocationOverlay/Darkness
@onready var echo_status: Label = $EcholocationOverlay/EchoStatus
@onready var red_flash: ColorRect = $EcholocationOverlay/RedFlash
@onready var win_screen: Control = $EcholocationOverlay/WinScreen
@onready var replay_button: Button = $EcholocationOverlay/WinScreen/CenterContainer/VBoxContainer/ReplayButton

const PULSE_SPEED := 850.0
const MAX_RADIUS := 360.0
const PULSE_COOLDOWN := 4.0
var pulse_age := -1.0
var pulse_screen_center := Vector2(0.5, 0.5)
var cooldown_remaining := 0.0
var auto_echo_pending := false

func _ready() -> void:
	darkness.visible = true
	echo_status.visible = true
	replay_button.pressed.connect(_on_replay_pressed)
	if get_tree().has_meta("respawn_echo_pending"):
		get_tree().remove_meta("respawn_echo_pending")
		auto_echo_pending = true

func flash_red_screen() -> void:
	red_flash.visible = true
	red_flash.modulate = Color(1, 1, 1, 0)
	var flash := create_tween()
	flash.tween_property(red_flash, "modulate", Color.WHITE, 0.06)
	flash.tween_property(red_flash, "modulate", Color(1, 1, 1, 0), 0.34)
	flash.tween_callback(_hide_red_flash)

func _hide_red_flash() -> void:
	red_flash.visible = false

func trigger_respawn_echo() -> void:
	auto_echo_pending = true

func show_win_screen() -> void:
	win_screen.visible = true
	get_tree().paused = true

func _on_replay_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _process(delta: float) -> void:
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
	var viewport := get_viewport()
	var viewport_size := get_viewport_rect().size
	var canvas_transform := viewport.get_canvas_transform()
	var player_screen_position: Vector2 = canvas_transform * player.global_position

	if auto_echo_pending:
		pulse_age = 0.0
		pulse_screen_center = player_screen_position / viewport_size
		cooldown_remaining = PULSE_COOLDOWN
		auto_echo_pending = false
	elif Input.is_action_just_pressed("echolocate") and cooldown_remaining <= 0.0:
		pulse_age = 0.0
		pulse_screen_center = player_screen_position / viewport_size
		cooldown_remaining = PULSE_COOLDOWN
	elif pulse_age >= 0.0:
		pulse_age += delta

	var material := darkness.material as ShaderMaterial
	material.set_shader_parameter("pulse_center", pulse_screen_center)
	material.set_shader_parameter("player_center", player_screen_position / viewport_size)
	material.set_shader_parameter("viewport_size", viewport_size)
	material.set_shader_parameter("pulse_age", pulse_age)
	material.set_shader_parameter("pulse_speed", PULSE_SPEED)
	material.set_shader_parameter("max_radius", MAX_RADIUS)
	if cooldown_remaining > 0.0:
		echo_status.text = "ECHO RECHARGING  %.1f s" % cooldown_remaining
	else:
		echo_status.text = "ECHO READY  (E)"
