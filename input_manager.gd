extends Node

@export var debug: bool = false
@export var minimum_hold_timer = 0.2
@export var ui_start_with: String = "ui_"
@export var allow_multiple_actions_per_key: bool = true

var inputs: Dictionary = {}
var current_inputs: Dictionary

enum InputPressTypes{
	TAP = 1,			# Triggers only when a button is pushed down and released quickly
	DOUBLE_TAP = 2,		# Triggers on the second press if you quickly push down the same button twice
	PRESS = 3,			# Triggers as soon as a button is pushed
	LONG_PRESS = 4,		# Triggers after a button has been pushed down for a set amount of time
	HOLD = 5,			# Triggers continuously while a button is being pushed down
	LONG_HOLD = 6,		# After a button has been pushed down for a set amount of time, this starts triggering continuously
	RELEASE = 7			# Triggers when the button is released after being pressed down
}

signal gui_input(action: String)
signal gameplay_input(action: String)


func _ready() -> void:
	if !FileAccess.file_exists("user://keybindings.json"):
		create_inputs()
		save_inputs()
	else:
		load_inputs()


func create_inputs() -> void:
	for actionName in InputMap.get_actions():
		for inputEvent in InputMap.action_get_events(actionName):
			var key: String
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
			
			if !inputs.has(key):
				var action: Dictionary
				action[str(InputPressTypes.PRESS)] = [actionName]
				inputs[key] = action
			else:
				inputs[key][str(InputPressTypes.PRESS)].append(actionName)

func load_inputs() -> void:
	var file = FileAccess.open("user://keybindings.json", FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) == OK:
		var data_received = json.data
		for key in data_received:
			inputs[key] = data_received[key]
	else:
		print("JSON Parse Error: ", json.get_error_message(), " in ", json_string, " at line ", json.get_error_line())

func save_inputs() -> void:
	var json_string = (JSON.stringify(inputs, "\t"))
	var file = FileAccess.open("user://keybindings.json", FileAccess.WRITE)
	file.store_string(json_string)
	file.close()


func _input(event):
	if !inputs.has(event.as_text()): return
	
	input_manager(event)


func input_manager(event: InputEvent) -> void:
	var action_name = event.as_text()
	
	if event.is_pressed():
		if !current_inputs.has(action_name):
			send_signal(event.as_text(), InputPressTypes.PRESS)
			current_inputs[action_name] = InputPressTypes.PRESS
		elif current_inputs[action_name] == InputPressTypes.RELEASE:
			send_signal(event.as_text(), InputPressTypes.DOUBLE_TAP)
		
		send_signal(event.as_text(), InputPressTypes.HOLD)
		if current_inputs[action_name] == InputPressTypes.LONG_PRESS:
			send_signal(event.as_text(), InputPressTypes.LONG_HOLD)
		
		await get_tree().create_timer(minimum_hold_timer).timeout
		if !current_inputs.has(action_name): return
		
		if current_inputs[action_name] != InputPressTypes.PRESS: return
		
		current_inputs[action_name] = InputPressTypes.LONG_PRESS
		send_signal(event.as_text(), InputPressTypes.LONG_PRESS)
	elif event.is_released():
		send_signal(event.as_text(), InputPressTypes.RELEASE)
		
		if !current_inputs.has(action_name): return
		
		if current_inputs[action_name] == InputPressTypes.PRESS:
			send_signal(event.as_text(), InputPressTypes.TAP)
		
		current_inputs[action_name] = InputPressTypes.RELEASE
		
		await get_tree().create_timer(minimum_hold_timer).timeout
		current_inputs.erase(action_name)

func send_signal(event: String, press_type: InputPressTypes) -> void:
	var press = str(press_type)
	if !inputs[event].has(press): return
	for action in inputs[event][press]:
		if action.begins_with(ui_start_with):
			gui_input.emit(action)
		else:
			gameplay_input.emit(action)


func _on_gameplay_input(action: String) -> void:
	if debug: print("Gameplay Signal : " + action)

func _on_gui_input(action: String) -> void:
	if debug: print("Gui Signal : " + action)


func _on_reset_pressed() -> void:
	inputs.clear()
	create_inputs()
	save_inputs()

func _on_save_pressed() -> void:
	if allow_multiple_actions_per_key:
		save_inputs()
		return
	
	#TODO Add logic
