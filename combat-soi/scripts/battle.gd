extends Control

enum BattleState {
	WAITING_FOR_ANSWER,
	RESOLVING_PLAYER_ATTACK,
	ENEMY_TURN,
	BATTLE_WON,
	BATTLE_LOST
}

const QUESTIONS_PATH := "res://data/questions.json"
const BOSS_RANGES := [
	{"first": 1, "last": 11, "name": "IRONCLAD"},
	{"first": 12, "last": 16, "name": "OVERSEER"},
	{"first": 17, "last": 22, "name": "THE FRAGMENTER"},
	{"first": 23, "last": 25, "name": "ARCHIVIST"}
]

@export var player_name := "Aventureiro"
@export var player_max_hp := 100
@export var player_base_damage := 10
@export var enemy_name := "Guardiao de Pedra"
@export var enemy_max_hp := 40
@export var enemy_attack_damage := 5

var player_hp: int
var enemy_hp: int
var battle_state := BattleState.WAITING_FOR_ANSWER
var questions: Array = []
var question_cursor := 0
var current_question: Dictionary = {}
var current_boss := ""

var enemy_hp_bar: ProgressBar
var enemy_hp_text: Label
var player_hp_bar: ProgressBar
var player_hp_text: Label
var boss_name_text: Label
var encounter_title_text: Label
var intro_text: Label
var boss_action_text: Label
var situation_text: Label
var feedback_text: Label
var concept_text: Label
var answers_grid: GridContainer
var answer_buttons: Array[Button] = []


func _ready() -> void:
	player_hp = player_max_hp
	enemy_hp = enemy_max_hp
	_build_interface()
	get_viewport().size_changed.connect(_update_answer_columns)
	_update_answer_columns()
	_update_health_bars()

	if not _load_questions():
		_set_battle_state(BattleState.RESOLVING_PLAYER_ATTACK)
		feedback_text.text = "Encounter data could not be loaded. See the debugger for details."
		return

	_show_next_question()
	_set_battle_state(BattleState.WAITING_FOR_ANSWER)
	feedback_text.text = "Select an intervention to respond to the system threat."


func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = Color("#101820")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var margins := MarginContainer.new()
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margins.add_theme_constant_override("margin_left", 20)
	margins.add_theme_constant_override("margin_top", 16)
	margins.add_theme_constant_override("margin_right", 20)
	margins.add_theme_constant_override("margin_bottom", 16)
	add_child(margins)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margins.add_child(layout)

	var boss_panel := PanelContainer.new()
	boss_panel.add_theme_stylebox_override("panel", _make_panel_style(Color("#243442")))
	layout.add_child(boss_panel)
	var boss_content := VBoxContainer.new()
	boss_content.add_theme_constant_override("separation", 5)
	boss_panel.add_child(boss_content)

	boss_name_text = _make_label("FCTarc13 HOSTILE SUBSYSTEM", 22, true)
	boss_name_text.add_theme_color_override("font_color", Color("#D7A84B"))
	boss_content.add_child(boss_name_text)
	encounter_title_text = _make_label("ENCOUNTER", 15, true)
	encounter_title_text.add_theme_color_override("font_color", Color("#A7B6B8"))
	boss_content.add_child(encounter_title_text)
	enemy_hp_text = _make_label("HOSTILE INTEGRITY", 14, true)
	boss_content.add_child(enemy_hp_text)
	enemy_hp_bar = _make_progress_bar(Color("#D65B45"))
	boss_content.add_child(enemy_hp_bar)

	var narrative_panel := PanelContainer.new()
	narrative_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	narrative_panel.add_theme_stylebox_override("panel", _make_panel_style(Color("#243442")))
	layout.add_child(narrative_panel)

	var narrative := VBoxContainer.new()
	narrative.add_theme_constant_override("separation", 9)
	narrative_panel.add_child(narrative)

	var intro_heading := _make_label("FIELD REPORT", 14, true)
	intro_heading.add_theme_color_override("font_color", Color("#83B692"))
	narrative.add_child(intro_heading)
	intro_text = _make_label("", 16)
	intro_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	narrative.add_child(intro_text)

	boss_action_text = _make_label("", 15)
	boss_action_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	boss_action_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boss_action_text.add_theme_color_override("font_color", Color("#D65B45"))
	narrative.add_child(boss_action_text)

	var situation_heading := _make_label("OPERATIONAL SITUATION", 16, true)
	situation_heading.add_theme_color_override("font_color", Color("#D7A84B"))
	narrative.add_child(situation_heading)
	situation_text = _make_label("", 20, true)
	situation_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	situation_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	narrative.add_child(situation_text)

	var interventions_heading := _make_label("AVAILABLE INTERVENTIONS", 15, true)
	interventions_heading.add_theme_color_override("font_color", Color("#83B692"))
	narrative.add_child(interventions_heading)

	answers_grid = GridContainer.new()
	answers_grid.add_theme_constant_override("h_separation", 10)
	answers_grid.add_theme_constant_override("v_separation", 8)
	answers_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	narrative.add_child(answers_grid)

	for choice_index in range(4):
		var choice_button := Button.new()
		choice_button.custom_minimum_size = Vector2(0, 58)
		choice_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choice_button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		choice_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		choice_button.add_theme_font_size_override("font_size", 15)
		choice_button.add_theme_stylebox_override("normal", _make_button_style(Color("#344B59")))
		choice_button.add_theme_stylebox_override("hover", _make_button_style(Color("#496273")))
		choice_button.add_theme_stylebox_override("disabled", _make_button_style(Color("#243442")))
		choice_button.pressed.connect(_on_intervention_selected.bind(choice_index))
		answer_buttons.append(choice_button)
		answers_grid.add_child(choice_button)

	feedback_text = _make_label("", 16, true)
	feedback_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(feedback_text)

	concept_text = _make_label("", 13)
	concept_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	concept_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	concept_text.add_theme_color_override("font_color", Color("#A7B6B8"))
	layout.add_child(concept_text)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	layout.add_child(footer)
	var player_label := _make_label(player_name, 18)
	footer.add_child(player_label)
	player_hp_text = _make_label("", 16)
	player_hp_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	footer.add_child(player_hp_text)
	player_hp_bar = _make_progress_bar(Color("#83B692"))
	player_hp_bar.custom_minimum_size = Vector2(160, 18)
	footer.add_child(player_hp_bar)


func _update_answer_columns() -> void:
	if is_instance_valid(answers_grid):
		answers_grid.columns = 1 if get_viewport_rect().size.x < 720 else 2


func _load_questions() -> bool:
	var file := FileAccess.open(QUESTIONS_PATH, FileAccess.READ)
	if file == null:
		push_error("Failed to open %s (error %d)." % [QUESTIONS_PATH, FileAccess.get_open_error()])
		return false

	var json := JSON.new()
	var parse_result := json.parse(file.get_as_text())
	if parse_result != OK:
		push_error("Invalid JSON in %s, line %d: %s" % [QUESTIONS_PATH, json.get_error_line(), json.get_error_message()])
		return false

	var parsed: Variant = json.data
	if typeof(parsed) != TYPE_ARRAY or parsed.is_empty():
		push_error("Encounter file must contain a non-empty JSON array.")
		return false

	var validated_encounters: Array = []
	for encounter_index in range(parsed.size()):
		var item: Variant = parsed[encounter_index]
		if typeof(item) != TYPE_DICTIONARY:
			push_error("Encounter %d must be a JSON object." % (encounter_index + 1))
			return false
		var encounter: Dictionary = item.duplicate(true)
		if not _normalize_and_validate_encounter(encounter, encounter_index):
			return false
		validated_encounters.append(encounter)

	questions = validated_encounters
	return true


func _normalize_and_validate_encounter(encounter: Dictionary, encounter_index: int) -> bool:
	var encounter_id := int(encounter.get("id", encounter_index + 1))
	if encounter.has("choices"):
		if typeof(encounter["choices"]) != TYPE_ARRAY:
			push_error("Encounter %d has malformed choices; expected an array." % encounter_id)
			return false
		if not _is_valid_index(encounter.get("correct_choice"), encounter_id):
			return false
		encounter["source_question"] = encounter.get("source_question", encounter.get("question", ""))
		encounter["source_answers"] = encounter.get("source_answers", encounter.get("answers", []))
		encounter["source_correct_answer"] = encounter.get("source_correct_answer", encounter.get("correct_answer", -1))
	else:
		# Compatibility adapter for the repository's existing question-only JSON.
		if not encounter.has("question") or not encounter.has("answers") or not encounter.has("correct_answer"):
			push_error("Encounter %d needs choices/correct_choice or legacy question/answers/correct_answer fields." % encounter_id)
			return false
		if typeof(encounter["question"]) != TYPE_STRING or typeof(encounter["answers"]) != TYPE_ARRAY:
			push_error("Encounter %d has invalid legacy question or answers data." % encounter_id)
			return false
		if not _is_valid_index(encounter["correct_answer"], encounter_id):
			return false
		encounter["source_question"] = encounter["question"]
		encounter["source_answers"] = encounter["answers"].duplicate(true)
		encounter["source_correct_answer"] = int(encounter["correct_answer"])
		encounter["choices"] = encounter["answers"].duplicate(true)
		encounter["correct_choice"] = int(encounter["correct_answer"])
		encounter["situation"] = encounter["question"]

	if encounter["choices"].size() != 4:
		push_error("Encounter %d must have exactly four choices; found %d." % [encounter_id, encounter["choices"].size()])
		return false
	for choice_index in range(encounter["choices"].size()):
		if typeof(encounter["choices"][choice_index]) != TYPE_STRING or encounter["choices"][choice_index].strip_edges().is_empty():
			push_error("Encounter %d choice %d must be non-empty text." % [encounter_id, choice_index])
			return false

	if not _is_valid_index(encounter["correct_choice"], encounter_id):
		return false
	for field in ["intro", "boss_action", "situation", "title", "boss", "explanation", "concept"]:
		if encounter.has(field) and typeof(encounter[field]) != TYPE_STRING:
			push_error("Encounter %d field '%s' must be text." % [encounter_id, field])
			return false

	var boss_name := str(encounter.get("boss", _boss_for_id(encounter_id)))
	if boss_name.strip_edges().is_empty():
		push_error("Encounter %d has an empty boss identifier." % encounter_id)
		return false
	encounter["boss"] = boss_name
	encounter["title"] = str(encounter.get("title", "Encounter %02d" % encounter_id))
	encounter["intro"] = str(encounter.get("intro", "FCTarc13 field report: a hostile process has disrupted subsystem operations."))
	encounter["boss_action"] = str(encounter.get("boss_action", "%s is interfering with facility operations." % boss_name))
	encounter["situation"] = str(encounter.get("situation", "Assess the system condition and select an operational intervention."))
	encounter["explanation"] = str(encounter.get("explanation", "Technical explanation is not included in this legacy encounter record."))
	encounter["concept"] = str(encounter.get("concept", "Concept metadata is not included in this legacy encounter record."))
	return true


func _is_valid_index(value: Variant, encounter_id: int) -> bool:
	var value_type := typeof(value)
	if value_type != TYPE_INT and value_type != TYPE_FLOAT:
		push_error("Encounter %d correct_choice must be an integer from 0 to 3." % encounter_id)
		return false
	var index := int(value)
	if float(value) != float(index) or index < 0 or index > 3:
		push_error("Encounter %d correct_choice must be an integer from 0 to 3." % encounter_id)
		return false
	return true


func _boss_for_id(encounter_id: int) -> String:
	for boss_range in BOSS_RANGES:
		if encounter_id >= boss_range["first"] and encounter_id <= boss_range["last"]:
			return boss_range["name"]
	return enemy_name


func _show_next_question() -> void:
	if question_cursor >= questions.size():
		_set_battle_state(BattleState.BATTLE_WON)
		feedback_text.text = "FCTarc13 systems stabilized. All %d encounters are complete." % questions.size()
		return

	current_question = questions[question_cursor]
	question_cursor += 1
	var next_boss := str(current_question["boss"])
	if next_boss != current_boss:
		current_boss = next_boss
		enemy_hp = enemy_max_hp
		_update_health_bars()

	boss_name_text.text = current_boss
	encounter_title_text.text = "%s  |  ENCOUNTER %02d / %02d" % [current_question["title"], question_cursor, questions.size()]
	intro_text.text = str(current_question["intro"])
	boss_action_text.text = "TRANSMISSION // " + str(current_question["boss_action"])
	situation_text.text = str(current_question["situation"])
	feedback_text.text = ""
	concept_text.text = ""
	for choice_index in range(answer_buttons.size()):
		answer_buttons[choice_index].text = str(current_question["choices"][choice_index])


func _on_intervention_selected(choice_index: int) -> void:
	if battle_state != BattleState.WAITING_FOR_ANSWER:
		return
	if choice_index < 0 or choice_index >= current_question["choices"].size():
		push_error("Selected intervention index is outside the validated choice range.")
		return

	# Lock all controls before resolving damage so repeated clicks cannot spend another turn.
	_set_battle_state(BattleState.RESOLVING_PLAYER_ATTACK)
	var correct := choice_index == int(current_question["correct_choice"])
	var damage := player_base_damage * 2 if correct else int(player_base_damage * 0.5)
	enemy_hp = maxi(0, enemy_hp - damage)
	_update_health_bars()

	var result_text := "INTERVENTION SUCCESSFUL" if correct else "INTERVENTION FAILED"
	var damage_text := "%d damage dealt to the hostile process." % damage
	feedback_text.text = "%s — %s\n%s" % [result_text, damage_text, str(current_question["explanation"])]
	concept_text.text = "SYSTEMS CONCEPT // " + str(current_question["concept"])

	await get_tree().create_timer(0.45).timeout
	if enemy_hp <= 0:
		feedback_text.text += "\nHostile process neutralized."
	else:
		_set_battle_state(BattleState.ENEMY_TURN)
		feedback_text.text += "\n%s attacks and deals %d damage." % [current_boss, enemy_attack_damage]
		await get_tree().create_timer(0.45).timeout
		player_hp = maxi(0, player_hp - enemy_attack_damage)
		_update_health_bars()
		if player_hp <= 0:
			_set_battle_state(BattleState.BATTLE_LOST)
			feedback_text.text += "\nOperator down. %s has overrun the facility." % current_boss
			return

	if question_cursor < questions.size():
		# Each record is one combat encounter; a neutralized hostile is replaced for the next one.
		if enemy_hp <= 0:
			enemy_hp = enemy_max_hp
			_update_health_bars()
		_show_next_question()
			_set_battle_state(BattleState.WAITING_FOR_ANSWER)
	else:
		_set_battle_state(BattleState.BATTLE_WON)
		feedback_text.text += "\nAll %d encounters complete. FCTarc13 is stable." % questions.size()


func _set_battle_state(next_state: BattleState) -> void:
	battle_state = next_state
	var can_intervene := battle_state == BattleState.WAITING_FOR_ANSWER
	for choice_button in answer_buttons:
		choice_button.disabled = not can_intervene


func _update_health_bars() -> void:
	if is_instance_valid(enemy_hp_bar):
		enemy_hp_bar.max_value = enemy_max_hp
		enemy_hp_bar.value = enemy_hp
		enemy_hp_text.text = "HOSTILE INTEGRITY: %d / %d" % [enemy_hp, enemy_max_hp]
	if is_instance_valid(player_hp_bar):
		player_hp_bar.max_value = player_max_hp
		player_hp_bar.value = player_hp
		player_hp_text.text = "HP: %d / %d" % [player_hp, player_max_hp]


func _make_label(text: String, font_size: int, centered := false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("#D9D8CC"))
	if centered:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _make_progress_bar(fill_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 18)
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", _make_panel_style(Color("#496273")))
	bar.add_theme_stylebox_override("fill", _make_panel_style(fill_color))
	return bar


func _make_panel_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(3)
	style.set_content_margin_all(12)
	return style


func _make_button_style(color: Color) -> StyleBoxFlat:
	var style := _make_panel_style(color)
	style.set_content_margin_all(8)
	return style
