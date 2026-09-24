const TICK_RATE=60;
const MAX_INPUT_LEAD=6;
const BASIC_ATTACK_RANGE=3;
const BASIC_ATTACK_DAMAGE=10;
const BASIC_ATTACK_COOLDOWN_TICKS=30;
const ACTIONS=new Set(['move_left','move_right','move_up','move_down','run','jump','basic_attack','dash','guard','skill_1','skill_2','skill_3','skill_4','skill_5','skill_6','skill_7','skill_8','skill_9','skill_10','skill_11','skill_12','skill_13']);
const clamp=(n,min,max)=>Math.max(min,Math.min(max,n));
const clone=v=>structuredClone(v);
const fail=(code,details={})=>({ok:false,code,...details});

function resolveAuthoritativeLoadout(participant,loadoutResolver){
 const loadout=loadoutResolver(clone(participant.authority));
 if(!loadout||typeof loadout!=='object'||Array.isArray(loadout))throw new Error('AUTHORITATIVE_LOADOUT_INVALID');
 if(typeof loadout.max_hp!=='number'||!Number.isFinite(loadout.max_hp)||loadout.max_hp<1||loadout.max_hp>250)throw new Error('AUTHORITATIVE_LOADOUT_INVALID');
 if(typeof loadout.max_mp!=='number'||!Number.isFinite(loadout.max_mp)||loadout.max_mp<0||loadout.max_mp>250)throw new Error('AUTHORITATIVE_LOADOUT_INVALID');
 return {max_hp:loadout.max_hp,max_mp:loadout.max_mp};
}

function initialPlayer(participant,index,loadoutResolver){
 const loadout=resolveAuthoritativeLoadout(participant,loadoutResolver);
 return {
  client_id:participant.client_id,character_id:participant.authority.character_id,
  hp:loadout.max_hp,mp:loadout.max_mp,x:index===0?-6:6,y:0,facing:index===0?1:-1,
  guarding:false,cooldowns:{},last_input_sequence:0,last_target_tick:0
 };
}

export function createAuthoritativeMatch({match,loadoutResolver}={}){
 if(!match||match.status!=='active'||!Array.isArray(match.participants)||match.participants.length!==2) throw new Error('ACTIVE_TWO_PLAYER_MATCH_REQUIRED');
 if(typeof loadoutResolver!=='function')throw new Error('AUTHORITATIVE_LOADOUT_RESOLVER_REQUIRED');
 let tick=0,finished=false,winner=null;
 const players=new Map(match.participants.map((p,i)=>[p.client_id,initialPlayer(p,i,loadoutResolver)]));
 const pending=new Map();

 function submitInput(clientId,input){
  const p=players.get(clientId); if(!p)return fail('PLAYER_NOT_IN_MATCH');
  if(finished)return fail('MATCH_FINISHED');
  if(!input||typeof input!=='object'||Array.isArray(input))return fail('INPUT_INVALID');
  const allowed=['sequence','target_tick','actions'];
  if(Object.keys(input).some(k=>!allowed.includes(k)))return fail('INPUT_FIELDS_INVALID');
  if(!Number.isInteger(input.sequence)||input.sequence<=p.last_input_sequence)return fail('INPUT_SEQUENCE_INVALID');
  if(!Number.isInteger(input.target_tick)||input.target_tick<tick+1||input.target_tick>tick+MAX_INPUT_LEAD)return fail('INPUT_TICK_INVALID');
  if(input.target_tick<=p.last_target_tick)return fail('INPUT_TICK_STALE',{last_target_tick:p.last_target_tick});
  if(!Array.isArray(input.actions)||input.actions.length>8||input.actions.some(a=>!ACTIONS.has(a)))return fail('INPUT_ACTION_INVALID');
  p.last_input_sequence=input.sequence;
  p.last_target_tick=input.target_tick;
  if(!pending.has(input.target_tick))pending.set(input.target_tick,[]);
  pending.get(input.target_tick).push({client_id:clientId,sequence:input.sequence,actions:[...new Set(input.actions)]});
  return {ok:true,accepted_sequence:input.sequence,target_tick:input.target_tick};
 }

 function step(){
  if(finished)return snapshot();
  tick+=1;
  const inputs=(pending.get(tick)||[]).sort((a,b)=>a.client_id.localeCompare(b.client_id)||a.sequence-b.sequence);
  pending.delete(tick);

  // Resolve same-tick posture/position first, then compute every hit before applying damage.
  // This keeps guard, movement, lethal damage and winner state independent of client-id iteration order.
  for(const item of inputs)applyMovementAndGuard(players.get(item.client_id),item.actions);
  const hits=[];
  for(const item of inputs){
   const hit=resolveCombatIntent(players.get(item.client_id),item.actions);
   if(hit)hits.push(hit);
  }
  for(const hit of hits){
   hit.target.hp=Math.max(0,hit.target.hp-hit.damage);
  }
  if(hits.length>0){
   const dead=[...players.values()].filter(p=>p.hp===0);
   if(dead.length>0){
    finished=true;
    winner=dead.length===1?[...players.values()].find(p=>p.client_id!==dead[0].client_id).client_id:null;
   }
  }

  for(const p of players.values()){
   for(const [k,v] of Object.entries(p.cooldowns))p.cooldowns[k]=Math.max(0,v-1);
  }
  return snapshot();
 }

 function applyMovementAndGuard(p,actions){
  const speed=actions.includes('run')?2:1;
  if(actions.includes('move_left'))p.x=clamp(p.x-speed,-20,20);
  if(actions.includes('move_right'))p.x=clamp(p.x+speed,-20,20);
  if(actions.includes('move_up'))p.y=clamp(p.y-1,-5,5);
  if(actions.includes('move_down'))p.y=clamp(p.y+1,-5,5);
  p.guarding=actions.includes('guard');
 }

 function resolveCombatIntent(p,actions){
  if(!actions.includes('basic_attack'))return null;
  if((p.cooldowns.basic_attack??0)>0)return null;
  p.cooldowns.basic_attack=BASIC_ATTACK_COOLDOWN_TICKS;
  const opponent=[...players.values()].find(x=>x.client_id!==p.client_id);
  const distance=Math.abs(p.x-opponent.x);
  if(distance>BASIC_ATTACK_RANGE)return null;
  const damage=opponent.guarding?BASIC_ATTACK_DAMAGE/2:BASIC_ATTACK_DAMAGE;
  return {source:p,target:opponent,damage};
 }

 function snapshot(){
  return clone({match_id:match.match_id,tick,tick_rate:TICK_RATE,status:finished?'finished':'active',winner_client_id:winner,players:[...players.values()].sort((a,b)=>a.client_id.localeCompare(b.client_id))});
 }
 return Object.freeze({submitInput,step,snapshot});
}
