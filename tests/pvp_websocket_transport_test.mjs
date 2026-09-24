import assert from 'node:assert/strict';
import WebSocket from 'ws';
import { createServer } from '../backend/server.mjs';

const ORIGIN='https://ws951125.github.io';
const EMBER='56451d3bdf1c7bf74852a3620894667730ddb088f350eb598badfa74c6d3c28e';
const STORM='5822c6cfb4737c29007f2450a598c501b79c17d8ed9a432e4327976cc6a7026e';

function createInbox(ws) {
  const queue=[];
  const waiters=[];

  ws.on('message', data => {
    const message=JSON.parse(String(data));
    const index=waiters.findIndex(waiter => waiter.predicate(message));
    if(index>=0){
      const [waiter]=waiters.splice(index,1);
      clearTimeout(waiter.timer);
      waiter.resolve(message);
      return;
    }
    queue.push(message);
  });

  function next(predicate, timeoutMs=3000) {
    const index=queue.findIndex(predicate);
    if(index>=0) return Promise.resolve(queue.splice(index,1)[0]);
    return new Promise((resolve,reject)=>{
      const waiter={predicate,resolve,reject,timer:null};
      waiter.timer=setTimeout(()=>{
        const current=waiters.indexOf(waiter);
        if(current>=0) waiters.splice(current,1);
        reject(new Error('timed out waiting for websocket message'));
      },timeoutMs);
      waiters.push(waiter);
    });
  }

  return {
    send(message){ ws.send(JSON.stringify(message)); },
    next,
    close(){ try { ws.close(1000,'test done'); } catch {} }
  };
}

async function openClient(url, origin=ORIGIN) {
  const ws=new WebSocket(url,{origin});
  await new Promise((resolve,reject)=>{
    ws.once('open',resolve);
    ws.once('error',reject);
  });
  return {ws,inbox:createInbox(ws)};
}

async function expectRejectedOrigin(url) {
  await new Promise((resolve,reject)=>{
    const ws=new WebSocket(url,{origin:'https://evil.example'});
    const timer=setTimeout(()=>reject(new Error('bad-origin websocket was not rejected')),3000);
    ws.once('unexpected-response',(_request,response)=>{
      clearTimeout(timer);
      assert.equal(response.statusCode,403);
      response.resume();
      resolve();
    });
    ws.once('open',()=>{
      clearTimeout(timer);
      ws.close();
      reject(new Error('bad-origin websocket unexpectedly opened'));
    });
    ws.once('error',error=>{
      if(String(error?.message||'').includes('403')){
        clearTimeout(timer);
        resolve();
      }
    });
  });
}

const service=async request=>({ok:true,request_id:request.request_id,png_base64:'dGVzdA=='});
const server=createServer({service,allowedOrigin:ORIGIN,pvpTickIntervalMs:100});
await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
const {port}=server.address();
const wsUrl=`ws://127.0.0.1:${port}/v1/pvp/ws`;

let host;
let guest;
let duplicate;

try{
  await expectRejectedOrigin(wsUrl);

  host=await openClient(wsUrl);
  guest=await openClient(wsUrl);

  host.inbox.send({type:'hello',protocol_version:1,client_id:'host_client'});
  guest.inbox.send({type:'hello',protocol_version:1,client_id:'guest_client'});
  const hostHello=await host.inbox.next(message=>message.type==='hello_ok');
  const guestHello=await guest.inbox.next(message=>message.type==='hello_ok');
  assert.equal(hostHello.client_id,'host_client');
  assert.equal(guestHello.client_id,'guest_client');
  assert.equal(typeof hostHello.connection_token,'string');
  assert.ok(hostHello.connection_token.length>10);

  duplicate=await openClient(wsUrl);
  duplicate.inbox.send({type:'hello',protocol_version:1,client_id:'host_client'});
  const duplicateError=await duplicate.inbox.next(message=>message.type==='error');
  assert.equal(duplicateError.code,'CLIENT_ALREADY_CONNECTED');

  host.inbox.send({type:'create_lobby',connection_token:hostHello.connection_token});
  const hostLobby=await host.inbox.next(message=>message.type==='lobby_state');
  const lobbyId=hostLobby.lobby.lobby_id;
  assert.equal(hostLobby.lobby.participants.length,1);

  guest.inbox.send({
    type:'join_lobby',
    connection_token:guestHello.connection_token,
    lobby_id:lobbyId
  });
  const joinedHost=await host.inbox.next(message=>message.type==='lobby_state'&&message.lobby.participants.length===2);
  const joinedGuest=await guest.inbox.next(message=>message.type==='lobby_state'&&message.lobby.participants.length===2);
  assert.equal(joinedHost.lobby.lobby_id,lobbyId);
  assert.equal(joinedGuest.lobby.lobby_id,lobbyId);

  host.inbox.send({
    type:'negotiate_loadout',
    connection_token:hostHello.connection_token,
    lobby_id:lobbyId,
    claim:{character_id:'ember_vanguard_001',content_fingerprint:EMBER,package_schema_version:1}
  });
  const hostAuthority=await host.inbox.next(message=>message.type==='authority_admitted');
  assert.equal(hostAuthority.authority.character_id,'ember_vanguard_001');

  guest.inbox.send({
    type:'negotiate_loadout',
    connection_token:guestHello.connection_token,
    lobby_id:lobbyId,
    claim:{character_id:'storm_duelist_001',content_fingerprint:STORM,package_schema_version:1}
  });
  const guestAuthority=await guest.inbox.next(message=>message.type==='authority_admitted');
  assert.equal(guestAuthority.authority.character_id,'storm_duelist_001');

  const bothAdmitted=message=>message.type==='lobby_state'&&message.lobby.participants.every(p=>p.authority);
  await host.inbox.next(bothAdmitted);
  await guest.inbox.next(bothAdmitted);

  host.inbox.send({
    type:'set_ready',
    connection_token:hostHello.connection_token,
    lobby_id:lobbyId,
    ready:true
  });
  guest.inbox.send({
    type:'set_ready',
    connection_token:guestHello.connection_token,
    lobby_id:lobbyId,
    ready:true
  });

  const bothReady=message=>message.type==='lobby_state'&&message.lobby.participants.length===2&&message.lobby.participants.every(p=>p.ready===true);
  await host.inbox.next(bothReady);
  await guest.inbox.next(bothReady);

  host.inbox.send({
    type:'start_match',
    connection_token:hostHello.connection_token,
    lobby_id:lobbyId
  });
  const hostStarted=await host.inbox.next(message=>message.type==='match_started');
  const guestStarted=await guest.inbox.next(message=>message.type==='match_started');
  assert.equal(hostStarted.match.match_id,guestStarted.match.match_id);
  const matchId=hostStarted.match.match_id;

  const initial=await host.inbox.next(message=>message.type==='match_state'&&message.state.match_id===matchId);
  assert.deepEqual(initial.state.players.map(player=>player.hp),[100,90]);

  host.inbox.send({
    type:'input',
    connection_token:'wrong-token',
    match_id:matchId,
    input:{sequence:1,target_tick:initial.state.tick+3,actions:['move_right']}
  });
  const authError=await host.inbox.next(message=>message.type==='error'&&message.request_type==='input');
  assert.equal(authError.code,'CONNECTION_AUTH_INVALID');

  host.inbox.send({
    type:'input',
    connection_token:hostHello.connection_token,
    match_id:matchId,
    client_id:'guest_client',
    input:{sequence:1,target_tick:initial.state.tick+3,actions:['move_right']}
  });
  const fieldsError=await host.inbox.next(message=>message.type==='error'&&message.request_type==='input');
  assert.equal(fieldsError.code,'MESSAGE_FIELDS_INVALID');

  const latest=await host.inbox.next(message=>message.type==='match_state'&&message.state.tick>=initial.state.tick);
  host.inbox.send({
    type:'input',
    connection_token:hostHello.connection_token,
    match_id:matchId,
    input:{sequence:1,target_tick:latest.state.tick+5,actions:['move_right']}
  });
  const ack=await host.inbox.next(message=>message.type==='input_ack');
  assert.equal(ack.accepted_sequence,1);

  const moved=await host.inbox.next(message=>{
    if(message.type!=='match_state') return false;
    const player=message.state.players.find(item=>item.client_id==='host_client');
    return player&&player.x>-6;
  });
  assert.ok(moved.state.players.find(item=>item.client_id==='host_client').x>-6);

  guest.inbox.send({
    type:'request_state',
    connection_token:guestHello.connection_token,
    match_id:matchId
  });
  const requested=await guest.inbox.next(message=>message.type==='match_state'&&message.state.match_id===matchId);
  assert.equal(requested.state.status,'active');

  console.log(`PVP_WEBSOCKET_TRANSPORT_TESTS_PASSED lobby=${lobbyId} match=${matchId} tick=${requested.state.tick}`);
}finally{
  duplicate?.inbox.close();
  host?.inbox.close();
  guest?.inbox.close();
  await new Promise(resolve=>setTimeout(resolve,25));
  await new Promise(resolve=>server.close(resolve));
}
