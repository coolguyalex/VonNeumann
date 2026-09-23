# Probe Colony — Design Direction Handoff

2026-09-18 · @Someone · Revised 2026-09-22

A 2D Godot game about an autonomous machine that wakes up on an alien planet and has to build a colony from nothing — and then abandon it, and build the next one. Terraria's tactile digging, Dwarf Fortress's emergent colony systems, and Factorio-style automation, with survival reframed as machine maintenance (charge, later lubricant and part wear) instead of hunger. Rovers are commanded by writing real code for them. This doc captures the conceptual/design-direction discussion so it can be picked up in a separate chat; the actual Godot build (scripts, scenes, tile setup) stays in the build chat.

**How to read the tags.** Because this doc mixes settled decisions with brainstorming, statements are tagged where it matters: **[Decided]** was explicitly settled by the designer; **[Leaning]** is the current direction but not locked; **[Idea]** is a proposal from discussion that nobody has committed to; **[Question]** is open. Untagged text is carried over from earlier versions unless a section says it was revised.

## What changed in the 2026-09-22 revision

This revision **reverses the central premise of the 2026-09-20 revision.** That revision made the colony nomadic and banned fixed crafting stations. Both are now overturned.

- **The colony settles.** Nomadism is out; **serial settlement** is in. You build real, fixed, efficient bases — and then depletion and hazards force you to strip what you can carry and leave the rest behind. (Rewritten section: *Why the colony moves on*.)
- **Fixed crafting stations come back.** Fixed underground smelters are *better* than mobile ones. Mobile processing is what you take on expeditions, and it pays a real efficiency penalty.
- **Belts are un-demoted.** In a game about abandoning places, a belt being a sunk cost is the point, not a problem.
- **There is a mission.** You are surveying the planet for the site where the colony ship should land. Moving is the job, not a punishment.
- **There is an identity.** You are the mission AI. Rover 0 is your current chassis, not your only one.
- **Physics is real.** Mass, thrust and density now drive movement. 1 tile = 1 metre, gravity is Mars-like. A full hold can physically ground you. (New section: *Physics, mass & scale*.)
- **Impurity is a system.** Recipes have ideal compositions; straying from them degrades the part. (New section: *Crafting, refining & impurity*.)
- **The scripting layer is text, not blocks.** The 7 Billion Humans drag-and-drop model is dropped in favour of a small Python-like language with an Arduino-style `setup()`/`loop()` structure. (Rewritten section: *Programming/scripting layer*.)
- **The cargo hold is built.** Gravel, compositions and the cargo meter are in the prototype as of today.

## Premise, mission & identity

**[Decided] Who you are.** You are the **mission AI**. Rover 0 is your current chassis — not your only one. Driving a rover directly means *inhabiting* it; writing a program means delegating to a body you are not currently in. Radio range is the reach of your attention.

This has consequences worth keeping:

- You can **transfer** into any chassis carrying a Logic module. Losing rover 0 hurts badly but does not end the run.
- **Game over is when every thinking machine is gone** — not when one specific rover dies. That lets hazards be genuinely lethal without being unfair.
- The colony is, literally, your distributed self. That is the emotional core the doc previously tried to get from nomadism.

**[Decided, for now] The mission: find the landing site.** You are the advance party. Somewhere on this planet is the site where the colony ship should set down. Your job is to survey candidates, work each one hard enough to learn what it is actually made of, and move on when it fails. The final act is building the permanent base at the site that passes.

Why this premise is load-bearing:

- **Moving is the job**, not a punishment for poor play.
- **Settling is how you survey.** You cannot evaluate a site without exploiting it, so building a base *is* the assessment.
- **Depletion and hazards become survey data** — they are the reasons a candidate fails, not arbitrary pressure.
- **Ground-penetrating radar is mission-critical**, not a convenience sensor.
- Everything you build is temporary right up until the last one, which is permanent. That is an ending.

**[Idea] Scenarios.** The full game should support several start scenarios and mission types, RimWorld-style, rather than one fixed premise. Named so far: how you get your first Fabrication module (salvaged from the wreck / built in from the start / earned by reaching a landmark) and what the mission is (survey for a landing site / investigate a failed previous mission / build a transmitter to call home / open-ended sandbox). **The default first scenario is salvage + survey.**

### Genre blend

- **Terraria** — 2D tile digging, physical world, tactile core loop
- **Dwarf Fortress** — emergent colony systems, autonomous units doing jobs, a real fixed base with deep material processing (smelting, slag, fuel), eventually abandoned
- **Factorio** — resource chains and automation as a *feel*
- **Valheim / Satisfactory** — tiered progression gated by resources and unlocks, not just player skill

**The guiding principle [Leaning]:** a factory is a machine for removing the need for attention; a colony sim is a machine for making attention scarce. Every piece of resource processing should create a *job for a rover or a decision for the player*, not just a ratio to optimize. Test for any proposed chemistry/geology detail: does it give the player a decision (is this vein worth the trip? can I finish before the storm?) or only an optimization (the ideal input ratio)? Decisions belong in the game; pure ratio-tuning is the Factorio trap. A related idea is a **depth budget**: build one processing chain, see whether hauling and feeding it is fun, and only then add more geology.

Survival is reframed as machine maintenance rather than hunger/thirst:

- **Charge** — core resource, drains over time and with activity. Now also scales with **mass**: hauling a heavy load costs more energy. First stat, not yet built.
- **Lubricant** — second currency, added later
- **Part wear/breakage** — parts degrade over time; this is the mechanic that eventually makes automation *necessary* rather than just efficient. It also gives every rover a running cost, which naturally limits how far the colony can scale by just building more rovers.

## Why the colony moves on

**[Decided] Serial settlement, not nomadism.** You build a real base. Fixed processing is genuinely better than mobile processing — smelters are more efficient, they can be buried where hazards cannot reach them, and belts can feed them. You invest, you automate, you get comfortable. Then the site runs out and you leave.

The reasoning that killed nomadism: it was invented to answer "why wouldn't a rover colony just build a permanent base that does the work better?" But the answer is that **they would, and they do, and then the deposit runs out** — which is how real mining settlements have always worked. Towns get built, worked for decades, and abandoned. The differentiation from Factorio never depended on denying the player a base; it comes from embodied rovers, hardware-gated code, and maintenance-as-survival.

It is also the stronger emotional design. Abandoning a base you spent four hours building stings. Never having one does not sting; it just feels thin.

Consequences:

- **The peak decision of the game is what to carry and what to leave.** Convoy capacity is finite, so migration is a packing problem.
- **Two forces end a settlement**, and they should stay distinct: **pull** (the ore here is exhausted or was never rich enough) and **push** (the hazards here are escalating). A rich site with a bad hazard profile is a real risk/reward call.
- **Migrations are chapter breaks**, not a constant state. **[Leaning]** a site should last on the order of hours, giving maybe six to ten migrations in a campaign.
- **[Idea] Hazards should be telegraphed.** Unforecast disasters read as random punishment. Forecast lead time should be gated by sensor hardware, in the same spirit as hardware-gated scripting.
- **[Idea] Digging doubles as shelter.** Burrowing to wait out a solar flare or sandstorm is temporary defence. Hazards could also reshape terrain (floods fill low ground, sandstorms bury, meteor strikes leave craters). Named so far: solar flares, hypervolcanism, sandstorms, floods, meteoroid swarms, earthquakes, lava, sandworms.
- **[Idea] Forced downtime is when the factory runs.** Hazards create time you cannot spend travelling or digging. That is exactly when smelting and fabrication should happen. This makes hazards, digging-as-shelter and processing reinforce each other instead of merely coexisting.
- **Engineering implication:** the world must still be much larger than one hand-built map, i.e. terrain generated as you travel. Prototype early. **[Question]** Is the world one long side-view strip, or separate regions you move between?

**Belts and pipes [Decided]:** they stay, as originally designed. Rovers build them physically, tile by tile, holding the materials, so a belt route proves that ground was actually explored. In a game about leaving places behind, a belt being an abandonable sunk cost is a *feature*. Rovers stay relevant because they pay upkeep that belts do not, terrain refuses belts, and a belt cannot scout.

**[Idea] Radio relays are the one fixed infrastructure worth planting.** They are cheap, they extend the reach of your attention, and they are trivially abandonable — a better answer to "what fixed infrastructure earns its place" than belts alone. They also solve navigation drift (see the scripting section).

## Progression arc

1. **Tier 0 (current MVP) [Decided]** — rover 0 is a bare machine with *crappy versions of most basic capabilities*: a **drill** (slow manual mining), a **cargo hold**, **suction** (vacuum), a **jetpack**, and a **flashlight**. No smelting or crafting. Deliberately meagre so the player feels the friction, and each piece is the seed of an upgrade path.
2. **Tier 1 — Fabrication.** The module is **salvaged from the wreck that brought you** [Decided], which sidesteps the bootstrap problem (fabrication would otherwise require fabrication) and gives the game an opening scene. It unlocks **sintering**: pressing raw regolith into crude structural parts — chassis, cargo pods, frames. Nothing robotic or electronic can be made this way.
3. **Tier 2 — Smelting.** Unlocks extracting metal from ore minerals, and with it every **robotic or electronic** part: drills, motors, sensors, Logic modules. **[Decided]** This is the structural/electronic split: sintered regolith can be a body, never a brain.
4. **Tier 3+** — upgrades to the starter kit (mining speed, cargo capacity, suction strength, a selective magnet), and the **Logic module** that unlocks programmatic control. The scripting layer arrives as an earned in-world capability, not a menu toggle.

**The mid-game resource-investment fork:** once basic automation exists, the player repeatedly chooses between spending materials on *more* rovers (throughput), on refining/sensors (capability), or splitting. This tension is the core of the mid-game.

**Division of labor** emerges once multiple rovers exist — haulers, scouts (implying fog of war), resource-specific extractors, and processing rovers for expeditions. Because a chassis has limited slots, specialization comes from physical constraints rather than a rules layer.

## Physics, mass & scale

**[Decided] Mass is real, and it is the spine that ties cargo to mobility.** This is *not* the continuous physics rig that was previously ruled out — there is still no tipping and no torque. It is scalar arithmetic:

```
mass          = chassis + parts + cargo
ground accel  = motor_force / mass
jetpack accel = thrust / mass − g
```

**[Decided] Scale and gravity.** 1 tile = **1 metre** (40 px), gravity is Mars-like at **3.71 m/s²** = 148 px/s². The existing player sprite works out to 2.8 × 2.9 m, almost exactly Curiosity's footprint, so the scale is honest.

**The liftoff rule is the payoff.** If `thrust < mass × g` you simply cannot take off. Working numbers [Leaning]: a 500 kg Tier-0 rover, a 150 L hold, a 3000 N jetpack.

| load | total mass | thrust needed | result |
|---|---|---|---|
| empty | 500 kg | 1855 N | climbs well (net 2.3 m/s²) |
| 150 L regolith | 725 kg | 2690 N | just barely lifts (net 0.43 m/s²) |
| 150 L hematite | 1295 kg | 4805 N | **grounded** |

Maximum liftable mass is 808 kg, so a full hold of regolith still flies but only about 58 L of hematite does — roughly a third of a tank. **The worthless bulk is light; the valuable ore is what pins you to the floor.** "Dump the gravel to fly out of this pit" becomes a decision made with your thumb, not a menu.

This also gives the **selective magnet** a real cost as well as a benefit: filtering for ore maximises value per trip and grounds you fastest.

**[Decided] Realism stops at feel.** Mass bites hard on acceleration and jetpack thrust, but ground braking stays generous, so being heavy feels *sluggish* rather than *slippery*. Ice-skating physics is the failure mode to avoid.

**Retuning the existing prototype.** The rescale invalidates several current numbers:

- Gravity 1200 → 148, on both the player and dropped items.
- The jump impulse (`jump_velocity = -600`) gives a 30 m leap under the new gravity. It should stop being an impulse and become jetpack thrust.
- Suction pull is an acceleration, so with gravity 8× weaker it feels ~8× stronger; `magnet_strength` needs dividing by roughly that.
- `throw_speed` of 600 px/s is 15 m/s and will sail a long way in low gravity.
- **[Question]** Drill reach is 480 px, which is now **12 metres** — a lot of arm for a 2.9 m machine. Cutting it to 3–4 m is realistic but noticeably changes how mining feels. This is the one retune that is a design choice rather than arithmetic.

## Mining, cargo & materials

**[Decided — built]** Mining does not yield one item per block. It yields **gravel**:

- Each rock is a **mixture**: some share of a target mineral, the rest regolith. Copper comes from malachite, iron from hematite, cobalt from cobaltite, carbon from graphite. Composition is what scouting reveals.
- The **cargo hold is a tank**, not slots: one running total per material against a shared capacity. The **hotbar stays** as 10 slots for tools and items — the two never mix, so a morning's mining can never bury your drill under pebbles.
- **[Decided] Volume is the cap; mass is the consequence.** The hold takes a fixed volume (150 L). Per-material density makes the load's *mass* vary, and too heavy means poor acceleration and no liftoff — but you can still crawl home. Soft failure, real decision.

| material | density (kg/L) |
|---|---|
| regolith (loose) | 1.5 |
| graphite | 2.2 |
| malachite | 4.0 |
| hematite | 5.3 |
| cobaltite | 6.3 |

- One rock is worth **10 units** of gravel and breaks into **3 pebbles** that share it. Every pebble carries the same mixture, so which one you catch never changes what you get.
- **Richness varies per rock** (±25%), rolled once per rock so a rich tile is rich in all its pieces. Vein-scale richness is still **[Question]**.
- **Suction** grabs everything indiscriminately; strength and range are the upgrade knobs. A **selective magnet** later filters what enters the hold.
- The existing tactile drop mechanic stays: a broken block pops gravel that suction pulls in. A partly-collected pebble shrinks rather than vanishing.
- **[Idea] Particles.** Purely visual: a burst of chips when a block breaks and a trickle of grit while drilling, with colours sampled from the tile.

## Crafting, refining & impurity

**[Decided] Fixed beats mobile.** Fixed underground smelters and fabricators are more efficient, safer from hazards, and can be belt-fed. Mobile processing modules exist for expeditions and pay a real **mobility tax** in throughput. This reverses the 2026-09-20 "no fixed crafting stations" decision.

**[Decided] Impurity degrades the product.** A recipe declares an ideal composition. Purity is the overlap between what it wants and what you fed it:

```
purity = 1 − ( Σ |actual% − ideal%| ) / 2
```

A recipe wanting 100% regolith, fed 70% regolith and 30% copper, scores **0.70**. Below **0.51 the recipe is refused outright**.

Each part type then degrades in its own currency:

| part | effect at 0.70 purity |
|---|---|
| scanner / radar | range × 0.70 |
| drill, motor | speed or force × 0.70 |
| chassis, structural | mass ÷ 0.70 → **43% heavier** |

Two things fall out of this for free:

- **Alloys are just recipes with mixed ideals.** A drill head wanting 80% iron / 20% carbon is steel. Same maths, no new system.
- **Smelter output purity can itself be a stat**, so a better smelter makes purer metal makes better parts makes better rovers — one chain across three tiers.

**Why anyone would ever build impure:** refining costs charge, a module, and time you may not have with a storm inbound. Impure parts are the *build it now* option. That is what makes it a decision rather than a strict penalty — and it is where rover quirks come from.

## Rover & module system

The player **builds rovers** assembled from parts. **Rover 0 is simply your current chassis**, made from the same part system. Explicitly **not** a physics rig — no tipping, no torque. A chassis has slots; each part contributes stats or unlocks capabilities.

Part categories, each its own small `Resource` definition (name, **mass**, build cost, purity, stats/capability flags granted, **devices exposed to the scripting namespace**):

- **Chassis** — defines slot count/types, base movement stats, and dry mass
- **Mobility** — wheels (fast on flat, bad in mud), treads (slower, steady), possibly hover. Plus the **jetpack**, which is now a thrust value in newtons fighting the rover's mass
- **Extraction** — the drill for solids; a different extractor for fluids
- **Sensors** — the "eyes"; they gate what a rover's program can *ask about*
- **Cargo** — holds gravel; capacity in litres is the stat
- **Collection** — suction, later a selective magnet
- **Processing** — mobile fabrication and smelting, for expeditions
- **Logic** — hosts you, or runs a program. Its tier sets the instruction budget
- **Radio** — communication range; gates rover-to-rover coordination entirely

**[Question]** Is loadout a one-time build choice, or can a rover be refitted later?

## Rover identity — stats and quirks

**[Decided]** Rovers need individual identity: stats and quirks.

- **[Decided] Impurity is where quirks come from.** A rover built cheap and in a hurry carries that history in its stats — a weak motor, a short-sighted scanner, a heavy frame. Quirks are earned, not randomly labelled.
- **[Idea]** Each rover has a name and a history (what it has dug, survived, lost). Loss should sting.
- **[Idea]** Quirks should have mechanical consequences the player can read and program around — a rover that drifts off course, drains charge faster in cold, or has a slow-warming sensor.
- **[Idea]** Quirks interact with the scripting layer: a program that works on one rover may need adjusting for another.
- **[Question]** Are stats/quirks fixed at build, or do they develop through use? How visible are they?

## Resource types

Follows the Satisfactory split: solid ores (drill/extractor, into cargo) vs. fluids like water, crude oil and gas (a different extractor type entirely; pipelines are viable again now that bases are fixed). This split gives the extraction category a natural sub-type fork, which is itself a reason to build specialized rovers rather than one generalist.

## Differentiation from Factorio/Satisfactory

This is fundamentally a **colony sim** (RimWorld/Dwarf Fortress DNA — physical, embodied hauling; friction from distance and terrain) where **programmed rovers replace the job-designation/priority-list layer**, rather than an automation game where agents are incidental to a belt network.

Load-bearing differentiators:

- **Hardware-gated code** — no radar attached means the name `radar` does not exist in your program
- **Real code, really written** — not a designation UI
- **Maintenance-as-survival** with no hunger stat
- **Mass and thrust as a constant physical constraint** on every decision
- **Serial settlement** — the game is partly about abandoning what you built
- **Impurity** — the same recipe produces different-quality objects

**Deposit geometry and tuning.** A large singular vein has stable geometry; a scatter of small deposits has none, suiting a rover that wanders and grabs. Neither should be trivial: large veins should be finite but slow-depleting, and small-deposit aggregates should sometimes rival a large vein's total yield, so the right approach depends on the map roll and how much scouting was done. Depletion tuning now directly sets how long a settlement lasts.

**Ground-penetrating radar is the key scouting sensor**, and under the survey mission it is mission-critical. Its value is letting the player judge a site *before committing to it*. Modelled loosely on real time-of-flight GPR: rather than rendering a literal radargram, the game simulates a pulse travelling outward in an arc and statistically summarizes the reflections. The core readout is an **average reflection time** (implying density) and a **standard deviation** across the arc (implying how scattered the deposit is) — low deviation with a solid average reads as one coherent body, high deviation as scattered material. Suggested tiering: a cheap unit gives only the average; a better one adds the deviation; a later one moves toward a coarse spatial plot. **[Idea]** The same readout can hint at ore *grade*, not only deposit shape.

## Programming/scripting layer

**[Decided] Text, not blocks.** The 7 Billion Humans drag-and-drop model is dropped. Rovers are programmed in a small **Python-like language**, and the teaching model is **worked examples the player copies, pastes and then modifies**.

Dropping blocks makes the hardware gating *more* literal, not less. With blocks, missing hardware greys out a dropdown. With text, the name simply is not there:

```
ERROR line 1: no device 'gpr'
```

**[Decided] Arduino structure.** A program is a `setup()` that runs once at boot and a `loop()` that runs forever. `setup()` has an obvious job: record your home beacon, calibrate, set constants.

**[Decided] The Logic module sets the instruction budget.** `loop()` runs until this tick's budget is spent, pauses mid-statement, and resumes next tick. This makes an infinite loop safe rather than a freeze, and turns the module tier into something meaningful to buy: **a better CPU thinks faster.**

**[Decided] Sensors are callable devices; actuators are assignable registers.** This maps directly onto the engine architecture — the script writes intents, the rover executes them, exactly as the keyboard does.

```
# follow the leader
def setup():
    home = gps.here()

def loop():
    target = radio.find("leader")
    if target.distance > 10:
        heading  = target.bearing
        throttle = 1
    else:
        throttle = 0
```

```
# dig when the radar sees ore close below
def loop():
    hit = gpr.scan("hematite")
    if hit.depth <= 1:
        drill = 1
    else:
        drill = 0
        throttle = 1
```

**[Decided] There is no built-in follow command.** Following is the *first program you write*. That makes the tutorial short, motivating, and a lesson in sensors and conditionals at once.

**[Decided] Language scope.** Variables, arithmetic, comparisons, `and`/`or`/`not`, `if`/`elif`/`else`, `while`, and device calls. No user-defined functions, lists or dicts at first. A custom interpreter (tokenizer, parser, tree-walker) rather than embedded Lua or GDScript, because two things are non-negotiable and both are free if we write it ourselves: **suspending mid-action across frames**, and **per-tick instruction budgets**. Everything is in metres and seconds by convention; no unit literals.

**[Decided] Material transfer is drop-and-suction.** One rover dumps cargo, another sucks it up. This needs no new mechanics — drops, suction and the hold already exist — and the only new verb is `dump`. It is also physically tactile, which fits the colony-sim DNA better than an abstract adjacent-transfer.

### Architecture

The doc previously said the player and rovers share one **Command queue**. That framing is **corrected**: player input is continuous (hold to drill, release to stop) and queueing it produces input lag and awkward cancellation.

What is actually shared is a **capability interface** — move, drill, suck, dump. Exactly one *controller* writes those intents each frame:

- `PlayerController` — reads Input
- `ProgramController` — runs the interpreter and its program counter
- `JobController` — runs a designation

The queue belongs only to the interpreter. A real benefit falls out: swapping controllers is how the mission AI **takes direct control of any rover**, which is both a debugging tool and the core fiction.

### Open items

- **[Idea] Drift.** If programs navigate by counting movements (dead reckoning), errors accumulate — wheel slip, slope, a weak motor from an impure part — so "retrace my steps home" misses. This is what makes **external references** valuable, which is the argument for radio beacons: navigate by bearing-to-beacon and the error stops accumulating. Progression: dead reckoning (free, drifts) → beacon navigation (needs radio). **Do not ship drift before the execution log exists.**
- **[Decided] Observability is part of version one.** Low observability means a rover comes home empty and you cannot tell whether it never found ore, the drill never fired, or it turned back too early. The fixes: a readable per-rover execution log, the ability to watch a program stepped or slowed, and a **datasheet per device** so the player knows what `gpr.scan()` returns. Datasheets are also a flavour win — you read the spec sheet for your sensor, exactly like a real component.
- **[Idea] Dry-run simulation** as a later Logic-module tier: preview a program's path before committing a trip. Answers observability with progression rather than a menu.
- **[Question] One program per rover, or shared?** Programs as assets written once and *assigned* to rovers would make fleets manageable while quirks still make identical programs behave differently.
- **[Question] Rendezvous.** Radio gives bearing and range; is that enough for a hauler to reliably meet a smelter, or is an explicit "wait until adjacent" primitive needed?
- **[Idea] Hazard- and charge-aware conditions**, available only with the relevant sensor, so surviving a storm becomes a programming problem.
- **[Question] Job assignment before scripting exists** — how is a rover told to do anything before the Logic module? Click-to-target, zone designation, or nothing at all until Logic arrives.

## Prototype status (build chat, as of 2026-09-22)

- Side-view movement; tile world with per-tile custom data (`solid`, `minable`, `drop_item_id`).
- **Drill:** mouse-aimed, hold Space with the drill selected, reach about 480 px, one second per tile; grid-walk raycast targeting, outlined target.
- **Drops:** a small copy of the tile pops out with random scatter, falls, and hops at random intervals.
- **Suction (still named "magnet" in the code):** hold Space with it selected; pull is `strength × (1/d² − 1/range²)`, smoothly reaching zero at the range.
- **Hotbar:** 10 slots, one item per slot, no stacking. Starts with the drill and suction.
- **Cargo hold (new):** `material_table.gd` holds rock compositions, colours and densities; `cargo.gd` is the tank (proportional partial fills, so a nearly-full hold cannot sort a load by luck); `cargo_meter.gd` draws it as a filling tank with per-material bands and a legend. Mining yields gravel, never hotbar items.
- **Known bug:** hotbar tool icons start blank. `player._ready()` adds the tools and triggers a redraw, but `Hotbar._refresh()` looks up the World by group and the World joins that group in *its* `_ready()`, which runs later. Icons resolve to null and nothing redraws them.
- Not built yet: mass/physics rescale, charge, flashlight, jetpack, parts/chassis, crafting, smelting, impurity, rovers, scripting, hazards, world generation.

## Open design questions

- [ ] **Drill reach** at the new scale — keep 12 m, or cut to a realistic 3–4 m?
- [ ] **World structure:** one long strip or separate regions? How is terrain generated?
- [ ] **Charge:** how is it replenished — solar, generator rovers, portable chargers? Now that bases are fixed, is base power a separate system from rover charge?
- [ ] **How long should one settlement last**, and how much can a convoy carry when you leave?
- [ ] **Vein-scale richness:** rock-level variation is built; how do whole veins differ?
- [ ] **Hazards:** how much warning, gated by which sensors? Which hazards exist first?
- [ ] **Rover identity:** how are stats and quirks revealed to the player?
- [ ] Are modules a one-time build choice per rover, or refittable?
- [ ] How is a rover assigned a job *before* the Logic module exists?
- [ ] Second survival stat: how does lubricant get consumed/refilled, and does a worn part underperform or fully fail?
- [ ] Fog of war — how much is hidden until a rover with the right sensor visits?
- [ ] Radar hardware tiering — is average / average+deviation / spatial-plot the right cadence?
- [ ] Scripting: shared programs, rendezvous primitives, pre-Logic job assignment (above).
