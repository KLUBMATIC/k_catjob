# k_catjob — Catalytic Converter Theft System (QBCore)

A street-focused catalytic converter theft system for **QBCore**.

Players use a custom **converter saw** on **any parked, empty vehicle** to cut out the catalytic converter.  
Each successful cut grants **one converter**, **materials scaled by level & vehicle class**, and **XP**.  
Converters can then be sold to a shady NPC for a custom dirty-item called **Inkedbills**.

There is **no job/mission system** – everything is **free-roam crime**.

---

## 🔧 Core Features

- 🎯 **Any parked car (no job system)**  
  - Use the configured tool item (e.g. `catsaw`) near **any parked, unoccupied vehicle**.
  - The script:
    - Checks that the vehicle is **empty & stationary**.
    - Ensures it’s not a **blacklisted class** (e.g. emergency vehicles).
    - Optionally blocks **owned vehicles** using a DB plate check.
    - Prevents farming the same plate repeatedly (per-plate cooldown).

- 🧰 **Under-the-car mechanic animation**  
  - When you start cutting:
    - Player is moved to a position underneath/beside the vehicle.
    - Plays a mechanic-style scenario: `WORLD_HUMAN_VEHICLE_MECHANIC`.
    - The vehicle is marked as a **mission entity** and requested for network control to greatly reduce despawns during the progress bar.

- 🔥 **Engine-break, car stays in the world**  
  - On success:
    - The **vehicle is NOT deleted** by this script.
    - Instead, it is made effectively dead:
      - `SetVehicleEngineHealth(vehicle, 0.0)`
      - `SetVehiclePetrolTankHealth(vehicle, 0.0)`
      - `SetVehicleEngineOn(vehicle, false, true, true)`
      - `SetVehicleUndriveable(vehicle, true)`
      - `SetVehicleDoorsLocked(vehicle, 2)`
    - Result: the car becomes a broken shell that **remains** in the world.

- 📈 **XP & Level scaling (no XP popup spam)**  
  - Every successful strip grants XP:
    - XP range per job is configurable.
    - Level thresholds are configurable.
  - Higher level = **more material rewards** (via a scaling multiplier).
  - XP is stored in player metadata: `metadata['catjob_xp']`.
  - XP is used to **gate shop inventory and reward scaling**, not to spam UI popups.
    - No XP toast at the bottom of the screen.
    - XP/Level are exposed primarily via the shop UI header.

- 🛒 **Sleek Scrapper Shop (NUI) – shop only**  
  - **Scrapper NPC** opens a **single shop panel** (no job tab, no extra menus).
  - UI is a clean, modern card on the right side of the screen:
    - Header shows **player level & XP bar**.
    - Item list uses icons pulled from `qb-inventory`’s image path.
    - Each shop item shows label, price, and required level.
  - Items are **level-gated**:
    - If player level < item level, the item is **hidden** from the list.

- 💸 **Buyer NPC – sells converters for Inkedbills**  
  - **Buyer NPC** lets players sell all their `catalytic_converter` items.
  - The script:
    - Checks how many converters the player has.
    - For each converter, randomly rolls between:
      - `Config.Sell.MinDirtyPer` and `Config.Sell.MaxDirtyPer` **Inkedbills**.
    - Grants that many `inkedbills` items.
    - Removes all converters.
  - Inkedbills are a **physical dirty item**, not a currency value.
    - You can use them in your own laundering scripts or black-market systems.

- 🚔 **ps-dispatch alerts (ps-mdt compatible)**  
  - As soon as a player starts cutting a car:
    - A `ps-dispatch` `CustomAlert` is triggered (configurable chance).
    - Includes:
      - Coords
      - Plate (if available)
      - Dispatch code (e.g. `10-60`)
      - Description (“Catalytic Converter Theft”)
      - Radius, sprite, color, etc.
  - These can be viewed by PD using your existing **ps-dispatch / ps-mdt** setup.

- 🛡️ **Anti-abuse protection**
  - **Owned vehicle check** (optional):
    - Uses a configured DB table (e.g. `player_vehicles`) to block stripping owned plates.
  - **Blacklisted vehicle classes**:
    - E.g. `Config.BlacklistedClasses = { 18 }` blocks emergency vehicles.
  - **Per-plate cooldown**:
    - Once a plate is stripped, it can’t be stripped again until `Config.StripCooldownSeconds` has passed.
  - **Per-player cooldown (blade heat)**:
    - After a successful cut, the player is put on cooldown.
    - Attempts to start another cut too soon will show:
      > “Your blade is too hot to cut right now. Let it cool down.”
    - Enforced both in:
      - A **server callback** before starting progressbar.
      - The server event itself as a backup.

---

## 📦 Dependencies

- `qb-core`
- `qb-target`
- `qb-inventory` (or compatible inventory with the same image handling)
- `ps-dispatch` (for police alerts)
- Any DB wrapper that provides a global `MySQL.scalar` (optional for owned-vehicle check)  
  - If `MySQL.scalar` doesn’t exist, the script simply **skips** the owned-vehicle protection and still works.

---

## 📂 Files & Structure

```text
k_catjob/
├── fxmanifest.lua
├── config.lua
├── README.md
├── client/
│   └── main.lua
├── server/
│   └── main.lua
├── html/
│   ├── index.html
│   ├── app.js
│   └── style.css
└── items/
    └── items.lua
