import sharp from 'sharp';

const SAFE_TOKEN_RE = /^[a-z0-9][a-z0-9_-]*$/;
const SAFE_VFX_PNG_RE = /^[A-Za-z0-9][A-Za-z0-9_.-]*\.png$/;
const SAFE_ANIMATION_PNG_RE = /^[A-Za-z0-9][A-Za-z0-9._ -]*\.png$/;
const SAFE_WAV_RE = /^[a-z0-9][a-z0-9._-]*\.wav$/;
const BASE64_RE = /^[A-Za-z0-9+/]*={0,2}$/;
const CONTROL_RE = /[\u0000-\u001f\u007f]/;

const V1_FIELDS = Object.freeze(['schema_version', 'package_id', 'package_version', 'character', 'skills']);
const V2_FIELDS = Object.freeze([...V1_FIELDS, 'animation_map', 'animation_asset', 'audio_bindings', 'audio_asset', 'vfx_asset']);
const CHARACTER_FIELDS = Object.freeze(['schema_version', 'id', 'name', 'archetype', 'stats', 'skill_slots', 'visual_profile', 'animation_map']);
const STAT_FIELDS = Object.freeze(['max_hp', 'max_mp', 'move_speed', 'depth_speed', 'run_multiplier', 'guard_move_multiplier']);
const REQUIRED_SKILL_SLOTS = Object.freeze(['skill_1', 'skill_2', 'skill_3', 'skill_4', 'skill_5', 'skill_6']);
const OPTIONAL_SKILL_SLOTS = Object.freeze(['skill_7', 'skill_8', 'skill_9', 'skill_10', 'skill_11', 'skill_12', 'skill_13']);
const SKILL_SLOT_FIELDS = Object.freeze([...REQUIRED_SKILL_SLOTS, ...OPTIONAL_SKILL_SLOTS]);
const SKILL_FIELDS = Object.freeze([
  'schema_version', 'id', 'name', 'type', 'damage', 'mp_cost', 'cooldown',
  'startup', 'active', 'recovery', 'speed', 'range', 'hitstun', 'knockback',
  'hitbox_half_width', 'hitbox_half_depth', 'formation_count', 'formation_spacing',
  'formation_interval', 'formation_offset', 'buff_duration', 'move_speed_multiplier',
  'basic_attack_damage_multiplier', 'trap_duration', 'aura_duration', 'visual',
  'impact_visual', 'timeline'
]);
const SUPPORTED_SKILL_TYPES = new Set(['melee', 'projectile', 'area', 'dash', 'formation', 'buff', 'beam', 'trap', 'aura', 'teleport', 'counter', 'grab', 'summon']);
const TIMELINE_FIELDS = Object.freeze(['schema_version', 'events']);
const TIMELINE_EVENT_FIELDS = Object.freeze(['id', 'type', 'time', 'duration', 'animation', 'visual', 'cue', 'half_width', 'half_depth', 'offset_x', 'offset_depth']);
const TIMELINE_TYPES = new Set(['animation', 'vfx', 'audio', 'hitbox', 'hurtbox']);
const ANIMATION_SEMANTICS = Object.freeze([
  'ready', 'walk', 'run', 'jump', 'dash', 'guard',
  'attack_1', 'attack_2', 'attack_3',
  'skill_1', 'skill_2', 'skill_3', 'skill_4', 'skill_5', 'skill_6'
]);
const AUDIO_BINDINGS = Object.freeze(['ready', 'basic_attack', 'hit_received', 'skill_cast', 'skill_impact']);

const MAX_PACKAGE_SKILLS = 6;
const MAX_TIMELINE_EVENTS = 64;
const MAX_TIMELINE_SECONDS = 30;
const MAX_SPATIAL_HALF_WIDTH = 4096;
const MAX_SPATIAL_HALF_DEPTH = 1;
const MAX_SPATIAL_OFFSET_X = 4096;
const MAX_SPATIAL_OFFSET_DEPTH = 1;
const MAX_PNG_BYTES = 5 * 1024 * 1024;
const MAX_PNG_BASE64_CHARS = 7 * 1024 * 1024;
const MAX_AUDIO_BYTES = 512 * 1024;
const MAX_AUDIO_BASE64_CHARS = 700 * 1024;
const MAX_IMAGE_DIMENSION = 4096;
const MAX_FRAME_COUNT = 64;

function reject(code) {
  return { accepted: false, code };
}

function plainObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function exactFields(value, allowed, required = allowed) {
  if (!plainObject(value)) return false;
  const allowedSet = new Set(allowed);
  if (Object.keys(value).some(key => !allowedSet.has(key))) return false;
  return required.every(key => Object.hasOwn(value, key));
}

function finiteNumber(value) {
  return typeof value === 'number' && Number.isFinite(value);
}

function integer(value) {
  return Number.isSafeInteger(value);
}

function boundedNumber(value, min, max, { inclusiveMin = true } = {}) {
  if (!finiteNumber(value)) return false;
  if (inclusiveMin ? value < min : value <= min) return false;
  return value <= max;
}

function safeToken(value) {
  return typeof value === 'string' && SAFE_TOKEN_RE.test(value);
}

function safeText(value, max = 200) {
  return typeof value === 'string' && value.trim().length > 0 && value.length <= max && !CONTROL_RE.test(value);
}

function strictBase64(value, maxChars) {
  return typeof value === 'string' &&
    value.length > 0 &&
    value.length <= maxChars &&
    value.length % 4 === 0 &&
    BASE64_RE.test(value);
}

function decodeBase64(value, maxChars) {
  if (!strictBase64(value, maxChars)) return null;
  const bytes = Buffer.from(value, 'base64');
  if (bytes.length === 0 || bytes.toString('base64') !== value) return null;
  return bytes;
}

function validateCharacter(character) {
  if (!exactFields(character, CHARACTER_FIELDS, ['schema_version', 'id', 'name', 'archetype', 'stats', 'skill_slots', 'visual_profile'])) {
    return reject('CHARACTER_FIELDS_INVALID');
  }
  if (character.schema_version !== 1) return reject('CHARACTER_SCHEMA_INVALID');
  if (!safeToken(character.id)) return reject('CHARACTER_ID_INVALID');
  if (!safeText(character.name)) return reject('CHARACTER_NAME_INVALID');
  if (!safeToken(character.archetype)) return reject('CHARACTER_ARCHETYPE_INVALID');
  if (!safeToken(character.visual_profile)) return reject('CHARACTER_VISUAL_INVALID');

  const animationMap = character.animation_map ?? character.id;
  if (!safeToken(animationMap)) return reject('CHARACTER_ANIMATION_MAP_INVALID');

  if (!exactFields(character.stats, STAT_FIELDS)) return reject('CHARACTER_STATS_FIELDS_INVALID');
  const s = character.stats;
  if (!integer(s.max_hp) || s.max_hp < 1 || s.max_hp > 10000) return reject('CHARACTER_MAX_HP_INVALID');
  if (!integer(s.max_mp) || s.max_mp < 0 || s.max_mp > 10000) return reject('CHARACTER_MAX_MP_INVALID');
  if (!boundedNumber(s.move_speed, 0, 2000, { inclusiveMin: false })) return reject('CHARACTER_MOVE_SPEED_INVALID');
  if (!boundedNumber(s.depth_speed, 0, 5, { inclusiveMin: false })) return reject('CHARACTER_DEPTH_SPEED_INVALID');
  if (!boundedNumber(s.run_multiplier, 1, 3)) return reject('CHARACTER_RUN_MULTIPLIER_INVALID');
  if (!boundedNumber(s.guard_move_multiplier, 0, 1)) return reject('CHARACTER_GUARD_MOVE_INVALID');

  if (!plainObject(character.skill_slots)) return reject('CHARACTER_SKILL_SLOTS_INVALID');
  const slotKeys = Object.keys(character.skill_slots);
  if (slotKeys.some(key => !SKILL_SLOT_FIELDS.includes(key))) return reject('CHARACTER_SKILL_SLOTS_FIELDS_INVALID');
  for (const slot of REQUIRED_SKILL_SLOTS) {
    if (!Object.hasOwn(character.skill_slots, slot) || !safeToken(character.skill_slots[slot])) {
      return reject('CHARACTER_REQUIRED_SKILL_SLOT_INVALID');
    }
  }
  for (const slot of OPTIONAL_SKILL_SLOTS) {
    if (Object.hasOwn(character.skill_slots, slot) && !safeToken(character.skill_slots[slot])) {
      return reject('CHARACTER_OPTIONAL_SKILL_SLOT_INVALID');
    }
  }

  return { accepted: true, animation_map: animationMap };
}

function timelineMediaToken(event, type) {
  if (type === 'animation') return event.animation ?? 'skill_1';
  if (type === 'vfx') return event.visual ?? 'projectile';
  if (type === 'audio') return event.cue ?? 'skill_cast';
  return '';
}

function validateTimeline(timeline) {
  if (!exactFields(timeline, TIMELINE_FIELDS)) return reject('TIMELINE_FIELDS_INVALID');
  if (timeline.schema_version !== 1) return reject('TIMELINE_SCHEMA_INVALID');
  if (!Array.isArray(timeline.events) || timeline.events.length > MAX_TIMELINE_EVENTS) return reject('TIMELINE_EVENTS_INVALID');

  const ids = new Set();
  let previousTime = -1;
  for (const event of timeline.events) {
    if (!plainObject(event)) return reject('TIMELINE_EVENT_INVALID');
    if (Object.keys(event).some(key => !TIMELINE_EVENT_FIELDS.includes(key))) return reject('TIMELINE_EVENT_FIELDS_INVALID');
    if (!safeText(event.id, 96) || ids.has(event.id)) return reject('TIMELINE_EVENT_ID_INVALID');
    ids.add(event.id);
    if (!TIMELINE_TYPES.has(event.type)) return reject('TIMELINE_EVENT_TYPE_INVALID');
    if (!finiteNumber(event.time) || event.time < 0) return reject('TIMELINE_EVENT_TIME_INVALID');
    const duration = event.duration ?? 0;
    if (!finiteNumber(duration) || duration < 0) return reject('TIMELINE_EVENT_DURATION_INVALID');
    if (event.time + duration > MAX_TIMELINE_SECONDS) return reject('TIMELINE_DURATION_LIMIT');
    if (event.time + 0.0001 < previousTime) return reject('TIMELINE_ORDER_INVALID');
    previousTime = Math.max(previousTime, event.time);

    if (['animation', 'vfx', 'audio'].includes(event.type)) {
      const activeField = event.type === 'animation' ? 'animation' : event.type === 'vfx' ? 'visual' : 'cue';
      const inactiveFields = ['animation', 'visual', 'cue'].filter(field => field !== activeField);
      if (inactiveFields.some(field => Object.hasOwn(event, field))) return reject('TIMELINE_MEDIA_FIELDS_INVALID');
      if (!safeToken(timelineMediaToken(event, event.type))) return reject('TIMELINE_MEDIA_TOKEN_INVALID');
      if (['half_width', 'half_depth', 'offset_x', 'offset_depth'].some(field => Object.hasOwn(event, field))) {
        return reject('TIMELINE_SPATIAL_FIELDS_INVALID');
      }
    } else {
      if (['animation', 'visual', 'cue'].some(field => Object.hasOwn(event, field))) return reject('TIMELINE_MEDIA_FIELDS_INVALID');
      const halfWidth = event.half_width ?? 24;
      const halfDepth = event.half_depth ?? 0.08;
      const offsetX = event.offset_x ?? 0;
      const offsetDepth = event.offset_depth ?? 0;
      if (!boundedNumber(halfWidth, 0, MAX_SPATIAL_HALF_WIDTH, { inclusiveMin: false })) return reject('TIMELINE_HALF_WIDTH_INVALID');
      if (!boundedNumber(halfDepth, 0, MAX_SPATIAL_HALF_DEPTH, { inclusiveMin: false })) return reject('TIMELINE_HALF_DEPTH_INVALID');
      if (!finiteNumber(offsetX) || Math.abs(offsetX) > MAX_SPATIAL_OFFSET_X) return reject('TIMELINE_OFFSET_X_INVALID');
      if (!finiteNumber(offsetDepth) || Math.abs(offsetDepth) > MAX_SPATIAL_OFFSET_DEPTH) return reject('TIMELINE_OFFSET_DEPTH_INVALID');
    }
  }
  return { accepted: true };
}

function validateSkill(skill) {
  const required = ['schema_version', 'id', 'name', 'type', 'damage', 'mp_cost', 'cooldown', 'startup', 'active', 'recovery', 'visual', 'impact_visual'];
  if (!exactFields(skill, SKILL_FIELDS, required)) return reject('SKILL_FIELDS_INVALID');
  if (skill.schema_version !== 1) return reject('SKILL_SCHEMA_INVALID');
  if (!safeToken(skill.id)) return reject('SKILL_ID_INVALID');
  if (!safeText(skill.name)) return reject('SKILL_NAME_INVALID');
  if (!SUPPORTED_SKILL_TYPES.has(skill.type)) return reject('SKILL_TYPE_INVALID');
  if (!integer(skill.damage) || skill.damage < 0) return reject('SKILL_DAMAGE_INVALID');
  if (!integer(skill.mp_cost) || skill.mp_cost < 0) return reject('SKILL_MP_COST_INVALID');
  for (const key of ['cooldown', 'startup', 'active', 'recovery', 'speed', 'range', 'hitstun', 'knockback', 'hitbox_half_width', 'hitbox_half_depth', 'formation_spacing', 'formation_interval', 'formation_offset', 'buff_duration', 'move_speed_multiplier', 'basic_attack_damage_multiplier', 'trap_duration', 'aura_duration']) {
    if (Object.hasOwn(skill, key) && !finiteNumber(skill[key])) return reject('SKILL_NUMERIC_INVALID');
  }
  if (Object.hasOwn(skill, 'formation_count') && !integer(skill.formation_count)) return reject('SKILL_NUMERIC_INVALID');
  for (const key of ['cooldown', 'startup', 'active', 'recovery', 'hitstun', 'knockback']) {
    if (skill[key] < 0) return reject('SKILL_NUMERIC_INVALID');
  }
  if (!safeToken(skill.visual) || !safeToken(skill.impact_visual)) return reject('SKILL_VISUAL_INVALID');

  const speed = skill.speed ?? 0;
  const range = skill.range ?? 0;
  const active = skill.active;
  const halfWidth = skill.hitbox_half_width ?? 24;
  const halfDepth = skill.hitbox_half_depth ?? 0.08;

  if (['melee', 'area', 'formation', 'beam', 'trap', 'aura', 'counter', 'grab', 'summon'].includes(skill.type)) {
    if (!finiteNumber(halfWidth) || !finiteNumber(halfDepth)) return reject('SKILL_HITBOX_INVALID');
  }

  if (skill.type === 'melee') {
    if (!finiteNumber(range) || range <= 0 || active <= 0 || halfWidth <= 0 || halfDepth <= 0) return reject('MELEE_BOUNDS_INVALID');
  } else if (skill.type === 'projectile' || skill.type === 'dash') {
    if (!finiteNumber(speed) || speed <= 0 || !finiteNumber(range) || range <= 0 || active <= 0 || !finiteNumber(halfWidth) || halfWidth <= 0 || !finiteNumber(halfDepth) || halfDepth <= 0) {
      return reject('MOTION_SKILL_BOUNDS_INVALID');
    }
  } else if (skill.type === 'area') {
    if (active <= 0 || halfWidth <= 0 || halfDepth <= 0) return reject('AREA_BOUNDS_INVALID');
  } else if (skill.type === 'formation') {
    const count = skill.formation_count ?? 0;
    const spacing = skill.formation_spacing ?? 0;
    const interval = skill.formation_interval ?? 0;
    const offset = skill.formation_offset ?? 0;
    if (!integer(count) || count <= 0 || !finiteNumber(spacing) || spacing <= 0 || !finiteNumber(interval) || interval <= 0 || !finiteNumber(offset) || offset < 0 || active <= 0 || halfWidth <= 0 || halfDepth <= 0) {
      return reject('FORMATION_BOUNDS_INVALID');
    }
    if (active + 0.0001 < (count - 1) * interval) return reject('FORMATION_ACTIVE_WINDOW_INVALID');
  } else if (skill.type === 'buff') {
    const duration = skill.buff_duration ?? 0;
    const moveMultiplier = skill.move_speed_multiplier ?? 1;
    const damageMultiplier = skill.basic_attack_damage_multiplier ?? 1;
    if (!finiteNumber(duration) || duration <= 0 || !finiteNumber(moveMultiplier) || moveMultiplier < 1 || !finiteNumber(damageMultiplier) || damageMultiplier < 1) {
      return reject('BUFF_BOUNDS_INVALID');
    }
  } else if (skill.type === 'beam') {
    if (!boundedNumber(range, 0, 4096, { inclusiveMin: false }) || active <= 0 || !boundedNumber(halfWidth, 0, 4096, { inclusiveMin: false }) || !boundedNumber(halfDepth, 0, 1, { inclusiveMin: false })) {
      return reject('BEAM_BOUNDS_INVALID');
    }
  } else if (skill.type === 'trap') {
    const trapDuration = skill.trap_duration ?? 0;
    if (!boundedNumber(range, 0, 2048) || active <= 0 || !boundedNumber(trapDuration, 0, 30, { inclusiveMin: false }) || !boundedNumber(halfWidth, 0, 4096, { inclusiveMin: false }) || !boundedNumber(halfDepth, 0, 1, { inclusiveMin: false })) {
      return reject('TRAP_BOUNDS_INVALID');
    }
  } else if (skill.type === 'aura') {
    const auraDuration = skill.aura_duration ?? 0;
    if (active <= 0 || !boundedNumber(auraDuration, 0, 30, { inclusiveMin: false }) || !boundedNumber(halfWidth, 0, 4096, { inclusiveMin: false }) || !boundedNumber(halfDepth, 0, 1, { inclusiveMin: false })) {
      return reject('AURA_BOUNDS_INVALID');
    }
  } else if (skill.type === 'teleport') {
    if (!boundedNumber(range, 0, 2048, { inclusiveMin: false })) return reject('TELEPORT_BOUNDS_INVALID');
  } else if (skill.type === 'counter') {
    if (!boundedNumber(range, 0, 1024, { inclusiveMin: false }) || !boundedNumber(active, 0, 2, { inclusiveMin: false }) || !boundedNumber(halfDepth, 0, 1, { inclusiveMin: false })) {
      return reject('COUNTER_BOUNDS_INVALID');
    }
  } else if (skill.type === 'grab') {
    const knockback = skill.knockback ?? 0;
    if (!boundedNumber(range, 0, 1024, { inclusiveMin: false }) || !boundedNumber(active, 0, 2, { inclusiveMin: false }) || !boundedNumber(knockback, 0, 256, { inclusiveMin: false }) || !boundedNumber(halfWidth, 0, 4096, { inclusiveMin: false }) || !boundedNumber(halfDepth, 0, 1, { inclusiveMin: false })) {
      return reject('GRAB_BOUNDS_INVALID');
    }
  } else if (skill.type === 'summon') {
    if (!boundedNumber(range, 0, 1024, { inclusiveMin: false }) || !boundedNumber(speed, 0, 1200, { inclusiveMin: false }) || !boundedNumber(active, 0, 8, { inclusiveMin: false }) || !boundedNumber(halfWidth, 0, 4096, { inclusiveMin: false }) || !boundedNumber(halfDepth, 0, 1, { inclusiveMin: false })) {
      return reject('SUMMON_BOUNDS_INVALID');
    }
  }

  if (Object.hasOwn(skill, 'timeline')) {
    const timeline = validateTimeline(skill.timeline);
    if (!timeline.accepted) return timeline;
  }
  return { accepted: true };
}

function validateCorePackage(pkg) {
  const characterResult = validateCharacter(pkg.character);
  if (!characterResult.accepted) return characterResult;
  if (pkg.package_id !== pkg.character.id) return reject('PACKAGE_CHARACTER_ID_MISMATCH');
  if (!Array.isArray(pkg.skills) || pkg.skills.length < 1 || pkg.skills.length > MAX_PACKAGE_SKILLS) {
    return reject('PACKAGE_SKILLS_INVALID');
  }

  const skills = new Map();
  for (const skill of pkg.skills) {
    const result = validateSkill(skill);
    if (!result.accepted) return result;
    if (skills.has(skill.id)) return reject('PACKAGE_SKILL_DUPLICATE');
    skills.set(skill.id, skill);
  }

  const referenced = new Set();
  for (const slot of REQUIRED_SKILL_SLOTS) {
    const skillId = pkg.character.skill_slots[slot];
    referenced.add(skillId);
    if (!skills.has(skillId)) return reject('PACKAGE_SKILL_REFERENCE_MISSING');
  }
  for (const skillId of skills.keys()) {
    if (!referenced.has(skillId)) return reject('PACKAGE_SKILL_UNREFERENCED');
  }

  return { accepted: true, animation_map: characterResult.animation_map };
}

function validateAnimationMap(value, expectedId) {
  if (!exactFields(value, ['schema_version', 'id', 'animations'])) return reject('ANIMATION_MAP_FIELDS_INVALID');
  if (value.schema_version !== 1 || !safeToken(value.id) || value.id !== expectedId) return reject('ANIMATION_MAP_ID_INVALID');
  if (!exactFields(value.animations, ANIMATION_SEMANTICS)) return reject('ANIMATION_MAP_ANIMATIONS_INVALID');
  for (const semantic of ANIMATION_SEMANTICS) {
    if (!safeToken(value.animations[semantic])) return reject('ANIMATION_MAP_TOKEN_INVALID');
  }
  return { accepted: true };
}

async function pngMetadata(bytes) {
  if (!bytes || bytes.length < 8 || bytes.length > MAX_PNG_BYTES) return null;
  try {
    const meta = await sharp(bytes, { failOn: 'error' }).metadata();
    if (meta.format !== 'png' || !integer(meta.width) || !integer(meta.height)) return null;
    return { width: meta.width, height: meta.height };
  } catch {
    return null;
  }
}

async function validateAnimationAsset(value, animationMap) {
  if (!exactFields(value, ['metadata', 'png_base64'])) return reject('ANIMATION_ASSET_FIELDS_INVALID');
  const m = value.metadata;
  const fields = ['schema_version', 'semantic', 'animation_id', 'file_name', 'mime_type', 'image_width', 'image_height', 'frame_count', 'fps'];
  if (!exactFields(m, fields)) return reject('ANIMATION_ASSET_METADATA_FIELDS_INVALID');
  if (m.schema_version !== 1 || !ANIMATION_SEMANTICS.includes(m.semantic) || !safeToken(m.animation_id)) return reject('ANIMATION_ASSET_METADATA_INVALID');
  if (m.animation_id !== animationMap.animations[m.semantic]) return reject('ANIMATION_ASSET_MAPPING_MISMATCH');
  if (typeof m.file_name !== 'string' || m.file_name.length > 96 || !SAFE_ANIMATION_PNG_RE.test(m.file_name) || m.file_name.includes('..')) return reject('ANIMATION_ASSET_FILENAME_INVALID');
  if (m.mime_type !== 'image/png') return reject('ANIMATION_ASSET_MIME_INVALID');
  if (!integer(m.image_width) || m.image_width < 1 || m.image_width > MAX_IMAGE_DIMENSION || !integer(m.image_height) || m.image_height < 1 || m.image_height > MAX_IMAGE_DIMENSION) return reject('ANIMATION_ASSET_DIMENSIONS_INVALID');
  if (!integer(m.frame_count) || m.frame_count < 1 || m.frame_count > MAX_FRAME_COUNT || m.image_width % m.frame_count !== 0) return reject('ANIMATION_ASSET_FRAMES_INVALID');
  if (!boundedNumber(m.fps, 1, 60)) return reject('ANIMATION_ASSET_FPS_INVALID');
  const bytes = decodeBase64(value.png_base64, MAX_PNG_BASE64_CHARS);
  const meta = await pngMetadata(bytes);
  if (!meta || meta.width !== m.image_width || meta.height !== m.image_height) return reject('ANIMATION_ASSET_PNG_INVALID');
  return { accepted: true };
}

function validateAudioBindings(value) {
  if (!exactFields(value, ['schema_version', 'cues'])) return reject('AUDIO_BINDINGS_FIELDS_INVALID');
  if (value.schema_version !== 1 || !exactFields(value.cues, AUDIO_BINDINGS)) return reject('AUDIO_BINDINGS_INVALID');
  for (const binding of AUDIO_BINDINGS) {
    if (!safeToken(value.cues[binding])) return reject('AUDIO_BINDING_TOKEN_INVALID');
  }
  return { accepted: true };
}

function readU16LE(bytes, offset) {
  return offset >= 0 && offset + 2 <= bytes.length ? bytes.readUInt16LE(offset) : -1;
}

function readU32LE(bytes, offset) {
  return offset >= 0 && offset + 4 <= bytes.length ? bytes.readUInt32LE(offset) : -1;
}

function inspectWav(bytes) {
  if (!bytes || bytes.length < 44 || bytes.length > MAX_AUDIO_BYTES) return null;
  if (bytes.toString('ascii', 0, 4) !== 'RIFF' || bytes.toString('ascii', 8, 12) !== 'WAVE') return null;
  if (readU32LE(bytes, 4) + 8 !== bytes.length) return null;

  let format = null;
  let dataSize = null;
  let offset = 12;
  while (offset + 8 <= bytes.length) {
    const id = bytes.toString('ascii', offset, offset + 4);
    const size = readU32LE(bytes, offset + 4);
    const start = offset + 8;
    if (size < 0 || start + size > bytes.length) return null;
    if (id === 'fmt ') {
      if (format || size < 16) return null;
      format = {
        audio_format: readU16LE(bytes, start),
        channels: readU16LE(bytes, start + 2),
        sample_rate: readU32LE(bytes, start + 4),
        byte_rate: readU32LE(bytes, start + 8),
        block_align: readU16LE(bytes, start + 12),
        bits_per_sample: readU16LE(bytes, start + 14)
      };
    } else if (id === 'data') {
      if (dataSize !== null) return null;
      dataSize = size;
    }
    offset = start + size + (size % 2);
  }
  if (!format || dataSize === null || format.audio_format !== 1) return null;
  if (![1, 2].includes(format.channels) || format.sample_rate < 8000 || format.sample_rate > 48000 || ![8, 16].includes(format.bits_per_sample)) return null;
  const expectedAlign = format.channels * format.bits_per_sample / 8;
  if (format.block_align !== expectedAlign || format.byte_rate !== format.sample_rate * expectedAlign || dataSize < 1 || dataSize % expectedAlign !== 0) return null;
  const durationMs = Math.round(dataSize * 1000 / format.byte_rate);
  if (durationMs < 1 || durationMs > 3000) return null;
  return { ...format, duration_ms: durationMs };
}

function validateAudioAsset(value, audioBindings) {
  if (!exactFields(value, ['metadata', 'wav_base64'])) return reject('AUDIO_ASSET_FIELDS_INVALID');
  const m = value.metadata;
  const fields = ['schema_version', 'binding', 'cue_id', 'file_name', 'mime_type', 'byte_size', 'sample_rate', 'channels', 'bits_per_sample', 'duration_ms'];
  if (!exactFields(m, fields)) return reject('AUDIO_ASSET_METADATA_FIELDS_INVALID');
  if (m.schema_version !== 1 || !AUDIO_BINDINGS.includes(m.binding) || !safeToken(m.cue_id)) return reject('AUDIO_ASSET_METADATA_INVALID');
  if (m.cue_id !== audioBindings.cues[m.binding]) return reject('AUDIO_ASSET_CUE_MISMATCH');
  const filename = typeof m.file_name === 'string' ? m.file_name.toLowerCase() : '';
  if (filename.length > 96 || !SAFE_WAV_RE.test(filename)) return reject('AUDIO_ASSET_FILENAME_INVALID');
  if (!['audio/wav', 'audio/x-wav', 'audio/wave', 'audio/vnd.wave'].includes(String(m.mime_type).toLowerCase())) return reject('AUDIO_ASSET_MIME_INVALID');
  if (!integer(m.byte_size) || m.byte_size < 1 || m.byte_size > MAX_AUDIO_BYTES) return reject('AUDIO_ASSET_SIZE_INVALID');
  if (!integer(m.sample_rate) || m.sample_rate < 8000 || m.sample_rate > 48000 || !integer(m.channels) || ![1, 2].includes(m.channels) || !integer(m.bits_per_sample) || ![8, 16].includes(m.bits_per_sample) || !integer(m.duration_ms) || m.duration_ms < 1 || m.duration_ms > 3000) {
    return reject('AUDIO_ASSET_PROPERTIES_INVALID');
  }
  const bytes = decodeBase64(value.wav_base64, MAX_AUDIO_BASE64_CHARS);
  if (!bytes || bytes.length !== m.byte_size) return reject('AUDIO_ASSET_BYTES_INVALID');
  const inspected = inspectWav(bytes);
  if (!inspected || inspected.sample_rate !== m.sample_rate || inspected.channels !== m.channels || inspected.bits_per_sample !== m.bits_per_sample || inspected.duration_ms !== m.duration_ms) {
    return reject('AUDIO_ASSET_WAV_INVALID');
  }
  return { accepted: true };
}

async function validateVfxAsset(value, character) {
  const fields = ['skill_slot', 'skill_id', 'mime_type', 'metadata', 'png_base64'];
  if (!exactFields(value, fields)) return reject('VFX_ASSET_FIELDS_INVALID');
  if (value.skill_slot !== 'skill_1' || value.skill_id !== character.skill_slots.skill_1 || value.mime_type !== 'image/png') return reject('VFX_ASSET_IDENTITY_INVALID');
  const m = value.metadata;
  const metadataFields = ['schema_version', 'file_name', 'mime_type', 'image_width', 'image_height', 'frame_count', 'crop', 'scale', 'offset', 'fps'];
  if (!exactFields(m, metadataFields)) return reject('VFX_METADATA_FIELDS_INVALID');
  if (m.schema_version !== 1 || typeof m.file_name !== 'string' || !SAFE_VFX_PNG_RE.test(m.file_name) || m.file_name.includes('..') || m.mime_type !== 'image/png') return reject('VFX_METADATA_INVALID');
  if (!integer(m.image_width) || m.image_width < 1 || m.image_width > MAX_IMAGE_DIMENSION || !integer(m.image_height) || m.image_height < 1 || m.image_height > MAX_IMAGE_DIMENSION) return reject('VFX_DIMENSIONS_INVALID');
  if (!integer(m.frame_count) || m.frame_count < 1 || m.frame_count > MAX_FRAME_COUNT) return reject('VFX_FRAME_COUNT_INVALID');
  if (!exactFields(m.crop, ['x', 'y', 'width', 'height']) || !integer(m.crop.x) || !integer(m.crop.y) || !integer(m.crop.width) || !integer(m.crop.height) || m.crop.x < 0 || m.crop.y < 0 || m.crop.width < 1 || m.crop.height < 1 || m.crop.x + m.crop.width > m.image_width || m.crop.y + m.crop.height > m.image_height || m.crop.width % m.frame_count !== 0) {
    return reject('VFX_CROP_INVALID');
  }
  if (!exactFields(m.offset, ['x', 'y']) || !finiteNumber(m.offset.x) || !finiteNumber(m.offset.y) || Math.abs(m.offset.x) > 4096 || Math.abs(m.offset.y) > 4096) return reject('VFX_OFFSET_INVALID');
  if (!boundedNumber(m.scale, 0.1, 8) || !boundedNumber(m.fps, 1, 60)) return reject('VFX_RENDER_METADATA_INVALID');
  const bytes = decodeBase64(value.png_base64, MAX_PNG_BASE64_CHARS);
  const meta = await pngMetadata(bytes);
  if (!meta || meta.width !== m.image_width || meta.height !== m.image_height) return reject('VFX_PNG_INVALID');
  return { accepted: true };
}

export async function validateSelfContainedPackage(pkg) {
  if (!plainObject(pkg)) return reject('PACKAGE_INVALID');
  if (![1, 2].includes(pkg.schema_version)) return reject('PACKAGE_SCHEMA_UNSUPPORTED');
  const allowed = pkg.schema_version === 1 ? V1_FIELDS : V2_FIELDS;
  if (!exactFields(pkg, allowed, V1_FIELDS)) return reject('PACKAGE_FIELDS_INVALID');
  if (!safeToken(pkg.package_id)) return reject('PACKAGE_ID_INVALID');
  if (!integer(pkg.package_version) || pkg.package_version < 1) return reject('PACKAGE_VERSION_INVALID');

  const core = validateCorePackage(pkg);
  if (!core.accepted) return core;

  if (pkg.schema_version === 2) {
    let animationMap = null;
    if (Object.hasOwn(pkg, 'animation_map')) {
      const result = validateAnimationMap(pkg.animation_map, core.animation_map);
      if (!result.accepted) return result;
      animationMap = pkg.animation_map;
    }
    if (Object.hasOwn(pkg, 'animation_asset')) {
      if (!animationMap) return reject('ANIMATION_ASSET_REQUIRES_MAP');
      const result = await validateAnimationAsset(pkg.animation_asset, animationMap);
      if (!result.accepted) return result;
    }

    let audioBindings = null;
    if (Object.hasOwn(pkg, 'audio_bindings')) {
      const result = validateAudioBindings(pkg.audio_bindings);
      if (!result.accepted) return result;
      audioBindings = pkg.audio_bindings;
    }
    if (Object.hasOwn(pkg, 'audio_asset')) {
      if (!audioBindings) return reject('AUDIO_ASSET_REQUIRES_BINDINGS');
      const result = validateAudioAsset(pkg.audio_asset, audioBindings);
      if (!result.accepted) return result;
    }

    if (Object.hasOwn(pkg, 'vfx_asset')) {
      const result = await validateVfxAsset(pkg.vfx_asset, pkg.character);
      if (!result.accepted) return result;
    }
  }

  return {
    accepted: true,
    package_id: pkg.package_id,
    package_version: pkg.package_version,
    package_schema_version: pkg.schema_version
  };
}

export const _test = Object.freeze({
  validateTimeline,
  validateSkill,
  inspectWav,
  decodeBase64,
  V1_FIELDS,
  V2_FIELDS
});
