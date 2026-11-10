# Duplicate Clothing Disassembler

A Cyber Engine Tweaks (CET) mod that disassembles duplicate clothing in V's backpack. From each set of copies it keeps the best one and disassembles the rest. It shows you the list first and only acts when you confirm.

Built 2026-11-10 for game 2.x. **Not tested in game yet.** There was no Lua interpreter to run it here, so the first launch is also its syntax check.

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

**Wardrobe:** the wardrobe keeps its own list of every clothing record you've owned (`WardrobeSystem.GetStoredItemIDs`). Disassembling a copy should leave its look in the wardrobe. **Not yet checked in game.**

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

**From the CET console** (output in `scripting.log`):
```lua
GetMod("DuplicateClothingDisassembler").scan() error("flush")
```
```lua
GetMod("DuplicateClothingDisassembler").run()
```

## First in-game test (checklist)

1. **Load check:** `scripting.log` shows `[DuplicateClothingDisassembler] loaded`, and there are no Lua errors in `cyber_engine_tweaks.log`.
2. **Test setup:** on a test save, give yourself duplicates in the CET console, then **Scan**:
   ```lua
   Game.AddToInventory("Items.Jacket_05_basic_02", 2)
   ```
   ```lua
   Game.AddToInventory("Items.Jacket_05_basic_01", 1)
   ```
   Expected: one Jacket_05_basic_02 to disassemble, and nothing from basic_01.
3. **Disassemble and check:** run it, then check that the components arrived and the wardrobe still has the look.

## Uninstall

Delete the `DuplicateClothingDisassembler` folder. The mod stores nothing and changes nothing until you click Disassemble.

## Licence

MIT, see [LICENSE](LICENSE). Cyberpunk 2077 is a trademark of CD PROJEKT S.A.; this is an unofficial fan mod.
