## The original's evaluation window (weval.tcl, filled in by doScoreCard in
## w_eval.c): Public Opinion on the left (is the mayor doing a good job, and
## the worst problems, with the share of votes each got), Statistics on the
## right (population, net migration, assessed value, category, game level, and
## the overall score with its annual change), and Dismiss Evaluation. It keeps
## up with the engine's yearly evaluation while it's open. It only reads the
## engine: running an evaluation draws random numbers, so opening it doesn't.
##
## Part of Metrobits: GPLv3 with Electronic Arts' additional terms (see
## LICENSE and micropolis-core/MicropolisGPLLicenseNotice.md).
class_name EvaluationWindow
extends Window

## 1989's names (w_eval.c), in CityEngine.Problem's order.
const PROBLEMS := ["CRIME", "POLLUTION", "HOUSING COSTS", "TAXES", "TRAFFIC", "UNEMPLOYMENT", "FIRES"]
const CLASSES := ["VILLAGE", "TOWN", "CITY", "CAPITAL", "METROPOLIS", "MEGALOPOLIS"]
const LEVELS := ["Easy", "Medium", "Hard"]

var heading: Label
## YES and NO, as percentages.
var approval_label: Label
var problem_names: Label
var problem_votes: Label
## Population, net migration, assessed value, category and game level.
var stats_label: Label
## The current score and its annual change.
var score_label: Label

var _engine: CityEngine


func _init() -> void:
	title = "Micropolis Evaluation"
	visible = false
	transient = true
	exclusive = false
	unresizable = true
	wrap_controls = true
	close_requested.connect(hide)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	heading = _label(column, "", 15)
	var sides := HBoxContainer.new()
	sides.add_theme_constant_override("separation", 8)
	column.add_child(sides)

	var left := _frame(sides)
	_label(left, "Public Opinion", 16)
	_label(left, "Is the mayor doing a good job?", 14)
	var yes_no := _columns(left)
	yes_no[0].text = "YES\nNO"
	approval_label = yes_no[1]
	_label(left, "What are the worst problems?", 14)
	var problems := _columns(left)
	problem_names = problems[0]
	problem_votes = problems[1]

	var right := _frame(sides)
	_label(right, "Statistics", 16)
	var stat_columns := _columns(right)
	stat_columns[0].text = "Population:\nNet Migration:\n(last year)\nAssessed Value:\nCategory:\nGame Level:"
	stats_label = stat_columns[1]
	_label(right, "Overall City Score\n(0 - 1000)", 14)
	var score_columns := _columns(right)
	score_columns[0].text = "Current Score:\nAnnual Change:"
	score_label = score_columns[1]

	var dismiss := Button.new()
	dismiss.text = "Dismiss Evaluation"
	dismiss.focus_mode = Control.FOCUS_NONE
	dismiss.pressed.connect(hide)
	column.add_child(dismiss)


## Opens it over the game, showing engine's latest evaluation, and keeps it
## up to date.
func open(engine: CityEngine) -> void:
	if _engine != engine:
		if _engine != null and _engine.evaluation_changed.is_connected(refresh):
			_engine.evaluation_changed.disconnect(refresh)
		_engine = engine
		_engine.evaluation_changed.connect(refresh)
	refresh()
	if not visible:
		popup_centered()


## Shows the engine's figures as 1989's doScoreCard formatted them.
func refresh() -> void:
	if _engine == null:
		return
	var evaluation := _engine.get_evaluation()
	heading.text = "City Evaluation  %d" % _engine.get_year()
	var approval: int = evaluation.approval
	approval_label.text = "%d%%\n%d%%" % [approval, 100 - approval]
	var names := PackedStringArray()
	var votes := PackedStringArray()
	for entry: Dictionary in evaluation.problems:
		if entry.votes > 0:
			names.append(PROBLEMS[entry.problem])
			votes.append("%d%%" % entry.votes)
	problem_names.text = "\n".join(names)
	problem_votes.text = "\n".join(votes)
	stats_label.text = "%s\n%s\n\n%s\n%s\n%s" % [str(evaluation.population), str(evaluation.population_delta),
		HeadPanel.format_money(evaluation.assessed_value), CLASSES[clampi(evaluation.city_class, 0, 5)],
		LEVELS[clampi(evaluation.game_level, 0, 2)]]
	score_label.text = "%d\n%d" % [evaluation.score, evaluation.score_delta]


func _frame(parent: Control) -> VBoxContainer:
	var frame := PanelContainer.new()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.custom_minimum_size.x = 240
	parent.add_child(frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	frame.add_child(column)
	return column


func _label(parent: Control, text: String, font_size := 13) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


## Two columns: captions right-aligned, values left-aligned, as 1989's
## message pairs were. Returns [captions, values].
func _columns(parent: Control) -> Array[Label]:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var captions := Label.new()
	captions.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	captions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(captions)
	var values := Label.new()
	values.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	values.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(values)
	return [captions, values]

