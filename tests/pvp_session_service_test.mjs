import assert from 'node:assert/strict';
import {
  PVP_AUTHORITY_POLICY,
  PVP_PROTOCOL_VERSION
} from '../backend/pvp/protocol.mjs';
import { createPvpSessionService } from '../backend/pvp/session_service.mjs';

const EMBER = '56451d3bdf1c7bf74852a3620894667730ddb088f350eb598badfa74c6d3c28e';
const STORM = '5822c6cfb4737c29007f2450a598c501b79c17d8ed9a432e4327976cc6a7026e';

const authorityCalls = [];
const service = createPvpSessionService({
  admitLoadout: async claim => {
    authorityCalls.push(structuredClone(claim));
    return {
      accepted: true,
      authority: {
        protocol_version: PVP_PROTOCOL_VERSION,
        authority_policy: PVP_AUTHORITY_POLICY,
        character_id: claim.character_id,
        content_fingerprint: claim.content_fingerprint,
        package_schema_version: claim.package_schema_version,
        ruleset_id: 'competitive_standard',
        ruleset_version: 1,
        power_budget_id: 'competitive_standard_v1'
      }
    };
  }
});

const created = service.createLobby({ client_id: 'client_host' });
assert.equal(created.ok, true);
assert.equal(created.lobby.status, 'waiting');
assert.equal(created.lobby.participants.length, 1);
const lobbyId = created.lobby.lobby_id;

const joined = service.joinLobby(lobbyId, { client_id: 'client_guest' });
assert.equal(joined.ok, true);
assert.equal(joined.lobby.participants.length, 2);
assert.equal(service.joinLobby(lobbyId, { client_id: 'client_third' }).code, 'LOBBY_FULL');

const prematureReady = service.setReady(lobbyId, 'client_host', true);
assert.equal(prematureReady.ok, false);
assert.equal(prematureReady.code, 'LOADOUT_NOT_ADMITTED');

const forgedClaim = await service.negotiateLoadout(lobbyId, 'client_host', {
  character_id: 'ember_vanguard_001',
  content_fingerprint: EMBER,
  package_schema_version: 1,
  damage: 999999,
  cooldown: 0
});
assert.equal(forgedClaim.ok, false);
assert.equal(forgedClaim.code, 'LOADOUT_CLAIM_INVALID');
assert.deepEqual(forgedClaim.errors, ['LOADOUT_CLAIM_FIELDS_INVALID']);
assert.equal(authorityCalls.length, 0);

const hostAdmission = await service.negotiateLoadout(lobbyId, 'client_host', {
  character_id: 'ember_vanguard_001',
  content_fingerprint: EMBER,
  package_schema_version: 1
});
assert.equal(hostAdmission.ok, true);
assert.equal(authorityCalls.length, 1);
assert.deepEqual(Object.keys(authorityCalls[0]).sort(), [
  'character_id',
  'content_fingerprint',
  'package_schema_version'
]);

const guestAdmission = await service.negotiateLoadout(lobbyId, 'client_guest', {
  character_id: 'storm_duelist_001',
  content_fingerprint: STORM,
  package_schema_version: 1
});
assert.equal(guestAdmission.ok, true);
assert.equal(authorityCalls.length, 2);

assert.equal(service.setReady(lobbyId, 'client_host', true).ok, true);
assert.equal(service.setReady(lobbyId, 'client_guest', true).ok, true);
assert.equal(service.startMatch(lobbyId, 'client_guest').code, 'HOST_REQUIRED');

const started = service.startMatch(lobbyId, 'client_host');
assert.equal(started.ok, true);
assert.equal(started.match.status, 'active');
assert.equal(started.match.participants.length, 2);
assert.equal(started.match.participants[0].authority.content_fingerprint, EMBER);
assert.equal(started.match.participants[1].authority.content_fingerprint, STORM);
assert.equal('damage' in started.match.participants[0].authority, false);
assert.equal('cooldown' in started.match.participants[0].authority, false);

started.match.participants[0].authority.character_id = 'tampered';
const afterMutation = service.getLobby(lobbyId);
assert.equal(afterMutation.lobby.participants[0].authority.character_id, 'ember_vanguard_001');
assert.equal(service.setReady(lobbyId, 'client_host', false).code, 'LOBBY_NOT_MUTABLE');
assert.equal(service.joinLobby(lobbyId, { client_id: 'late_client' }).code, 'LOBBY_NOT_MUTABLE');

const mismatchService = createPvpSessionService({
  admitLoadout: async claim => ({
    accepted: true,
    authority: {
      protocol_version: PVP_PROTOCOL_VERSION,
      authority_policy: PVP_AUTHORITY_POLICY,
      character_id: claim.character_id,
      content_fingerprint: claim.content_fingerprint,
      package_schema_version: claim.package_schema_version,
      ruleset_id: claim.character_id === 'ember_vanguard_001' ? 'competitive_standard' : 'future_ruleset',
      ruleset_version: 1,
      power_budget_id: 'competitive_standard_v1'
    }
  })
});
const mismatchLobby = mismatchService.createLobby({ client_id: 'host2' }).lobby.lobby_id;
mismatchService.joinLobby(mismatchLobby, { client_id: 'guest2' });
await mismatchService.negotiateLoadout(mismatchLobby, 'host2', {
  character_id: 'ember_vanguard_001',
  content_fingerprint: EMBER,
  package_schema_version: 1
});
await mismatchService.negotiateLoadout(mismatchLobby, 'guest2', {
  character_id: 'storm_duelist_001',
  content_fingerprint: STORM,
  package_schema_version: 1
});
mismatchService.setReady(mismatchLobby, 'host2', true);
mismatchService.setReady(mismatchLobby, 'guest2', true);
assert.equal(mismatchService.startMatch(mismatchLobby, 'host2').code, 'AUTHORITY_CONTRACT_MISMATCH');

const fingerprintMismatchService = createPvpSessionService({
  admitLoadout: async claim => ({
    accepted: true,
    authority: {
      protocol_version: PVP_PROTOCOL_VERSION,
      authority_policy: PVP_AUTHORITY_POLICY,
      character_id: claim.character_id,
      content_fingerprint: STORM,
      package_schema_version: claim.package_schema_version,
      ruleset_id: 'competitive_standard',
      ruleset_version: 1,
      power_budget_id: 'competitive_standard_v1'
    }
  })
});
const badLobby = fingerprintMismatchService.createLobby({ client_id: 'host3' }).lobby.lobby_id;
const badAdmission = await fingerprintMismatchService.negotiateLoadout(badLobby, 'host3', {
  character_id: 'ember_vanguard_001',
  content_fingerprint: EMBER,
  package_schema_version: 1
});
assert.equal(badAdmission.ok, false);
assert.equal(badAdmission.code, 'LOADOUT_AUTHORITY_REJECTED');
assert.equal(badAdmission.errors.includes('AUTHORITY_FINGERPRINT_MISMATCH'), true);

const throwingService = createPvpSessionService({
  admitLoadout: async () => {
    throw new Error('authority unavailable');
  }
});
const throwingLobby = throwingService.createLobby({ client_id: 'host4' }).lobby.lobby_id;
const adapterFailure = await throwingService.negotiateLoadout(throwingLobby, 'host4', {
  character_id: 'ember_vanguard_001',
  content_fingerprint: EMBER,
  package_schema_version: 1
});
assert.equal(adapterFailure.ok, false);
assert.equal(adapterFailure.code, 'AUTHORITY_ADMISSION_ERROR');
assert.equal(throwingService.getLobby(throwingLobby).lobby.participants[0].authority, null);
assert.equal(throwingService.setReady(throwingLobby, 'host4', true).code, 'LOADOUT_NOT_ADMITTED');

console.log('PVP_SESSION_SERVICE_TESTS_PASSED');
