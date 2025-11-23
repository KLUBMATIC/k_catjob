# k_catjob – Catalytic Converter Job & Scrapper Shop

QBCore job where players talk to an NPC to:
- Start a catalytic converter theft job (specific parked car)
- Open a scrapper shop
- Check their XP / level

Now includes:
- **Custom sleek NUI** (no more qb-menu) with tabs:
  - Job
  - Shop
  - Progress
- Shop items with **item icons based on the image from qb-inventory**.
- ps-ui circle minigame as the skillcheck
- ps-dispatch CustomAlert hook that shows in ps-mdt
- XP system stored in QBCore metadata
- Level-gated shop items
- Material rewards scaling with level

---

## Installation

1. Drop the `k_catjob` folder into your server resources:
   - `resources/[qb]/k_catjob` (or similar)

2. Add this to your `server.cfg` after qb-core and dependencies:

```cfg
ensure qb-core
ensure qb-target
ensure qb-menu
ensure qb-inventory
ensure ps-ui
ensure ps-dispatch
ensure ps-mdt
ensure k_catjob
```

> The NUI uses `qb-inventory` item images via: `nui://qb-inventory/html/images/<imageName>.png`

---

## Required Items

The resource includes an `items/items.lua` file with:

- `catsaw`
- `catalytic_converter`
- `scrapmetal`
- `copper`
- `steel`

They are formatted like standard qb-core items so you can paste/merge them into `qb-core/shared/items.lua`.

Make sure the images exist in `qb-inventory/html/images/`:

- `catsaw.png`
- `catalytic_converter.png`
- `scrapmetal.png`
- `copper.png`
- `steel.png`

(or change the image names in qb-core items if you use different ones).

---

## UI Overview

The NUI lives in `html/index.html` and is opened via qb-target on the scrapper NPC:

- **Header bar**:
  - Title + subtitle
  - Compact XP bar and level indicator
- **Tabs**:
  - `Job` – contract info + "Start Job" button
  - `Shop` – scrollable list of shop items
    - Each row shows:
      - Icon (from qb-inventory image)
      - Name
      - Price & required level
      - Buy button
  - `Progress` – XP & level summary cards

The UI is dark, minimal, and built to look like a professional operations console rather than a native GTA popup.

---

## How It Works

### Opening the UI

- Player 3rd-eyes the scrapper NPC (via qb-target).
- Client triggers `k-catjob:client:OpenMainMenu`, which:
  - Calls `k-catjob:server:GetUIData` to fetch:
    - XP, level, next XP threshold
    - Visible shop items (respecting level requirements) plus image names
  - Opens the NUI with that data.

### Starting a Job

- In the **Job** tab, the player clicks **Start Job**.
- NUI calls `nui_startJob` → client event `k-catjob:client:RequestJob`.
- Server:
  - Picks a random spot from `Config.Job.Spots`.
  - Stores it in `ActiveJobs`.
  - Sends the coords and index back to client.
- Client:
  - Creates a blip and GPS route to that exact parked car location.

### Cutting the Converter

- At the spot, player uses the `catsaw` item.
- Client:
  - Checks distance to job coords.
  - Starts `ps-ui` circle minigame.
- On success:
  - Calls server `FinishJob`:
    - Validates correct spot + proximity.
    - Grants `catalytic_converter` and level-scaled materials.
    - Adds XP, handles level-ups.
    - Optionally triggers ps-dispatch / ps-mdt alert.
- On fail:
  - Job is cleared and can optionally ping dispatch (configurable).

### Shop Icons

- Server-side callbacks consult `QBCore.Shared.Items[item.name].image` (or fall back to `<name>.png`).
- NUI uses those values and renders icons like:
  - `nui://qb-inventory/html/images/catsaw.png`
- This keeps the shop visuals naturally in sync with whatever icons you use in your inventory.

---

## Tweaks

- Change NPC position and ped in `Config.NPC`.
- Add / adjust contract vehicle spots in `Config.Job.Spots`.
- Add more shop items or adjust level gates in `Config.ShopItems`.
- Adjust ps-ui difficulty in `Config.PSUI`.
- Tune dispatch behavior in `Config.Dispatch`.

Enjoy the new clean panel instead of the stock menu. :)


### Better cars + more resources

- The script now uses the **actual GTA vehicle class** (`GetVehicleClass`) of the car you hit.
- All GTA vehicles are supported automatically – if it has a converter, you can try to take it.
- Rewards scale with:
  - **Your level** (XP): each level adds ~15% more payout.
  - **Vehicle class**:
    - Compacts / basic stuff → normal payout.
    - Muscle / sports classics / sedans / SUVs / coupes → +25%.
    - Sports / super cars → +50%.

This scaling affects:
- Number of converters you get.
- Amount of materials you get.
- XP you gain per successful job.


## Vehicle list file (data/vehicles.lua)

The cars the job system "targets" are now defined in a separate file:

- `data/vehicles.lua`

This file defines **tiers** of vehicle models:

- Tier 1 – beaters / compacts
- Tier 2 – sedans, SUVs, muscle
- Tier 3 – high-end, sports & super

On each job request the server:

1. Looks up the player's **level**.
2. Uses that to pick a **tier**.
3. Picks a **random model** from that tier and stores it in the active job data.

Right now the script still lets you cut converters from **any** nearby vehicle at the job location,
but the tier/model is chosen from this file so you can:

- Easily add **custom vehicles**.
- Adjust how "good" the cars get as players level up.
- Hook in future logic (e.g. actually spawning that exact model at the spot, logging, etc.).
