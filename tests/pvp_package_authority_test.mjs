import assert from 'node:assert/strict';
import {
  createServerPackageAuthority,
  createServerPackageAuthorityStore,
  _test
} from '../backend/pvp/package_authority.mjs';

const EMBER='56451d3bdf1c7bf74852a3620894667730ddb088f350eb598badfa74c6d3c28e';
const STORM='5822c6cfb4737c29007f2450a598c501b79c17d8ed9a432e4327976cc6a7026e';

const authority=createServerPackageAuthority();
assert.equal((await authority({character_id:'ember_vanguard_001',content_fingerprint:EMBER,package_schema_version:1})).accepted,true);
assert.equal((await authority({character_id:'ember_vanguard_001',content_fingerprint:'0'.repeat(64),package_schema_version:1})).code,'CONTENT_FINGERPRINT_MISMATCH');
assert.equal((await authority({character_id:'ember_vanguard_001',content_fingerprint:EMBER,package_schema_version:2})).code,'PACKAGE_SCHEMA_UNSUPPORTED');
assert.equal((await authority({character_id:'unknown_001',content_fingerprint:'a'.repeat(64),package_schema_version:1})).code,'PACKAGE_NOT_FOUND');

const builtinStore=createServerPackageAuthorityStore();
const emberAdmission=await builtinStore.admitLoadout({character_id:'ember_vanguard_001',content_fingerprint:EMBER,package_schema_version:1});
const stormAdmission=await builtinStore.admitLoadout({character_id:'storm_duelist_001',content_fingerprint:STORM,package_schema_version:1});
assert.deepEqual(builtinStore.resolveLoadout(emberAdmission.authority),{max_hp:100,max_mp:100});
assert.deepEqual(builtinStore.resolveLoadout(stormAdmission.authority),{max_hp:90,max_mp:120});
assert.equal(builtinStore.resolveLoadout({...emberAdmission.authority,content_fingerprint:STORM}),null);

const pkg={
 schema_version:1,ruleset_id:'competitive_standard',ruleset_version:1,power_budget_id:'competitive_standard_v1',
 character:{id:'custom_001',stats:{max_hp:100,max_mp:100,move_speed:220,depth_speed:1,run_multiplier:1.5,guard_move_multiplier:0.5},skill_slots:{skill_1:'bolt_001'}},
 skills:[{id:'bolt_001',type:'projectile',damage:18,mp_cost:20,cooldown:1.8}]
};
const fp=_test.fingerprint(pkg);
const customStore=createServerPackageAuthorityStore({packageResolver:async id=>id==='custom_001'?structuredClone(pkg):null});
const accepted=await customStore.admitLoadout({character_id:'custom_001',content_fingerprint:fp,package_schema_version:1});
assert.equal(accepted.accepted,true);
assert.equal(accepted.authority.content_fingerprint,fp);
assert.equal('damage' in accepted.authority,false);
assert.equal('cooldown' in accepted.authority,false);
assert.deepEqual(customStore.resolveLoadout(accepted.authority),{max_hp:100,max_mp:100});
const resolvedCopy=customStore.resolveLoadout(accepted.authority);
resolvedCopy.max_hp=1;
assert.deepEqual(customStore.resolveLoadout(accepted.authority),{max_hp:100,max_mp:100});

const forged=structuredClone(pkg); forged.skills[0].damage=999;
const forgedFp=_test.fingerprint(forged);
const forgedAuthority=createServerPackageAuthority({packageResolver:async()=>forged});
assert.equal((await forgedAuthority({character_id:'custom_001',content_fingerprint:forgedFp,package_schema_version:1})).code,'SKILL_DAMAGE_OUT_OF_BOUNDS');

const extra=structuredClone(pkg); extra.character.stats.cheat=1;
assert.equal(_test.validateCustomPackage(extra).code,'CHARACTER_STATS_FIELDS_INVALID');
const badType=structuredClone(pkg); badType.skills[0].type='arbitrary_script';
assert.equal(_test.validateCustomPackage(badType).code,'SKILL_TYPE_UNSUPPORTED');
const badRules=structuredClone(pkg); badRules.ruleset_version=2;
assert.equal(_test.validateCustomPackage(badRules).code,'RULESET_UNSUPPORTED');
const missingSkill=structuredClone(pkg); missingSkill.character.skill_slots.skill_2='missing_001';
assert.equal(_test.validateCustomPackage(missingSkill).code,'SKILL_SLOT_RESOLUTION_FAILED');
console.log('PVP_PACKAGE_AUTHORITY_TESTS_PASSED');
