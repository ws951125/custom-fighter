import assert from 'node:assert/strict';
import { createAuthoritativeMatch } from '../backend/pvp/authoritative_match.mjs';

const auth=id=>({character_id:id});
const match={match_id:'m1',status:'active',participants:[
 {client_id:'a',authority:auth('ember_vanguard_001')},
 {client_id:'b',authority:auth('storm_duelist_001')}
]};
const loadoutResolver=authority=>authority.character_id==='ember_vanguard_001'
 ? {max_hp:120,max_mp:80}
 : {max_hp:90,max_mp:110};

assert.throws(()=>createAuthoritativeMatch({match}),/AUTHORITATIVE_LOADOUT_RESOLVER_REQUIRED/);
assert.throws(
 ()=>createAuthoritativeMatch({match,loadoutResolver:()=>({max_hp:999,max_mp:100})}),
 /AUTHORITATIVE_LOADOUT_INVALID/
);

const orderingSim=createAuthoritativeMatch({match,loadoutResolver});
assert.equal(orderingSim.submitInput('a',{sequence:1,target_tick:2,actions:[]}).ok,true);
assert.equal(orderingSim.submitInput('a',{sequence:2,target_tick:1,actions:[]}).code,'INPUT_TICK_STALE');
assert.equal(orderingSim.submitInput('a',{sequence:2,target_tick:2,actions:[]}).code,'INPUT_TICK_STALE');

const sim=createAuthoritativeMatch({match,loadoutResolver});
const initial=sim.snapshot();
assert.equal(initial.tick,0);
assert.equal(initial.players.find(p=>p.client_id==='a').hp,120);
assert.equal(initial.players.find(p=>p.client_id==='a').mp,80);
assert.equal(initial.players.find(p=>p.client_id==='b').hp,90);
assert.equal(initial.players.find(p=>p.client_id==='b').mp,110);
assert.equal(sim.submitInput('x',{sequence:1,target_tick:1,actions:[]}).code,'PLAYER_NOT_IN_MATCH');
assert.equal(sim.submitInput('a',{sequence:1,target_tick:1,actions:['move_right'],damage:999}).code,'INPUT_FIELDS_INVALID');
assert.equal(sim.submitInput('a',{sequence:1,target_tick:1,actions:['move_right','run']}).ok,true);
assert.equal(sim.submitInput('a',{sequence:1,target_tick:2,actions:[]}).code,'INPUT_SEQUENCE_INVALID');

let s=sim.step();
let a=s.players.find(p=>p.client_id==='a');
let b=s.players.find(p=>p.client_id==='b');
assert.equal(a.x,-4);

assert.equal(sim.submitInput('a',{sequence:2,target_tick:2,actions:['basic_attack']}).ok,true);
assert.equal(sim.submitInput('b',{sequence:1,target_tick:2,actions:['move_left','run']}).ok,true);
s=sim.step();
b=s.players.find(p=>p.client_id==='b');
assert.equal(b.x,4);
assert.equal(b.hp,90,'out-of-range attack must not damage');

assert.equal(sim.submitInput('a',{sequence:3,target_tick:3,actions:['move_right','run']}).ok,true);
assert.equal(sim.submitInput('b',{sequence:2,target_tick:3,actions:['move_left','run']}).ok,true);
sim.step();

assert.equal(sim.submitInput('a',{sequence:4,target_tick:4,actions:['move_right']}).ok,true);
assert.equal(sim.submitInput('b',{sequence:3,target_tick:4,actions:['move_left']}).ok,true);
s=sim.step();
a=s.players.find(p=>p.client_id==='a');
b=s.players.find(p=>p.client_id==='b');
assert.equal(a.x,-1);
assert.equal(b.x,1);

assert.equal(sim.submitInput('a',{sequence:5,target_tick:5,actions:['basic_attack']}).ok,true);
s=sim.step();
b=s.players.find(p=>p.client_id==='b');
assert.equal(b.hp,90,'cooldown is server-owned and blocks early repeat');

while((sim.snapshot().players.find(p=>p.client_id==='a').cooldowns.basic_attack??0)>0) sim.step();
const target=sim.snapshot().tick+1;
assert.equal(sim.submitInput('b',{sequence:4,target_tick:target,actions:['guard']}).ok,true);
assert.equal(sim.submitInput('a',{sequence:6,target_tick:target,actions:['basic_attack']}).ok,true);
s=sim.step();
b=s.players.find(p=>p.client_id==='b');
assert.equal(b.guarding,true);
assert.equal(b.hp,85,'same-tick guard must be applied before authority resolves attack damage');

const copy=sim.snapshot();
copy.players[0].hp=0;
assert.notEqual(sim.snapshot().players[0].hp,0);
assert.equal(sim.submitInput('a',{sequence:7,target_tick:sim.snapshot().tick+99,actions:[]}).code,'INPUT_TICK_INVALID');
assert.equal(sim.submitInput('a',{sequence:7,target_tick:sim.snapshot().tick+1,actions:['cheat_damage']}).code,'INPUT_ACTION_INVALID');
console.log('PVP_AUTHORITATIVE_MATCH_TESTS_PASSED');
