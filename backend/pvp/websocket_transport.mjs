import crypto from 'node:crypto';
import { WebSocketServer } from 'ws';
import { PVP_PROTOCOL_VERSION, normalizeClientId } from './protocol.mjs';

const OPEN = 1;
const MAX_MESSAGE_BYTES = 64 * 1024;
const LOBBY_ID_PATTERN = /^[A-Za-z0-9_.:-]{1,128}$/;
const MATCH_ID_PATTERN = /^[A-Za-z0-9_.:-]{1,128}$/;

const MESSAGE_KEYS = Object.freeze({
  hello: new Set(['type','protocol_version','client_id']),
  create_lobby: new Set(['type','connection_token']),
  join_lobby: new Set(['type','connection_token','lobby_id']),
  negotiate_loadout: new Set(['type','connection_token','lobby_id','claim']),
  set_ready: new Set(['type','connection_token','lobby_id','ready']),
  start_match: new Set(['type','connection_token','lobby_id']),
  input: new Set(['type','connection_token','match_id','input']),
  request_state: new Set(['type','connection_token','match_id'])
});

function exactKeys(value, allowed) {
  return value && typeof value === 'object' && !Array.isArray(value) && Object.keys(value).every(key => allowed.has(key));
}

function safeSend(ws, message) {
  if (ws.readyState !== OPEN) return false;
  ws.send(JSON.stringify(message));
  return true;
}

function errorMessage(requestType, code, extra = {}) {
  return { type:'error', request_type:String(requestType || ''), code, ...extra };
}

function normalizeId(value, pattern) {
  const text = String(value ?? '').trim();
  return pattern.test(text) ? text : '';
}

export function createPvpWebSocketTransport({
  sessionService,
  createMatch,
  resolveLoadout,
  tickIntervalMs = 1000 / 60,
  setIntervalFn = setInterval,
  clearIntervalFn = clearInterval
} = {}) {
  if (!sessionService) throw new TypeError('sessionService required');
  if (typeof createMatch !== 'function') throw new TypeError('createMatch required');
  if (typeof resolveLoadout !== 'function') throw new TypeError('resolveLoadout required');

  const states = new Map();
  const clientSockets = new Map();
  const lobbySockets = new Map();
  const matches = new Map();

  function stateFor(ws) {
    return states.get(ws) ?? null;
  }

  function sendError(ws, requestType, code, extra = {}) {
    safeSend(ws, errorMessage(requestType, code, extra));
  }

  function requireBoundConnection(ws, raw) {
    const state = stateFor(ws);
    if (!state?.client_id) {
      sendError(ws, raw?.type, 'HELLO_REQUIRED');
      return null;
    }
    if (String(raw?.connection_token ?? '') !== state.connection_token) {
      sendError(ws, raw?.type, 'CONNECTION_AUTH_INVALID');
      return null;
    }
    return state;
  }

  function attachLobby(ws, lobbyId) {
    const state = stateFor(ws);
    if (!state) return false;
    if (state.lobby_id && state.lobby_id !== lobbyId) {
      sendError(ws, 'join_lobby', 'CONNECTION_ALREADY_IN_LOBBY');
      return false;
    }
    state.lobby_id = lobbyId;
    if (!lobbySockets.has(lobbyId)) lobbySockets.set(lobbyId, new Set());
    lobbySockets.get(lobbyId).add(ws);
    return true;
  }

  function broadcastLobby(lobbyId) {
    const result = sessionService.getLobby(lobbyId);
    if (!result.ok) return;
    for (const ws of lobbySockets.get(lobbyId) ?? []) {
      safeSend(ws, { type:'lobby_state', lobby:result.lobby });
    }
  }

  function broadcastMatchState(lobbyId, snapshot) {
    for (const ws of lobbySockets.get(lobbyId) ?? []) {
      safeSend(ws, { type:'match_state', state:snapshot });
    }
  }

  function startMatchLoop(matchId) {
    const entry = matches.get(matchId);
    if (!entry || entry.timer) return;
    entry.timer = setIntervalFn(() => {
      const snapshot = entry.sim.step();
      broadcastMatchState(entry.lobby_id, snapshot);
      if (snapshot.status === 'finished' && entry.timer) {
        clearIntervalFn(entry.timer);
        entry.timer = null;
      }
    }, tickIntervalMs);
    entry.timer?.unref?.();
  }

  function preflightLoadouts(lobbyId) {
    const result = sessionService.getLobby(lobbyId);
    if (!result.ok) return result;
    for (const participant of result.lobby.participants) {
      if (!participant.authority || !resolveLoadout(participant.authority)) {
        return { ok:false, code:'AUTHORITATIVE_LOADOUT_UNAVAILABLE' };
      }
    }
    return { ok:true };
  }

  async function handleMessage(ws, data) {
    if (Buffer.byteLength(data) > MAX_MESSAGE_BYTES) {
      sendError(ws, '', 'MESSAGE_TOO_LARGE');
      return;
    }

    let raw;
    try {
      raw = JSON.parse(String(data));
    } catch {
      sendError(ws, '', 'MESSAGE_JSON_INVALID');
      return;
    }
    if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
      sendError(ws, '', 'MESSAGE_INVALID');
      return;
    }

    const type = String(raw.type ?? '').trim();
    const allowed = MESSAGE_KEYS[type];
    if (!allowed) {
      sendError(ws, type, 'MESSAGE_TYPE_UNSUPPORTED');
      return;
    }
    if (!exactKeys(raw, allowed)) {
      sendError(ws, type, 'MESSAGE_FIELDS_INVALID');
      return;
    }

    if (type === 'hello') {
      const state = stateFor(ws);
      if (!state || state.client_id) {
        sendError(ws, type, 'CONNECTION_ALREADY_BOUND');
        return;
      }
      if (Number(raw.protocol_version) !== PVP_PROTOCOL_VERSION) {
        sendError(ws, type, 'PROTOCOL_VERSION_MISMATCH', { protocol_version:PVP_PROTOCOL_VERSION });
        return;
      }
      const clientId = normalizeClientId(raw.client_id);
      if (!clientId) {
        sendError(ws, type, 'CLIENT_ID_INVALID');
        return;
      }
      const existing = clientSockets.get(clientId);
      if (existing && existing !== ws && existing.readyState === OPEN) {
        sendError(ws, type, 'CLIENT_ALREADY_CONNECTED');
        ws.close(1008, 'client already connected');
        return;
      }
      state.client_id = clientId;
      state.connection_token = crypto.randomUUID();
      clientSockets.set(clientId, ws);
      safeSend(ws, {
        type:'hello_ok',
        protocol_version:PVP_PROTOCOL_VERSION,
        client_id:clientId,
        connection_id:state.connection_id,
        connection_token:state.connection_token
      });
      return;
    }

    const state = requireBoundConnection(ws, raw);
    if (!state) return;

    if (type === 'create_lobby') {
      if (state.lobby_id) {
        sendError(ws, type, 'CONNECTION_ALREADY_IN_LOBBY');
        return;
      }
      const result = sessionService.createLobby({ client_id:state.client_id });
      if (!result.ok) {
        sendError(ws, type, result.code);
        return;
      }
      if (!attachLobby(ws, result.lobby.lobby_id)) return;
      broadcastLobby(result.lobby.lobby_id);
      return;
    }

    if (type === 'join_lobby') {
      const lobbyId = normalizeId(raw.lobby_id, LOBBY_ID_PATTERN);
      if (!lobbyId) {
        sendError(ws, type, 'LOBBY_ID_INVALID');
        return;
      }
      const result = sessionService.joinLobby(lobbyId, { client_id:state.client_id });
      if (!result.ok) {
        sendError(ws, type, result.code);
        return;
      }
      if (!attachLobby(ws, lobbyId)) return;
      broadcastLobby(lobbyId);
      return;
    }

    if (type === 'negotiate_loadout') {
      const lobbyId = normalizeId(raw.lobby_id, LOBBY_ID_PATTERN);
      if (!lobbyId || state.lobby_id !== lobbyId) {
        sendError(ws, type, 'LOBBY_BINDING_REQUIRED');
        return;
      }
      const result = await sessionService.negotiateLoadout(lobbyId, state.client_id, raw.claim);
      if (!result.ok) {
        sendError(ws, type, result.code, result.errors ? { errors:result.errors } : {});
        return;
      }
      safeSend(ws, { type:'authority_admitted', authority:result.authority });
      broadcastLobby(lobbyId);
      return;
    }

    if (type === 'set_ready') {
      const lobbyId = normalizeId(raw.lobby_id, LOBBY_ID_PATTERN);
      if (!lobbyId || state.lobby_id !== lobbyId) {
        sendError(ws, type, 'LOBBY_BINDING_REQUIRED');
        return;
      }
      const result = sessionService.setReady(lobbyId, state.client_id, raw.ready === true);
      if (!result.ok) {
        sendError(ws, type, result.code);
        return;
      }
      broadcastLobby(lobbyId);
      return;
    }

    if (type === 'start_match') {
      const lobbyId = normalizeId(raw.lobby_id, LOBBY_ID_PATTERN);
      if (!lobbyId || state.lobby_id !== lobbyId) {
        sendError(ws, type, 'LOBBY_BINDING_REQUIRED');
        return;
      }
      const preflight = preflightLoadouts(lobbyId);
      if (!preflight.ok) {
        sendError(ws, type, preflight.code);
        return;
      }
      const result = sessionService.startMatch(lobbyId, state.client_id);
      if (!result.ok) {
        sendError(ws, type, result.code);
        return;
      }

      let sim;
      try {
        sim = createMatch({ match:result.match, loadoutResolver:resolveLoadout });
      } catch {
        sendError(ws, type, 'MATCH_AUTHORITY_INIT_FAILED');
        return;
      }
      matches.set(result.match.match_id, { sim, lobby_id:lobbyId, timer:null });
      for (const peer of lobbySockets.get(lobbyId) ?? []) {
        safeSend(peer, { type:'match_started', match:result.match });
      }
      broadcastMatchState(lobbyId, sim.snapshot());
      startMatchLoop(result.match.match_id);
      return;
    }

    if (type === 'input') {
      const matchId = normalizeId(raw.match_id, MATCH_ID_PATTERN);
      const entry = matches.get(matchId);
      if (!matchId || !entry) {
        sendError(ws, type, 'MATCH_NOT_FOUND');
        return;
      }
      if (state.lobby_id !== entry.lobby_id) {
        sendError(ws, type, 'MATCH_BINDING_REQUIRED');
        return;
      }
      const result = entry.sim.submitInput(state.client_id, raw.input);
      if (!result.ok) {
        sendError(ws, type, result.code, 'last_sequence' in result ? { last_sequence:result.last_sequence } : {});
        return;
      }
      safeSend(ws, {
        type:'input_ack',
        match_id:matchId,
        accepted_sequence:result.accepted_sequence,
        target_tick:result.target_tick
      });
      return;
    }

    if (type === 'request_state') {
      const matchId = normalizeId(raw.match_id, MATCH_ID_PATTERN);
      const entry = matches.get(matchId);
      if (!matchId || !entry) {
        sendError(ws, type, 'MATCH_NOT_FOUND');
        return;
      }
      if (state.lobby_id !== entry.lobby_id) {
        sendError(ws, type, 'MATCH_BINDING_REQUIRED');
        return;
      }
      safeSend(ws, { type:'match_state', state:entry.sim.snapshot() });
    }
  }

  function accept(ws) {
    const state = {
      connection_id: crypto.randomUUID(),
      connection_token: '',
      client_id: '',
      lobby_id: ''
    };
    states.set(ws, state);

    let chain = Promise.resolve();
    ws.on('message', data => {
      chain = chain
        .then(() => handleMessage(ws, data))
        .catch(() => sendError(ws, '', 'TRANSPORT_INTERNAL_ERROR'));
    });

    ws.on('close', () => {
      const current = states.get(ws);
      if (current?.client_id && clientSockets.get(current.client_id) === ws) {
        clientSockets.delete(current.client_id);
      }
      if (current?.lobby_id) {
        const peers = lobbySockets.get(current.lobby_id);
        peers?.delete(ws);
        if (peers?.size === 0) lobbySockets.delete(current.lobby_id);
      }
      states.delete(ws);
    });
  }

  function close() {
    for (const entry of matches.values()) {
      if (entry.timer) clearIntervalFn(entry.timer);
      entry.timer = null;
    }
    matches.clear();
    for (const ws of states.keys()) {
      try { ws.close(1001, 'server shutdown'); } catch {}
    }
    states.clear();
    clientSockets.clear();
    lobbySockets.clear();
  }

  return Object.freeze({ accept, close });
}

export function attachPvpWebSocketTransport(server, {
  sessionService,
  createMatch,
  resolveLoadout,
  allowedOrigin,
  path = '/v1/pvp/ws',
  tickIntervalMs = 1000 / 60
} = {}) {
  if (!server) throw new TypeError('server required');
  const expectedOrigin = String(allowedOrigin ?? '').trim();
  if (!expectedOrigin) throw new TypeError('allowedOrigin required');

  const wss = new WebSocketServer({ noServer:true, maxPayload:MAX_MESSAGE_BYTES });
  const transport = createPvpWebSocketTransport({
    sessionService,
    createMatch,
    resolveLoadout,
    tickIntervalMs
  });

  const onUpgrade = (request, socket, head) => {
    let pathname = '';
    try {
      pathname = new URL(request.url ?? '/', 'http://localhost').pathname;
    } catch {
      socket.destroy();
      return;
    }
    if (pathname !== path) {
      socket.destroy();
      return;
    }
    const origin = String(request.headers.origin ?? '');
    if (origin !== expectedOrigin) {
      socket.write('HTTP/1.1 403 Forbidden\r\nConnection: close\r\nContent-Length: 0\r\n\r\n');
      socket.destroy();
      return;
    }
    wss.handleUpgrade(request, socket, head, ws => transport.accept(ws));
  };

  server.on('upgrade', onUpgrade);
  server.once('close', () => {
    server.off('upgrade', onUpgrade);
    transport.close();
  });

  return transport;
}
