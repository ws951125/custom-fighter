extends "res://game/runtime/preview_family_animation_main.gd"

const OpponentBehaviorProfileClass = preload("res://game/core/ai/opponent_behavior_profile.gd")
const OpponentBehaviorProfilesClass = preload("res://game/core/ai/opponent_behavior_profiles.gd")
const OpponentDecisionStateClass = preload("res://game/core/ai/opponent_decision_state.gd")
const OpponentAttackChainState = preload("res://game/core/combat/attack_chain_state.gd")
const OpponentCombatBox = preload("res://game/core/combat/combat_box.gd")

const SINGLE_PLAYER_MODE := "single_player"
const OPPONENT_MOVE_SPEED := 300.0
const OPPONENT_DEPTH_SPEED := 0.60

var match_over := false
var match_result := ""
var match_overlay: CenterContainer
var match_result_label: Label
var restart_button: Button
var return_creator_button: Button
var _web_restart_callback
var _web_return_creator_callback
var _web_select_opponent_profile_callback
var opponent_profile_panel: PanelContainer
var opponent_profile_selector: OptionButton

var opponent_ai_active := false
var opponent_profile_id := OpponentBehaviorProfilesClass.DEFAULT_PROFILE_ID
var opponent_behavior_profile = OpponentBehaviorProfileClass.new()
var opponent_decision_state = OpponentDecisionStateClass.new()
var opponent_attack_chain = OpponentAttackChainState.new()
var opponent_current_intent: Dictionary = {}
var opponent_decision_accumulator := 0.0
var opponent_decision_tick := 0
var opponent_guarding := false
var opponent_attack_count := 0
var opponent_hit_count := 0
var opponent_last_damage := 0

func _ready() -> void:
	super()
	_configure_opponent_ai()
	_create_opponent_profile_selector()
	_create_match_overlay()
	_install_match_bridges()
	_set_match_web_state()

func _process(delta: float) -> void:
	if match_over:
		return
	super(delta)
	if opponent_ai_active:
		_process_opponent_ai(delta)
	if dummy_state.is_defeated():
		_finish_match("victory")
	elif player_state.is_defeated():
		_finish_match("defeat")

func _configure_opponent_ai() -> void:
	opponent_ai_active = _router_mode() == SINGLE_PLAYER_MODE
	opponent_profile_id = _router_profile_id()
	opponent_current_intent = opponent_decision_state.idle_intent()
	if not opponent_ai_active:
		_set_opponent_ai_web_state()
		return

	var errors: PackedStringArray = OpponentBehaviorProfilesClass.load_profile(
		opponent_profile_id,
		opponent_behavior_profile
	)
	if not errors.is_empty() or not opponent_behavior_profile.loaded:
		opponent_ai_active = false
		push_error("Failed to load opponent behavior profile: %s" % " | ".join(errors))
	_set_opponent_ai_web_state()

func _router_mode() -> String:
	var router: Variant = get_parent()
	if router == null:
		return "training"
	return str(router.get("app_mode")).strip_edges().to_lower()

func _router_profile_id() -> String:
	var router: Variant = get_parent()
	if router == null:
		return OpponentBehaviorProfilesClass.DEFAULT_PROFILE_ID
	return OpponentBehaviorProfilesClass.normalize_profile_id(str(router.get("opponent_profile_id")))

func _create_opponent_profile_selector() -> void:
	if not opponent_ai_active:
		return
	opponent_profile_panel = PanelContainer.new()
	opponent_profile_panel.name = "OpponentProfileSelector"
	opponent_profile_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	opponent_profile_panel.offset_left = -330.0
	opponent_profile_panel.offset_top = 18.0
	opponent_profile_panel.offset_right = -18.0
	opponent_profile_panel.offset_bottom = 82.0
	opponent_profile_panel.z_index = 90
	add_child(opponent_profile_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	opponent_profile_panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)

	var label := Label.new()
	label.text = "AI Difficulty"
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)

	opponent_profile_selector = OptionButton.new()
	opponent_profile_selector.custom_minimum_size = Vector2(190.0, 42.0)
	opponent_profile_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var selected_index := 0
	var profile_ids: PackedStringArray = OpponentBehaviorProfilesClass.profile_ids()
	for index in range(profile_ids.size()):
		var profile_id := profile_ids[index]
		opponent_profile_selector.add_item(OpponentBehaviorProfilesClass.display_label(profile_id))
		opponent_profile_selector.set_item_metadata(index, profile_id)
		if profile_id == opponent_profile_id:
			selected_index = index
	opponent_profile_selector.select(selected_index)
	opponent_profile_selector.item_selected.connect(_on_opponent_profile_selected)
	row.add_child(opponent_profile_selector)

func _on_opponent_profile_selected(index: int) -> void:
	if opponent_profile_selector == null or index < 0 or index >= opponent_profile_selector.item_count:
		return
	_request_opponent_profile(str(opponent_profile_selector.get_item_metadata(index)))

func _request_opponent_profile(profile_id: String) -> void:
	var normalized := profile_id.strip_edges().to_lower()
	if not opponent_ai_active or not OpponentBehaviorProfilesClass.is_supported(normalized):
		return
	if normalized == opponent_profile_id:
		return
	var router: Variant = get_parent()
	if router != null and router.has_method("switch_opponent_profile"):
		router.call_deferred("switch_opponent_profile", normalized)

func _process_opponent_ai(delta: float) -> void:
	opponent_attack_chain.tick(delta)
	if not _opponent_actionable():
		opponent_current_intent = opponent_decision_state.idle_intent()
		opponent_guarding = false
		opponent_decision_accumulator = 0.0
		_set_opponent_ai_web_state()
		return

	_apply_opponent_movement(delta)
	opponent_decision_accumulator += maxf(0.0, delta)
	if opponent_decision_accumulator + 0.0001 < opponent_behavior_profile.reaction_interval:
		return

	opponent_decision_accumulator = 0.0
	opponent_decision_tick += 1
	var snapshot := {
		"decision_tick": opponent_decision_tick,
		"opponent_x": dummy_x,
		"opponent_depth": dummy_depth,
		"player_x": player_x,
		"player_depth": player_depth,
		"opponent_actionable": _opponent_actionable(),
		"guard_ready": not opponent_attack_chain.is_attacking(),
		"threatened": false,
		"basic_attack_ready": not opponent_attack_chain.is_attacking() and not player_state.is_defeated(),
		"ready_skill_slots": []
	}
	opponent_current_intent = opponent_decision_state.decide(opponent_behavior_profile, snapshot)
	opponent_guarding = bool(opponent_current_intent.get("guard", false))
	if bool(opponent_current_intent.get("basic_attack", false)):
		_try_opponent_basic_attack()
	_set_opponent_ai_web_state()

func _opponent_actionable() -> bool:
	return (
		not dummy_state.is_defeated()
		and dummy_state.hitstun_remaining <= 0.0
		and dummy_recovery_state.state_name() == "READY"
		and not dummy_knockback_state.is_active()
	)

func _apply_opponent_movement(delta: float) -> void:
	if opponent_attack_chain.is_attacking() or not _opponent_actionable():
		return
	var move_x := float(opponent_current_intent.get("move_x", 0.0))
	var move_depth := float(opponent_current_intent.get("move_depth", 0.0))
	# Bound one-frame displacement so hosted-browser stalls cannot make the
	# adapter jump across both the preferred band and attack range in one frame.
	var safe_delta := minf(maxf(delta, 0.0), 0.05)
	dummy_x += move_x * OPPONENT_MOVE_SPEED * safe_delta
	dummy_depth += move_depth * OPPONENT_DEPTH_SPEED * safe_delta
	dummy_x = clampf(dummy_x, 90.0, maxf(size.x, 1280.0) - 90.0)
	dummy_depth = clampf(dummy_depth, 0.0, 1.0)

func _try_opponent_basic_attack() -> void:
	if not _opponent_actionable() or player_state.is_defeated():
		return
	var step := opponent_attack_chain.try_start_attack()
	if step <= 0:
		return

	opponent_attack_count += 1
	var facing := -1.0 if player_x < dummy_x else 1.0
	var hitbox := OpponentCombatBox.new(
		Vector2(
			dummy_x + facing * opponent_attack_chain.hitbox_offset_for_step(step),
			dummy_depth
		),
		Vector2(
			opponent_attack_chain.hitbox_half_width_for_step(step),
			opponent_attack_chain.hitbox_half_depth_for_step(step)
		)
	)
	var player_hurtbox := OpponentCombatBox.new(
		Vector2(player_x, player_depth),
		Vector2(DUMMY_HURTBOX_HALF_WIDTH, DUMMY_HURTBOX_HALF_DEPTH)
	)
	if not hitbox.overlaps(player_hurtbox):
		_set_opponent_ai_web_state()
		return

	var dealt := receive_player_hit(
		opponent_attack_chain.damage_for_step(step),
		dummy_x,
		dummy_depth,
		opponent_attack_chain.hitstun_for_step(step)
	)
	opponent_last_damage = dealt
	if dealt > 0:
		opponent_hit_count += 1
	_set_opponent_ai_web_state()

func _create_match_overlay() -> void:
	match_overlay = CenterContainer.new()
	match_overlay.name = "MatchResultOverlay"
	match_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	match_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	match_overlay.visible = false
	match_overlay.z_index = 100
	add_child(match_overlay)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440.0, 250.0)
	match_overlay.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 18)
	margin.add_child(layout)

	match_result_label = Label.new()
	match_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	match_result_label.add_theme_font_size_override("font_size", 34)
	layout.add_child(match_result_label)

	var hint := Label.new()
	hint.text = "重新開始會重置 HP、MP、位置、技能冷卻與所有戰鬥狀態"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(hint)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	layout.add_child(actions)

	restart_button = Button.new()
	restart_button.text = "重新開始"
	restart_button.custom_minimum_size = Vector2(180.0, 52.0)
	restart_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	restart_button.pressed.connect(_restart_match)
	actions.add_child(restart_button)

	return_creator_button = Button.new()
	return_creator_button.text = "返回 Creator"
	return_creator_button.custom_minimum_size = Vector2(180.0, 52.0)
	return_creator_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return_creator_button.pressed.connect(_return_to_creator)
	actions.add_child(return_creator_button)

func _finish_match(result: String) -> void:
	if match_over:
		return
	match_over = true
	match_result = result
	match_result_label.text = "勝利！" if result == "victory" else "失敗"
	match_overlay.visible = true
	player_guarding = false
	player_running = false
	opponent_guarding = false
	opponent_current_intent = opponent_decision_state.idle_intent()
	fireball_projectile.deactivate()
	_set_runtime_controllers_processing(false)
	_set_opponent_ai_web_state()
	_set_match_web_state()
	queue_redraw()

func _restart_match() -> void:
	_switch_router_mode(SINGLE_PLAYER_MODE if opponent_ai_active else "training")

func _return_to_creator() -> void:
	_switch_router_mode("creator")

func _switch_router_mode(mode_name: String) -> void:
	var router: Variant = get_parent()
	if router != null and router.has_method("switch_mode"):
		router.call_deferred("switch_mode", mode_name)

func _set_runtime_controllers_processing(enabled: bool) -> void:
	for node_name in ["AreaSkillController", "FormationSkillController", "BuffSkillController", "MeleeSkillController", "BeamSkillController", "TrapSkillController", "AuraSkillController", "TeleportSkillController", "CounterSkillController"]:
		var controller := get_node_or_null(node_name)
		if controller != null:
			controller.set_process(enabled)

func _install_match_bridges() -> void:
	if not OS.has_feature("web"):
		return
	_web_restart_callback = JavaScriptBridge.create_callback(_web_restart_match)
	_web_return_creator_callback = JavaScriptBridge.create_callback(_web_return_to_creator)
	_web_select_opponent_profile_callback = JavaScriptBridge.create_callback(_web_select_opponent_profile)
	var window = JavaScriptBridge.get_interface("window")
	window.customFighterRestartMatch = _web_restart_callback
	window.customFighterReturnToCreator = _web_return_creator_callback
	window.customFighterSelectOpponentProfile = _web_select_opponent_profile_callback

func _web_restart_match(_args: Array) -> void:
	_restart_match()

func _web_return_to_creator(_args: Array) -> void:
	_return_to_creator()

func _web_select_opponent_profile(args: Array) -> void:
	if args.is_empty():
		return
	_request_opponent_profile(str(args[0]))

func _set_match_web_state() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval(
		"document.documentElement.dataset.matchOver='%s';" % ("true" if match_over else "false") +
		"document.documentElement.dataset.matchResult=%s;" % JSON.stringify(match_result) +
		"document.documentElement.dataset.matchRestartReady='%s';" % ("true" if restart_button != null else "false") +
		"document.documentElement.dataset.matchReturnCreatorReady='%s';" % ("true" if return_creator_button != null else "false")
	)
	_set_opponent_ai_web_state()

func _set_opponent_ai_web_state() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval(
		"document.documentElement.dataset.opponentAiActive='%s';" % ("true" if opponent_ai_active else "false") +
		"document.documentElement.dataset.opponentAiProfile=%s;" % JSON.stringify(opponent_profile_id if opponent_ai_active else "") +
		"document.documentElement.dataset.opponentAiReactionInterval='%.3f';" % (opponent_behavior_profile.reaction_interval if opponent_ai_active and opponent_behavior_profile.loaded else 0.0) +
		"document.documentElement.dataset.opponentAiBasicAttackRange='%.1f';" % (opponent_behavior_profile.basic_attack_range if opponent_ai_active and opponent_behavior_profile.loaded else 0.0) +
		"document.documentElement.dataset.opponentAiProfileSelectorVisible='%s';" % ("true" if opponent_profile_panel != null else "false") +
		"document.documentElement.dataset.opponentAiProfileSelectorCount='%d';" % (opponent_profile_selector.item_count if opponent_profile_selector != null else 0) +
		"document.documentElement.dataset.opponentAiIntent=%s;" % JSON.stringify(_opponent_intent_name()) +
		"document.documentElement.dataset.opponentAiDecisionTick='%d';" % opponent_decision_tick +
		"document.documentElement.dataset.opponentAiGuarding='%s';" % ("true" if opponent_guarding else "false") +
		"document.documentElement.dataset.opponentAiAttackCount='%d';" % opponent_attack_count +
		"document.documentElement.dataset.opponentAiHitCount='%d';" % opponent_hit_count +
		"document.documentElement.dataset.opponentAiLastDamage='%d';" % opponent_last_damage
	)

func _opponent_intent_name() -> String:
	if bool(opponent_current_intent.get("guard", false)):
		return "guard"
	if bool(opponent_current_intent.get("basic_attack", false)):
		return "basic_attack"
	var skill_slot := str(opponent_current_intent.get("skill_slot", ""))
	if not skill_slot.is_empty():
		return "skill:%s" % skill_slot
	if (
		absf(float(opponent_current_intent.get("move_x", 0.0))) > 0.01
		or absf(float(opponent_current_intent.get("move_depth", 0.0))) > 0.01
	):
		return "move"
	return "idle"
