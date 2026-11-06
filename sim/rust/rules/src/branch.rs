//! The Bend branches the rules mirror: one variant per Bend case, named
//! `<Module><Def><Case>`. Each Rust match arm starts with `branch!` naming
//! its variant. Under the `trace` feature the arms taken are recorded.

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum B {
    /// `sm/items:keep:True{}`
    SmItemsKeepTrue,
    /// `sm/items:keep:False{}`
    SmItemsKeepFalse,
    /// `sm/items:is_none:None{}`
    SmItemsIsNoneNone,
    /// `sm/items:is_none:Some{item}`
    SmItemsIsNoneSome,
    /// `sm/items:has_items:Nil{}`
    SmItemsHasItemsNil,
    /// `sm/items:has_items:x <> rest`
    SmItemsHasItemsCons,
    /// `sm/items:has_seats:Nil{}`
    SmItemsHasSeatsNil,
    /// `sm/items:has_seats:x <> rest`
    SmItemsHasSeatsCons,
    /// `sm/items:slots.items:D.Slots{a, b, c, d, e, f, g, h}`
    SmItemsSlotsItemsSlots,
    /// `sm/items:occupied:None{} <> rest`
    SmItemsOccupiedNoneCons,
    /// `sm/items:occupied:Some{item} <> rest`
    SmItemsOccupiedSomeCons,
    /// `sm/items:occupied:Nil{}`
    SmItemsOccupiedNil,
    /// `sm/items:bool.nat:True{}`
    SmItemsBoolNatTrue,
    /// `sm/items:bool.nat:False{}`
    SmItemsBoolNatFalse,
    /// `sm/items:copies.one:None{}`
    SmItemsCopiesOneNone,
    /// `sm/items:copies.one:Some{actual}`
    SmItemsCopiesOneSome,
    /// `sm/items:copies:x <> rest`
    SmItemsCopiesCons,
    /// `sm/items:copies:Nil{}`
    SmItemsCopiesNil,
    /// `sm/items:grabs.open:S.Grabs{distributing, grabbing, holding, granted, intake}`
    SmItemsGrabsOpenGrabs,
    /// `sm/items:grabs.open_all:seat <> rest`
    SmItemsGrabsOpenAllCons,
    /// `sm/items:grabs.open_all:Nil{}`
    SmItemsGrabsOpenAllNil,
    /// `sm/items:grabs.stop_intake:S.Grabs{distributing, grabbing, holding, granted, intake}`
    SmItemsGrabsStopIntakeGrabs,
    /// `sm/items:grabs.give:S.Grabs{distributing, grabbing, holding, granted, intake}`
    SmItemsGrabsGiveGrabs,
    /// `sm/items:grabs.close:S.Grabs{distributing, grabbing, holding, granted, intake}`
    SmItemsGrabsCloseGrabs,
    /// `sm/items:grabs.placed:S.Grabs{distributing, grabbing, holding, granted, intake}`
    SmItemsGrabsPlacedGrabs,
    /// `sm/items:owned.table:seat <> rest`
    SmItemsOwnedTableCons,
    /// `sm/items:owned.table:Nil{}`
    SmItemsOwnedTableNil,
    /// `sm/items:stock.open:D.ItemRule{enabled, per_player, on_table}`
    SmItemsStockOpenItemRule,
    /// `sm/items:round.items:D.RoundRules{_, _, items}`
    SmItemsRoundItemsRoundRules,
    /// `sm/items:pool.go:+item <> rest`
    SmItemsPoolGoCons,
    /// `sm/items:pool.go:Nil{}`
    SmItemsPoolGoNil,
    /// `sm/items:begin.go:+seat <> rest`
    SmItemsBeginGoCons,
    /// `sm/items:begin.go:Nil{}`
    SmItemsBeginGoNil,
    /// `sm/items:begin.seats:0n`
    SmItemsBeginSeatsZero,
    /// `sm/items:begin.seats:_`
    SmItemsBeginSeatsAny,
    /// `sm/items:puts.here:None{}`
    SmItemsPutsHereNone,
    /// `sm/items:puts.here:Some{item}`
    SmItemsPutsHereSome,
    /// `sm/items:puts:+slot <> rest`
    SmItemsPutsCons,
    /// `sm/items:puts:Nil{}`
    SmItemsPutsNil,
    /// `sm/items:grab.intake:True{}`
    SmItemsGrabIntakeTrue,
    /// `sm/items:grab.intake:False{}`
    SmItemsGrabIntakeFalse,
    /// `sm/items:grab.offer:True{} Some{item}`
    SmItemsGrabOfferTrueSome,
    /// `sm/items:grab.offer:True{} None{}`
    SmItemsGrabOfferTrueNone,
    /// `sm/items:grab.offer:False{} _`
    SmItemsGrabOfferFalse,
    /// `sm/items:grab.needs.go:+seat <> rest`
    SmItemsGrabNeedsGoCons,
    /// `sm/items:finish.ended:D.At{seat, grabbing} <> rest`
    SmItemsFinishEndedAtCons,
    /// `sm/items:finish.ended:Nil{}`
    SmItemsFinishEndedNil,
    /// `sm/items:finish.empty:seat <> rest`
    SmItemsFinishEmptyCons,
    /// `sm/items:finish.empty:Nil{}`
    SmItemsFinishEmptyNil,
    /// `sm/items:stalled:+seat <> rest`
    SmItemsStalledCons,
    /// `sm/items:stalled:Nil{}`
    SmItemsStalledNil,
    /// `sm/items:holders:D.At{seat, None{}} <> rest`
    SmItemsHoldersAtNoneCons,
    /// `sm/items:holders:D.At{seat, Some{item}} <> rest`
    SmItemsHoldersAtSomeCons,
    /// `sm/items:holders:Nil{}`
    SmItemsHoldersNil,
    /// `sm/items:amount.live:D.RandomAmount{}`
    SmItemsAmountLiveRandomAmount,
    /// `sm/items:amount.live:D.FixedAmount{amount}`
    SmItemsAmountLiveFixedAmount,
    /// `sm/items:winnerless:None{}`
    SmItemsWinnerlessNone,
    /// `sm/items:winnerless:Some{seat}`
    SmItemsWinnerlessSome,
    /// `sm/items:gun.empty:Nil{}`
    SmItemsGunEmptyNil,
    /// `sm/items:gun.empty:shell <> rest`
    SmItemsGunEmptyCons,
    /// `sm/items:jam.options:D.At{+seat, hp} <> rest`
    SmItemsJamOptionsAtCons,
    /// `sm/items:jam.options:Nil{}`
    SmItemsJamOptionsNil,
    /// `sm/items:jam.any:Nil{}`
    SmItemsJamAnyNil,
    /// `sm/items:jam.any:option <> rest`
    SmItemsJamAnyCons,
    /// `sm/items:steal.fits:D.Adrenaline{}`
    SmItemsStealFitsAdrenaline,
    /// `sm/items:steal.fits:D.Saw{}`
    SmItemsStealFitsSaw,
    /// `sm/items:steal.fits:D.Jammer{}`
    SmItemsStealFitsJammer,
    /// `sm/items:steal.fits:_`
    SmItemsStealFitsAny,
    /// `sm/items:steal.here:None{}`
    SmItemsStealHereNone,
    /// `sm/items:steal.here:Some{+item}`
    SmItemsStealHereSome,
    /// `sm/items:steal.slots:+slot <> rest`
    SmItemsStealSlotsCons,
    /// `sm/items:steal.slots:Nil{}`
    SmItemsStealSlotsNil,
    /// `sm/items:steal.owner:True{}`
    SmItemsStealOwnerTrue,
    /// `sm/items:steal.owner:False{}`
    SmItemsStealOwnerFalse,
    /// `sm/items:steal.owners:D.At{+owner, inventory} <> rest`
    SmItemsStealOwnersAtCons,
    /// `sm/items:steal.owners:Nil{}`
    SmItemsStealOwnersNil,
    /// `sm/items:steal.any:Nil{}`
    SmItemsStealAnyNil,
    /// `sm/items:steal.any:option <> rest`
    SmItemsStealAnyCons,
    /// `sm/items:use.fits:D.Adrenaline{}`
    SmItemsUseFitsAdrenaline,
    /// `sm/items:use.fits:D.Saw{}`
    SmItemsUseFitsSaw,
    /// `sm/items:use.fits:D.Jammer{}`
    SmItemsUseFitsJammer,
    /// `sm/items:use.fits:_`
    SmItemsUseFitsAny,
    /// `sm/items:use.here:None{}`
    SmItemsUseHereNone,
    /// `sm/items:use.here:Some{+item}`
    SmItemsUseHereSome,
    /// `sm/items:use.slots:+slot <> rest`
    SmItemsUseSlotsCons,
    /// `sm/items:use.slots:Nil{}`
    SmItemsUseSlotsNil,
    /// `sm/items:ends_turn:D.Beer{}`
    SmItemsEndsTurnBeer,
    /// `sm/items:ends_turn:_`
    SmItemsEndsTurnAny,
    /// `sm/items:invert:D.Live{}`
    SmItemsInvertLive,
    /// `sm/items:invert:D.Blank{}`
    SmItemsInvertBlank,
    /// `sm/items:flip:D.Clockwise{}`
    SmItemsFlipClockwise,
    /// `sm/items:flip:D.CounterClockwise{}`
    SmItemsFlipCounterClockwise,
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
    /// `sm/items:grab.needs.go:Nil{}`
    SmItemsGrabNeedsGoNil,
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
    /// `simple/point:item.chained:D.Jammer{}`
    SimplePointItemChainedJammer,
    /// `simple/point:item.chained:D.Adrenaline{}`
    SimplePointItemChainedAdrenaline,
    /// `simple/point:item.chained:_`
    SimplePointItemChainedAny,
    /// `simple/point:jam.options:None{}`
    SimplePointJamOptionsNone,
    /// `simple/point:jam.options:Some{slot}`
    SimplePointJamOptionsSome,
    /// `simple/point:steal.options:None{}`
    SimplePointStealOptionsNone,
    /// `simple/point:steal.options:Some{slot}`
    SimplePointStealOptionsSome,
    /// `simple/point:steal_jam.options:None{}`
    SimplePointStealJamOptionsNone,
    /// `simple/point:steal_jam.options:Some{slot}`
    SimplePointStealJamOptionsSome,
    /// `simple/point:steal_jam.here:True{}`
    SimplePointStealJamHereTrue,
    /// `simple/point:steal_jam.here:False{}`
    SimplePointStealJamHereFalse,
    /// `simple/point:first.range:D.TwoSeats{}`
    SimplePointFirstRangeTwoSeats,
    /// `simple/point:first.range:D.ThreeSeats{}`
    SimplePointFirstRangeThreeSeats,
    /// `simple/point:first.range:D.FourSeats{}`
    SimplePointFirstRangeFourSeats,
    /// `simple/point:phase.request:T.NeedFirst{}`
    SimplePointPhaseRequestNeedFirst,
    /// `simple/point:phase.request:T.NeedHealth{}`
    SimplePointPhaseRequestNeedHealth,
    /// `simple/point:phase.request:T.NeedAmount{}`
    SimplePointPhaseRequestNeedAmount,
    /// `simple/point:phase.request:T.NeedBatch{}`
    SimplePointPhaseRequestNeedBatch,
    /// `simple/point:batch.request:1n+1n+extra`
    SimplePointBatchRequestSuccSucc,
    /// `simple/point:batch.request:_`
    SimplePointBatchRequestAny,
    /// `simple/point:phase.request:T.NeedSwap{_, _, 1n+extra}`
    SimplePointPhaseRequestNeedSwapSucc,
    /// `simple/point:phase.request:T.NeedSwap{_, _, 0n}`
    SimplePointPhaseRequestNeedSwapZero,
    /// `simple/point:phase.request:T.Idle{+seat}`
    SimplePointPhaseRequestIdle,
    /// `simple/point:idle.request:True{}`
    SimplePointIdleRequestTrue,
    /// `simple/point:choose:Nil{}`
    SimplePointChooseNil,
    /// `simple/point:choose:move <> rest`
    SimplePointChooseCons,
    /// `simple/point:idle.request:False{}`
    SimplePointIdleRequestFalse,
    /// `simple/point:phase.request:T.Ended{}`
    SimplePointPhaseRequestEnded,
    /// `simple/point:phase.request:T.Blocked{_}`
    SimplePointPhaseRequestBlocked,
    /// `simple/point:phase.request:T.Stalled{}`
    SimplePointPhaseRequestStalled,
    /// `simple/point:phase.request:T.NeedTurnAmount{_, _, _}`
    SimplePointPhaseRequestNeedTurnAmount,
    /// `simple/point:phase.request:T.NeedItem{_, _, _, rest}`
    SimplePointPhaseRequestNeedItem,
    /// `simple/point:phase.request:T.NeedPhone{_, _, _}`
    SimplePointPhaseRequestNeedPhone,
    /// `simple/point:phone.request:1n+1n+1n+1n+extra`
    SimplePointPhoneRequestSuccSuccSuccSucc,
    /// `simple/point:phone.request:_`
    SimplePointPhoneRequestAny,
    /// `sm/rules:alive:0n`
    SmRulesAliveZero,
    /// `sm/rules:alive:1n+rest`
    SmRulesAliveSucc,
    /// `sm/rules:living:D.At{seat, 1n+hp} <> rest`
    SmRulesLivingAtSuccCons,
    /// `sm/rules:living:D.At{seat, 0n} <> rest`
    SmRulesLivingAtZeroCons,
    /// `sm/rules:seats.keep:True{}`
    SmRulesSeatsKeepTrue,
    /// `sm/rules:seats.keep:False{}`
    SmRulesSeatsKeepFalse,
    /// `sm/rules:successor:Nil{}`
    SmRulesSuccessorNil,
    /// `sm/rules:successor:+head <> rest`
    SmRulesSuccessorCons,
    /// `sm/rules:traversal:D.Clockwise{}`
    SmRulesTraversalClockwise,
    /// `sm/rules:traversal:D.CounterClockwise{}`
    SmRulesTraversalCounterClockwise,
    /// `sm/rules:jam.state:S.Free{}`
    SmRulesJamStateFree,
    /// `sm/rules:jam.state:S.Jammed{}`
    SmRulesJamStateJammed,
    /// `sm/rules:jam.state:S.JammedSkipped{}`
    SmRulesJamStateJammedSkipped,
    /// `sm/rules:jam_rank.bit:S.Jammed{}`
    SmRulesJamRankBitJammed,
    /// `sm/rules:jam_rank.bit:_`
    SmRulesJamRankBitAny,
    /// `sm/rules:predecessor:0n`
    SmRulesPredecessorZero,
    /// `sm/rules:predecessor:1n+n`
    SmRulesPredecessorSucc,
    /// `sm/rules:value.or:Some{x}`
    SmRulesValueOrSome,
    /// `sm/rules:value.or:None{}`
    SmRulesValueOrNone,
    /// `sm/rules:rules.load:D.LoadRules{a, _, _, _} 0n`
    SmRulesRulesLoadLoadRulesZero,
    /// `sm/rules:rules.load:D.LoadRules{_, b, _, _} 1n`
    SmRulesRulesLoadLoadRulesOne,
    /// `sm/rules:rules.load:D.LoadRules{_, _, c, _} 2n`
    SmRulesRulesLoadLoadRulesTwo,
    /// `sm/rules:rules.load:D.LoadRules{_, _, _, d} _`
    SmRulesRulesLoadLoadRules,
    /// `sm/rules:load.actual:D.LoadRule{D.RandomShells{}, _}`
    SmRulesLoadActualLoadRuleRandomShells,
    /// `sm/rules:load.actual:D.LoadRule{D.FixedShells{live, blank}, _}`
    SmRulesLoadActualLoadRuleFixedShells,
    /// `sm/rules:load.actual:D.LoadRule{D.AllLive{live}, _}`
    SmRulesLoadActualLoadRuleAllLive,
    /// `sm/rules:load.next:True{} _`
    SmRulesLoadNextTrue,
    /// `sm/rules:load.next:False{} 0n`
    SmRulesLoadNextFalseZero,
    /// `sm/rules:load.next:False{} 1n`
    SmRulesLoadNextFalseOne,
    /// `sm/rules:load.next:False{} 2n`
    SmRulesLoadNextFalseTwo,
    /// `sm/rules:load.next:False{} _`
    SmRulesLoadNextFalse,
    /// `sm/rules:round.next:True{}`
    SmRulesRoundNextTrue,
    /// `sm/rules:round.next:False{}`
    SmRulesRoundNextFalse,
    /// `sm/rules:captured:True{}`
    SmRulesCapturedTrue,
    /// `sm/rules:captured:False{}`
    SmRulesCapturedFalse,
    /// `sm/rules:shot.health:D.Blank{}`
    SmRulesShotHealthBlank,
    /// `sm/rules:shot.health:D.Live{}`
    SmRulesShotHealthLive,
    /// `sm/rules:shot.passes:D.Blank{} True{}`
    SmRulesShotPassesBlankTrue,
    /// `sm/rules:shot.passes:_ _`
    SmRulesShotPassesAny,
    /// `sm/rules:winner.only:seat <> Nil{}`
    SmRulesWinnerOnlyConsNil,
    /// `sm/rules:winner.only:_`
    SmRulesWinnerOnlyAny,
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
