extends Control

enum BattleState {
	WAITING_FOR_ANSWER,
	RESOLVING_PLAYER_ATTACK,
	ENEMY_TURN,
	BATTLE_WON,
	BATTLE_LOST
}

const QUESTIONS_PATH := "res://data/questions.json"

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
var question_order: Array[int] = []
var question_cursor := 0
var current_question: Dictionary = {}

var enemy_hp_bar: ProgressBar
var enemy_hp_text: Label
var player_hp_bar: ProgressBar
var player_hp_text: Label
var question_text: Label
var status_text: Label
var answer_buttons: Array[Button] = []


func _ready() -> void:
	randomize()
	player_hp = player_max_hp
	enemy_hp = enemy_max_hp
	_build_interface()
	_update_health_bars()

	if not _load_questions():
		battle_state = BattleState.RESOLVING_PLAYER_ATTACK
		status_text.text = "Nao foi possivel carregar data/questions.json."
		return

	_show_next_question()
	_set_battle_state(BattleState.WAITING_FOR_ANSWER)
	status_text.text = "Escolha uma resposta."


func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = Color("#111918")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var margins := MarginContainer.new()
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margins.add_theme_constant_override("margin_left", 32)
	margins.add_theme_constant_override("margin_top", 24)
	margins.add_theme_constant_override("margin_right", 32)
	margins.add_theme_constant_override("margin_bottom", 24)
	add_child(margins)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	margins.add_child(layout)

	var enemy_heading := _make_label("INIMIGO", 16, true)
	enemy_heading.add_theme_color_override("font_color", Color("#e8b866"))
	layout.add_child(enemy_heading)

	var enemy_portrait := PanelContainer.new()
	enemy_portrait.custom_minimum_size = Vector2(0, 100)
	enemy_portrait.add_theme_stylebox_override("panel", _make_panel_style(Color("#24302c")))
	layout.add_child(enemy_portrait)

	var portrait_center := CenterContainer.new()
	enemy_portrait.add_child(portrait_center)
	var portrait_mark := _make_label("?", 42, true)
	portrait_mark.add_theme_color_override("font_color", Color("#e8b866"))
	portrait_center.add_child(portrait_mark)

	var enemy_name_text := _make_label(enemy_name, 22, true)
	layout.add_child(enemy_name_text)

	enemy_hp_text = _make_label("HP", 16)
	layout.add_child(enemy_hp_text)
	enemy_hp_bar = _make_progress_bar(Color("#d45e4c"))
	layout.add_child(enemy_hp_bar)

	var divider := HSeparator.new()
	divider.add_theme_color_override("separator", Color("#394642"))
	layout.add_child(divider)

	var question_panel := PanelContainer.new()
	question_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	question_panel.add_theme_stylebox_override("panel", _make_panel_style(Color("#1b2623")))
	layout.add_child(question_panel)

	var question_content := VBoxContainer.new()
	question_content.add_theme_constant_override("separation", 14)
	question_panel.add_child(question_content)

	var question_heading := _make_label("PERGUNTA", 16, true)
	question_heading.add_theme_color_override("font_color", Color("#e8b866"))
	question_content.add_child(question_heading)

	question_text = _make_label("", 21, true)
	question_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question_content.add_child(question_text)

	var answers_grid := GridContainer.new()
	answers_grid.columns = 2
	answers_grid.add_theme_constant_override("h_separation", 10)
	answers_grid.add_theme_constant_override("v_separation", 10)
	question_content.add_child(answers_grid)

	for answer_index in range(4):
		var answer_button := Button.new()
		answer_button.custom_minimum_size = Vector2(0, 54)
		answer_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		answer_button.add_theme_font_size_override("font_size", 17)
		answer_button.add_theme_stylebox_override("normal", _make_button_style(Color("#34433d")))
		answer_button.add_theme_stylebox_override("hover", _make_button_style(Color("#46584f")))
		answer_button.add_theme_stylebox_override("disabled", _make_button_style(Color("#27332f")))
		answer_button.pressed.connect(_on_answer_selected.bind(answer_index))
		answer_buttons.append(answer_button)
		answers_grid.add_child(answer_button)

	status_text = _make_label("", 16, true)
	status_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(status_text)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	layout.add_child(footer)

	var player_label := _make_label(player_name, 18)
	footer.add_child(player_label)

	player_hp_text = _make_label("HP", 16)
	player_hp_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	footer.add_child(player_hp_text)

	player_hp_bar = _make_progress_bar(Color("#64b985"))
	player_hp_bar.custom_minimum_size = Vector2(160, 18)
	footer.add_child(player_hp_bar)


func _load_questions() -> bool:
	if not FileAccess.file_exists(QUESTIONS_PATH):
		push_error("Arquivo de perguntas nao encontrado: " + QUESTIONS_PATH)
		return false

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(QUESTIONS_PATH))
	if typeof(parsed) != TYPE_ARRAY or parsed.is_empty():
		push_error("O arquivo de perguntas deve conter uma lista JSON nao vazia.")
		return false

	for item in parsed:
		if typeof(item) != TYPE_DICTIONARY:
			push_error("Cada pergunta deve ser um objeto JSON.")
			return false
		if not item.has("question") or not item.has("answers") or not item.has("correct_answer"):
			push_error("Pergunta sem question, answers ou correct_answer.")
			return false
		if typeof(item["question"]) != TYPE_STRING or typeof(item["answers"]) != TYPE_ARRAY:
			push_error("Texto da pergunta ou alternativas em formato invalido.")
			return false
		if item["answers"].size() != 4:
			push_error("Cada pergunta deve ter exatamente quatro alternativas.")
			return false
		if typeof(item["correct_answer"]) != TYPE_INT or item["correct_answer"] < 0 or item["correct_answer"] > 3:
			push_error("A resposta correta deve ser o indice de 0 a 3.")
			return false
		for answer in item["answers"]:
			if typeof(answer) != TYPE_STRING:
				push_error("Todas as alternativas devem ser texto.")
				return false

	questions = parsed
	return true


func _show_next_question() -> void:
	if question_cursor >= question_order.size():
		question_order.clear()
		for question_index in range(questions.size()):
			question_order.append(question_index)
		question_order.shuffle()
		question_cursor = 0

	current_question = questions[question_order[question_cursor]]
	question_cursor += 1
	question_text.text = str(current_question["question"])
	for answer_index in range(answer_buttons.size()):
		answer_buttons[answer_index].text = str(current_question["answers"][answer_index])


func _on_answer_selected(answer_index: int) -> void:
	if battle_state != BattleState.WAITING_FOR_ANSWER:
		return

	_set_battle_state(BattleState.RESOLVING_PLAYER_ATTACK)
	var correct := answer_index == int(current_question["correct_answer"])
	var damage := player_base_damage * 2 if correct else int(player_base_damage * 0.5)
	enemy_hp = maxi(0, enemy_hp - damage)
	_update_health_bars()
	status_text.text = "Correto! Voce causou %d de dano." % damage if correct else "Errado. Voce causou %d de dano." % damage

	await get_tree().create_timer(0.45).timeout
	if enemy_hp <= 0:
		_set_battle_state(BattleState.BATTLE_WON)
		status_text.text = "Vitoria! %s foi derrotado." % enemy_name
		return

	_set_battle_state(BattleState.ENEMY_TURN)
	status_text.text = "%s ataca e causa %d de dano." % [enemy_name, enemy_attack_damage]
	await get_tree().create_timer(0.45).timeout
	player_hp = maxi(0, player_hp - enemy_attack_damage)
	_update_health_bars()
	if player_hp <= 0:
		_set_battle_state(BattleState.BATTLE_LOST)
		status_text.text = "Derrota. %s venceu a batalha." % enemy_name
		return

	_show_next_question()
	_set_battle_state(BattleState.WAITING_FOR_ANSWER)
	status_text.text = "Escolha uma resposta."


func _set_battle_state(next_state: BattleState) -> void:
	battle_state = next_state
	var can_answer := battle_state == BattleState.WAITING_FOR_ANSWER
	for answer_button in answer_buttons:
		answer_button.disabled = not can_answer


func _update_health_bars() -> void:
	if is_instance_valid(enemy_hp_bar):
		enemy_hp_bar.max_value = enemy_max_hp
		enemy_hp_bar.value = enemy_hp
		enemy_hp_text.text = "HP: %d / %d" % [enemy_hp, enemy_max_hp]
	if is_instance_valid(player_hp_bar):
		player_hp_bar.max_value = player_max_hp
		player_hp_bar.value = player_hp
		player_hp_text.text = "HP: %d / %d" % [player_hp, player_max_hp]


func _make_label(text: String, font_size: int, centered := false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("#edf1e8"))
	if centered:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _make_progress_bar(fill_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 18)
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", _make_panel_style(Color("#29332f")))
	bar.add_theme_stylebox_override("fill", _make_panel_style(fill_color))
	return bar


func _make_panel_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(5)
	style.set_content_margin_all(12)
	return style


func _make_button_style(color: Color) -> StyleBoxFlat:
	var style := _make_panel_style(color)
	style.set_content_margin_all(8)
	return style