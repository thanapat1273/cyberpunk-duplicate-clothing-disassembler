# Duplicate Clothing Disassembler

A Cyber Engine Tweaks (CET) mod that disassembles duplicate clothing in V's backpack. From each set of copies it keeps the best one and disassembles the rest. It shows you the list first and only acts when you confirm.

Built 2026-11-10 for game 2.5. Checked in game ✅:
- **The scan:** colour variants stay apart, and quality is read correctly.
- **The overlay:** disassembled 9 real duplicates with 0 failures, and a rescan found 0 left.
- **The Disassemble Junk button** (2026-11-11), in every combination tried, with Confirm and Cancel each time:
  - duplicates only;
  - junk only;
  - both;
  - cancel, then reopen.

  The popup always closed cleanly.

Not yet tried: turning the link off with the checkbox.

## What counts as a duplicate

Copies are duplicates only when they are **the same TweakDB record**: the same item in the same colour.

- **Colour variants are never mixed.** Each colour variant is its own record with its own appearance, e.g. `Items.Balaclava_02_basic_01` … `_04` (checked in the game's TweakDB: all 2,074 clothing records).
- **Quality isn't part of the record.** A Common and a Legendary copy of `Items.Jacket_05_basic_02` are the same record with a different quality on each copy.

| You have | It keeps | It disassembles |
|---|---|---|
| Jacket A Common + Jacket A Legendary | Legendary | Common |
| Jacket A Legendary × 2 | one Legendary | the other one |
| Jacket A colour 1 + Jacket A colour 2 | both (different records) | nothing |
| Jacket A Rare (**equipped**) + Jacket A Legendary | both: equipped items are never touched | nothing |
| Jacket A Legendary (equipped) + Jacket A Legendary | the equipped one | the other one |

Quality is ranked with the game's own order (`RPGManager.ConvertQualityToCombinedValue`): Common < Common+ < … < Legendary++.

**Never touched:**
- equipped clothing;
- items tagged `Quest`, `IconicWeapon` or `UnequipBlocked`, which the game refuses to disassemble anyway;
- the stash: only V's backpack is read.

## How it disassembles

It uses the game's own path, the same one as the backpack's **Disassemble junk** button:

`ItemActionsHelper.DisassembleItem(player, itemID, amount)` → `DisassembleAction` → `CraftingSystem` → crafting components into the backpack.

So the vanilla checks run again on every item, and you get the normal components.

**Wardrobe:** one copy of every item is always kept, so no look ever leaves your wardrobe.

## Install

Needs **Cyber Engine Tweaks**.

Copy the `bin` folder into the game folder, so the file ends up at:

`bin/x64/plugins/cyber_engine_tweaks/mods/DuplicateClothingDisassembler/init.lua`

## Use

1. **Make a manual save.** Disassembling can't be undone.
2. Open the CET overlay (the key you set for CET).
3. Click **Scan backpack**. You get a list like `Jacket (Items.Jacket_05_basic_02) — keep Legendary | disassemble Common, Rare`.
4. Click **Disassemble N item(s)…**, then **Yes, disassemble**.
5. Click **Scan** again to check that nothing is left.

**From the backpack's Disassemble Junk button** (on by default):
- **Clicking it** opens the usual confirmation. Its number counts your junk **plus** the duplicate clothing copies. With no junk but some duplicates, the button opens the confirmation instead of saying there's no junk.
- **Confirming** disassembles the junk as usual, then the duplicates, with the same rules as above.
- **To turn it off**, untick **"Also run with the backpack's Disassemble Junk button"** in the overlay window. The choice is saved in `settings.json` in the mod's folder.
- **If a hook ever fails** (e.g. after a game update), the button falls back to its vanilla behaviour and the reason goes to the mod's log.
- **If a popup ever stays stuck** (screen dimmed, nothing responds), run `GetMod("DuplicateClothingDisassembler").unlock()` in the CET console.

**From the CET console** (output in `scripting.log`):
```lua
GetMod("DuplicateClothingDisassembler").scan() error("flush")
```
```lua
GetMod("DuplicateClothingDisassembler").run()
```

## First in-game test (checklist)

1. **Load check:** `scripting.log` shows `[DuplicateClothingDisassembler] loaded`, and there are no Lua errors in `cyber_engine_tweaks.log`.
2. **Test setup:** on a test save, give yourself duplicates in the CET console, then **Scan**. `Game.AddToInventory` gives **one** clothing item per call whatever the count, so run the first line twice:
   ```lua
   Game.AddToInventory("Items.Jacket_05_basic_02", 1)
   ```
   ```lua
   Game.AddToInventory("Items.Jacket_05_basic_01", 1)
   ```
   Expected: one Jacket_05_basic_02 to disassemble, and nothing from basic_01 (a different colour). Checked in game 2026-11-10 ✅.
3. **Disassemble and check:** run it, check that the crafting components arrived, then **Scan** again; it should find 0 duplicates.

## Uninstall

Delete the `DuplicateClothingDisassembler` folder. It stores only its own `settings.json`, and changes nothing until you confirm a disassemble.

## Licence

MIT, see [LICENSE](LICENSE). Cyberpunk 2077 is a trademark of CD PROJEKT S.A.; this is an unofficial fan mod.
