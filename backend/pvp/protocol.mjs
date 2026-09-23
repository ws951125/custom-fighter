export const PVP_PROTOCOL_VERSION = 1;
export const PVP_AUTHORITY_POLICY = 'server_authoritative';
export const MAX_PVP_PARTICIPANTS = 2;

const CLIENT_ID_PATTERN = /^[A-Za-z0-9_.:-]{1,64}$/;
const CHARACTER_ID_PATTERN = /^[A-Za-z0-9_.-]{1,96}$/;
const FINGERPRINT_PATTERN = /^[a-f0-9]{64}$/;

const LOADOUT_CLAIM_KEYS = new Set([
  'character_id',
  'content_fingerprint',
  'package_schema_version'
]);

const AUTHORITY_SUMMARY_KEYS = new Set([
  'protocol_version',
  'authority_policy',
  'character_id',
  'content_fingerprint',
  'package_schema_version',
  'ruleset_id',
  'ruleset_version',
  'power_budget_id'
]);

function isPositiveInteger(value) {
  return Number.isInteger(value) && value > 0;
}

function exactKeys(value, allowedKeys) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return false;
  return Object.keys(value).every(key => allowedKeys.has(key));
}

export function normalizeClientId(value) {
  const clientId = String(value ?? '').trim();
  return CLIENT_ID_PATTERN.test(clientId) ? clientId : '';
}

export function validateLoadoutClaim(rawClaim) {
  const errors = [];
  if (!exactKeys(rawClaim, LOADOUT_CLAIM_KEYS)) {
    errors.push('LOADOUT_CLAIM_FIELDS_INVALID');
    return { ok: false, errors, claim: null };
  }

  const characterId = String(rawClaim.character_id ?? '').trim();
  const contentFingerprint = String(rawClaim.content_fingerprint ?? '').trim().toLowerCase();
  const packageSchemaVersion = Number(rawClaim.package_schema_version);

  if (!CHARACTER_ID_PATTERN.test(characterId)) errors.push('CHARACTER_ID_INVALID');
  if (!FINGERPRINT_PATTERN.test(contentFingerprint)) errors.push('CONTENT_FINGERPRINT_INVALID');
  if (!isPositiveInteger(packageSchemaVersion)) errors.push('PACKAGE_SCHEMA_VERSION_INVALID');

  if (errors.length) return { ok: false, errors, claim: null };
  return {
    ok: true,
    errors: [],
    claim: Object.freeze({
      character_id: characterId,
      content_fingerprint: contentFingerprint,
      package_schema_version: packageSchemaVersion
    })
  };
}

export function validateAuthorityAdmission(rawAdmission, claim) {
  const errors = [];
  if (!rawAdmission || rawAdmission.accepted !== true) {
    errors.push('AUTHORITY_ADMISSION_REJECTED');
    return { ok: false, errors, authority: null };
  }

  const authority = rawAdmission.authority;
  if (!exactKeys(authority, AUTHORITY_SUMMARY_KEYS)) {
    errors.push('AUTHORITY_SUMMARY_FIELDS_INVALID');
    return { ok: false, errors, authority: null };
  }

  const normalized = {
    protocol_version: Number(authority.protocol_version),
    authority_policy: String(authority.authority_policy ?? '').trim(),
    character_id: String(authority.character_id ?? '').trim(),
    content_fingerprint: String(authority.content_fingerprint ?? '').trim().toLowerCase(),
    package_schema_version: Number(authority.package_schema_version),
    ruleset_id: String(authority.ruleset_id ?? '').trim(),
    ruleset_version: Number(authority.ruleset_version),
    power_budget_id: String(authority.power_budget_id ?? '').trim()
  };

  if (normalized.protocol_version !== PVP_PROTOCOL_VERSION) errors.push('PROTOCOL_VERSION_MISMATCH');
  if (normalized.authority_policy !== PVP_AUTHORITY_POLICY) errors.push('AUTHORITY_POLICY_INVALID');
  if (normalized.character_id !== claim.character_id) errors.push('AUTHORITY_CHARACTER_MISMATCH');
  if (normalized.content_fingerprint !== claim.content_fingerprint) errors.push('AUTHORITY_FINGERPRINT_MISMATCH');
  if (normalized.package_schema_version !== claim.package_schema_version) errors.push('AUTHORITY_PACKAGE_SCHEMA_MISMATCH');
  if (!normalized.ruleset_id) errors.push('AUTHORITY_RULESET_ID_MISSING');
  if (!isPositiveInteger(normalized.ruleset_version)) errors.push('AUTHORITY_RULESET_VERSION_INVALID');
  if (!normalized.power_budget_id) errors.push('AUTHORITY_POWER_BUDGET_ID_MISSING');

  if (errors.length) return { ok: false, errors, authority: null };
  return { ok: true, errors: [], authority: Object.freeze(normalized) };
}

export function authorityCompatibilityKey(authority) {
  return [
    authority.protocol_version,
    authority.authority_policy,
    authority.package_schema_version,
    authority.ruleset_id,
    authority.ruleset_version,
    authority.power_budget_id
  ].join('|');
}
