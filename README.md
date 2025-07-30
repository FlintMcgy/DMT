# Dynamic Mission Toolkit (DMT) for DCS World

The **Dynamic Mission Toolkit (DMT)** is an expanding library of ready-to-use mission scripts for [DCS World](https://www.digitalcombatsimulator.com/).  
Each script is **standalone**, **plug-and-play**, and can be dropped directly into your missions without rewriting core logic.

You can use a single script, combine several, or integrate them into larger dynamic missions.  
No unnecessary dependencies — each script lists its own requirements.

<br>

## 📚 Scripts List

- [Capture Zone](#capturezonelua)

<br><br>

## ⚡ Quick Start (General)

Most DMT scripts follow the same basic setup:

1. **Place the script** in your mission folder.  
2. **Open the Mission Editor** and create any required zones, units, or triggers mentioned in the script’s description.  
3. **Add a Trigger:**  
   - Type: `MISSION START`  
   - Action: `DO SCRIPT FILE`  
   - File: `YourScript.lua`  
4. **Save and run the mission** — the script will start automatically.

<br><br>

## 📜 Script Details

### `CaptureZone.lua`

**Description:**  
Manages **zone ownership** and **contested status** by detecting ground units inside trigger zones.

**Features:**

- Progressive capture mechanics  
- Visual zone color changes based on ownership  
- Contested overlays and progress bars  
- Optional player notifications when zones are captured  
- Works entirely with **DCS Scripting API** — no MOOSE or MIST required  
- Requires properly named trigger zones in the Mission Editor  
- **Note:** Does **not** capture airbases — use native DCS capture logic for those  

**Requirements:**

- Trigger zones named according to script instructions
