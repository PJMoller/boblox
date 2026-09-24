# Coin Clicker Simulator

A complete Roblox **clicker + pet simulator**, written in Luau and synced to Studio with [Rojo](https://rojo.space).
Simulators are one of the most reliable money-making genres on Roblox: short fun loops, lots of things to collect,
and many natural places to sell game passes and boosts.

## What's in the game

| Feature | Why it matters for earnings |
| --- | --- |
| Click for coins, with a **Click Power** and **Coin Generator** upgrade tree | Simple core loop anyone understands in 5 seconds |
| **Rebirths**: reset for a permanent +50% multiplier | Long-term goals, so players come back |
| **3 eggs, 14 pets, 6 rarities**; pets float behind you | Collecting, rare pulls and showing off. Legendary/Mythic hatches are announced to the whole server |
| **Daily reward** with a 7-day streak | Day-1/day-7 retention, which Roblox's algorithm rewards |
| **6 game passes**: 2x Coins, Auto Clicker, Triple Hatch, Lucky Eggs, +3 Pet Slots, VIP (with a chat tag) | One-time purchases, the biggest revenue source |
| **5 developer products**: 3 coin packs (they scale with your progress so they never become worthless), Instant Rebirth, 2x Server Luck | Repeat purchases. Server Luck is social: one buyer boosts everyone and it's announced |
| **Premium bonus** (+10% coins) | Keeps Premium players around, and Roblox pays you for Premium players' time in your game |
| Auto Clicker works while AFK | Longer sessions mean more Premium Payouts |

Technical details:
- Server-authoritative logic: clients only send requests, and clicks are rate-limited to stop exploiters.
- Saves with DataStores, with retries, autosave every 60s and a final save on shutdown. If loading fails the player is kicked instead of being given an empty save, so progress is never wiped.
- Safe purchase handling: every receipt is de-duplicated and saved before Roblox is told it succeeded.
- All balancing (prices, pets, odds, multipliers) lives in one file: [`src/shared/Config.luau`](src/shared/Config.luau).

## Project layout

```
src/
  shared/   Config.luau (all tuning + monetization IDs), Format.luau (number formatting)
  server/   Main.server.luau, DataService, GameService, MonetizationService
  client/   UI.client.luau (entire UI, built in code), PetFollow.client.luau (pet visuals)
default.project.json   Rojo project (also creates a baseplate + spawn)
```

## Getting it running (about 20 minutes)

1. **Install Roblox Studio** and the **Rojo** Studio plugin (search for "Rojo" in the Creator Store, or see rojo.space).
2. **Install the Rojo CLI.** The easiest route is [Rokit](https://github.com/rojo-rbx/rokit): run `rokit install` in this folder. You can also use the Rojo VS Code extension.
3. Run `rojo serve` in this folder. In Studio, open a new **Baseplate**, click **Rojo → Connect**, and the game syncs in.
   - Or build a place file directly: `rojo build -o game.rbxlx`, then open it in Studio.
4. **File → Publish to Roblox** to create the experience.
5. Enable saving: **Game Settings → Security → Enable Studio Access to API Services** (for testing saves in Studio).
6. Press **Play** to test. In Studio every shop item is shown even before its ID is set. In the live game, items without an ID are hidden.

## Setting up monetization (this is how you get paid)

1. Go to [create.roblox.com](https://create.roblox.com) → your experience → **Monetization → Passes**. Create one pass for each entry in `Config.GamePasses`, give it an icon, and **put it on sale** at the suggested price.
2. **Monetization → Developer Products**: create one product for each entry in `Config.DevProducts`.
3. Paste every numeric ID into `src/shared/Config.luau` (`Id = 0` → `Id = 123456789`) and republish.
   The server prints a warning in the output for anything still missing an ID.
4. Test purchases in Studio. They're free there and go through the real receipt code.

The prices shown in-game are read live from Roblox, so changing a price on the website needs no code change.

## Turning it into a hit

The code does the monetization plumbing. How much you earn depends on getting players in and keeping them. Honestly, most
Roblox games earn little, and the ones that do well usually get there through iteration. Some advice that helps:

- **Make it look good.** Replace the orb pets in `PetFollow.client.luau` with real pet models, and add a themed map. Thumbnails and the icon decide your click-through rate, so spend real effort on them.
- **Add content often.** New eggs and areas are just new entries in `Config.Eggs` and `Config.PetTypes`. Weekly updates, with a note in the game title (e.g. "[UPDATE 3]"), bring players back.
- **Watch your analytics** (Creator Dashboard → Analytics): day-1 retention, session length and payer conversion. Tune prices and odds in `Config.luau` based on the data.
- **Advertise.** Once retention is decent (roughly 10%+ day-1), run Sponsored Experiences ads with a small budget and scale up what works.
- **Community**: a Roblox group and a Discord server for update pings and giveaways.
- **Ideas for next features:** global leaderboards (OrderedDataStore), trading, pet fusing (3 of the same pet into a golden one), playtime rewards, codes, new worlds unlocked by rebirths, and limited-time event eggs.
- Stay within the [Roblox Community Standards](https://en.help.roblox.com/hc/articles/203313410) and paid random item rules. Random paid items must show their odds, which the egg menu already does, and eggs here cost in-game coins, not Robux.

Robux earned can be cashed out through **DevEx** once you meet Roblox's eligibility requirements.
