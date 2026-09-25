import assert from 'node:assert/strict';
import WebSocket from 'ws';
import { createServer } from '../backend/server.mjs';

const ORIGIN='https://ws951125.github.io';
const EMBER='56451d3bdf1c7bf74852a3620894667730ddb088f350eb598badfa74c6d3c28e';
const STORM='5822c6cfb4737c29007f2450a598c501b79c17d8ed9a432e4327976cc6a7026e';

function createInbox(ws) {
  const queue=[];
  const waiters=[];
  ws.on('message',data=>{
    const message=JSON.parse(String(data));
    const index=waiters.findIndex(waiter=>waiter.predicate(message));
    if(index>=0){
      const [waiter]=waiters.splice(index,1);
      clearTimeout(waiter.timer);
      waiter.resolve(message);
      return;
    }
    queue.push(message);
  });
  return {
    send(message){ ws.send(JSON.stringify(message)); },
    next(predicate,timeoutMs=3000){
      const index=queue.findIndex(predicate);
      if(index>=0)return Promise.resolve(queue.splice(index,1)[0]);
      return new Promise((resolve,reject)=>{
        const waiter={predicate,resolve,timer:null};
        waiter.timer=setTimeout(()=>{
          const current=waiters.indexOf(waiter);
          if(current>=0)waiters.splice(current,1);
          reject(new Error('timed out waiting for websocket message'));
        },timeoutMs);
        waiters.push(waiter);
      });
    },
    close(){ try{ws.close(1000,'test done');}catch{} }
  };
}

async function openClient(url,origin=ORIGIN){
  const ws=new WebSocket(url,{origin});
  await new Promise((resolve,reject)=>{ws.once('open',resolve);ws.once('error',reject);});
  return {ws,inbox:createInbox(ws)};
}

async function expectRejectedOrigin(url){
  await new Promise((resolve,reject)=>{
    const ws=new WebSocket(url,{origin:'https://evil.example'});
    const timer=setTimeout(()=>reject(new Error('bad-origin websocket was not rejected')),3000);
    ws.once('unexpected-response',(_request,response)=>{
      clearTimeout(timer);
      assert.equal(response.statusCode,403);
      response.resume();
      resolve();
    });
    ws.once('open',()=>{clearTimeout(timer);ws.close();reject(new Error('bad-origin websocket unexpectedly opened'));});
    ws.once('error',error=>{
      if(String(error?.message||'').includes('403')){clearTimeout(timer);resolve();}
    });
  });
}

const service=async request=>({ok:true,request_id:request.request_id,png_base64:'dGVzdA=='});
const server=createServer({
  service,
  allowedOrigin:ORIGIN,
  pvpTickIntervalMs:50,
  pvpReconnectWindowMs:300,
  pvpHeartbeatTimeoutMs:5000,
  pvpHeartbeatCheckMs:100
});
await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
const {port}=server.address();
const wsUrl=`ws://127.0.0.1:${port}/v1/pvp/ws`;
const clients=[];

async function setupMatch(prefix){
  const host=await openClient(wsUrl);
  const guest=await openClient(wsUrl);
  clients.push(host,guest);
  const hostId=`${prefix}_host`;
  const guestId=`${prefix}_guest`;
  host.inbox.send({type:'hello',protocol_version:1,client_id:hostId});
  guest.inbox.send({type:'hello',protocol_version:1,client_id:guestId});
  const hostHello=await host.inbox.next(m=>m.type==='hello_ok');
  const guestHello=await guest.inbox.next(m=>m.type==='hello_ok');
  assert.equal(typeof hostHello.reconnect_token,'string');
  assert.equal(hostHello.reconnect_window_ms,300);

  host.inbox.send({type:'create_lobby',connection_token:hostHello.connection_token});
  const lobbyId=(await host.inbox.next(m=>m.type==='lobby_state')).lobby.lobby_id;
  guest.inbox.send({type:'join_lobby',connection_token:guestHello.connection_token,lobby_id:lobbyId});
  await host.inbox.next(m=>m.type==='lobby_state'&&m.lobby.participants.length===2);
  await guest.inbox.next(m=>m.type==='lobby_state'&&m.lobby.participants.length===2);

  host.inbox.send({
    type:'negotiate_loadout',connection_token:hostHello.connection_token,lobby_id:lobbyId,
    claim:{character_id:'ember_vanguard_001',content_fingerprint:EMBER,package_schema_version:1}
  });
  guest.inbox.send({
    type:'negotiate_loadout',connection_token:guestHello.connection_token,lobby_id:lobbyId,
    claim:{character_id:'storm_duelist_001',content_fingerprint:STORM,package_schema_version:1}
  });
  await host.inbox.next(m=>m.type==='authority_admitted');
  await guest.inbox.next(m=>m.type==='authority_admitted');
  const admitted=m=>m.type==='lobby_state'&&m.lobby.participants.length===2&&m.lobby.participants.every(p=>p.authority);
  await host.inbox.next(admitted);
  await guest.inbox.next(admitted);

  host.inbox.send({type:'set_ready',connection_token:hostHello.connection_token,lobby_id:lobbyId,ready:true});
  guest.inbox.send({type:'set_ready',connection_token:guestHello.connection_token,lobby_id:lobbyId,ready:true});
  const ready=m=>m.type==='lobby_state'&&m.lobby.participants.length===2&&m.lobby.participants.every(p=>p.ready);
  await host.inbox.next(ready);
  await guest.inbox.next(ready);

  host.inbox.send({type:'start_match',connection_token:hostHello.connection_token,lobby_id:lobbyId});
  const started=await host.inbox.next(m=>m.type==='match_started');
  await guest.inbox.next(m=>m.type==='match_started');
  const matchId=started.match.match_id;
  const initial=await host.inbox.next(m=>m.type==='match_state'&&m.state.match_id===matchId);
  assert.equal(initial.state.players.find(p=>p.client_id===hostId)?.hp,100);
  assert.equal(initial.state.players.find(p=>p.client_id===guestId)?.hp,90);
  return {host,guest,hostId,guestId,hostHello,guestHello,lobbyId,matchId,initial};
}

try{
  await expectRejectedOrigin(wsUrl);

  const duplicateA=await openClient(wsUrl);
  const duplicateB=await openClient(wsUrl);
  clients.push(duplicateA,duplicateB);
  duplicateA.inbox.send({type:'hello',protocol_version:1,client_id:'duplicate_client'});
  await duplicateA.inbox.next(m=>m.type==='hello_ok');
  duplicateB.inbox.send({type:'hello',protocol_version:1,client_id:'duplicate_client'});
  assert.equal((await duplicateB.inbox.next(m=>m.type==='error')).code,'CLIENT_ALREADY_CONNECTED');

  const first=await setupMatch('first');

  first.host.inbox.send({type:'ping',connection_token:first.hostHello.connection_token,client_time_ms:123});
  const pong=await first.host.inbox.next(m=>m.type==='pong');
  assert.equal(pong.client_time_ms,123);
  assert.equal(Number.isSafeInteger(pong.server_time_ms),true);

  first.host.inbox.send({
    type:'input',connection_token:first.hostHello.connection_token,match_id:first.matchId,
    input:{sequence:1,target_tick:first.initial.state.tick+1,actions:['move_right']}
  });
  assert.equal((await first.host.inbox.next(m=>m.type==='error'&&m.request_type==='input')).code,'INPUT_INTENT_FIELDS_INVALID');

  first.guest.ws.close(1001,'reconnect test');
  const reconnecting=await first.host.inbox.next(m=>m.type==='peer_status'&&m.client_id===first.guestId&&m.status==='reconnecting');
  assert.ok(reconnecting.reconnect_deadline_ms>0);

  const resumed=await openClient(wsUrl);
  clients.push(resumed);
  resumed.inbox.send({
    type:'hello',
    protocol_version:1,
    client_id:first.guestId,
    reconnect_token:first.guestHello.reconnect_token
  });
  const resumedHello=await resumed.inbox.next(m=>m.type==='hello_ok');
  assert.equal(resumedHello.reconnected,true);
  assert.equal(resumedHello.reconnect_token,first.guestHello.reconnect_token);
  await resumed.inbox.next(m=>m.type==='lobby_state'&&m.lobby.lobby_id===first.lobbyId);
  const resumedState=await resumed.inbox.next(m=>m.type==='match_state'&&m.state.match_id===first.matchId);
  assert.equal(resumedState.state.status,'active');
  await first.host.inbox.next(m=>m.type==='peer_status'&&m.client_id===first.guestId&&m.status==='connected');

  resumed.inbox.send({type:'forfeit',connection_token:resumedHello.connection_token,match_id:first.matchId});
  const explicitFinished=await first.host.inbox.next(m=>m.type==='match_finished');
  assert.equal(explicitFinished.state.status,'finished');
  assert.equal(explicitFinished.state.winner_client_id,first.hostId);
  assert.equal(explicitFinished.state.forfeited_client_id,first.guestId);
  assert.equal(explicitFinished.state.result_reason,'forfeit');

  const second=await setupMatch('timeout');
  second.guest.ws.close(1001,'disconnect timeout test');
  await second.host.inbox.next(m=>m.type==='peer_status'&&m.client_id===second.guestId&&m.status==='reconnecting');
  const timeoutFinished=await second.host.inbox.next(m=>m.type==='match_finished',2000);
  assert.equal(timeoutFinished.state.winner_client_id,second.hostId);
  assert.equal(timeoutFinished.state.forfeited_client_id,second.guestId);
  assert.equal(timeoutFinished.state.result_reason,'disconnect_timeout');

  const waitingHost=await openClient(wsUrl);
  const waitingGuest=await openClient(wsUrl);
  clients.push(waitingHost,waitingGuest);
  waitingHost.inbox.send({type:'hello',protocol_version:1,client_id:'leave_host'});
  waitingGuest.inbox.send({type:'hello',protocol_version:1,client_id:'leave_guest'});
  const waitingHostHello=await waitingHost.inbox.next(m=>m.type==='hello_ok');
  const waitingGuestHello=await waitingGuest.inbox.next(m=>m.type==='hello_ok');
  waitingHost.inbox.send({type:'create_lobby',connection_token:waitingHostHello.connection_token});
  const waitingLobby=(await waitingHost.inbox.next(m=>m.type==='lobby_state')).lobby.lobby_id;
  waitingGuest.inbox.send({type:'join_lobby',connection_token:waitingGuestHello.connection_token,lobby_id:waitingLobby});
  await waitingHost.inbox.next(m=>m.type==='lobby_state'&&m.lobby.participants.length===2);
  await waitingGuest.inbox.next(m=>m.type==='lobby_state'&&m.lobby.participants.length===2);
  waitingHost.inbox.send({type:'leave_lobby',connection_token:waitingHostHello.connection_token,lobby_id:waitingLobby});
  assert.equal((await waitingHost.inbox.next(m=>m.type==='lobby_left')).closed,false);
  const promoted=await waitingGuest.inbox.next(m=>m.type==='lobby_state'&&m.lobby.participants.length===1);
  assert.equal(promoted.lobby.host_client_id,'leave_guest');

  console.log('PVP_WEBSOCKET_TRANSPORT_WU5_TESTS_PASSED');
}finally{
  for(const client of clients)client.inbox.close();
  await new Promise(resolve=>setTimeout(resolve,50));
  await new Promise(resolve=>server.close(resolve));
}
