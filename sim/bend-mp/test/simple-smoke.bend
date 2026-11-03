import Base
import ../domain.bend as D
import ../simple/main.bend as M
import ../simple/state.bend as T

# Smoke test for check.sh: 64 matches at each table size, answered from a
# hashed tape, all finished with nothing stuck and no fuel spent. Items are
# on, at the default caps.

def mix(+x: U32) -> U32:
  +x1 : U32 = U32.xor(x, U32.shrn(x, 16n))
  +x2 : U32 = U32.mul(x1, 2146121005)
  +x3 : U32 = U32.xor(x2, U32.shrn(x2, 15n))
  +x4 : U32 = U32.mul(x3, 2221713035)
  U32.xor(x4, U32.shrn(x4, 16n))

def answer.for(request: T.Request, word: U32) -> Nat:
  match request:
    case T.Draw{_, D.Range{_, extra}}:
      U32.to_nat(U32.mod(word, U32.from_nat(2n+extra)))
    case T.Choose{_, D.NonEmpty{_, rest}}:
      U32.to_nat(U32.mod(word, U32.from_nat(1n+List.length(&2, T.Move, rest))))
    case _:
      0n

type Totals is Data:
  Totals{finished: U32, stuck: U32, exhausted: U32}

def play(fuel: Nat, +request: T.Request, +state: T.State, +seed: U32, +step: U32) -> Totals:
  match fuel request:
    case _ T.Finished{}:
      Totals{1, 0, 0}
    case _ T.Stuck{}:
      Totals{0, 1, 0}
    case 0n _:
      Totals{0, 0, 1}
    case 1n+rest _:
      +next : T.State = M.stepped.state(M.answer(state, answer.for(request, mix(U32.xor(seed, mix(step))))))
      play(rest, M.request(next), next, seed, (step + 1 : U32))

def totals.add(a: Totals, b: Totals) -> Totals:
  match a b:
    case Totals{af, as, ae} Totals{bf, bs, be}:
      Totals{(af + bf : U32), (as + bs : U32), (ae + be : U32)}

def batch(n: Nat, +table: D.Table, +salt: U32) -> Totals:
  match n:
    case 0n:
      Totals{0, 0, 0}
    case 1n+(+rest):
      +state : T.State = M.stepped.state(M.start(D.config.default(table)))
      totals.add(play(20000n, M.request(state), state, mix(U32.xor(salt, U32.from_nat(rest))), 0), batch(rest, table, salt))

def line(label: String, totals: Totals) -> String:
  match totals:
    case Totals{finished, stuck, exhausted}:
      "simple smoke " ++ label ++ " finished=" ++ U32.show(finished) ++ " stuck=" ++ U32.show(stuck) ++ " exhausted=" ++ U32.show(exhausted)

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print(line("2", batch(64n, D.TwoSeats{}, 21)))
    IO.print(line("3", batch(64n, D.ThreeSeats{}, 22)))
    IO.print(line("4", batch(64n, D.FourSeats{}, 23)))
