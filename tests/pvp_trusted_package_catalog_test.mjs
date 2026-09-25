import assert from 'node:assert/strict';
import { createServerPackageAuthorityStore, _test as authorityTest } from '../backend/pvp/package_authority.mjs';
import {
  TRUSTED_COMPETITIVE_CUSTOM_FINGERPRINTS,
  listTrustedCompetitivePackages,
  resolveTrustedCompetitivePackage
} from '../backend/pvp/trusted_package_catalog.mjs';

const expectedIds=['creator_blaze_001','creator_frost_001'];
const catalog=listTrustedCompetitivePackages();
assert.deepEqual(catalog.map(item=>item.character_id),expectedIds);

for(const entry of catalog){
  const pkg=await resolveTrustedCompetitivePackage(entry.character_id);
  assert.ok(pkg);
  assert.equal(pkg.character.id,entry.character_id);
  assert.equal(authorityTest.fingerprint(pkg),entry.content_fingerprint);
  assert.equal(entry.content_fingerprint,TRUSTED_COMPETITIVE_CUSTOM_FINGERPRINTS[entry.character_id]);

  const mutated=structuredClone(pkg);
  mutated.character.stats.max_hp=1;
  const fresh=await resolveTrustedCompetitivePackage(entry.character_id);
  assert.notEqual(fresh.character.stats.max_hp,1);
}
assert.equal(await resolveTrustedCompetitivePackage('unknown_custom_001'),null);

const store=createServerPackageAuthorityStore({packageResolver:resolveTrustedCompetitivePackage});
const blaze=await store.admitLoadout({
  character_id:'creator_blaze_001',
  content_fingerprint:TRUSTED_COMPETITIVE_CUSTOM_FINGERPRINTS.creator_blaze_001,
  package_schema_version:1
});
const frost=await store.admitLoadout({
  character_id:'creator_frost_001',
  content_fingerprint:TRUSTED_COMPETITIVE_CUSTOM_FINGERPRINTS.creator_frost_001,
  package_schema_version:1
});
assert.equal(blaze.accepted,true);
assert.equal(frost.accepted,true);
assert.deepEqual(store.resolveLoadout(blaze.authority),{max_hp:100,max_mp:90});
assert.deepEqual(store.resolveLoadout(frost.authority),{max_hp:90,max_mp:110});

const forgedPackage=await resolveTrustedCompetitivePackage('creator_blaze_001');
forgedPackage.skills[0].damage=60;
const forgedFingerprint=authorityTest.fingerprint(forgedPackage);
const rejected=await store.admitLoadout({
  character_id:'creator_blaze_001',
  content_fingerprint:forgedFingerprint,
  package_schema_version:1
});
assert.equal(rejected.accepted,false);
assert.equal(rejected.code,'CONTENT_FINGERPRINT_MISMATCH');

console.log('PVP_TRUSTED_PACKAGE_CATALOG_TESTS_PASSED');
