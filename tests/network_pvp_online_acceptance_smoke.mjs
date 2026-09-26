import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { chromium } from 'playwright';

const baseUrl=String(process.env.CUSTOM_FIGHTER_WEB_URL||'http://127.0.0.1:8000').replace(/\/$/,'');
const browserChannel=String(process.env.BROWSER_CHANNEL||'').trim();
const productionOrigin='https://ws951125.github.io';
const isProduction=new URL(baseUrl).origin===productionOrigin;
const localBackendPort=8792;
const localWsUrl=`ws://127.0.0.1:${localBackendPort}/v1/pvp/ws`;
const productionWsUrl='wss://custom-fighter-ai-vfx-6899.onrender.com/v1/pvp/ws';
const suffix=`${process.env.GITHUB_RUN_ID||'local'}_${process.env.GITHUB_RUN_ATTEMPT||'1'}_${process.pid}`.replace(/[^A-Za-z0-9_.:-]/g,'_');
const hostClient=`accept_host_${suffix}`;
const guestClient=`accept_guest_${suffix}`;
let backendProcess=null;
let backendOutput='';

function attachDiagnostics(page,label){
  page.on('console',message=>{
    if(message.type()==='error')console.error(`[${label} console] ${message.text()}`);
  });
  page.on('pageerror',error=>console.error(`[${label} pageerror] ${error.message}`));
  page.on('requestfailed',request=>console.error(`[${label} requestfailed] ${request.method()} ${request.url()} ${request.failure()?.errorText||''}`));
}

async function waitForBackend(url,origin){
  let lastError='';
  for(let attempt=1;attempt<=40;attempt+=1){
    try{
      const response=await fetch(`${url}/healthz`,{headers:{Origin:origin}});
      if(response.ok)return;
      lastError=`HTTP ${response.status}`;
    }catch(error){
      lastError=String(error?.message||error);
    }
    await new Promise(resolve=>setTimeout(resolve,250));
  }
  throw new Error(`WU6 local backend did not become ready: ${lastError}\n${backendOutput}`);
}

function startLocalBackend(){
  const origin=new URL(baseUrl).origin;
  backendProcess=spawn(process.execPath,['backend/server.mjs'],{
    cwd:process.cwd(),
    env:{...process.env,PORT:String(localBackendPort),CUSTOM_FIGHTER_ALLOWED_ORIGIN:origin},
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
  if(!isProduction)url.searchParams.set('pvp_ws',wsUrl);
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
    if(commandArg===null)window.customFighterNetworkPvpCommand(commandName);
    else window.customFighterNetworkPvpCommand(commandName,commandArg);
  },[name,arg??null]);
}

async function dataset(page,key){
  return page.evaluate(name=>document.documentElement.dataset[name]||'',key);
}

async function players(page){
  return JSON.parse((await dataset(page,'networkPvpPlayers'))||'[]');
}

async function moveOne(page,commandName,clientId,direction){
  const before=(await players(page)).find(player=>player.client_id===clientId)?.x;
  assert.equal(typeof before,'number');
  await command(page,commandName);
  await page.waitForFunction(
    ([id,startX,dir])=>{
      const list=JSON.parse(document.documentElement.dataset.networkPvpPlayers||'[]');
      const player=list.find(item=>item.client_id===id);
      return Boolean(player)&&(dir>0?player.x>startX:player.x<startX);
    },
    [clientId,before,direction],
    {timeout:10000}
  );
}

async function waitBasicAttackReady(page,clientId){
  await page.waitForFunction(
    id=>{
      const list=JSON.parse(document.documentElement.dataset.networkPvpPlayers||'[]');
      const player=list.find(item=>item.client_id===id);
      return Boolean(player)&&Number(player.cooldowns?.basic_attack||0)===0;
    },
    clientId,
    {timeout:5000}
  );
}

if(!isProduction)await startLocalBackend();

const launchOptions={headless:true};
if(browserChannel)launchOptions.channel=browserChannel;
const browser=await chromium.launch(launchOptions);
const hostContext=await browser.newContext();
const guestContext=await browser.newContext();
const host=await hostContext.newPage();
const guest=await guestContext.newPage();
attachDiagnostics(host,'wu6-host');
attachDiagnostics(guest,'wu6-guest');

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

  await command(host,'create_lobby');
  await host.waitForFunction(()=>Boolean(document.documentElement.dataset.networkPvpLobbyId),null,{timeout:10000});
  const lobbyId=await dataset(host,'networkPvpLobbyId');
  await command(guest,'join_lobby',lobbyId);
  await Promise.all([
    host.waitForFunction(()=>JSON.parse(document.documentElement.dataset.networkPvpParticipants||'[]').length===2,null,{timeout:10000}),
    guest.waitForFunction(()=>JSON.parse(document.documentElement.dataset.networkPvpParticipants||'[]').length===2,null,{timeout:10000})
  ]);

  await Promise.all([
    command(host,'admit_creator_blaze'),
    command(guest,'admit_creator_frost')
  ]);
  const admitted=()=>JSON.parse(document.documentElement.dataset.networkPvpParticipants||'[]').length===2
    && JSON.parse(document.documentElement.dataset.networkPvpParticipants||'[]').every(player=>player.authority&&player.authority.character_id);
  await Promise.all([
    host.waitForFunction(admitted,null,{timeout:10000}),
    guest.waitForFunction(admitted,null,{timeout:10000})
  ]);
  const participants=JSON.parse(await dataset(host,'networkPvpParticipants'));
  assert.equal(participants.find(player=>player.client_id===hostClient)?.authority?.character_id,'creator_blaze_001');
  assert.equal(participants.find(player=>player.client_id===guestClient)?.authority?.character_id,'creator_frost_001');

  await Promise.all([command(host,'ready'),command(guest,'ready')]);
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
  const matchId=await dataset(host,'networkPvpMatchId');
  assert.equal(matchId,await dataset(guest,'networkPvpMatchId'));

  await host.waitForFunction(()=>JSON.parse(document.documentElement.dataset.networkPvpPlayers||'[]').length===2,null,{timeout:10000});
  const initial=await players(host);
  assert.equal(initial.find(player=>player.client_id===hostClient)?.character_id,'creator_blaze_001');
  assert.equal(initial.find(player=>player.client_id===guestClient)?.character_id,'creator_frost_001');
  assert.equal(initial.find(player=>player.client_id===hostClient)?.hp,100);
  assert.equal(initial.find(player=>player.client_id===guestClient)?.hp,90);

  await command(host,'forge_combat_state');
  await host.waitForFunction(()=>document.documentElement.dataset.networkPvpLastError==='INPUT_INTENT_FIELDS_INVALID',null,{timeout:5000});
  const afterForge=await players(host);
  assert.equal(afterForge.find(player=>player.client_id===guestClient)?.hp,90);
  assert.equal(Number(afterForge.find(player=>player.client_id===hostClient)?.cooldowns?.basic_attack||0),0);

  for(let step=0;step<5;step+=1){
    await moveOne(host,'move_right',hostClient,1);
    await moveOne(guest,'move_left',guestClient,-1);
  }
  const closePlayers=await players(host);
  const hostX=closePlayers.find(player=>player.client_id===hostClient)?.x;
  const guestX=closePlayers.find(player=>player.client_id===guestClient)?.x;
  assert.ok(Math.abs(hostX-guestX)<=3);

  let expectedGuestHp=90;
  for(let attackIndex=0;attackIndex<9;attackIndex+=1){
    await waitBasicAttackReady(host,hostClient);
    await command(host,'attack');
    const previousHp=expectedGuestHp;
    await host.waitForFunction(
      ([guestId,priorHp])=>{
        const status=document.documentElement.dataset.networkPvpMatchStatus;
        const list=JSON.parse(document.documentElement.dataset.networkPvpPlayers||'[]');
        const target=list.find(player=>player.client_id===guestId);
        return status==='finished'||Boolean(target&&target.hp<priorHp);
      },
      [guestClient,previousHp],
      {timeout:7000}
    );
    const statePlayers=await players(host);
    expectedGuestHp=statePlayers.find(player=>player.client_id===guestClient)?.hp;
    if(await dataset(host,'networkPvpMatchStatus')==='finished')break;
  }

  await Promise.all([
    host.waitForFunction(()=>document.documentElement.dataset.networkPvpMatchStatus==='finished',null,{timeout:7000}),
    guest.waitForFunction(()=>document.documentElement.dataset.networkPvpMatchStatus==='finished',null,{timeout:7000})
  ]);
  assert.equal(await dataset(host,'networkPvpWinner'),hostClient);
  assert.equal(await dataset(host,'networkPvpResultReason'),'combat');

  const finalPlayers=await players(host);
  assert.equal(finalPlayers.find(player=>player.client_id===guestClient)?.hp,0);
  assert.equal(finalPlayers.find(player=>player.client_id===hostClient)?.hp,100);

  console.log(
    `NETWORK_PVP_WU6_ONLINE_ACCEPTANCE_PASSED browser=${browserChannel||'chromium'} production=${isProduction} lobby=${lobbyId} match=${matchId} winner=${hostClient} custom=creator_blaze_001,creator_frost_001 forged=INPUT_INTENT_FIELDS_INVALID`
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
