import crypto from 'node:crypto';
import { PVP_AUTHORITY_POLICY, PVP_PROTOCOL_VERSION } from './protocol.mjs';

const RULESET_ID = 'competitive_standard';
const RULESET_VERSION = 1;
const POWER_BUDGET_ID = 'competitive_standard_v1';
const PACKAGE_SCHEMA_VERSION = 1;

const BUILTIN = Object.freeze({
  ember_vanguard_001: '56451d3bdf1c7bf74852a3620894667730ddb088f350eb598badfa74c6d3c28e',
  storm_duelist_001: '5822c6cfb4737c29007f2450a598c501b79c17d8ed9a432e4327976cc6a7026e'
});

function reject(code, details = {}) {
  return { accepted: false, code, ...details };
}

function canonical(value) {
  if (Array.isArray(value)) return '[' + value.map(canonical).join(',') + ']';
  if (value && typeof value === 'object') {
    return '{' + Object.keys(value).sort().map(key => JSON.stringify(key) + ':' + canonical(value[key])).join(',') + '}';
  }
  return JSON.stringify(value);
}

function fingerprint(value) {
  return crypto.createHash('sha256').update(canonical(value)).digest('hex');
}

function authorityFrom(characterId, contentFingerprint, schemaVersion = PACKAGE_SCHEMA_VERSION) {
  return {
    protocol_version: PVP_PROTOCOL_VERSION,
    authority_policy: PVP_AUTHORITY_POLICY,
    character_id: characterId,
    content_fingerprint: contentFingerprint,
    package_schema_version: schemaVersion,
    ruleset_id: RULESET_ID,
    ruleset_version: RULESET_VERSION,
    power_budget_id: POWER_BUDGET_ID
  };
}

function validateCustomPackage(pkg) {
  if (!pkg || typeof pkg !== 'object' || Array.isArray(pkg)) return reject('PACKAGE_INVALID');
  const allowed = ['schema_version','character','skills','ruleset_id','ruleset_version','power_budget_id'];
  if (Object.keys(pkg).some(key => !allowed.includes(key))) return reject('PACKAGE_FIELDS_INVALID');
  if (pkg.schema_version !== PACKAGE_SCHEMA_VERSION) return reject('PACKAGE_SCHEMA_UNSUPPORTED');
  if (pkg.ruleset_id !== RULESET_ID || pkg.ruleset_version !== RULESET_VERSION) return reject('RULESET_UNSUPPORTED');
  if (pkg.power_budget_id !== POWER_BUDGET_ID) return reject('POWER_BUDGET_UNSUPPORTED');
  if (!pkg.character || typeof pkg.character !== 'object' || Array.isArray(pkg.character)) return reject('CHARACTER_INVALID');
  if (pkg.character.id !== pkg.character_id && 'character_id' in pkg) return reject('CHARACTER_ID_MISMATCH');
  const characterAllowed = ['id','stats','skill_slots'];
  if (Object.keys(pkg.character).some(key => !characterAllowed.includes(key))) return reject('CHARACTER_FIELDS_INVALID');
  if (typeof pkg.character.id !== 'string' || !/^[a-z0-9_]{1,64}$/.test(pkg.character.id)) return reject('CHARACTER_ID_INVALID');
  const stats = pkg.character.stats;
  if (!stats || typeof stats !== 'object' || Array.isArray(stats)) return reject('CHARACTER_STATS_INVALID');
  const statAllowed = ['max_hp','max_mp','move_speed','depth_speed','run_multiplier','guard_move_multiplier'];
  if (Object.keys(stats).some(key => !statAllowed.includes(key))) return reject('CHARACTER_STATS_FIELDS_INVALID');
  const ranges = {max_hp:[1,250],max_mp:[0,250],move_speed:[1,600],depth_speed:[0.1,5],run_multiplier:[1,2],guard_move_multiplier:[0,1]};
  for (const [key,[min,max]] of Object.entries(ranges)) {
    if (typeof stats[key] !== 'number' || !Number.isFinite(stats[key]) || stats[key] < min || stats[key] > max) return reject('CHARACTER_STAT_OUT_OF_BOUNDS',{field:key});
  }
  if (!pkg.character.skill_slots || typeof pkg.character.skill_slots !== 'object' || Array.isArray(pkg.character.skill_slots)) return reject('SKILL_SLOTS_INVALID');
  if (!Array.isArray(pkg.skills) || pkg.skills.length < 1 || pkg.skills.length > 13) return reject('SKILLS_INVALID');
  const skillById = new Map();
  for (const skill of pkg.skills) {
    if (!skill || typeof skill !== 'object' || Array.isArray(skill)) return reject('SKILL_INVALID');
    const skillAllowed=['id','type','damage','mp_cost','cooldown'];
    if (Object.keys(skill).some(key=>!skillAllowed.includes(key))) return reject('SKILL_FIELDS_INVALID');
    if (typeof skill.id !== 'string' || !/^[a-z0-9_]{1,64}$/.test(skill.id)) return reject('SKILL_ID_INVALID');
    if (!['projectile','melee','area','buff','movement','defense','summon','grab','counter'].includes(skill.type)) return reject('SKILL_TYPE_UNSUPPORTED',{skill_id:skill.id});
    if (!Number.isInteger(skill.damage) || skill.damage < 0 || skill.damage > 60) return reject('SKILL_DAMAGE_OUT_OF_BOUNDS',{skill_id:skill.id});
    if (!Number.isInteger(skill.mp_cost) || skill.mp_cost < 0 || skill.mp_cost > 100) return reject('SKILL_MP_OUT_OF_BOUNDS',{skill_id:skill.id});
    if (typeof skill.cooldown !== 'number' || !Number.isFinite(skill.cooldown) || skill.cooldown < 0.25 || skill.cooldown > 30) return reject('SKILL_COOLDOWN_OUT_OF_BOUNDS',{skill_id:skill.id});
    if (skillById.has(skill.id)) return reject('SKILL_DUPLICATE',{skill_id:skill.id});
    skillById.set(skill.id, skill);
  }
  for (const [slot,id] of Object.entries(pkg.character.skill_slots)) {
    if (!/^skill_(?:[1-9]|1[0-3])$/.test(slot) || typeof id !== 'string' || !skillById.has(id)) return reject('SKILL_SLOT_RESOLUTION_FAILED',{slot});
  }
  return { accepted:true, character_id:pkg.character.id };
}

export function createServerPackageAuthority({ packageResolver } = {}) {
  return async function admitLoadout(claim) {
    if (claim.package_schema_version !== PACKAGE_SCHEMA_VERSION) return reject('PACKAGE_SCHEMA_UNSUPPORTED');

    if (BUILTIN[claim.character_id]) {
      if (claim.content_fingerprint !== BUILTIN[claim.character_id]) return reject('CONTENT_FINGERPRINT_MISMATCH');
      return { accepted:true, authority:authorityFrom(claim.character_id, BUILTIN[claim.character_id]) };
    }

    if (typeof packageResolver !== 'function') return reject('PACKAGE_NOT_FOUND');
    let pkg;
    try { pkg = await packageResolver(claim.character_id); }
    catch { return reject('PACKAGE_RESOLUTION_ERROR'); }
    const validation = validateCustomPackage(pkg);
    if (!validation.accepted) return validation;
    if (validation.character_id !== claim.character_id) return reject('CHARACTER_ID_MISMATCH');

    const authoritativeFingerprint = fingerprint(pkg);
    if (claim.content_fingerprint !== authoritativeFingerprint) return reject('CONTENT_FINGERPRINT_MISMATCH');
    return { accepted:true, authority:authorityFrom(claim.character_id, authoritativeFingerprint) };
  };
}

export const _test = Object.freeze({ canonical, fingerprint, validateCustomPackage });
