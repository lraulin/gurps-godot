class_name GameUI
extends Control

## HUD for turn info, maneuver buttons, and messages.

signal end_turn_pressed
signal maneuver_selected(type: Maneuver.Type)

@onready var turn_label: Label = $TurnPanel/VBox/TurnLabel
@onready var character_label: Label = $TurnPanel/VBox/CharacterLabel
@onready var message_label: Label = $TurnPanel/VBox/MessageLabel
@onready var maneuver_container: VBoxContainer = $ManeuverPanel/VBox/ManeuverList
@onready var end_turn_button: Button = $TurnPanel/VBox/EndTurnButton
@onready var maneuver_title: Label = $ManeuverPanel/VBox/Title

var _maneuver_buttons: Array[Button] = []

func _ready() -> void:
	end_turn_button.pressed.connect(func(): end_turn_pressed.emit())
	message_label.text = ""

func set_turn_info(char_name: String, turn_num: int, total: int) -> void:
	turn_label.text = "Turn: %d / %d" % [turn_num, total]
	character_label.text = char_name
	message_label.text = "Move, then choose a maneuver"

func set_maneuvers(available: Array[Maneuver.Type]) -> void:
	# Clear old buttons
	for btn in _maneuver_buttons:
		btn.queue_free()
	_maneuver_buttons.clear()

	for type in available:
		var btn: Button = Button.new()
		btn.text = Maneuver.get_maneuver_name(type)
		btn.pressed.connect(func(): maneuver_selected.emit(type))
		maneuver_container.add_child(btn)
		_maneuver_buttons.append(btn)

func show_message(text: String) -> void:
	message_label.text = text
