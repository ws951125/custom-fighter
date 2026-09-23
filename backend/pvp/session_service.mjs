import {
  MAX_PVP_PARTICIPANTS,
  authorityCompatibilityKey,
  normalizeClientId,
  validateAuthorityAdmission,
  validateLoadoutClaim
} from './protocol.mjs';

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

export function createPvpSessionService({ admitLoadout, idFactory } = {}) {
  if (typeof admitLoadout !== 'function') {
    throw new TypeError('admitLoadout must be a server-owned function');
  }

  let lobbySequence = 0;
  let matchSequence = 0;
  const lobbies = new Map();

  const nextId = typeof idFactory === 'function'
    ? idFactory
    : kind => {
        if (kind === 'match') {
          matchSequence += 1;
          return `match_${String(matchSequence).padStart(6, '0')}`;
        }
        lobbySequence += 1;
        return `lobby_${String(lobbySequence).padStart(6, '0')}`;
      };

  function fail(code, extra = {}) {
    return { ok: false, code, ...extra };
  }

  function publicLobby(lobby) {
    return clone({
      lobby_id: lobby.lobby_id,
      host_client_id: lobby.host_client_id,
      status: lobby.status,
      revision: lobby.revision,
      match_id: lobby.match_id,
      participants: lobby.participants.map(participant => ({
        client_id: participant.client_id,
        ready: participant.ready,
        authority: participant.authority
      }))
    });
  }

  function findLobby(lobbyId) {
    return lobbies.get(String(lobbyId ?? '').trim()) ?? null;
  }

  function findParticipant(lobby, clientId) {
    return lobby.participants.find(participant => participant.client_id === clientId) ?? null;
  }

  function requireMutableLobby(lobby) {
    if (!lobby) return fail('LOBBY_NOT_FOUND');
    if (lobby.status !== 'waiting') return fail('LOBBY_NOT_MUTABLE');
    return null;
  }

  function createLobby({ client_id } = {}) {
    const clientId = normalizeClientId(client_id);
    if (!clientId) return fail('CLIENT_ID_INVALID');

    const lobby = {
      lobby_id: nextId('lobby'),
      host_client_id: clientId,
      status: 'waiting',
      revision: 1,
      match_id: '',
      participants: [{
        client_id: clientId,
        ready: false,
        authority: null
      }]
    };
    lobbies.set(lobby.lobby_id, lobby);
    return { ok: true, lobby: publicLobby(lobby) };
  }

  function joinLobby(lobbyId, { client_id } = {}) {
    const lobby = findLobby(lobbyId);
    const mutableError = requireMutableLobby(lobby);
    if (mutableError) return mutableError;

    const clientId = normalizeClientId(client_id);
    if (!clientId) return fail('CLIENT_ID_INVALID');

    const existing = findParticipant(lobby, clientId);
    if (existing) return { ok: true, lobby: publicLobby(lobby) };
    if (lobby.participants.length >= MAX_PVP_PARTICIPANTS) return fail('LOBBY_FULL');

    lobby.participants.push({
      client_id: clientId,
      ready: false,
      authority: null
    });
    lobby.revision += 1;
    return { ok: true, lobby: publicLobby(lobby) };
  }

  async function negotiateLoadout(lobbyId, clientIdValue, rawClaim) {
    const lobby = findLobby(lobbyId);
    const mutableError = requireMutableLobby(lobby);
    if (mutableError) return mutableError;

    const clientId = normalizeClientId(clientIdValue);
    if (!clientId) return fail('CLIENT_ID_INVALID');
    const participant = findParticipant(lobby, clientId);
    if (!participant) return fail('CLIENT_NOT_IN_LOBBY');

    const validation = validateLoadoutClaim(rawClaim);
    if (!validation.ok) return fail('LOADOUT_CLAIM_INVALID', { errors: validation.errors });

    const claim = validation.claim;
    const admission = await admitLoadout(clone(claim));
    const authorityValidation = validateAuthorityAdmission(admission, claim);
    if (!authorityValidation.ok) {
      participant.ready = false;
      participant.authority = null;
      lobby.revision += 1;
      return fail('LOADOUT_AUTHORITY_REJECTED', { errors: authorityValidation.errors });
    }

    if (lobby.status !== 'waiting' || !findParticipant(lobby, clientId)) {
      return fail('LOBBY_CHANGED_DURING_ADMISSION');
    }

    participant.ready = false;
    participant.authority = clone(authorityValidation.authority);
    lobby.revision += 1;
    return {
      ok: true,
      authority: clone(participant.authority),
      lobby: publicLobby(lobby)
    };
  }

  function setReady(lobbyId, clientIdValue, readyValue) {
    const lobby = findLobby(lobbyId);
    const mutableError = requireMutableLobby(lobby);
    if (mutableError) return mutableError;

    const clientId = normalizeClientId(clientIdValue);
    if (!clientId) return fail('CLIENT_ID_INVALID');
    const participant = findParticipant(lobby, clientId);
    if (!participant) return fail('CLIENT_NOT_IN_LOBBY');

    const ready = readyValue === true;
    if (ready && !participant.authority) return fail('LOADOUT_NOT_ADMITTED');

    participant.ready = ready;
    lobby.revision += 1;
    return { ok: true, lobby: publicLobby(lobby) };
  }

  function startMatch(lobbyId, requesterClientIdValue) {
    const lobby = findLobby(lobbyId);
    const mutableError = requireMutableLobby(lobby);
    if (mutableError) return mutableError;

    const requesterClientId = normalizeClientId(requesterClientIdValue);
    if (!requesterClientId) return fail('CLIENT_ID_INVALID');
    if (requesterClientId !== lobby.host_client_id) return fail('HOST_REQUIRED');
    if (lobby.participants.length !== MAX_PVP_PARTICIPANTS) return fail('TWO_PLAYERS_REQUIRED');
    if (lobby.participants.some(participant => !participant.authority)) return fail('LOADOUT_NOT_ADMITTED');
    if (lobby.participants.some(participant => !participant.ready)) return fail('PLAYERS_NOT_READY');

    const compatibility = new Set(
      lobby.participants.map(participant => authorityCompatibilityKey(participant.authority))
    );
    if (compatibility.size !== 1) return fail('AUTHORITY_CONTRACT_MISMATCH');

    lobby.status = 'active';
    lobby.match_id = nextId('match');
    lobby.revision += 1;
    return {
      ok: true,
      match: clone({
        match_id: lobby.match_id,
        lobby_id: lobby.lobby_id,
        status: 'active',
        authority_contract: authorityCompatibilityKey(lobby.participants[0].authority),
        participants: lobby.participants.map(participant => ({
          client_id: participant.client_id,
          authority: participant.authority
        }))
      }),
      lobby: publicLobby(lobby)
    };
  }

  function getLobby(lobbyId) {
    const lobby = findLobby(lobbyId);
    return lobby ? { ok: true, lobby: publicLobby(lobby) } : fail('LOBBY_NOT_FOUND');
  }

  return Object.freeze({
    createLobby,
    joinLobby,
    negotiateLoadout,
    setReady,
    startMatch,
    getLobby
  });
}
