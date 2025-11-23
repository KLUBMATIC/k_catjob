# k_catjob — Catalytic Converter Job (QBCore)

A QBCore job where players talk to an NPC to:
- Start a **catalytic converter theft contract**, or
- Open a **shop** to buy job-related items.

Players get:
- A **search-area zone** on the map (radius blip) where a target vehicle is parked.
- A **locked** vehicle spawned from a tiered vehicle list.
- A long **progressbar** interaction to cut the converter (no skillcheck).
- **One converter per car** plus level-scaled material rewards and XP.
- A **bottom-center popup** showing XP earned and level-up info.
- **ps-dispatch** alert (linked to ps-mdt) as soon as someone starts cutting.

---

## Requirements

- QBCore framework
- `qb-target`
- `qb-inventory` (or compatible inventory using the same NUI images path)
- `ps-dispatch` (for police alerts)
- `ps-mdt` (optional, integrates via ps-dispatch metadata)
- A valid `vehicles.lua` list included with this resource

---

## Files / Structure

```text
k_catjob/
├── fxmanifest.lua
├── config.lua
├── client/
│   └── main.lua
├── server/
│   └── main.lua
├── data/
│   └── vehicles.lua        # Tiered vehicle list used for jobs
├── items/
│   └── items.lua           # Item definitions snippet for qb-core/shared/items.lua
└── html/
    ├── index.html          # Modern UI (Job / Shop / XP)
    ├── style.css
    └── app.js
```

---

## Installation

1. **Place the resource**

   Drop the `k_catjob` folder into your server resources:
   ```text
   resources/[qb]/k_catjob
   ```

2. **Add to server.cfg**

   ```cfg
   ensure k_catjob
   ```

3. **Add items to QBCore**

   Open `qb-core/shared/items.lua` and copy the entries from:

   ```text
   k_catjob/items/items.lua
   ```

   Make sure the `image` names match icons that exist in:
   ```text
   qb-inventory/html/images/
   ```

   Required items generally include (names may vary based on your edits):

   - `catsaw`               – tool used to cut converters
   - `catalytic_converter`  – main loot item
   - `scrapmetal`, `copper`, `steel` – material rewards

4. **Vehicle list**

   The script uses a **tiered vehicle list** defined in:

   ```text
   k_catjob/data/vehicles.lua
   ```

   That file should define a global `CatJobVehicles` table, for example:

   ```lua
   CatJobVehicles = {
       [1] = {
           label  = "Low Tier",
           models = { "blista", "asea", "panto" }
       },
       [2] = {
           label  = "Mid Tier",
           models = { "sultan", "kuruma" }
       },
       [3] = {
           label  = "High Tier",
           models = { "comet2", "schafter3" }
       },
   }
   ```

   The script **does not** pull directly from config vehicle models; it reads from this list and picks tiers based on player level.

5. **Dependencies**

   Make sure these are running and named exactly:

   - `qb-core`
   - `qb-target`
   - `qb-inventory`
   - `ps-dispatch`
   - `ps-mdt` (optional, but expected if you want MDT hooks from dispatch)

---

## Configuration

All configurable options are in `config.lua`.

### NPC

```lua
Config.NPC = {
    model = 's_m_y_dealer_01',
    coords = vector4(123.45, -1034.21, 29.28, 180.0), -- CHANGE to your desired location
    scenario = 'WORLD_HUMAN_CLIPBOARD',
}
```

Set the NPC’s position and model wherever you want players to start the job / open the shop.

### Job Zone / Search Radius

```lua
Config.Job = {
    BlipSprite   = 1,
    BlipColor    = 5,
    BlipText     = 'Target Area',
    SearchRadius = 75.0,  -- meters
    Spots = {
        vector4(426.77, -1028.45, 28.90, 88.0),
        -- add more vector4(x, y, z, heading)
    },
}
```

- Each `Spot` is where a **locked vehicle** can spawn.
- The blip is a **radius** centered on that spot; the car is somewhere inside.
- No route is set; players must search the area.

### Rewards & XP

```lua
Config.Rewards = {
    ConverterItem = 'catalytic_converter',
    MinConverters = 1, -- kept for compatibility; server logic forces 1
    MaxConverters = 1,
    BaseMats      = 1, -- base materials before scaling
    Materials = {
        'scrapmetal',
        'copper',
        'steel',
    }
}

Config.XP = {
    MinXPPerJob = 10,
    MaxXPPerJob = 25,
    Levels = {
        [1] = 0,
        [2] = 100,
        [3] = 250,
        [4] = 500,
        [5] = 800,
        [6] = 1200,
    },
    MaxLevel = 6,
}
```

- Player XP is stored in metadata: `Player.PlayerData.metadata["catjob_xp"]`
- Level determines:
  - Which **tier** of cars they can get
  - How many **materials** they receive (scaled with level & vehicle class)
  - Which **shop items** are unlocked

### Progressbar (cutting time)

```lua
Config.Progress = {
    MinTimeMs = 15000,   -- minimum duration (ms)
    MaxTimeMs = 25000,   -- maximum duration (ms)
    Label     = 'Cutting Converter...',
}
```

The script uses `QBCore.Functions.Progressbar` instead of any skillcheck.

### Dispatch

```lua
Config.Dispatch = {
    Enabled        = true,
    AlertOnFail    = true,   -- still used if you want extra alerts on failures (not required)
    AlertOnSuccess = false,  -- success-based alerts disabled by default
    AlertChance    = 50,     -- percent chance to send an alert
}
```

- **Important:** A `ps-dispatch` alert is triggered **as soon as the player starts using the saw** on the car (subject to `AlertChance`).
- No more success-based or delayed-only alerts; the risk is front-loaded.

---

## How It Works (Gameplay)

1. **Talk to NPC (qb-target)**
   - 3rd eye the NPC, choose **“Talk to Scrapper”**.
   - Opens the modern UI (Job / Shop / XP tabs).

2. **Start Job**
   - In the **Job** tab, click **Start Job**.
   - Server:
     - Reads player XP → computes level.
     - Picks a **vehicle tier** from `data/vehicles.lua`.
     - Randomly picks a **Spot** from `Config.Job.Spots`.
   - Client:
     - Creates a **radius blip** at the spot (search area).
     - Spawns the **locked** target vehicle at that location.

3. **Find & Cut the Car**
   - Player searches the **zone** for the parked job car.
   - Use the `catsaw` item while near the car.
   - As soon as the process starts:
     - `ps-dispatch` alert is sent (if enabled + chance passes).
   - A long **progressbar** runs while the player is “cutting”.

4. **Rewards**
   - On success:
     - 1x `catalytic_converter` is given.
     - Materials (`scrapmetal`, `copper`, `steel`, etc.) given based on:
       - Player level
       - Vehicle class (e.g., high-end cars give more)
     - XP is granted & saved.
   - The car is **not deleted**; it remains in the world, just locked.

5. **XP Popup**
   - On completion, a **bottom-center toast** appears:
     - Shows `XP gained: <amount>`
     - Adds `• Level up: X` if the player leveled.
   - No item list is shown in the toast. Item rewards are visible via inventory / item boxes.

---

## Shop & Level Gating

Shop items are configured in `config.lua`:

```lua
Config.ShopItems = {
    {
        name  = 'catsaw',
        price = 1500,
        amount = 10,
        level = 1,
        label = 'Converter Saw',
    },
    -- etc...
}
```

- Only items where `player_level >= item.level` are shown in the shop UI.
- Each item displays an icon using:
  ```text
  nui://qb-inventory/html/images/<item.image or item.name>.png
  ```

---

## UI / Controls

- **Open UI:** 3rd-eye the NPC → “Talk to Scrapper”.
- **Tabs:**
  - **Job:** Start/see status of current contract.
  - **Shop:** Buy tools & materials (level-gated).
  - **XP:** View XP, current level, and XP needed for next level.
- **Close UI:** ESC or the “×” button in the top-right.

---

## Event Reference

### Client

- `k-catjob:client:OpenMainMenu`
- `k-catjob:client:OpenShop`
- `k-catjob:client:ShowXP`
- `k-catjob:client:RequestJob`
- `k-catjob:client:AssignJob`
- `k-catjob:client:ClearJob`
- `k-catjob:client:UseSaw`
- `k-catjob:client:ShowJobRewards`

### Server

- `k-catjob:server:RequestJob`
- `k-catjob:server:FailJob`
- `k-catjob:server:FinishJob`
- `k-catjob:server:BuyItem`

Callbacks:
- `k-catjob:server:GetShopItems`
- `k-catjob:server:GetXP`
- `k-catjob:server:GetUIData`

---

## Notes / Tips

- If dispatch isn’t firing, make sure `ps-dispatch` is **started** and the resource name matches what this script expects.
- If icons aren’t showing in the shop:
  - Confirm the `image` property in `qb-core/shared/items.lua`.
  - Confirm the corresponding `.png` exists in `qb-inventory/html/images/`.
- You can safely tweak XP / rewards / search radius to tune risk vs reward.

Enjoy ripping converters out of Los Santos in a more structured way. 🔧🚗
