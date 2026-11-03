import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { load, position, plain, bool, array } from './runtime.mjs';
const MOVE = { dealer: 0, player: 1, adrenaline: 2, beer: 3, phone: 4, cigarettes: 5, medicine: 6, handcuffs: 7, saw: 8, inverter: 9, glass: 10 };
const { lib: L, close } = await load();
try {
const run = (input, fixed = false, depth = 18) => plain(L, L.search(bool(fixed), BigInt(depth), position(L, input, fixed)));
const cases = [
 [{}, 'dealer', '3/10', ['dealer'], 2],
 [{playerTurn:false}, 'dealer', '0/1', ['dealer','player'], 3],
 [{live:2,blank:2,playerItems:'m'}, 'glass','3/10',['glass','dealer'],10],
 [{maxHealth:4,dealerHp:2,playerHp:3,live:3,blank:1,shell:'live',playerItems:'s'},'saw','1/3',['saw','dealer'],8],
 [{maxHealth:4,dealerHp:2,playerHp:3,live:3,blank:1,shell:'live',playerItems:'s',sawed:true},'dealer','1/3',['dealer'],7],
 [{live:2,blank:1,playerItems:'h'},'handcuff','1/4',['handcuff','dealer','dealer'],6],
 [{live:2,blank:2,playerItems:'h',cuffs:1},'dealer','3/16',['dealer','handcuff','dealer'],9],
 [{live:2,blank:1,playerItems:'h',cuffs:2},'player','-1000000/1',['player'],1],
 [{live:2,blank:2,playerItems:'e',playerHp:2},'medicine','2/25',['medicine','dealer'],12],
 [{live:2,blank:2,dealerHp:0},null,'1/2',[],0],
 [{live:0,blank:2},null,'3/4',[],0],
 [{live:2,blank:2},null,'1/4',[],0,0],
 [{live:2,blank:2,playerItems:'hs'},'handcuff','1/4',['handcuff','dealer','saw','dealer'],39],
 [{live:3,blank:0},'dealer','0/1',['dealer','player','dealer'],13],
];
for (const [input,move,value,path,nodes,depth] of cases) {
 const result=run(input,false,depth??18);
 assert.deepEqual(result,{move,value,path,nodes}, JSON.stringify(input));
}
assert.deepEqual(run({dealerHp:0,playerHp:0}),{error:'divide by zero'});
assert.deepEqual(run({live:2,blank:2,playerItems:'b'}),{error:'item not found'});
assert.deepEqual(run({live:5,blank:4,playerItems:'f'}),{error:'phone index out of range'});
console.log(`reference: ${cases.length} exact results and 3 aborts pass`);

const state = (input = {}, fixed = true) => position(L,input,fixed);
const outcomes = (input,m,fixed=true) => {
 const result=L['model.outcomes'](bool(fixed),state(input,fixed),BigInt(m));
 assert.equal(result.$,'Done'); return array(result.value);
};
const rational = q => [q.negative ? -q.numerator : q.numerator,q.denominator];
const gcd = (a,b) => b===0n ? (a<0n?-a:a) : gcd(b,a%b);
const fraction = (n,d=1n) => { const g=gcd(n,d);return [n/g,d/g]; };
const add = ([a,b],[c,d]) => fraction(a*d+c*b,b*d);
const mul = ([a,b],[c,d]) => fraction(a*c,b*d);
const compare = ([a,b],[c,d]) => a*d-c*b;
const qvalue = result => { assert.equal(result.$,'Done'); return rational(result.value.value); };
const hp = (s,side) => side?s.player_hp:s.dealer_hp;
assert.equal(outcomes({playerHp:1},5)[0].state.player_hp,2n);
assert.equal(outcomes({playerHp:1},5,false)[0].state.player_hp,3n);
assert.equal(outcomes({},5)[0].state.player_hp,3n);
assert.equal(outcomes({},5,false)[0].state.player_hp,4n);
assert.equal(outcomes({playerHp:4},5)[0].state.player_hp,4n);
const med=outcomes({playerHp:2,live:2,blank:2},6);
assert.deepEqual(med.map(o=>rational(o.probability)),[[1n,2n],[1n,2n]]);
assert.deepEqual(med.map(o=>o.state.player_hp),[3n,1n]);
assert.deepEqual(outcomes({playerHp:2,live:2,blank:2},6,false).map(o=>o.state.player_hp),[3n,0n]);
assert.equal(outcomes({playerItems:'b'},3)[0].state.player_items.$,'Nil');
assert.ok(run({live:2,blank:2,playerItems:'b'},true).value);
assert.equal(outcomes({shell:'blank'},0).length,1);
assert.equal(outcomes({shell:'blank'},0)[0].state.dealer_hp,3n);
assert.equal(outcomes({shell:'blank'},0,false)[0].state.dealer_hp,2n);
assert.equal(outcomes({shell:'blank'},9)[0].state.slots.head,1n);
assert.equal(outcomes({shell:'blank'},9,false)[0].state.slots.head,2n);
const inverted=outcomes({live:1,blank:2,playerItems:'i'},9)[0].state;
assert.deepEqual(rational(L['model.chamber_probability'](inverted)),[2n,3n]);
const phon=outcomes({live:2,blank:2},4);
assert.ok(phon.every(o=>array(o.state.slots)[0]===0n));
assert.equal(outcomes({live:1,blank:1},4).length,2);
assert.ok(outcomes({live:1,blank:1},4).every(o=>array(o.state.slots)[1]!==0n));
assert.equal(outcomes({live:1,blank:1,playerTurn:false},4).length,1);
assert.ok(outcomes({live:1,blank:1,playerTurn:false},4).every(o=>array(o.state.slots).every(v=>v===0n)));
assert.deepEqual(phon.reduce((p,o)=>add(p,rational(o.probability)),[0n,1n]),[1n,1n]);
assert.deepEqual(outcomes({live:2,blank:2},4,false).reduce((p,o)=>add(p,rational(o.probability)),[0n,1n]),[2n,1n]);
assert.ok(run({live:2,blank:2,playerItems:'f'},true).value);
assert.equal(outcomes({live:1,blank:0,cuffs:2},0)[0].state.cuffs,1n);
assert.equal(outcomes({live:1,blank:0,cuffs:1},0)[0].state.player,false);
assert.equal(outcomes({live:1,blank:0,cuffs:1},0,false)[0].state.player,true);
assert.equal(outcomes({live:1,blank:0,sawed:true},3)[0].state.sawed,true);
const stealDead=state({playerItems:'a',dealerItems:'as',sawed:true});
assert.equal(array(L['model.candidates'](true,stealDead)).includes(2n),false);
assert.equal(array(L['model.candidates'](false,stealDead)).includes(2n),true);
assert.ok(array(L['model.candidates'](true,state({playerTurn:false}))).includes(1n));

assert.equal(outcomes({live:0,blank:1,cuffs:2},1)[0].state.cuffs,2n);
assert.equal(outcomes({live:0,blank:1,cuffs:2},1,false)[0].state.cuffs,1n);
{
 const [numerator,denominator]=run({live:2,blank:1,playerItems:'h',cuffs:2},true).value.split('/').map(BigInt);
 assert.ok(0n<=numerator&&numerator<=denominator&&denominator>0n,'a cuffed position scores like any leaf, between 0 and 1');
}
assert.equal(run({dealerHp:0,playerHp:0},true).value,'1/2');
assert.equal(L['heuristic.obvious'](true,state({playerTurn:false,dealerHp:1,playerHp:2,shell:'live',dealerItems:'s'})).value,8n);
assert.equal(L['heuristic.obvious'](false,state({playerTurn:false,dealerHp:1,playerHp:2,shell:'live',dealerItems:'s'},false)).value,1n);
// Spec 5.5: a contradicted known shell adds +-1,000,000 as one term; it does not replace the score.
const score=(input,m)=>rational(L['heuristic.score'](state(input,false),BigInt(m)));
const contradicted={live:2,blank:2,shell:'live',playerHp:2,dealerItems:'s'};
assert.deepEqual(score(contradicted,MOVE.saw),[-999860n,1n]);
assert.deepEqual(score(contradicted,MOVE.dealer),[90n,1n]);
assert.deepEqual(score({live:1,blank:0,shell:'live',dealerHp:0},MOVE.player),[100n,1n]);
// Input boundary: wrong types are rejected rather than coerced.
for (const fixed of [true, false]) {
 for (const bad of [{playerTurn:'false'},{playerTurn:0},{sawed:'false'},{sawed:1},{shell:'toString'},{shell:'__proto__'},{shell:1},{live:1.5},{blank:-1},{live:'2'}]) {
  assert.throws(() => position(L, bad, fixed), JSON.stringify(bad));
 }
}
const cli = (args, input = '{}') => spawnSync(process.execPath, [new URL('./cli.mjs', import.meta.url).pathname, ...args], { input, encoding: 'utf8' });
for (const args of [['--refrence','--depth=0'],['--depth='],['--depth=x'],['--depth=-1'],['--depth=1.5'],['--depth=0','extra']]) {
 assert.notEqual(cli(args).status, 0, args.join(' '));
}
assert.equal(cli(['--reference','--depth=0']).status, 0);

const glass=outcomes({live:1,blank:1},10)[0].state;
assert.equal(glass.live,0n);
assert.equal(L['state.total'](glass),2n);
assert.equal(L['model.outcomes'](true,glass,0n).value.head.state.live,0n);
assert.equal(L['model.outcomes'](true,glass,0n).value.head.state.dealer_hp,2n);
const sOrder=state({live:2,blank:2,playerItems:'hs'},false);
const ranked=L['heuristic.ordered'](L['model.candidates'](false,sOrder),sOrder);
assert.equal(ranked.$,'Done');
assert.deepEqual(array(ranked.value).map(x=>[x.move,L['rational.show'](x.key)]),[[0n,'152/3'],[1n,'220/3'],[7n,'301/2'],[8n,'301/2']]);

// Exhaustive finite generators cover both turns, all small load compositions,
// known chambers and each item. No sampling or external service is needed.
let arithmeticCases=0;
for(let a=-6;a<=6;a++) for(let b=1;b<=6;b++) for(let c=-4;c<=4;c++) for(let d=1;d<=4;d++) {
 const x=L['rational.make'](a<0,BigInt(Math.abs(a)),BigInt(b));
 const y=L['rational.make'](c<0,BigInt(Math.abs(c)),BigInt(d));
 assert.deepEqual(rational(L['rational.add'](x,y)),add(fraction(BigInt(a),BigInt(b)),fraction(BigInt(c),BigInt(d))));
 assert.deepEqual(rational(L['rational.mul'](x,y)),mul(fraction(BigInt(a),BigInt(b)),fraction(BigInt(c),BigInt(d))));
 assert.equal(L['rational.lt'](x,y),BigInt(a)*BigInt(d)<BigInt(c)*BigInt(b));arithmeticCases++;
}
let probabilityCases=0, countCases=0, valueCases=0, expectationCases=0;
for(let live=0;live<=3;live++) for(let blank=0;blank<=3;blank++) {
 if(live+blank===0) continue;
 for(const shell of ['unknown',...(live?['live']:[]),...(blank?['blank']:[])]) {
  for(const playerTurn of [true,false]) {
   const input={live,blank,shell,playerTurn,playerHp:2,dealerHp:2,maxHealth:3};
   const s=state(input);
   for(let m=0;m<=10;m++) {
    const xs=array(L['model.outcomes'](true,s,BigInt(m)).value);
    assert.deepEqual(xs.reduce((p,o)=>add(p,rational(o.probability)),[0n,1n]),[1n,1n]); probabilityCases++;
    for(const o of xs) {
     const total=L['state.total'](o.state);
     assert.equal(total,L['state.total'](s)-([0,1,3].includes(m)?1n:0n));
     assert.ok(o.state.live>=0n && o.state.blank>=0n);
     const physical=(st,t)=>st[t===1?'live':'blank']+BigInt(array(st.slots).filter(x=>x===BigInt(t)).length);
     if(![0,1,3,9].includes(m)) {
      assert.equal(physical(o.state,1),physical(s,1));
      assert.equal(physical(o.state,2),physical(s,2));
     }
     if([0,1,3].includes(m)) {
      const lostLive=physical(s,1)-physical(o.state,1);
      const lostBlank=physical(s,2)-physical(o.state,2);
      assert.ok(lostLive===0n||lostLive===1n);
      assert.ok(lostBlank===0n||lostBlank===1n);
      assert.equal(lostLive+lostBlank,1n);
     }
     assert.equal(o.state.weight.numerator,1n);countCases++;
    }
   }
   const v=qvalue(L.search(true,2n,s));
   assert.ok(compare(v,[0n,1n])>=0n&&compare(v,[1n,1n])<=0n);valueCases++;
  }
 }
}
// A second traversal averages every outcome of the model's candidates and
// outcomes, which the loops above check on their own. No alpha/beta or
// production search helper participates, so it checks the search against the
// Bellman equation, not the transition model.
function brute(s,depth) {
 if(depth===0||s.player_hp===0n||s.dealer_hp===0n||L['state.total'](s)===0n) {
  if(s.player_hp+s.dealer_hp===0n)return [1n,2n];
  if(s.dealer_hp===0n)return [1n,1n];
  return fraction(s.player_hp,s.player_hp+s.dealer_hp);
 }
 const values=array(L['model.candidates'](true,s)).map(m=> {
  const os=array(L['model.outcomes'](true,s,m).value);
  return os.reduce((a,o)=>add(a,mul(rational(o.probability),brute(o.state,depth-(m<=1n?1:0)))),[0n,1n]);
 });
 assert.ok(values.length);
 return values.reduce((a,b)=>(s.player?compare(a,b)<0n:compare(a,b)>0n)?b:a);
}
for(const playerTurn of [true,false]) for(let live=0;live<=2;live++) for(let blank=0;blank<=2;blank++) {
 for(const item of ['', 'm','e','h','s','i','b','f','a']) {
  const s=state({playerTurn,live,blank,playerHp:2,dealerHp:2,playerItems:item,dealerItems:item==='a'?'c':''});
  assert.deepEqual(qvalue(L.search(true,2n,s)),brute(s,2));expectationCases++;
 }
}
console.log(`fixed: ${probabilityCases} normalized distributions, ${countCases} shell-count checks, ${valueCases} bounded values, ${expectationCases} brute-force expectations; differential item/abort tests pass`);

} finally { close(); }
