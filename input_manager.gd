extends Node

@export var debug: bool = false
@export var minimum_hold_timer = 0.2

var inputs_gui: Dictionary = {}
var inputs_game: Dictionary = {}

enum InputPressTypes{
	NONE= 0,
	TAP = 1,		# Triggers only when a button is pushed down and released quickly
	DOUBLE_TAP = 2,	# Triggers on the second press if you quickly push down the same button twice
	PRESS = 3,		# Triggers as soon as a button is pushed
	LONG_PRESS = 4,	# Triggers after a button has been pushed down for a set amount of time
	RELEASE = 5		# Triggers when the button is released after being pressed down
}

var current_inputs: Dictionary
var pressed_inputs: Array[String]

signal gui_input(action: String)
signal gameplay_input(action: String)


func _ready() -> void:
	if FileAccess.file_exists("user://keybindings.json"):
		load_inputs()
		return
	
	for actionName in InputMap.get_actions():
		for inputEvent in InputMap.action_get_events(actionName):
			var key: String
			var action: Dictionary
			if inputEvent is InputEventKey:
				key = OS.get_keycode_string(
					DisplayServer.keyboard_get_label_from_physical(
						inputEvent.physical_keycode
					)
				)
				if key.is_empty():
					key = OS.get_keycode_string(
						DisplayServer.keyboard_get_label_from_physical(
							inputEvent.keycode
						)
					)
			else:
				key = inputEvent.as_text()
			action[InputPressTypes.PRESS] = actionName
			if actionName.begins_with("ui_"):
				inputs_gui[key] = actionName
			else:
				inputs_game[key] = action
	
	save_inputs()


func load_inputs() -> void:
	var file = FileAccess.open("user://keybindings.json", FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) == OK:
		var data_received = json.data
		for key in data_received:
			if typeof(data_received[key]) == TYPE_DICTIONARY:
				inputs_game[key] = data_received[key]
			else:
				inputs_gui[key] = data_received[key]
	else:
		print("JSON Parse Error: ", json.get_error_message(), " in ", json_string, " at line ", json.get_error_line())

func save_inputs() -> void:
	var json_string = (JSON.stringify(inputs_gui)).left(-1)
	json_string += "," + (JSON.stringify(inputs_game).right(-1))
	var file = FileAccess.open("user://keybindings.json", FileAccess.WRITE)
	file.store_string(json_string)
	file.close()


# Better for GUI
func _input(event):
	if !inputs_gui.has(event.as_text()): return
	
	gui_input.emit(inputs_gui[event.as_text()])
	#get_tree().get_root().set_input_as_handled()

# Better for idk
func _shortcut_input(event: InputEvent) -> void:
	#if debug : print("shortcut")
	#input_manager(event)
	#get_tree().get_root().set_input_as_handled()
	pass

# Better for Gameplay
func _unhandled_input(event: InputEvent) -> void:
	if !inputs_game.has(event.as_text()): return
	
	input_manager(event)
	get_tree().get_root().set_input_as_handled()


func input_manager(event: InputEvent) -> void:
	var action_name = event.as_text()
	
	if event.is_pressed():
		if !current_inputs.has(action_name):
			send_gameplay_signal(event.as_text(), InputPressTypes.PRESS)
			current_inputs[action_name] = InputPressTypes.PRESS
		elif current_inputs[action_name] == InputPressTypes.RELEASE:
			send_gameplay_signal(event.as_text(), InputPressTypes.DOUBLE_TAP)
		
		await get_tree().create_timer(minimum_hold_timer).timeout
		if !current_inputs.has(action_name): return
		
		if current_inputs[action_name] != InputPressTypes.PRESS: return
		
		current_inputs[action_name] = InputPressTypes.LONG_PRESS
		send_gameplay_signal(event.as_text(), InputPressTypes.LONG_PRESS)
	elif event.is_released():
		send_gameplay_signal(event.as_text(), InputPressTypes.RELEASE)
		
		if !current_inputs.has(action_name): return
		
		if current_inputs[action_name] == InputPressTypes.PRESS:
			send_gameplay_signal(event.as_text(), InputPressTypes.TAP)
		
		current_inputs[action_name] = InputPressTypes.RELEASE
		
		await get_tree().create_timer(minimum_hold_timer).timeout
		current_inputs.erase(action_name)


func send_gameplay_signal(event: String, press_type: InputPressTypes) -> void:
	var press = str(press_type)
	if !inputs_game[event].has(press): return
	gameplay_input.emit(inputs_game[event][press])


func _on_gameplay_input(action: String) -> void:
	if debug: print("Gameplay Signal : " + action)

func _on_gui_input(action: String) -> void:
	if debug: print("Gui Signal : " + action)
