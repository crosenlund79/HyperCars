# Garage economy

The **single authoritative description** of the garage economy. Other documents link
here instead of repeating prices. Garage races only: quick, spectator, couch, network,
championship and arena races never touch money. Numbers are **provisional**; they live
in `src/garage/default_garage_rules.tres` and `src/garage/garage_rules.gd` defaults.

## Current rules

**Verified from the original manual:** starting money, prize money for the top five
only, buy and sell after a race (selling pays less), two weapon types per race (front /
rear), quantity limited only by money. The numbers are HyperCars choices.

### Money and supplies

| Item | Value |
|---|---|
| Start | $300, 5 front missiles and 5 mines owned and equipped |
| Prizes, 1st–5th | $550 / 400 / 300 / 200 / 125 |
| Prizes, 6th–10th and DNF | nothing |
| Front / rear missile | $40 per round |
| Homing missile | $90 per round |
| Super missile | $150 per round |
| Mine | $30 per round |
| Selling | pays 50 % of the price |
| Stock limit | 99 rounds per type |

Prices are fixed; the original's fluctuating prices are not implemented.

### Car

| Item | Value |
|---|---|
| Repairs | $2 per 1 % condition (a full rebuild from 0 % costs $200) |
| Free emergency patch-up | a car below 50 % is patched up to 50 % before the race, so a broke player can always race |
| Armour LIGHT | −20 % damage, $250 |
| Armour HEAVY | −35 % damage, $400 more |

Armour is kept for the career and never sold back.

### Races

- Ammunition: the garage player races with their own rounds; race-length ammunition
  scaling applies only to everyone else.
- Prizes do not depend on race length.
- A finished race is settled once: prize, rounds left, condition. Leaving before the
  flag pays nothing, uses no rounds and causes no damage.

### Career

Money, rounds, equipped weapons, condition, armour and race count are saved in
`user://garage.cfg` after every change. Nothing is written while a race is running, so
quitting mid-race equals leaving the race. **NEW GARAGE** (a second press confirms) on
the garage setup screen starts over.

## Review 2026-11-17 (Big Refinement)

## Evidence

**Measured in the real game.** 30 armed three-lap races: three circuits × five environments × Classic / Tactical, nine rivals each, 270 car-races. For every car the run recorded its finishing position, the damage it took and the rounds it fired.

| finish | damage taken (% condition) | front rounds used | rear rounds used |
|---|---|---|---|
| 1st | 8 | 5.3 | 3.3 |
| 2nd | 29 | 3.5 | 3.8 |
| 3rd | 39 | 2.2 | 3.1 |
| 4th | 47 | 2.8 | 4.4 |
| 5th | 59 | 2.6 | 3.6 |
| 6th | 65 | 3.1 | 3.9 |
| 7th–9th | 74–78 | 3.3–4.1 | 1.7–3.6 |
| DNF | 105 | 2.8 | 2.3 |

Overall, the mean wear is 55 % per race; the 90th percentile is 99 %.

**Modelled.** A ten-race garage session, 200 random sessions per scenario, drawing races from the measured table. After every race the player repairs first, then restocks.

- Restock target: 5 front + 5 rear rounds; the conservative player keeps 3 + 3 and repairs only to 70 %.
- Heavy damage: the average finishing range with ×1.6 damage.

## Before → after (mean after ten races)

| scenario | before: money / rounds / condition | after: money / rounds / condition |
|---|---|---|
| strong (P1–3) | $1443 / 10 / 100 % | $2159 / 10 / 100 % |
| average (P3–6) | $2 / 0.2 / 28 % | $11 / 2.7 / 68 % |
| poor (P6–9) | $1 / 0 / 0 % | $0 / 0 / 1 % (starts each race at 50 %) |
| heavy damage | $1 / 0 / 5 % | $3 / 0.8 / 24 % |
| conservative | $1 / 0 / 6 % | $3 / 0.5 / 21 % |

Condition is what remains after that player's post-race repairs. The free patch-up is applied at the start of the next race.

**Finding.** Before the change, an average driver earned about $125 per race against roughly $150 of repairs and $210 of ammunition. They were broke and racing a wreck within three or four races. Only strong drivers prospered.

## Changes (modest, evidence-based)

| rule | before | after |
|---|---|---|
| prize money (top five only, as in the manual) | $500 / 350 / 250 / 150 / 100 | $550 / 400 / 300 / 200 / 125 |
| repairs | $3 per 1 % | $2 per 1 % |
| free emergency patch-up | to 30 % | to 50 % |

**Unchanged:** starting money and supplies, weapon prices, sell 50 %, armour, DNF = no prize, top-five-only prizes.

**Rejected alternative.** Bigger prizes alone (+20 %) mostly enriched strong drivers ($2437) and left average drivers broke.

Invariants are tested in `tests/unit/test_player_garage.gd` (`test_economy_invariants`):

- a podium pays a typical race's repairs;
- a win pays a full rebuild;
- the patch-up starts above the critical zone;
- prizes fall with position.

## Needs human judgement

- Whether drivers finishing outside the top five should earn anything. The original paid the top five only, so this was left unchanged.
- Whether the strong driver's surplus matters, given that money can only buy rounds, repairs and armour.
- How it feels over a long session.
