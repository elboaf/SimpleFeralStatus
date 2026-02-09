# SimpleFeralStatus for Turtle WoW

A lightweight addon for Feral Druids in Turtle WoW that displays energy/rage, caster mana, combo points, and energy tick tracking in a compact, integrated UI.

## Features

- **Three-tier Display System:**
  - **Top row:** 5 Combo Points (red indicators, Cat form only)
  - **Middle row:** Form Resource (Energy in Cat form, Rage in Bear form, Mana in non-combat forms)
  - **Bottom row:** Caster Mana (shown only in combat forms - Cat and Bear)

- **Energy Tick Tracker:** Visual white spark that shows the timing of your next natural energy regeneration tick (Cat form only)

- **Smart Form Detection:** Automatically switches between energy (yellow), rage (red), and mana (blue) displays based on your current shapeshift form

- **Unified Movement:** All UI elements move together as one unit when unlocked

## Installation

1. Download the `SimpleFeralStatus.lua` file
2. Place it in your `World of Warcraft\Interface\AddOns\` folder
3. Create a new folder called `SimpleFeralStatus` (if it doesn't exist)
4. Move the `.lua` file into that folder
5. Restart WoW or type `/reload` in-game

## Configuration

### Dimensions:
- All bars are 120 pixels wide × 6 pixels tall
- Combo points are 24 pixels each (total 120 pixels, no spacing)
- No gaps between bars

### Default Position:
Centered on screen

## Slash Commands

- `/sfs` or `/simpleferal` - Show help menu
- `/sfs reset` - Reset all frame positions to center screen
- `/sfs lock` - Lock frames in place
- `/sfs unlock` - Unlock frames for moving (drag the energy/rage bar)
- `/sfs spark` - Toggle energy spark visibility
- `/sfs debug` - Show debug information about forms and resources

## How to Use

1. **Moving the UI:** Type `/sfs unlock`, then drag the middle (energy/rage) bar to move all elements together
2. **Locking Position:** After positioning, type `/sfs lock` to prevent accidental movement
3. **Form-Specific Displays:**
   - **Cat Form:** Yellow energy bar + red combo points + mana bar below + energy tick spark
   - **Bear Form:** Red rage bar + mana bar below (no combo points)
   - **Caster/Moonkin/Travel Forms:** Blue mana bar only (bottom bar hidden)
4. **Energy Management:** Watch the white spark move along the energy bar to anticipate your next energy tick

## Technical Details

- **Energy Tick Logic:** Tracks natural 20-energy ticks (every 2 seconds) separately from ability-based energy gains
- **Form Detection:** Uses `GetShapeshiftFormInfo()` to detect all druid forms including Moonkin and Travel forms
- **Resource Tracking:** Utilizes Turtle WoW's enhanced `UnitMana()` which returns both form resource and caster mana
- **Event-Driven Updates:** Efficiently updates only when relevant game events occur

## Compatibility

- Designed specifically for **Turtle WoW** (uses Turtle-specific API features)
- Works only for Druid characters (auto-hides for other classes)
- Lightweight with minimal performance impact

## Notes

- The mana bar only shows in combat forms (Cat/Bear) since caster forms already display mana in the default UI
- Combo points only appear in Cat form
- Energy tick spark only appears in Cat form when not at full energy
- All elements are precisely aligned with no gaps for a clean, integrated look

## Troubleshooting

If the addon doesn't work:
1. Verify the file is in the correct folder: `Interface\AddOns\SimpleFeralStatus\SimpleFeralStatus.lua`
2. Check if you're playing a Druid character
3. Try `/sfs debug` to see current form and resource information
4. Use `/reload` to reload the UI

## Credits

Created for the Turtle WoW community. Based on classic WoW addon design principles with Turtle WoW-specific enhancements.
