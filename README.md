# zSuite

Integrated World of Warcraft addon suite combining LorisID, Strix, and PhaseWatcher modules under a unified zUI framework.

**Game Version:** 12.0+ (Retail)

## Modules

| Module | Description |
|--------|-------------|
| **LorisID** | Injects item/spell/quest/NPC IDs into tooltips |
| **Strix** | Mail recipient autocomplete — alt list + recent recipients |
| **PhaseWatcher** | Real-time phase/shard ID detection and display |

## zUI Framework

A dark-themed widget factory providing:

- `StyledFrame` / `TitleBar` / `CloseButton` — consistent window chrome
- `OptionsCheckbox` / `OptionsSlider` / `OptionsColorSwatch` — settings panel widgets
- `AttachScrollBar` — custom scrollbar for ScrollFrame
- `CardLayout.SurfaceVariant` — BASE/PANEL/RAISED/SOFT surface presets
- `Security.IsSafe` / `SafeGet` — Blizzard 12.0 Secret Value protection layer
- `AnimateFrameHeight` — ease-out cubic height animation
- Tabbed options panel via `CreateTabbedOptionsFrame` + `AddOptionsTab`

## Slash Commands

| Command | Action |
|---------|--------|
| `/zsuite` or `/zsuite config` | Open settings panel |
| `/zsuite version` | Show version |
| `/lid` or `/lorisid` | LorisID controls (config/cache/debug) |
| `/strix` | Open Strix settings |
| `/pw` or `/phasewatcher` | PhaseWatcher controls (toggle/hex/dec/lock/reset) |

## Installation

1. Copy the `zSuite` folder into `World of Warcraft\_retail_\Interface\AddOns\`
2. Ensure all game content is downloaded so the game client has access to the required API

## Dependencies

- **Optional:** [LibSharedMedia-3.0](https://www.curseforge.com/wow/addons/libsharedmedia-3-0) — for custom fonts and background textures

## License

[MIT](LICENSE)
