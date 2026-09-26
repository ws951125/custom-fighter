import assert from 'node:assert/strict';
import sharp from 'sharp';
import { validateSelfContainedPackage, _test } from '../backend/sharing/self_contained_package_validator.mjs';

function baseSkill(id, type) {
  return {
    schema_version: 1,
    id,
    name: id,
    type,
    damage: 12,
    mp_cost: 8,
    cooldown: 0.8,
    startup: 0.1,
    active: 0.5,
    recovery: 0.15,
    speed: type === 'projectile' || type === 'dash' ? 500 : 0,
    range: ['melee', 'projectile', 'dash'].includes(type) ? 360 : 0,
    hitstun: 0.15,
    knockback: 120,
    hitbox_half_width: 24,
    hitbox_half_depth: 0.08,
    formation_count: type === 'formation' ? 3 : 0,
    formation_spacing: type === 'formation' ? 48 : 0,
    formation_interval: type === 'formation' ? 0.1 : 0,
    formation_offset: type === 'formation' ? 24 : 0,
    buff_duration: type === 'buff' ? 2 : 0,
    move_speed_multiplier: type === 'buff' ? 1.1 : 1,
    basic_attack_damage_multiplier: type === 'buff' ? 1.1 : 1,
    visual: 'package_visual',
    impact_visual: 'package_impact'
  };
}

function legacyPackage() {
  const skills = [
    baseSkill('pkg_projectile', 'projectile'),
    baseSkill('pkg_dash', 'dash'),
    baseSkill('pkg_area', 'area'),
    baseSkill('pkg_formation', 'formation'),
    baseSkill('pkg_buff', 'buff'),
    baseSkill('pkg_melee', 'melee')
  ];
  skills[2].active = 0.5;
  skills[2].hitbox_half_width = 24;
  skills[2].hitbox_half_depth = 0.08;
  skills[3].active = 0.5;
  skills[5].range = 120;
  skills[5].active = 0.2;

  return {
    schema_version: 1,
    package_id: 'package_hero',
    package_version: 1,
    character: {
      schema_version: 1,
      id: 'package_hero',
      name: 'Package Hero',
      archetype: 'balanced',
      stats: {
        max_hp: 140,
        max_mp: 120,
        move_speed: 380,
        depth_speed: 0.72,
        run_multiplier: 1.6,
        guard_move_multiplier: 0.35
      },
      skill_slots: {
        skill_1: 'pkg_projectile',
        skill_2: 'pkg_dash',
        skill_3: 'pkg_area',
        skill_4: 'pkg_formation',
        skill_5: 'pkg_buff',
        skill_6: 'pkg_melee'
      },
      visual_profile: 'training_blue',
      animation_map: 'ember_vanguard'
    },
    skills
  };
}

function animationMap() {
  return {
    schema_version: 1,
    id: 'ember_vanguard',
    animations: {
      ready: 'package_ready_custom',
      walk: 'ember_walk',
      run: 'ember_run',
      jump: 'ember_jump',
      dash: 'ember_dash',
      guard: 'ember_guard',
      attack_1: 'ember_attack_one',
      attack_2: 'ember_attack_two',
      attack_3: 'ember_attack_three',
      skill_1: 'ember_skill_one',
      skill_2: 'ember_skill_two',
      skill_3: 'ember_skill_three',
      skill_4: 'ember_skill_four',
      skill_5: 'ember_skill_five',
      skill_6: 'ember_skill_six'
    }
  };
}

function audioBindings() {
  return {
    schema_version: 1,
    cues: {
      ready: 'character_ready',
      basic_attack: 'basic_attack',
      hit_received: 'character_hit',
      skill_cast: 'package_cast_custom',
      skill_impact: 'skill_impact'
    }
  };
}

function pcmWav(sampleRate = 8000, channels = 1, bits = 8, dataSize = 800) {
  const bytes = Buffer.alloc(44 + dataSize);
  bytes.write('RIFF', 0, 'ascii');
  bytes.writeUInt32LE(36 + dataSize, 4);
  bytes.write('WAVE', 8, 'ascii');
  bytes.write('fmt ', 12, 'ascii');
  bytes.writeUInt32LE(16, 16);
  bytes.writeUInt16LE(1, 20);
  bytes.writeUInt16LE(channels, 22);
  bytes.writeUInt32LE(sampleRate, 24);
  const blockAlign = channels * bits / 8;
  bytes.writeUInt32LE(sampleRate * blockAlign, 28);
  bytes.writeUInt16LE(blockAlign, 32);
  bytes.writeUInt16LE(bits, 34);
  bytes.write('data', 36, 'ascii');
  bytes.writeUInt32LE(dataSize, 40);
  bytes.fill(bits === 8 ? 128 : 0, 44);
  return bytes;
}

const png = await sharp({
  create: {
    width: 16,
    height: 4,
    channels: 4,
    background: { r: 220, g: 80, b: 140, alpha: 1 }
  }
}).png().toBuffer();

const wav = pcmWav();
const v2 = {
  ...legacyPackage(),
  schema_version: 2,
  animation_map: animationMap(),
  animation_asset: {
    metadata: {
      schema_version: 1,
      semantic: 'ready',
      animation_id: 'package_ready_custom',
      file_name: 'package-ready.png',
      mime_type: 'image/png',
      image_width: 16,
      image_height: 4,
      frame_count: 4,
      fps: 18
    },
    png_base64: png.toString('base64')
  },
  audio_bindings: audioBindings(),
  audio_asset: {
    metadata: {
      schema_version: 1,
      binding: 'skill_cast',
      cue_id: 'package_cast_custom',
      file_name: 'package-cast.wav',
      mime_type: 'audio/wav',
      byte_size: wav.length,
      sample_rate: 8000,
      channels: 1,
      bits_per_sample: 8,
      duration_ms: 100
    },
    wav_base64: wav.toString('base64')
  },
  vfx_asset: {
    skill_slot: 'skill_1',
    skill_id: 'pkg_projectile',
    mime_type: 'image/png',
    metadata: {
      schema_version: 1,
      file_name: 'package-strip.png',
      mime_type: 'image/png',
      image_width: 16,
      image_height: 4,
      frame_count: 4,
      crop: { x: 0, y: 0, width: 16, height: 4 },
      scale: 2,
      offset: { x: 12, y: -8 },
      fps: 20
    },
    png_base64: png.toString('base64')
  }
};

const v1Result = await validateSelfContainedPackage(legacyPackage());
assert.deepEqual(v1Result, {
  accepted: true,
  package_id: 'package_hero',
  package_version: 1,
  package_schema_version: 1
});

const v2Result = await validateSelfContainedPackage(v2);
assert.deepEqual(v2Result, {
  accepted: true,
  package_id: 'package_hero',
  package_version: 1,
  package_schema_version: 2
});

const timelinePackage = legacyPackage();
timelinePackage.skills[0].timeline = {
  schema_version: 1,
  events: [
    { id: 'cast_anim', type: 'animation', time: 0, duration: 0.2, animation: 'skill_1' },
    { id: 'cast_vfx', type: 'vfx', time: 0.1, duration: 0.2, visual: 'package_visual' },
    { id: 'cast_audio', type: 'audio', time: 0.15, duration: 0, cue: 'skill_cast' },
    { id: 'cast_hit', type: 'hitbox', time: 0.2, duration: 0.2, half_width: 40, half_depth: 0.12, offset_x: 24, offset_depth: -0.02 }
  ]
};
assert.equal((await validateSelfContainedPackage(timelinePackage)).accepted, true);

const scriptTopLevel = structuredClone(v2);
scriptTopLevel.script = 'res://evil.gd';
assert.equal((await validateSelfContainedPackage(scriptTopLevel)).code, 'PACKAGE_FIELDS_INVALID');

const nestedScript = structuredClone(v2);
nestedScript.vfx_asset.metadata.script_path = 'res://evil.gd';
assert.equal((await validateSelfContainedPackage(nestedScript)).code, 'VFX_METADATA_FIELDS_INVALID');

const badPng = structuredClone(v2);
badPng.vfx_asset.png_base64 = Buffer.from('not a png').toString('base64');
assert.equal((await validateSelfContainedPackage(badPng)).code, 'VFX_PNG_INVALID');

const animationMismatch = structuredClone(v2);
animationMismatch.animation_asset.metadata.animation_id = 'wrong_ready';
assert.equal((await validateSelfContainedPackage(animationMismatch)).code, 'ANIMATION_ASSET_MAPPING_MISMATCH');

const audioMismatch = structuredClone(v2);
audioMismatch.audio_asset.metadata.cue_id = 'wrong_cue';
assert.equal((await validateSelfContainedPackage(audioMismatch)).code, 'AUDIO_ASSET_CUE_MISMATCH');

const badWav = structuredClone(v2);
const tamperedWav = Buffer.from(wav);
tamperedWav[0] = 0;
badWav.audio_asset.wav_base64 = tamperedWav.toString('base64');
assert.equal((await validateSelfContainedPackage(badWav)).code, 'AUDIO_ASSET_WAV_INVALID');

const badTimeline = legacyPackage();
badTimeline.skills[0].timeline = {
  schema_version: 1,
  events: [
    { id: 'bad_vfx', type: 'vfx', time: 0, duration: 0.1, visual: '../evil.gd' }
  ]
};
assert.equal((await validateSelfContainedPackage(badTimeline)).code, 'TIMELINE_MEDIA_TOKEN_INVALID');

const badSpatialTimeline = legacyPackage();
badSpatialTimeline.skills[0].timeline = {
  schema_version: 1,
  events: [
    { id: 'bad_hit', type: 'hitbox', time: 0, duration: 0.1, half_width: 5000 }
  ]
};
assert.equal((await validateSelfContainedPackage(badSpatialTimeline)).code, 'TIMELINE_HALF_WIDTH_INVALID');

const duplicateSkill = legacyPackage();
duplicateSkill.skills[5] = structuredClone(duplicateSkill.skills[0]);
assert.equal((await validateSelfContainedPackage(duplicateSkill)).code, 'PACKAGE_SKILL_DUPLICATE');

const missingReference = legacyPackage();
missingReference.character.skill_slots.skill_1 = 'missing_skill';
assert.equal((await validateSelfContainedPackage(missingReference)).code, 'PACKAGE_SKILL_REFERENCE_MISSING');

const tooManySkills = legacyPackage();
tooManySkills.skills.push(baseSkill('seventh_skill', 'projectile'));
assert.equal((await validateSelfContainedPackage(tooManySkills)).code, 'PACKAGE_SKILLS_INVALID');

assert.equal(_test.inspectWav(wav).duration_ms, 100);
assert.equal(_test.inspectWav(Buffer.from('bad')), null);
assert.equal(_test.decodeBase64('%%%bad%%%', 100), null);

console.log('SELF_CONTAINED_PACKAGE_VALIDATOR_TESTS_PASSED');
