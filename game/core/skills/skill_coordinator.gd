class_name SkillCoordinator
extends RefCounted

var _owner: StringName = &""

func can_claim(owner: StringName) -> bool:
	if owner == &"":
		return false
	return _owner == &"" or _owner == owner

func try_claim(owner: StringName) -> bool:
	if not can_claim(owner):
		return false
	_owner = owner
	return true

func release(owner: StringName) -> void:
	if owner != &"" and _owner == owner:
		_owner = &""

func reset() -> void:
	_owner = &""

func is_busy() -> bool:
	return _owner != &""

func is_owned_by(owner: StringName) -> bool:
	return owner != &"" and _owner == owner

func owner_name() -> String:
	return String(_owner)
