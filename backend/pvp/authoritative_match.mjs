const INPUT_KEYS = new Set(['sequence','move_x','move_y','run','jump','guard','action']);
const ACTIONS = new Set(['none','basic_attack','dash',...Array.from({length:13},(_,i)=>`skill_${i+1}`)]);
const MAX_SEQUENCE = Number.MAX_SAFE_INTEGER;
const TICK_RATE = 60;

function fail(code, extra={}) { return {ok:false,code,...extra}; }
function clone(value){ return JSON.parse(JSON.stringify(value)); }
function exactKeys(value, allowed){ return value && typeof value==='object' && !Array.isArray(value) && Object.keys(value).every(k=>allowed.has(k)); }
function axis(value){ return Number.isInteger(value) && value>=-1 && value<=1; }

export function validateInputIntent(raw){
  if(!exactKeys(raw,INPUT_KEYS)) return fail('INPUT_FIELDS_INVALID');
  if(!Number.isSafeInteger(raw.sequence)||raw.sequence<1||raw.sequence>MAX_SEQUENCE) return fail('INPUT_SEQUENCE_INVALID');
  if(!axis(raw.move_x)||!axis(raw.move_y)) return fail('INPUT_AXIS_INVALID');
  if(typeof raw.run!=='boolean'||typeof raw.jump!=='boolean'||typeof raw.guard!=='boolean') return fail('INPUT_FLAG_INVALID');
  if(typeof raw.action!=='string'||!ACTIONS.has(raw.action)) return fail('INPUT_ACTION_INVALID');
  return {ok:true,input:Object.freeze({...raw})};
}

export function createAuthoritativeMatch({match, loadoutResolver}={}){
  if(!match||match.status!=='active'||!Array.isArray(match.participants)||match.participants.length!==2) throw new TypeError('active two-player match required');
  if(typeof loadoutResolver!=='function') throw new TypeError('loadoutResolver required');
  let tick=0;
  const players=new Map();
  for(const p of match.participants){
    const loadout=loadoutResolver(p.authority);
    if(!loadout||!Number.isFinite(loadout.max_hp)||!Number.isFinite(loadout.max_mp)) throw new TypeError('authoritative loadout required');
    players.set(p.client_id,{client_id:p.client_id,character_id:p.authority.character_id,hp:loadout.max_hp,mp:loadout.max_mp,x:0,y:0,guarding:false,last_input_sequence:0,pending:null,cooldowns:{}});
  }
  function submitInput(clientId,raw){
    const player=players.get(clientId); if(!player) return fail('CLIENT_NOT_IN_MATCH');
    const v=validateInputIntent(raw); if(!v.ok) return v;
    if(v.input.sequence<=player.last_input_sequence) return fail('INPUT_SEQUENCE_STALE',{last_sequence:player.last_input_sequence});
    player.last_input_sequence=v.input.sequence; player.pending=v.input; return {ok:true,accepted_sequence:v.input.sequence};
  }
  function step(){
    tick+=1;
    for(const p of players.values()){
      const input=p.pending; if(!input) continue;
      p.x+=input.move_x; p.y+=input.move_y; p.guarding=input.guard;
      p.pending=null;
    }
    return snapshot();
  }
  function snapshot(){
    return clone({match_id:match.match_id,status:'active',tick,tick_rate:TICK_RATE,participants:[...players.values()].map(p=>({client_id:p.client_id,character_id:p.character_id,hp:p.hp,mp:p.mp,x:p.x,y:p.y,guarding:p.guarding,last_input_sequence:p.last_input_sequence,cooldowns:p.cooldowns}))});
  }
  return Object.freeze({submitInput,step,snapshot});
}
