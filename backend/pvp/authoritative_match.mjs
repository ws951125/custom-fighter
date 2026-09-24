const TICK_RATE=60;
const MAX_INPUT_LEAD=6;
const ACTIONS=new Set(['move_left','move_right','move_up','move_down','run','jump','basic_attack','dash','guard','skill_1','skill_2','skill_3','skill_4','skill_5','skill_6','skill_7','skill_8','skill_9','skill_10','skill_11','skill_12','skill_13']);
const clamp=(n,min,max)=>Math.max(min,Math.min(max,n));
const clone=v=>structuredClone(v);
const fail=(code,details={})=>({ok:false,code,...details});

function initialPlayer(participant,index){
 return {
  client_id:participant.client_id,character_id:participant.authority.character_id,
  hp:100,mp:100,x:index===0?-6:6,y:0,facing:index===0?1:-1,
  guarding:false,cooldowns:{},last_input_sequence:0
 };
}

export function createAuthoritativeMatch({match}){
 if(!match||match.status!=='active'||!Array.isArray(match.participants)||match.participants.length!==2) throw new Error('ACTIVE_TWO_PLAYER_MATCH_REQUIRED');
 let tick=0,finished=false,winner=null;
 const players=new Map(match.participants.map((p,i)=>[p.client_id,initialPlayer(p,i)]));
 const pending=new Map();

 function submitInput(clientId,input){
  const p=players.get(clientId); if(!p)return fail('PLAYER_NOT_IN_MATCH');
  if(finished)return fail('MATCH_FINISHED');
  if(!input||typeof input!=='object'||Array.isArray(input))return fail('INPUT_INVALID');
  const allowed=['sequence','target_tick','actions'];
  if(Object.keys(input).some(k=>!allowed.includes(k)))return fail('INPUT_FIELDS_INVALID');
  if(!Number.isInteger(input.sequence)||input.sequence<=p.last_input_sequence)return fail('INPUT_SEQUENCE_INVALID');
  if(!Number.isInteger(input.target_tick)||input.target_tick<tick+1||input.target_tick>tick+MAX_INPUT_LEAD)return fail('INPUT_TICK_INVALID');
  if(!Array.isArray(input.actions)||input.actions.length>8||input.actions.some(a=>!ACTIONS.has(a)))return fail('INPUT_ACTION_INVALID');
  // Client proposals are intents only; combat facts such as damage/hp/cooldown are not accepted fields.
  p.last_input_sequence=input.sequence;
  if(!pending.has(input.target_tick))pending.set(input.target_tick,[]);
  pending.get(input.target_tick).push({client_id:clientId,sequence:input.sequence,actions:[...new Set(input.actions)]});
  return {ok:true,accepted_sequence:input.sequence,target_tick:input.target_tick};
 }

 function step(){
  if(finished)return snapshot();
  tick+=1;
  const inputs=(pending.get(tick)||[]).sort((a,b)=>a.client_id.localeCompare(b.client_id)||a.sequence-b.sequence);
  pending.delete(tick);
  for(const item of inputs)apply(players.get(item.client_id),item.actions);
  for(const p of players.values()){
   for(const [k,v] of Object.entries(p.cooldowns))p.cooldowns[k]=Math.max(0,v-1);
  }
  return snapshot();
 }

 function apply(p,actions){
  const speed=actions.includes('run')?2:1;
  if(actions.includes('move_left'))p.x=clamp(p.x-speed,-20,20);
  if(actions.includes('move_right'))p.x=clamp(p.x+speed,-20,20);
  if(actions.includes('move_up'))p.y=clamp(p.y-1,-5,5);
  if(actions.includes('move_down'))p.y=clamp(p.y+1,-5,5);
  p.guarding=actions.includes('guard');
  const opponent=[...players.values()].find(x=>x.client_id!==p.client_id);
  if(actions.includes('basic_attack')&&p.cooldowns.basic_attack===0||actions.includes('basic_attack')&&p.cooldowns.basic_attack==null){
   p.cooldowns.basic_attack=30;
   const distance=Math.abs(p.x-opponent.x);
   if(distance<=3){
    const damage=opponent.guarding?5:10;
    opponent.hp=Math.max(0,opponent.hp-damage);
    if(opponent.hp===0){finished=true;winner=p.client_id;}
   }
  }
 }

 function snapshot(){
  return clone({match_id:match.match_id,tick,tick_rate:TICK_RATE,status:finished?'finished':'active',winner_client_id:winner,players:[...players.values()].sort((a,b)=>a.client_id.localeCompare(b.client_id))});
 }
 return Object.freeze({submitInput,step,snapshot});
}
