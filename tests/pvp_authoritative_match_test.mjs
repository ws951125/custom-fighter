import assert from 'node:assert/strict';
import {createAuthoritativeMatch,validateInputIntent} from '../backend/pvp/authoritative_match.mjs';
const match={match_id:'match_1',status:'active',participants:[
 {client_id:'a',authority:{character_id:'ember_vanguard_001'}},
 {client_id:'b',authority:{character_id:'storm_duelist_001'}}
]};
const game=createAuthoritativeMatch({match,loadoutResolver:a=>({max_hp:a.character_id.startsWith('ember')?100:90,max_mp:100})});
const valid={sequence:1,move_x:1,move_y:0,run:false,jump:false,guard:false,action:'none'};
assert.equal(validateInputIntent(valid).ok,true);
assert.equal(validateInputIntent({...valid,damage:999}).code,'INPUT_FIELDS_INVALID');
assert.equal(validateInputIntent({...valid,sequence:0}).code,'INPUT_SEQUENCE_INVALID');
assert.equal(validateInputIntent({...valid,move_x:2}).code,'INPUT_AXIS_INVALID');
assert.equal(validateInputIntent({...valid,action:'set_hp'}).code,'INPUT_ACTION_INVALID');
assert.equal(game.submitInput('a',valid).ok,true);
assert.equal(game.submitInput('a',valid).code,'INPUT_SEQUENCE_STALE');
assert.equal(game.submitInput('missing',valid).code,'CLIENT_NOT_IN_MATCH');
const first=game.step();
assert.equal(first.tick,1); assert.equal(first.tick_rate,60);
assert.equal(first.participants[0].x,1); assert.equal(first.participants[0].hp,100);
first.participants[0].hp=0; first.participants[0].x=999;
const immutable=game.snapshot();
assert.equal(immutable.participants[0].hp,100); assert.equal(immutable.participants[0].x,1);
assert.equal(game.submitInput('a',{...valid,sequence:2,move_x:-1,guard:true}).ok,true);
assert.equal(game.submitInput('b',{...valid,sequence:1,move_y:1}).ok,true);
const second=game.step();
assert.equal(second.tick,2); assert.equal(second.participants[0].x,0); assert.equal(second.participants[0].guarding,true);
assert.equal(second.participants[1].y,1);
assert.equal(game.step().tick,3);
assert.equal(game.snapshot().participants[0].last_input_sequence,2);
console.log('PVP_AUTHORITATIVE_MATCH_TESTS_PASSED');
