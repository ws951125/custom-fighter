import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { chromium } from 'playwright';

const baseUrl=String(process.env.CUSTOM_FIGHTER_WEB_URL||'http://127.0.0.1:8000').replace(/\/$/,'');
const browserChannel=String(process.env.BROWSER_CHANNEL||'').trim();
const productionOrigin='https://ws951125.github.io';
const isProduction=new URL(baseUrl).origin===productionOrigin;
const localBackendPort=8791;
const localWsUrl=`ws://127.0.0.1:${localBackendPort}/v1/pvp/ws`;
const productionWsUrl='wss://custom-fighter-ai-vfx-6899.onrender.com/v1/pvp/ws';
const suffix=String(process.env.GITHUB_RUN_ID||process.pid).replace(/[^A-Za-z0-9_.:-]/g,'_');
const hostClient=`host_${suffix}`;
const guestClient=`guest_${suffix}`;
let backendProcess=null;
let backendOutput='';

function attachDiagnostics(page,label){
  page.on('console',message=>{
    if(message.type()==='error') console.error(`[${label} console] ${message.text()}`);
  });
  page.on('pageerror',error=>console.error(`[${label} pageerror] ${error.message}`));
  page.on('requestfailed',request=>console.error(`[${label} requestfailed] ${request.method()} ${request.url()} ${request.failure()?.errorText||''}`));
}

async function waitForBackend(url,origin){
  let lastError='';
  for(let attempt=1;attempt<=30;attempt+=1){
    try{
      const response=await fetch(`${url}/healthz`,{headers:{Origin:origin}});
      if(response.ok) return;
      lastError=`HTTP ${response.status}`;
    }catch(error){
      lastError=String(error?.message||error);
    }
    await new Promise(resolve=>setTimeout(resolve,250));
  }
  throw new Error(`local PvP backend did not become ready: ${lastError}\n${backendOutput}`);
}

function startLocalBackend(){
  const origin=new URL(baseUrl).origin;
  backendProcess=spawn(process.execPath,['backend/server.mjs'],{
    cwd:process.cwd(),
    env:{
      ...process.env,
      PORT:String(localBackendPort),
      CUSTOM_FIGHTER_ALLOWED_ORIGIN:origin
    },
    stdio:['ignore','pipe','pipe']
  });
  backendProcess.stdout.on('data',chunk=>{backendOutput+=String(chunk);});
  backendProcess.stderr.on('data',chunk=>{backendOutput+=String(chunk);});
  return waitForBackend(`http://127.0.0.1:${localBackendPort}`,origin);
}

function pageUrl(clientId,wsUrl){
  const url=new URL(baseUrl+'/');
  url.searchParams.set('mode','competitive_hosted');
  url.searchParams.set('client',clientId);
  if(!isProduction) url.searchParams.set('pvp_ws',wsUrl);
  return url.toString();
}

async function waitReady(page){
  await page.waitForFunction(()=>{
    return document.documentElement.dataset.appMode==='competitive_hosted'
      && document.documentElement.dataset.networkPvpReady==='true'
      && typeof window.customFighterNetworkPvpCommand==='function';
  },null,{timeout:20000});
}

async function command(page,name,arg){
  await page.evaluate(([commandName,commandArg])=>{
    if(commandArg===null) window.customFighterNetworkPvpCommand(commandName);
    else window.customFighterNetworkPvpCommand(commandName,commandArg);
  },[name,arg??null]);
}

async function dataset(page,key){
  return page.evaluate(name=>document.documentElement.dataset[name]||'',key);
}

async function participants(page){
  return JSON.parse((await dataset(page,'networkPvpParticipants'))||'[]');
}

async function players(page){
  return JSON.parse((await dataset(page,'networkPvpPlayers'))||'[]');
}

if(!isProduction) await startLocalBackend();

const launchOptions={headless:true};
if(browserChannel) launchOptions.channel=browserChannel;
const browser=await chromium.launch(launchOptions);
const hostContext=await browser.newContext();
const guestContext=await browser.newContext();
const host=await hostContext.newPage();
const guest=await guestContext.newPage();
attachDiagnostics(host,'host');
attachDiagnostics(guest,'guest');

try{
  const wsUrl=isProduction?productionWsUrl:localWsUrl;
  await Promise.all([
    host.goto(pageUrl(hostClient,wsUrl),{waitUntil:'domcontentloaded'}),
    guest.goto(pageUrl(guestClient,wsUrl),{waitUntil:'domcontentloaded'})
  ]);
  await Promise.all([waitReady(host),waitReady(guest)]);

  await Promise.all([command(host,'connect'),command(guest,'connect')]);
  await Promise.all([
    host.waitForFunction(()=>document.documentElement.dataset.networkPvpConnection==='BOUND',null,{timeout:15000}),
    guest.waitForFunction(()=>document.documentElement.dataset.networkPvpConnection==='BOUND',null,{timeout:15000})
  ]);
  assert.equal(await dataset(host,'networkPvpLastError'),'');
  assert.equal(await dataset(guest,'networkPvpLastError'),'');

  await command(host,'create_lobby');
  await host.waitForFunction(()=>Boolean(document.documentElement.dataset.networkPvpLobbyId),null,{timeout:10000});
  const lobbyId=await dataset(host,'networkPvpLobbyId');
  assert.ok(lobbyId.length>0);

  await command(guest,'join_lobby',lobbyId);
  await Promise.all([
    host.waitForFunction(()=>JSON.parse(document.documentElement.dataset.networkPvpParticipants||'[]').length===2,null,{timeout:10000}),
    guest.waitForFunction(()=>JSON.parse(document.documentElement.dataset.networkPvpParticipants||'[]').length===2,null,{timeout:10000})
  ]);

  await Promise.all([command(host,'admit_ember'),command(guest,'admit_storm')]);
  const admitted=()=>JSON.parse(document.documentElement.dataset.networkPvpParticipants||'[]').length===2
    && JSON.parse(document.documentElement.dataset.networkPvpParticipants||'[]').every(player=>player.authority&&player.authority.character_id);
  await Promise.all([
    host.waitForFunction(admitted,null,{timeout:10000}),
    guest.waitForFunction(admitted,null,{timeout:10000})
  ]);
  const hostParticipants=await participants(host);
  assert.equal(hostParticipants.find(player=>player.client_id===hostClient).authority.character_id,'ember_vanguard_001');
  assert.equal(hostParticipants.find(player=>player.client_id===guestClient).authority.character_id,'storm_duelist_001');

  await command(host,'ready');
  await command(guest,'ready');
  const bothReady=()=>JSON.parse(document.documentElement.dataset.networkPvpParticipants||'[]').length===2
    && JSON.parse(document.documentElement.dataset.networkPvpParticipants||'[]').every(player=>player.ready===true);
  await Promise.all([
    host.waitForFunction(bothReady,null,{timeout:10000}),
    guest.waitForFunction(bothReady,null,{timeout:10000})
  ]);

  await command(host,'start');
  await Promise.all([
    host.waitForFunction(()=>document.documentElement.dataset.networkPvpMatchStatus==='active'&&Boolean(document.documentElement.dataset.networkPvpMatchId),null,{timeout:10000}),
    guest.waitForFunction(()=>document.documentElement.dataset.networkPvpMatchStatus==='active'&&Boolean(document.documentElement.dataset.networkPvpMatchId),null,{timeout:10000})
  ]);

  const hostMatchId=await dataset(host,'networkPvpMatchId');
  const guestMatchId=await dataset(guest,'networkPvpMatchId');
  assert.equal(hostMatchId,guestMatchId);
  await Promise.all([
    host.waitForFunction(()=>JSON.parse(document.documentElement.dataset.networkPvpPlayers||'[]').length===2,null,{timeout:10000}),
    guest.waitForFunction(()=>JSON.parse(document.documentElement.dataset.networkPvpPlayers||'[]').length===2,null,{timeout:10000})
  ]);

  const initialPlayers=await players(host);
  assert.equal(initialPlayers.find(player=>player.client_id===hostClient)?.hp,100);
  assert.equal(initialPlayers.find(player=>player.client_id===guestClient)?.hp,90);

  if(!isProduction){
    const before=initialPlayers.find(player=>player.client_id===hostClient).x;
    await command(host,'move_right');
    await host.waitForFunction(
      ([clientId,startX])=>JSON.parse(document.documentElement.dataset.networkPvpPlayers||'[]')
        .some(player=>player.client_id===clientId&&player.x>startX),
      [hostClient,before],
      {timeout:10000}
    );
    assert.equal(await dataset(host,'networkPvpLastError'),'');
  }else{
    await command(host,'request_state');
    await host.waitForFunction(()=>Number(document.documentElement.dataset.networkPvpTick||'0')>=0,null,{timeout:5000});
  }

  await host.waitForFunction(()=>Number(document.documentElement.dataset.networkPvpLatencyMs||'-1')>=0,null,{timeout:7000});
  assert.ok(Number(await dataset(host,'networkPvpLatencyMs'))>=0);

  await command(guest,'disconnect');
  await guest.waitForFunction(()=>document.documentElement.dataset.networkPvpConnection==='RECONNECTING',null,{timeout:5000}).catch(()=>{});
  await guest.waitForFunction(
    ()=>document.documentElement.dataset.networkPvpConnection==='BOUND'
      && Number(document.documentElement.dataset.networkPvpReconnectCount||'0')>=1,
    null,
    {timeout:12000}
  );
  assert.ok(Number(await dataset(guest,'networkPvpReconnectCount'))>=1);
  assert.equal(await dataset(guest,'networkPvpMatchId'),hostMatchId);

  await command(guest,'forfeit');
  await Promise.all([
    host.waitForFunction(()=>document.documentElement.dataset.networkPvpMatchStatus==='finished',null,{timeout:7000}),
    guest.waitForFunction(()=>document.documentElement.dataset.networkPvpMatchStatus==='finished',null,{timeout:7000})
  ]);
  assert.equal(await dataset(host,'networkPvpWinner'),hostClient);
  assert.equal(await dataset(host,'networkPvpResultReason'),'forfeit');

  const finalPlayers=await players(host);
  const finalTick=Number(await dataset(host,'networkPvpTick'));
  assert.equal(finalPlayers.length,2);
  assert.ok(finalTick>=0);

  console.log(
    `NETWORK_PVP_WEB_SMOKE_PASSED browser=${browserChannel||'chromium'} production=${isProduction} lobby=${lobbyId} match=${hostMatchId} tick=${finalTick} reconnects=${await dataset(guest,'networkPvpReconnectCount')} rtt=${await dataset(host,'networkPvpLatencyMs')} result=${await dataset(host,'networkPvpResultReason')} clients=${hostClient},${guestClient}`
  );
}finally{
  await hostContext.close();
  await guestContext.close();
  await browser.close();
  if(backendProcess&&!backendProcess.killed){
    backendProcess.kill();
    await new Promise(resolve=>{
      const timer=setTimeout(resolve,1000);
      backendProcess.once('exit',()=>{clearTimeout(timer);resolve();});
    });
  }
}
