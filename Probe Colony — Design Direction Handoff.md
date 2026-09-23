# Probe Colony — Design Direction Handoff

2026-09-18 · @Someone · Revised 2026-09-23

A 2D Godot game about an autonomous machine that wakes up on an alien planet and has to build a colony from nothing — and then abandon it, and build the next one. Terraria's tactile digging, Dwarf Fortress's emergent colony systems, and Factorio-style automation, with survival reframed as machine maintenance (charge, later lubricant and part wear) instead of hunger. Rovers are commanded by writing real code for them. This doc captures the conceptual/design-direction discussion so it can be picked up in a separate chat; the actual Godot build (scripts, scenes, tile setup) stays in the build chat.

**How to read the tags.** Because this doc mixes settled decisions with brainstorming, statements are tagged where it matters: **[Decided]** was explicitly settled by the designer; **[Leaning]** is the current direction but not locked; **[Idea]** is a proposal from discussion that nobody has committed to; **[Question]** is open. Untagged text is carried over from earlier versions unless a section says it was revised.

## What changed in the 2026-09-22 revision

This revision **reverses the central premise of the 2026-09-20 revision.** That revision made the colony nomadic and banned fixed crafting stations. Both are now overturned.

- **The colony settles.** Nomadism is out; **serial settlement** is in. You build real, fixed, efficient bases — and then depletion and hazards force you to strip what you can carry and leave the rest behind. (Rewritten section: *Why the colony moves on*.)
- **Fixed crafting stations come back.** Fixed underground smelters are *better* than mobile ones. Mobile processing is what you take on expeditions, and it pays a real efficiency penalty.
- **Belts are un-demoted.** In a game about abandoning places, a belt being a sunk cost is the point, not a problem.
- **There is a mission.** You are surveying the planet for the site where the colony ship should land. Moving is the job, not a punishment.
- **There is an identity.** You are the mission AI. Rover 0 is your current chassis, not your only one.
- **Physics is real.** Mass, thrust and density now drive movement. 1 tile = half a metre, gravity is Mars-like. A full hold can physically ground you. (New section: *Physics, mass & scale*.) **Built and verified 2026-09-22.**
- **Impurity is a system.** Recipes have ideal compositions; straying from them degrades the part. (New section: *Crafting, refining & impurity*.)
- **The scripting layer is text, not blocks.** The 7 Billion Humans drag-and-drop model is dropped in favour of a small Python-like language with an Arduino-style `setup()`/`loop()` structure. (Rewritten section: *Programming/scripting layer*.)
- **Damage is per-part, and fuel is its own resource.** Parts each carry a condition that degrades before it fails; the jetpack burns manufactured reaction mass rather than charge, because a rocket is the only thing that works in a thin atmosphere. (New section: *Damage, wear & fuel*.)
- **The cargo hold is built.** Gravel, compositions and the cargo meter are in the prototype as of today, along with the mass system and mining particles.

## What changed in the 2026-09-23 revision

- **Jetpack fuel and cargo dumping are built.** The jetpack burns manufactured propellant that has mass and burns off in flight; holding G pours the hold back out, which is also the physical half of rover-to-rover transfer.
- **The art scale is now 1 pixel = 1 centimetre**, ahead of drawing module art. This is a pixels-per-metre change only — no mass, volume or speed retuning was needed, and every physics number was verified unchanged. (New subsection: *Art scale — 1 pixel = 1 centimetre*, under *Physics, mass & scale*.) A module size table and the chassis attachment grammar are recorded there too.

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

- **Charge** — electrical, drains over time and with activity, recharged by sunlight. Now also scales with **mass**: hauling a heavy load costs more energy. First stat, not yet built.
- **Fuel** — reaction mass for the jetpack, manufactured rather than recharged. See *Damage, wear & fuel*.
- **Lubricant** — third currency, added later
- **Part wear/breakage** — parts degrade with use, per part; this is the mechanic that eventually makes automation *necessary* rather than just efficient. It also gives every rover a running cost, which naturally limits how far the colony can scale by just building more rovers.

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

**[Decided] Scale and gravity.** 1 tile = **half a metre** (40 px, so 80 px to the metre), gravity is Mars-like at **3.71 m/s²** = 296.8 px/s².

The half-metre tile is not arbitrary — it is forced by the mass system. At 1 m a tile is a cubic metre, which is **1.5 tonnes of regolith**: more than the whole rover, and a hold big enough to be fun would need a 40-tonne mining truck to carry it. At half a metre a tile is 125 L (~190 kg), the player sprite works out to a believable 1.4 m working machine, and a hold still takes a dozen tiles. The gameplay payoff comes from the density *ratios*, so nothing is lost by choosing the absolute scale that keeps the pacing.

**The liftoff rule is the payoff.** If `thrust < mass × g` you simply cannot take off. Shipped numbers: a **1200 kg** rover, a **1500 L** hold, a **13,500 N** jetpack.

| load | total mass | result |
|---|---|---|
| empty | 1.20 t | climbs well (net 7.5 m/s²) |
| 1500 L regolith | 3.45 t | just barely lifts (net 0.2 m/s²) |
| 1500 L hematite | 9.15 t | **grounded** |

Maximum liftable mass is **3.64 t**, so a full hold of regolith still flies but only about 460 L of hematite does — 31% of the tank. **The worthless bulk is light; the valuable ore is what pins you to the floor.** "Dump the gravel to fly out of this pit" becomes a decision made with your thumb, not a menu.

Sideways movement is a force too, so the same mass drives handling: empty, the rover reaches its 5 m/s top speed in 0.60 s (exactly what 10,000 N / 1200 kg predicts); fully loaded with ore it takes ten times as long. Top speed itself is unchanged by load — a heavy rover gets there eventually, it just takes forever.

**[Idea] This is the argument for a hauler companion.** Once ore is heavy, the reason to build rover #1 stops being abstract throughput and becomes physical: you are grounded, and the ore still has to get home. A dedicated hauler carries no drill and no sensors, so it is lighter and carries more per trip — **mass makes specialization mathematically optimal, not merely thematic.** The shuttle loop (follow, take the load, run it back, return) is also the natural second program after "follow me".

This also gives the **selective magnet** a real cost as well as a benefit: filtering for ore maximises value per trip and grounds you fastest.

**[Decided] Realism stops at feel.** Mass bites hard on acceleration and jetpack thrust, but ground braking stays generous, so being heavy feels *sluggish* rather than *slippery*. Ice-skating physics is the failure mode to avoid.

**Retuning the existing prototype — done.** The rescale invalidated several numbers, all since corrected:

- Gravity 1200 → 296.8, on both the player and dropped items.
- The jump impulse is gone; W now holds the jetpack, and whether you leave the ground is decided by the physics rather than an `is_on_floor()` check.
- Suction pull is an acceleration, so against 4× weaker gravity the old value felt 4× stronger; `magnet_strength` divided to 6.2e6. (Later converted to real units entirely — see *Art scale* below.)
- `throw_speed` of 600 px/s is 7.5 m/s at the new scale, which is fine, so it was left alone. (Also later converted to a real m/s export.)
- **[Decided] Drill reach is 2.8 m**, about two body lengths, down from the 6 m the old pixel value became. Less fun, more believable — the designer's call.

**A trap worth recording.** Zeroing `velocity.y` while grounded makes a CharacterBody2D stop pressing into the floor, so `is_on_floor()` flickers and the rover silently gets *air control* while standing still. Keep one frame's worth of weight pressing down instead.

### Art scale — 1 pixel = 1 centimetre

**[Decided — built, 2026-09-23]** Ahead of drawing module art, `PIXELS_PER_METER` moved from 80 to **100**, so **one pixel is one centimetre.** Draw a module at N pixels wide and that is its size in the world in centimetres — no conversion, no lookup table.

This is a different kind of change from the tile-size rescale above, and much smaller: it is purely how many pixels of art represent a metre on screen. It does **not** touch `TILE_METERS` (still 0.5 m) or any mass, volume, density, thrust or speed — those are simulation constants, tuned in real units, and every one of them was verified to come out bit-identical after the change (same masses, same liftoff table, same fuel burn, same magnet pull at a given distance). The reason this was possible with almost no retuning is the earlier decision to tune everything in kilograms, newtons, metres and litres and convert to pixels only at the moment of use — this is that decision paying for itself.

What did move, because it lived directly in pixel-measured scene resources rather than behind `Units.gd`:

- The tile grid, its atlas region and every tile's collision polygon (40 px → 50 px).
- The rover's collision box, now **140 × 145 px = 1.40 × 1.45 m** exactly — also fixing the old 111×115 px box, which was sitting on an off-grid half-pixel.
- A handful of leftover raw-pixel tuning values that predated the mass rescale (magnet strength/range, throw speed/distance, hop height, drop scatter) were converted to real metres and metres³/s² rather than just multiplied by the 1.25 scale factor, so `PIXELS_PER_METER` never has to be hunted down and retuned again.
- The two existing art assets (`tile.png`, `Sprite_RV1.png`) were rescaled 1.25× with nearest-neighbour, which lands exactly on integer pixel boundaries (40×1.25=50) — a lossless resize, not a redraw. They remain placeholders; the module art below replaces them properly.

**Module size table**, for the upcoming art pass. Sizes are exact, physically reasoned proportions for a 1.40 × 1.45 m, 1.2 t machine, given directly in pixels — which, at this scale, means directly in centimetres:

| hardpoint | canvas (px = cm) | real size | notes |
|---|---|---|---|
| chassis / hull | 200 × 200 | ~2.0 × 1.8 m bounding box | existing sprite; antenna mast sticks up out of the top of this canvas |
| undercarriage (mobility) | 140 × 40 | 1.4 × 0.4 m | wheels, treads, hover — spans the full hull width |
| front tool | 60 × 40 | 0.6 × 0.4 m | drill, fluid extractor |
| rear tool | 40 × 40 | 0.4 × 0.4 m | claw, manipulator |
| mast | 20 × 50 | 0.2 × 0.5 m | antenna, radar dish |
| head / sensors | 60 × 30 | 0.6 × 0.3 m | cameras, proximity sensor |
| internal (never drawn) | — | — | cargo, fuel tank, logic, radio — icon only, 32 × 32, same style as the existing drill/magnet placeholder icons |

**The attachment grammar:** the socket belongs to the chassis, not the module. Draw the connector geometry (the segmented boom joints already visible on RV1) as part of the chassis art, on its own layer, and let every module simply butt up against it. Any module then fits any socket by construction, a missing module leaves a visibly empty socket rather than a hole, and — because there is still no physics rig, no torque, no structural simulation — parts only ever need to *look* attached, never actually be joined.

## Damage, wear & fuel

### Damage and wear

**[Decided] Condition is tracked PER PART, not as one rover health bar.** Three reasons it earns the extra bookkeeping:

- *Which* part failed is a far more interesting sentence than how hurt you are. "My drill is worn out" is a problem with a shape; "my rover is at 40%" is not.
- It feeds specialization: a dedicated hauler wears its motors and never its drill, because it hasn't got one.
- It connects straight to impurity. A part built at 0.7 purity starts with less durability and wears faster, so **building cheap literally shortens a rover's life** — and that history is where quirks come from.

**[Decided] Parts degrade first, then fail.** A drill at 30% condition is slow; at 0% it stops. Gradual decline is what gives the player warning, and it is the same argument as the execution log: silent sudden failure is punishment, not difficulty.

**[Leaning] Wear follows use, per category.** Motors wear with distance travelled — and faster under load, since a heavy rover works them harder. Drills wear with rock broken. Sensors and logic wear with time powered.

**[Decided] Impact damage is kinetic energy, ½mv², so a full hold makes every fall worse.** This is the *third* consequence of mass, after acceleration and liftoff: flying home loaded is now risky in a new way. Mars gravity keeps falls survivable enough to be a cost rather than instant death.

**Repair needs a Fabrication module and materials**, so damage feeds the crafting loop rather than being a separate system.

**[Question]** Can a part be repaired to full, or does refurbishment leave it permanently a little worse? Permanent degradation would make attrition real and force eventual replacement, which suits a game about running an industrial base — but it needs to not feel like pure grind.

### Jet fuel

**[Decided] Fuel is reaction mass, and it is NOT charge.** The atmosphere settles this: on a thin-atmosphere world a jetpack cannot be a ducted fan, because there is no air to push against. It has to be a rocket, and a rocket carries propellant.

That one physical fact pays for itself:

- **Fuel has weight and burns off as you fly.** A full tank hurts your thrust-to-weight at liftoff and helps at the end of the burn. That is real rocket behaviour and it needs no special-casing — it falls out of the mass system already built.
- **Dumping fuel to save weight** is a legitimate emergency action, exactly as aircraft do it.
- **Fuel must be manufactured, never recharged**, which is the real difference from charge:

| | charge | fuel |
|---|---|---|
| powers | drill, motors, sensors, logic | the jetpack only |
| refilled by | sunlight, time | industry |
| the problem it poses | time and weather | a production chain |

**[Leaning] Made by ISRU, from what is already on the table.** Real Mars mission plans make methalox from CO₂ and water; the material table already has **graphite**, and water is listed as a future fluid. Carbon + water → propellant gives both a purpose and pulls the fluid-extraction fork into the main line rather than leaving it a side branch.

Early on, flying is a luxury you cannot afford, so you walk. The first fuel refinery is a real milestone.

**[Question]** Is the fuel tank a part with its own dry mass and capacity stat (so a bigger tank costs you payload)? That seems right, and it makes range-versus-cargo a live trade on every build.

**Built 2026-09-23.** Propellant has density (0.83 kg/L) and counts toward total mass, burn rate is `thrust / (Isp × g0)` at Isp 330, and the Tier 0 tank is 150 L — about 30 seconds of continuous full thrust. Running dry means no thrust at all. Holding the button while too heavy to lift still burns propellant: the thruster does not know it is not working, and the meter has already said so.

### Dumping the hold

**[Decided — built] Hold G to pour gravel back out.** Without it the mass system could strand a player: loaded past liftoff weight at the bottom of a hole, with nothing to shed. Volume comes out proportionally from every material, so what lands is a scoop of the mixture and what stays behind is still the same gravel.

This is also **the physical half of rover-to-rover transfer**, arriving early and for free: one machine pours, another sucks it up, and the only new verb the scripting layer will need is `dump`.

Dumped gravel carries a short pickup delay so dumping with the suction running doesn't pull it straight back in — which means a tailings pile is something you can deliberately leave, exactly what the vibration sorter will produce at scale.

## Mining, cargo & materials

**[Decided — built]** Mining does not yield one item per block. It yields **gravel**:

- Each rock is a **mixture**: some share of a target mineral, the rest regolith. Copper comes from malachite, iron from hematite, cobalt from cobaltite, carbon from graphite. Composition is what scouting reveals.
- The **cargo hold is a tank**, not slots: one running total per material against a shared capacity. The **hotbar stays** as 10 slots for tools and items — the two never mix, so a morning's mining can never bury your drill under pebbles.
- **[Decided] Volume is the cap; mass is the consequence.** The hold takes a fixed volume (1500 L). Per-material density makes the load's *mass* vary, and too heavy means poor acceleration and no liftoff — but you can still crawl home. Soft failure, real decision.

| material | density (kg/L) |
|---|---|
| regolith (loose) | 1.5 |
| graphite | 2.2 |
| malachite | 4.0 |
| hematite | 5.3 |
| cobaltite | 6.3 |

- One rock is worth **125 litres** of gravel (half a metre cubed) and breaks into **3 pebbles** that share it, so a 1500 L hold takes 12 tiles. Every pebble carries the same mixture, so which one you catch never changes what you get.
- **Richness varies per rock** (±25%), rolled once per rock so a rich tile is rich in all its pieces. Vein-scale richness is still **[Question]**.
- **Suction** grabs everything indiscriminately; strength and range are the upgrade knobs. A **selective magnet** later filters what enters the hold.
- The existing tactile drop mechanic stays: a broken block pops gravel that suction pulls in. A partly-collected pebble shrinks rather than vanishing.
- **[Decided — built] Particles.** Purely visual: a trickle of grit while the drill bites and a burst of chips when the block breaks, with colours sampled from the tile art and cached per tile type, so a new ore gets matching particles for free. They are drawn much *lighter* than the rock — tinting them the sampled colour exactly makes dark grit on dark stone invisible.

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

### Sorting

**[Leaning] Density fractionation by vibration is the first sorter.** Shaking a load so the heavy fraction settles out is real ore beneficiation (shaking tables, jigs, spirals) and it is *mechanically* simple — a motor and a screen, no electronics — so it can be sintered at Tier 1 while a magnetic sorter needs coils and waits for Tier 2. That gives the two a clean division of labour:

- **Vibration (Tier 1, cheap):** a coarse light/heavy split. It cannot tell hematite from cobaltite, because they are close in density.
- **Magnetic/selective (Tier 2+):** picks out one named mineral.

The reason this matters more now: **sorting makes a load more valuable and heavier per litre at the same time.** Concentrate your hold down to pure ore and you have traded flight for value, and you will be driving home. The discarded fraction becomes a tailings pile at the dig site — physical evidence of the work, and a landmark.

**[Question]** Tier 1, or on rover 0 from the start? Tier 1 is the current lean, so the pain of hauling worthless bulk lands before the cure does.

## Rover & module system

The player **builds rovers** assembled from parts. **Rover 0 is simply your current chassis**, made from the same part system. Explicitly **not** a physics rig — no tipping, no torque. A chassis has slots; each part contributes stats or unlocks capabilities.

Part categories, each its own small `Resource` definition (name, **mass**, build cost, **purity**, **condition and max durability**, stats/capability flags granted, **devices exposed to the scripting namespace**):

- **Chassis** — defines slot count/types, base movement stats, and dry mass
- **Mobility** — wheels (fast on flat, bad in mud), treads (slower, steady), possibly hover. Plus the **jetpack**, which is now a thrust value in newtons fighting the rover's mass
- **Extraction** — the drill for solids; a different extractor for fluids
- **Sensors** — the "eyes"; they gate what a rover's program can *ask about*
- **Cargo** — holds gravel; capacity in litres is the stat
- **Collection** — suction, later a selective magnet
- **Processing** — mobile fabrication and smelting, for expeditions
- **Fuel tank** — propellant capacity. Its contents have real mass and burn off in flight, so a bigger tank buys range at the cost of payload
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

## Prototype status (build chat, as of 2026-09-23)

- Side-view movement; tile world with per-tile custom data (`solid`, `minable`, `drop_item_id`). Tiles now draw at 50 px (still physically half a metre).
- **Drill:** mouse-aimed, hold Space with the drill selected, reach 2.8 m (280 px), one second per tile; grid-walk raycast targeting, outlined target.
- **Drops:** a small copy of the tile pops out with random scatter, falls, and hops at random intervals.
- **Suction (still named "magnet" in the code):** hold Space with it selected; pull is `strength × (1/d² − 1/range²)`, computed in real metres and metres³/s², smoothly reaching zero at the range.
- **Hotbar:** 10 slots, one item per slot, no stacking. Starts with the drill and suction.
- **Cargo hold:** `material_table.gd` holds rock compositions, colours and densities; `cargo.gd` is the tank (proportional partial fills both in and out, so a load can't be sorted by luck either way); `cargo_meter.gd` draws it as a filling tank with per-material bands, a legend, mass and a fuel gauge.
- **Physics & mass:** `units.gd` owns the scale (100 px/m — 1 px = 1 cm — and Mars gravity) and every conversion to pixels. Materials have densities, the hold has a `mass()`, and the player moves by force over mass. W holds the jetpack; thrust versus weight decides whether you lift, with no special-case check anywhere.
- **Fuel:** the jetpack burns manufactured propellant with real mass and density; running dry means no thrust at all.
- **Dumping:** hold G to pour gravel back out proportionally, escaping an overloaded hold.
- **Mining particles:** `mining_particles.gd`; grit while drilling, a burst on break, tinted from cached tile colours.
- **Fixed:** hotbar tool icons used to start blank until you pressed a number key (a `_ready()` ordering issue); the first refresh is now deferred until the tree is up.
- Not built yet: charge, damage/wear, flashlight, parts/chassis, crafting, smelting, impurity, sorting, rovers, scripting, hazards, world generation, module art.
- **Testing note:** when scripting a headless verification run, time things with `Engine.get_physics_frames()`. A `SceneTree._process` loop runs per *render* frame, and headless renders far faster than the 60 Hz physics tick, so counting render frames inflates every measured duration.

## Open design questions

- [ ] **Sorting tier** — vibration sorter at Tier 1, or on rover 0 from the start?
- [ ] **Repair** — back to full condition, or permanently a little worse each time?
- [ ] **Fuel economy** — how far does a tank get you, and is the tank's size a build-time trade against cargo?
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
