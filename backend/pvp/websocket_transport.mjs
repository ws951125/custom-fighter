import crypto from 'node:crypto';
import { WebSocketServer } from 'ws';
import { PVP_PROTOCOL_VERSION, normalizeClientId } from './protocol.mjs';

const OPEN = 1;
const MAX_MESSAGE_BYTES = 64 * 1024;
const LOBBY_ID_PATTERN = /^[A-Za-z0-9_.:-]{1,128}$/;
const MATCH_ID_PATTERN = /^[A-Za-z0-9_.:-]{1,128}$/;
const NETWORK_INPUT_KEYS = new Set(['sequence','actions']);

const MESSAGE_KEYS = Object.freeze({
  hello: new Set(['type','protocol_version','client_id','reconnect_token']),
  create_lobby: new Set(['type','connection_token']),
  join_lobby: new Set(['type','connection_token','lobby_id']),
  leave_lobby: new Set(['type','connection_token','lobby_id']),
  negotiate_loadout: new Set(['type','connection_token','lobby_id','claim']),
  set_ready: new Set(['type','connection_token','lobby_id','ready']),
  start_match: new Set(['type','connection_token','lobby_id']),
  input: new Set(['type','connection_token','match_id','input']),
  request_state: new Set(['type','connection_token','match_id']),
  forfeit: new Set(['type','connection_token','match_id']),
  ping: new Set(['type','connection_token','client_time_ms'])
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
  reconnectWindowMs = 10_000,
  heartbeatTimeoutMs = 15_000,
  heartbeatCheckMs = 1_000,
  setIntervalFn = setInterval,
  clearIntervalFn = clearInterval,
  setTimeoutFn = setTimeout,
  clearTimeoutFn = clearTimeout,
  nowFn = Date.now
} = {}) {
  if (!sessionService) throw new TypeError('sessionService required');
  if (typeof createMatch !== 'function') throw new TypeError('createMatch required');
  if (typeof resolveLoadout !== 'function') throw new TypeError('resolveLoadout required');
  if (!Number.isFinite(reconnectWindowMs) || reconnectWindowMs < 100 || reconnectWindowMs > 120_000) throw new TypeError('reconnectWindowMs out of range');
  if (!Number.isFinite(heartbeatTimeoutMs) || heartbeatTimeoutMs < 500 || heartbeatTimeoutMs > 120_000) throw new TypeError('heartbeatTimeoutMs out of range');

  const states = new Map();
  const clientSockets = new Map();
  const clientSessions = new Map();
  const lobbySockets = new Map();
  const matches = new Map();
  let shuttingDown = false;

  function stateFor(ws) {
    return states.get(ws) ?? null;
  }

  function sendError(ws, requestType, code, extra = {}) {
    safeSend(ws, errorMessage(requestType, code, extra));
  }

  function clearDisconnectTimer(session) {
    if (session?.disconnect_timer) {
      clearTimeoutFn(session.disconnect_timer);
      session.disconnect_timer = null;
    }
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
    state.last_seen_at = nowFn();
    return state;
  }

  function detachLobbySocket(ws, lobbyId) {
    if (!lobbyId) return;
    const peers = lobbySockets.get(lobbyId);
    peers?.delete(ws);
    if (peers?.size === 0) lobbySockets.delete(lobbyId);
  }

  function attachLobby(ws, lobbyId) {
    const state = stateFor(ws);
    if (!state) return false;
    if (state.lobby_id && state.lobby_id !== lobbyId) {
      sendError(ws, 'join_lobby', 'CONNECTION_ALREADY_IN_LOBBY');
      return false;
    }
    state.lobby_id = lobbyId;
    const session = clientSessions.get(state.client_id);
    if (session) session.lobby_id = lobbyId;
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

  function broadcastPeerStatus(lobbyId, clientId, status, reconnectDeadlineMs = 0) {
    if (!lobbyId) return;
    for (const ws of lobbySockets.get(lobbyId) ?? []) {
      safeSend(ws, {
        type:'peer_status',
        client_id:clientId,
        status,
        reconnect_deadline_ms:reconnectDeadlineMs
      });
    }
  }

  function broadcastMatchState(lobbyId, snapshot) {
    for (const ws of lobbySockets.get(lobbyId) ?? []) {
      safeSend(ws, { type:'match_state', state:snapshot });
    }
  }

  function stopMatchLoop(entry) {
    if (entry?.timer) {
      clearIntervalFn(entry.timer);
      entry.timer = null;
    }
  }

  function finishMatchByForfeit(entry, clientId, reason) {
    if (!entry) return { ok:false, code:'MATCH_NOT_FOUND' };
    const result = entry.sim.finishByForfeit(clientId, reason);
    if (!result.ok) return result;
    stopMatchLoop(entry);
    broadcastMatchState(entry.lobby_id, result.state);
    for (const ws of lobbySockets.get(entry.lobby_id) ?? []) {
      safeSend(ws, { type:'match_finished', state:result.state });
    }
    return result;
  }

  function startMatchLoop(matchId) {
    const entry = matches.get(matchId);
    if (!entry || entry.timer) return;
    entry.timer = setIntervalFn(() => {
      const snapshot = entry.sim.step();
      broadcastMatchState(entry.lobby_id, snapshot);
      if (snapshot.status === 'finished') stopMatchLoop(entry);
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

  function scheduleDisconnectExpiry(clientId, session) {
    clearDisconnectTimer(session);
    const deadline = nowFn() + reconnectWindowMs;
    session.reconnect_deadline_at = deadline;
    session.disconnect_timer = setTimeoutFn(() => {
      const current = clientSessions.get(clientId);
      if (!current || current !== session || clientSockets.has(clientId)) return;

      if (current.match_id) {
        const entry = matches.get(current.match_id);
        const snapshot = entry?.sim.snapshot();
        if (entry && snapshot?.status === 'active') {
          finishMatchByForfeit(entry, clientId, 'disconnect_timeout');
        }
      } else if (current.lobby_id) {
        const leave = sessionService.leaveLobby(current.lobby_id, clientId);
        if (leave.ok && !leave.closed) broadcastLobby(current.lobby_id);
      }

      broadcastPeerStatus(current.lobby_id, clientId, 'disconnected', 0);
      clientSessions.delete(clientId);
    }, reconnectWindowMs);
    session.disconnect_timer?.unref?.();
    return deadline;
  }

  function bindFreshSession(ws, state, clientId) {
    const session = {
      reconnect_token: crypto.randomUUID(),
      lobby_id: '',
      match_id: '',
      reconnect_deadline_at: 0,
      disconnect_timer: null
    };
    clientSessions.set(clientId, session);
    state.client_id = clientId;
    state.connection_token = crypto.randomUUID();
    state.last_seen_at = nowFn();
    clientSockets.set(clientId, ws);
    safeSend(ws, {
      type:'hello_ok',
      protocol_version:PVP_PROTOCOL_VERSION,
      client_id:clientId,
      connection_id:state.connection_id,
      connection_token:state.connection_token,
      reconnect_token:session.reconnect_token,
      reconnect_window_ms:reconnectWindowMs,
      reconnected:false
    });
  }

  function bindReconnectSession(ws, state, clientId, session) {
    clearDisconnectTimer(session);
    session.reconnect_deadline_at = 0;
    state.client_id = clientId;
    state.connection_token = crypto.randomUUID();
    state.lobby_id = session.lobby_id;
    state.match_id = session.match_id;
    state.last_seen_at = nowFn();
    clientSockets.set(clientId, ws);

    if (state.lobby_id) {
      if (!lobbySockets.has(state.lobby_id)) lobbySockets.set(state.lobby_id, new Set());
      lobbySockets.get(state.lobby_id).add(ws);
    }

    safeSend(ws, {
      type:'hello_ok',
      protocol_version:PVP_PROTOCOL_VERSION,
      client_id:clientId,
      connection_id:state.connection_id,
      connection_token:state.connection_token,
      reconnect_token:session.reconnect_token,
      reconnect_window_ms:reconnectWindowMs,
      reconnected:true
    });

    if (state.lobby_id) {
      broadcastPeerStatus(state.lobby_id, clientId, 'connected', 0);
      const lobby = sessionService.getLobby(state.lobby_id);
      if (lobby.ok) safeSend(ws, { type:'lobby_state', lobby:lobby.lobby });
    }
    if (state.match_id) {
      const entry = matches.get(state.match_id);
      if (entry) safeSend(ws, { type:'match_state', state:entry.sim.snapshot() });
    }
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

      const existingSocket = clientSockets.get(clientId);
      if (existingSocket && existingSocket !== ws && existingSocket.readyState === OPEN) {
        sendError(ws, type, 'CLIENT_ALREADY_CONNECTED');
        ws.close(1008, 'client already connected');
        return;
      }

      const suppliedReconnectToken = String(raw.reconnect_token ?? '').trim();
      const session = clientSessions.get(clientId);
      if (!session) {
        if (suppliedReconnectToken) {
          sendError(ws, type, 'RECONNECT_SESSION_NOT_FOUND');
          return;
        }
        bindFreshSession(ws, state, clientId);
        return;
      }

      if (!suppliedReconnectToken) {
        sendError(ws, type, 'RECONNECT_TOKEN_REQUIRED');
        return;
      }
      if (suppliedReconnectToken !== session.reconnect_token) {
        sendError(ws, type, 'RECONNECT_AUTH_INVALID');
        return;
      }
      if (session.reconnect_deadline_at && nowFn() > session.reconnect_deadline_at) {
        sendError(ws, type, 'RECONNECT_WINDOW_EXPIRED');
        return;
      }
      bindReconnectSession(ws, state, clientId, session);
      return;
    }

    const state = requireBoundConnection(ws, raw);
    if (!state) return;

    if (type === 'ping') {
      if (!Number.isSafeInteger(raw.client_time_ms) || raw.client_time_ms < 0) {
        sendError(ws, type, 'PING_TIME_INVALID');
        return;
      }
      safeSend(ws, {
        type:'pong',
        client_time_ms:raw.client_time_ms,
        server_time_ms:nowFn()
      });
      return;
    }

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

    if (type === 'leave_lobby') {
      const lobbyId = normalizeId(raw.lobby_id, LOBBY_ID_PATTERN);
      if (!lobbyId || state.lobby_id !== lobbyId) {
        sendError(ws, type, 'LOBBY_BINDING_REQUIRED');
        return;
      }
      if (state.match_id) {
        sendError(ws, type, 'MATCH_ACTIVE_USE_FORFEIT');
        return;
      }
      const result = sessionService.leaveLobby(lobbyId, state.client_id);
      if (!result.ok) {
        sendError(ws, type, result.code);
        return;
      }
      detachLobbySocket(ws, lobbyId);
      state.lobby_id = '';
      const session = clientSessions.get(state.client_id);
      if (session) session.lobby_id = '';
      safeSend(ws, { type:'lobby_left', lobby_id:lobbyId, closed:result.closed === true });
      if (!result.closed) broadcastLobby(lobbyId);
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
      for (const participant of result.match.participants) {
        const session = clientSessions.get(participant.client_id);
        if (session) session.match_id = result.match.match_id;
        const peer = clientSockets.get(participant.client_id);
        const peerState = peer ? stateFor(peer) : null;
        if (peerState) peerState.match_id = result.match.match_id;
      }
      for (const peer of lobbySockets.get(lobbyId) ?? []) {
        safeSend(peer, { type:'match_started', match:result.match });
      }
      broadcastMatchState(lobbyId, sim.snapshot());
      startMatchLoop(result.match.match_id);
      return;
    }

    if (type === 'forfeit') {
      const matchId = normalizeId(raw.match_id, MATCH_ID_PATTERN);
      const entry = matches.get(matchId);
      if (!matchId || !entry) {
        sendError(ws, type, 'MATCH_NOT_FOUND');
        return;
      }
      if (state.match_id !== matchId || state.lobby_id !== entry.lobby_id) {
        sendError(ws, type, 'MATCH_BINDING_REQUIRED');
        return;
      }
      const result = finishMatchByForfeit(entry, state.client_id, 'forfeit');
      if (!result.ok) {
        sendError(ws, type, result.code);
        return;
      }
      safeSend(ws, { type:'forfeit_ack', match_id:matchId });
      return;
    }

    if (type === 'input') {
      const matchId = normalizeId(raw.match_id, MATCH_ID_PATTERN);
      const entry = matches.get(matchId);
      if (!matchId || !entry) {
        sendError(ws, type, 'MATCH_NOT_FOUND');
        return;
      }
      if (state.match_id !== matchId || state.lobby_id !== entry.lobby_id) {
        sendError(ws, type, 'MATCH_BINDING_REQUIRED');
        return;
      }
      if (!exactKeys(raw.input, NETWORK_INPUT_KEYS)) {
        sendError(ws, type, 'INPUT_INTENT_FIELDS_INVALID');
        return;
      }
      const before = entry.sim.snapshot();
      const player = before.players.find(item => item.client_id === state.client_id);
      const lastTargetTick = Number(player?.last_target_tick ?? before.tick);
      const targetTick = Math.max(before.tick + 1, lastTargetTick + 1);
      if (targetTick > before.tick + 6) {
        sendError(ws, type, 'INPUT_WINDOW_FULL');
        return;
      }
      const result = entry.sim.submitInput(state.client_id, {
        sequence: raw.input.sequence,
        target_tick:targetTick,
        actions:raw.input.actions
      });
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
      if (state.match_id !== matchId || state.lobby_id !== entry.lobby_id) {
        sendError(ws, type, 'MATCH_BINDING_REQUIRED');
        return;
      }
      safeSend(ws, { type:'match_state', state:entry.sim.snapshot() });
    }
  }

  function accept(ws) {
    const state = {
      connection_id:crypto.randomUUID(),
      connection_token:'',
      client_id:'',
      lobby_id:'',
      match_id:'',
      last_seen_at:nowFn()
    };
    states.set(ws,state);

    let chain=Promise.resolve();
    ws.on('message',data=>{
      chain=chain
        .then(()=>handleMessage(ws,data))
        .catch(()=>sendError(ws,'','TRANSPORT_INTERNAL_ERROR'));
    });

    ws.on('close',()=>{
      const current=states.get(ws);
      if (!current) return;

      const isCurrentSocket = current.client_id && clientSockets.get(current.client_id) === ws;
      if (isCurrentSocket) clientSockets.delete(current.client_id);
      detachLobbySocket(ws,current.lobby_id);
      states.delete(ws);

      if (shuttingDown || !isCurrentSocket) return;
      const session=clientSessions.get(current.client_id);
      if (!session) return;
      session.lobby_id=current.lobby_id || session.lobby_id;
      session.match_id=current.match_id || session.match_id;
      const deadline=scheduleDisconnectExpiry(current.client_id,session);
      broadcastPeerStatus(session.lobby_id,current.client_id,'reconnecting',deadline);
    });
  }

  const watchdog = setIntervalFn(()=>{
    if (shuttingDown) return;
    const now=nowFn();
    for (const [ws,state] of states.entries()) {
      if (!state.client_id || ws.readyState !== OPEN) continue;
      if (now - state.last_seen_at > heartbeatTimeoutMs) {
        try { ws.close(4001,'heartbeat timeout'); } catch {}
      }
    }
  },Math.max(100,Math.min(heartbeatCheckMs,heartbeatTimeoutMs/2)));
  watchdog?.unref?.();

  function close() {
    shuttingDown=true;
    clearIntervalFn(watchdog);
    for (const entry of matches.values()) stopMatchLoop(entry);
    matches.clear();
    for (const session of clientSessions.values()) clearDisconnectTimer(session);
    for (const ws of states.keys()) {
      try { ws.close(1001,'server shutdown'); } catch {}
    }
    states.clear();
    clientSockets.clear();
    clientSessions.clear();
    lobbySockets.clear();
  }

  return Object.freeze({accept,close});
}

export function attachPvpWebSocketTransport(server,{
  sessionService,
  createMatch,
  resolveLoadout,
  allowedOrigin,
  path='/v1/pvp/ws',
  tickIntervalMs=1000/60,
  reconnectWindowMs=10_000,
  heartbeatTimeoutMs=15_000,
  heartbeatCheckMs=1_000
}={}) {
  if (!server) throw new TypeError('server required');
  const expectedOrigin=String(allowedOrigin??'').trim();
  if (!expectedOrigin) throw new TypeError('allowedOrigin required');

  const wss=new WebSocketServer({noServer:true,maxPayload:MAX_MESSAGE_BYTES});
  const transport=createPvpWebSocketTransport({
    sessionService,
    createMatch,
    resolveLoadout,
    tickIntervalMs,
    reconnectWindowMs,
    heartbeatTimeoutMs,
    heartbeatCheckMs
  });

  const onUpgrade=(request,socket,head)=>{
    let pathname='';
    try {
      pathname=new URL(request.url??'/','http://localhost').pathname;
    } catch {
      socket.destroy();
      return;
    }
    if (pathname!==path) {
      socket.destroy();
      return;
    }
    const origin=String(request.headers.origin??'');
    if (origin!==expectedOrigin) {
      socket.write('HTTP/1.1 403 Forbidden\r\nConnection: close\r\nContent-Length: 0\r\n\r\n');
      socket.destroy();
      return;
    }
    wss.handleUpgrade(request,socket,head,ws=>transport.accept(ws));
  };

  server.on('upgrade',onUpgrade);
  server.once('close',()=>{
    server.off('upgrade',onUpgrade);
    transport.close();
  });

  return transport;
}
