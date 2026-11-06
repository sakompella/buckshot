//! The Bend branches the rules mirror: one variant per Bend case, named
//! `<Module><Def><Case>`. Each Rust match arm starts with `branch!` naming
//! its variant. Under the `trace` feature the arms taken are recorded.

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum B {
    /// `simple/point:option.move:T.ShootAt{target}`
    SimplePointOptionMoveShootAt,
    /// `simple/point:option.move:T.UseSlot{_, item}`
    SimplePointOptionMoveUseSlot,
    /// `simple/point:option.move:T.JamWith{_, target}`
    SimplePointOptionMoveJamWith,
    /// `simple/point:option.move:T.StealWith{_, owner, _, item}`
    SimplePointOptionMoveStealWith,
    /// `simple/point:option.move:T.StealJamWith{_, owner, _, target}`
    SimplePointOptionMoveStealJamWith,
    /// `simple/main:answer.draw:T.State{world, players, T.NeedFirst{}, notes, grabs}`
    SimpleMainAnswerDrawNeedFirst,
    /// `simple/main:answer.draw:T.State{world, players, T.NeedHealth{}, notes, grabs}`
    SimpleMainAnswerDrawNeedHealth,
    /// `simple/main:answer.draw:T.State{world, players, T.NeedAmount{}, notes, grabs}`
    SimpleMainAnswerDrawNeedAmount,
    /// `simple/main:answer.draw:T.State{world, players, T.NeedBatch{}, notes, grabs}`
    SimpleMainAnswerDrawNeedBatch,
    /// `simple/main:answer.draw:T.State{world, players, T.NeedSwap{load, shells, +i}, notes, grabs}`
    SimpleMainAnswerDrawNeedSwap,
    /// `simple/main:answer.draw:T.State{world, players, T.NeedTurnAmount{from, passing, winner}, notes, grabs}`
    SimpleMainAnswerDrawNeedTurnAmount,
    /// `simple/main:answer.draw:T.State{world, players, T.NeedItem{+seat, first, second, rest}, notes, grabs}`
    SimpleMainAnswerDrawNeedItem,
    /// `simple/main:answer.draw:T.State{world, players, T.NeedPhone{seat, owner, slot}, notes, grabs}`
    SimpleMainAnswerDrawNeedPhone,
    /// `simple/main:answer.draw:_`
    SimpleMainAnswerDrawAny,
    /// `simple/main:answer.choice:T.State{world, players, T.Idle{+seat}, notes, grabs}`
    SimpleMainAnswerChoiceIdle,
    /// `simple/main:answer.choice:_`
    SimpleMainAnswerChoiceAny,
    /// `simple/main:grant.step:rank S.Act{players}`
    SimpleMainGrantStepAct,
    /// `simple/main:grant.step:rank S.Lift{players}`
    SimpleMainGrantStepLift,
    /// `simple/main:grant.step:0n S.Skip{players}`
    SimpleMainGrantStepZeroSkip,
    /// `simple/main:grant.step:1n+rest S.Skip{+players}`
    SimpleMainGrantStepSuccSkip,
    /// `simple/main:shuffle:0n`
    SimpleMainShuffleZero,
    /// `simple/main:shuffle:1n+rest`
    SimpleMainShuffleSucc,
    /// `simple/main:batch.found:None{}`
    SimpleMainBatchFoundNone,
    /// `simple/main:batch.found:Some{S.Batch{_, sampled}}`
    SimpleMainBatchFoundSomeBatch,
    /// `simple/main:load.ready:Nil{}`
    SimpleMainLoadReadyNil,
    /// `simple/main:load.ready:only <> Nil{}`
    SimpleMainLoadReadyConsNil,
    /// `simple/main:load.ready:first <> next <> rest`
    SimpleMainLoadReadyConsCons,
    /// `simple/main:load.refill:Nil{}`
    SimpleMainLoadRefillNil,
    /// `simple/main:load.refill:deck`
    SimpleMainLoadRefillAny,
    /// `simple/main:grab.check.done:True{}`
    SimpleMainGrabCheckDoneTrue,
    /// `simple/main:grab.check.done:False{}`
    SimpleMainGrabCheckDoneFalse,
    /// `simple/main:grab.end_all:+seat <> rest`
    SimpleMainGrabEndAllCons,
    /// `simple/main:grab.end_all:Nil{}`
    SimpleMainGrabEndAllNil,
    /// `simple/main:grab.put.held:None{}`
    SimpleMainGrabPutHeldNone,
    /// `simple/main:grab.put.held:Some{+item}`
    SimpleMainGrabPutHeldSome,
    /// `simple/main:grab.place.last:True{}`
    SimpleMainGrabPlaceLastTrue,
    /// `simple/main:grab.place.last:False{}`
    SimpleMainGrabPlaceLastFalse,
    /// `simple/main:grab.chosen:Some{item}`
    SimpleMainGrabChosenSome,
    /// `simple/main:grab.chosen:None{}`
    SimpleMainGrabChosenNone,
    /// `simple/main:grab.pool:Nil{}`
    SimpleMainGrabPoolNil,
    /// `simple/main:grab.pool:item <> Nil{}`
    SimpleMainGrabPoolConsNil,
    /// `simple/main:grab.pool:first <> second <> rest`
    SimpleMainGrabPoolConsCons,
    /// `simple/main:grab.takes:S.TakeItem{} <> Nil{}`
    SimpleMainGrabTakesTakeItemConsNil,
    /// `simple/main:grab.takes:_`
    SimpleMainGrabTakesAny,
    /// `simple/main:grab.act.own:S.PutAt{slot} <> _`
    SimpleMainGrabActOwnPutAtCons,
    /// `simple/main:grab.act.own:_`
    SimpleMainGrabActOwnAny,
    /// `simple/main:grab.taker:+seat <> rest`
    SimpleMainGrabTakerCons,
    /// `simple/main:grab.taker:Nil{}`
    SimpleMainGrabTakerNil,
    /// `simple/main:grab.continue.ready:False{} False{}`
    SimpleMainGrabContinueReadyFalseFalse,
    /// `simple/main:grab.continue.ready:_ _`
    SimpleMainGrabContinueReadyAny,
    /// `simple/main:grab.next:first <> second <> rest`
    SimpleMainGrabNextConsCons,
    /// `simple/main:grab.next:_`
    SimpleMainGrabNextAny,
    /// `simple/main:grab.loop:_ Drawing{}`
    SimpleMainGrabLoopDrawing,
    /// `simple/main:grab.loop:_ Loading{}`
    SimpleMainGrabLoopLoading,
    /// `simple/main:grab.loop:_ NoTaker{}`
    SimpleMainGrabLoopNoTaker,
    /// `simple/main:grab.loop:0n Taking{_}`
    SimpleMainGrabLoopZeroTaking,
    /// `simple/main:grab.loop:0n Placing{_, _}`
    SimpleMainGrabLoopZeroPlacing,
    /// `simple/main:grab.loop:1n+fuel Taking{+seat}`
    SimpleMainGrabLoopSuccTaking,
    /// `simple/main:grab.loop:1n+fuel Placing{+seat, +slot}`
    SimpleMainGrabLoopSuccPlacing,
    /// `simple/main:distribute.begin:Nil{}`
    SimpleMainDistributeBeginNil,
    /// `simple/main:distribute.begin:+seat <> +rest`
    SimpleMainDistributeBeginCons,
    /// `simple/main:amount.rule:D.RandomAmount{}`
    SimpleMainAmountRuleRandomAmount,
    /// `simple/main:amount.rule:D.FixedAmount{amount}`
    SimpleMainAmountRuleFixedAmount,
    /// `simple/main:health.rule:D.RandomHealth{}`
    SimpleMainHealthRuleRandomHealth,
    /// `simple/main:health.rule:D.FixedHealth{health}`
    SimpleMainHealthRuleFixedHealth,
    /// `simple/main:first.override:None{}`
    SimpleMainFirstOverrideNone,
    /// `simple/main:first.override:Some{seat}`
    SimpleMainFirstOverrideSome,
    /// `simple/main:win.final:True{}`
    SimpleMainWinFinalTrue,
    /// `simple/main:win.final:False{}`
    SimpleMainWinFinalFalse,
    /// `simple/main:turn.winner:Some{seat}`
    SimpleMainTurnWinnerSome,
    /// `simple/main:turn.winner:None{}`
    SimpleMainTurnWinnerNone,
    /// `simple/main:turn.recipient:True{}`
    SimpleMainTurnRecipientTrue,
    /// `simple/main:turn.recipient:False{}`
    SimpleMainTurnRecipientFalse,
    /// `simple/main:turn.continue:Nil{}`
    SimpleMainTurnContinueNil,
    /// `simple/main:turn.continue:shell <> rest`
    SimpleMainTurnContinueCons,
    /// `simple/main:turn.live:True{}`
    SimpleMainTurnLiveTrue,
    /// `simple/main:turn.live:False{}`
    SimpleMainTurnLiveFalse,
    /// `simple/main:turn.amount:D.RandomAmount{}`
    SimpleMainTurnAmountRandomAmount,
    /// `simple/main:turn.amount:D.FixedAmount{amount}`
    SimpleMainTurnAmountFixedAmount,
    /// `simple/main:death:D.Live{} 0n`
    SimpleMainDeathLiveZero,
    /// `simple/main:death.remember:True{}`
    SimpleMainDeathRememberTrue,
    /// `simple/main:death.remember:False{}`
    SimpleMainDeathRememberFalse,
    /// `simple/main:death:_ _`
    SimpleMainDeathAny,
    /// `simple/main:shoot.gun:Nil{}`
    SimpleMainShootGunNil,
    /// `simple/main:shoot.gun:shell <> rest`
    SimpleMainShootGunCons,
    /// `simple/main:item.end:True{}`
    SimpleMainItemEndTrue,
    /// `simple/main:item.end:False{}`
    SimpleMainItemEndFalse,
    /// `simple/main:item.shell:Nil{}`
    SimpleMainItemShellNil,
    /// `simple/main:item.shell:+shell <> rest`
    SimpleMainItemShellCons,
    /// `simple/main:item.chamber:D.Glass{}`
    SimpleMainItemChamberGlass,
    /// `simple/main:item.chamber:D.Beer{}`
    SimpleMainItemChamberBeer,
    /// `simple/main:item.chamber:D.Inverter{}`
    SimpleMainItemChamberInverter,
    /// `simple/main:item.chamber:_`
    SimpleMainItemChamberAny,
    /// `simple/main:item.effect:D.Saw{}`
    SimpleMainItemEffectSaw,
    /// `simple/main:item.effect:D.Jammer{}`
    SimpleMainItemEffectJammer,
    /// `simple/main:item.effect:D.Cigarettes{}`
    SimpleMainItemEffectCigarettes,
    /// `simple/main:item.heal:True{}`
    SimpleMainItemHealTrue,
    /// `simple/main:item.heal:False{}`
    SimpleMainItemHealFalse,
    /// `simple/main:item.effect:D.Phone{}`
    SimpleMainItemEffectPhone,
    /// `simple/main:item.tell:None{}`
    SimpleMainItemTellNone,
    /// `simple/main:item.tell:Some{secret}`
    SimpleMainItemTellSome,
    /// `simple/main:item.effect:D.Adrenaline{}`
    SimpleMainItemEffectAdrenaline,
    /// `simple/main:item.effect:D.Remote{}`
    SimpleMainItemEffectRemote,
    /// `simple/main:item.effect:D.Glass{}`
    SimpleMainItemEffectGlass,
    /// `simple/main:item.effect:D.Beer{}`
    SimpleMainItemEffectBeer,
    /// `simple/main:item.effect:D.Inverter{}`
    SimpleMainItemEffectInverter,
    /// `simple/main:item.clue.found:None{}`
    SimpleMainItemClueFoundNone,
    /// `simple/main:item.clue.found:Some{shell}`
    SimpleMainItemClueFoundSome,
    /// `simple/main:item.route:D.Phone{}`
    SimpleMainItemRoutePhone,
    /// `simple/main:item.phone:0n|1n|2n`
    SimpleMainItemPhoneZeroOneTwo,
    /// `simple/main:item.phone:3n`
    SimpleMainItemPhoneThree,
    /// `simple/main:item.phone:_`
    SimpleMainItemPhoneAny,
    /// `simple/main:item.route:item`
    SimpleMainItemRouteAny,
    /// `simple/main:pickup.selected:Some{T.ShootAt{target}}`
    SimpleMainPickupSelectedSomeShootAt,
    /// `simple/main:pickup.selected:Some{T.UseSlot{slot, item}}`
    SimpleMainPickupSelectedSomeUseSlot,
    /// `simple/main:pickup.selected:Some{T.JamWith{slot, target}}`
    SimpleMainPickupSelectedSomeJamWith,
    /// `simple/main:pickup.selected:Some{T.StealWith{adrenaline, owner, slot, item}}`
    SimpleMainPickupSelectedSomeStealWith,
    /// `simple/main:pickup.selected:Some{T.StealJamWith{adrenaline, owner, slot, target}}`
    SimpleMainPickupSelectedSomeStealJamWith,
    /// `simple/main:pickup.selected:None{}`
    SimpleMainPickupSelectedNone,
}

#[cfg(feature = "trace")]
thread_local! {
    static TRACE: core::cell::RefCell<Vec<B>> = const { core::cell::RefCell::new(Vec::new()) };
}

#[cfg(feature = "trace")]
pub(crate) fn record(branch: B) {
    TRACE.with(|trace| trace.borrow_mut().push(branch));
}

/// The branches taken on this thread since the last call.
#[cfg(feature = "trace")]
#[must_use]
pub fn take_trace() -> Vec<B> {
    TRACE.with(|trace| core::mem::take(&mut *trace.borrow_mut()))
}
