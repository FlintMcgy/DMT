# Dynamic Mission Toolkit (DMT) for DCS World

The **Dynamic Mission Toolkit (DMT)** is an expanding library of ready-to-use mission scripts for [DCS World](https://www.digitalcombatsimulator.com/).  
Each script is **standalone**, **plug-and-play**, and can be dropped directly into your missions without needing to rewrite core logic.  

You can use a single script, combine several, or integrate them into larger dynamic missions.  
No unnecessary dependencies — each script lists its own requirements.

---

## 📚 Available Scripts

### `CaptureZone.lua` ✅ *(Available Now)*
Manages **zone ownership** and **contested status** by detecting ground units within defined trigger zones.

**Features:**
- Progressive capture mechanics
- Visual zone color changes based on ownership
- Contested overlays and progress bars
- Optional player notifications when zones are captured
- Works entirely with **DCS Scripting API** — no MOOSE or MIST required
- Requires properly named trigger zones in the Mission Editor
- **Note:** Does **not** capture airbases — use native DCS capture logic for those

**Quick Start:**
1. Place `CaptureZone.lua` into your mission’s folder.
2. Create and name your trigger zones as required.
3. Add a trigger:
   - **Type:** `MISSION START`
   - **Action:** `DO SCRIPT FILE`
   - **File:** `CaptureZone.lua`
4. Run the mission — zones will automatically update.

---
