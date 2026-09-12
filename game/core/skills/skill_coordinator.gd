class_name SkillCoordinator
extends RefCounted

var _owner: StringName = &""
var _last_claimed_owner: StringName = &""
var _last_rejected_owner: StringName = &""
var _claim_count := 0
var _rejection_count := 0

func can_claim(owner: StringName) -> bool:
	if owner == &"":
		return false
	return _owner == &"" or _owner == owner

func try_claim(owner: StringName) -> bool:
	if owner == &"":
		_rejection_count += 1
		_last_rejected_owner = owner
		return false
	if _owner != &"" and _owner != owner:
		_rejection_count += 1
		_last_rejected_owner = owner
		return false
	if _owner == &"":
		_owner = owner
		_last_claimed_owner = owner
		_claim_count += 1
	return true

func release(owner: StringName) -> void:
	if owner != &"" and _owner == owner:
		_owner = &""

func reset() -> void:
	_owner = &""
	_last_claimed_owner = &""
	_last_rejected_owner = &""
	_claim_count = 0
	_rejection_count = 0

func is_busy() -> bool:
	return _owner != &""

func is_owned_by(owner: StringName) -> bool:
	return owner != &"" and _owner == owner

func owner_name() -> String:
	return String(_owner)

func last_claimed_owner_name() -> String:
	return String(_last_claimed_owner)

func last_rejected_owner_name() -> String:
	return String(_last_rejected_owner)

func claim_count() -> int:
	return _claim_count

func rejection_count() -> int:
	return _rejection_count
