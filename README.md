# pi-drilling

A drilling minigame for FiveM that runs GTA's built-in `DRILLING` scaleform and exposes it as a simple client export.

Fork of [meta-hub/fivem-drilling](https://github.com/meta-hub/fivem-drilling), rewritten to use [ox_lib](https://github.com/overextended/ox_lib) and a callback-free export API.

## Features

- Uses the native `DRILLING` scaleform (no custom NUI)
- Heat, speed and depth mechanics: drill too fast and you overheat, too slow and you make no progress
- Rebindable controls through FiveM's key binding settings
- Configurable difficulty, time limit and UI per call
- Safe against double starts and script errors (the scaleform is always cleaned up)

## Requirements

- [ox_lib](https://github.com/overextended/ox_lib) (a recent version)

## Installation

1. Put the `pi-drilling` folder in your server's `resources` directory.
2. Add the following to your `server.cfg`, making sure `ox_lib` starts first:

```cfg
ensure ox_lib
ensure pi-drilling
```

3. Restart the server or run `refresh` and `ensure pi-drilling`.

## Usage

### Export

```lua
local success, reason = exports['pi-drilling']:StartDrilling()

if success then
    print('Drilling succeeded')
else
    print('Drilling failed', reason)
end
```

`StartDrilling` blocks until the minigame ends. Call it from client-side code only.

| Return values            | Meaning                                          |
| ------------------------ | ------------------------------------------------ |
| `true`                   | The drill reached 100% depth                     |
| `false`                  | The drill overheated or the time limit ran out   |
| `false, 'already_running'` | A drilling minigame is already active          |
| `false, 'error'`         | An error occurred while running the minigame     |

```lua
-- Returns true while the minigame is running
local running = exports['pi-drilling']:IsDrilling()
```

### Options

All options are optional. Unknown keys are ignored.

```lua
local success = exports['pi-drilling']:StartDrilling({
    temperatureRise = 1.0,
    temperatureCool = 1.0,
    depthRate = 0.10,
    speedRate = 0.50,
    maxDuration = 120000,
    showTextUI = true,
    disableMovement = true,
})
```

| Option            | Default  | Description                                                              |
| ----------------- | -------- | ------------------------------------------------------------------------ |
| `temperatureRise` | `1.0`    | How quickly heat builds up while drilling. Higher is harder.             |
| `temperatureCool` | `1.0`    | How quickly the drill cools down when it is not cutting new material.    |
| `depthRate`       | `0.10`   | How quickly the drill moves deeper while the depth key is held.          |
| `speedRate`       | `0.50`   | How quickly the drill speed changes while a speed key is held.           |
| `maxDuration`     | `120000` | Time limit in milliseconds. `0` disables the limit.                      |
| `showTextUI`      | `true`   | Show the control hints with `lib.showTextUI`.                            |
| `disableMovement` | `true`   | Disable the player's movement controls while drilling.                   |

### Event interface

If you prefer events over exports:

```lua
local requestId = 'my-drill-attempt'

AddEventHandler('pi-drilling:client:result', function(id, success, reason)
    if id ~= requestId then return end
    print('Result:', success, reason)
end)

TriggerEvent('pi-drilling:client:start', requestId, {
    showTextUI = true,
})
```

## Controls

| Key | Action                  |
| --- | ----------------------- |
| `W` | Drill deeper            |
| `S` | Retract the drill       |
| `D` | Increase drill speed    |
| `A` | Decrease drill speed    |

The keys can be changed by each player under **Settings → Key Bindings → FiveM**.

## How it works

- The drill only advances into new material while its speed is above 10%. Holding only the depth key does nothing.
- Drilling into new material heats the drill. The faster the drill spins, the faster it heats.
- The hotter the drill gets, the slower it advances.
- Retracting the drill (or letting it sit inside the hole it has already made) cools it down.
- You win by reaching 100% depth. You lose if the temperature reaches 100% or the time limit runs out.

## Notes

- The resource does not play a drill prop, animation or sound, and it does not give any rewards. The calling resource is responsible for those.
- Always validate payouts and loot on the server. The result is produced on the client, so do not treat it as proof that the player really completed the minigame.

## Credits & License

Based on [meta-hub/fivem-drilling](https://github.com/meta-hub/fivem-drilling) by meta-hub.

Differences from the original: ox_lib instead of meta_libs, a client export instead of the `Drilling:Start` event with a callback, configurable options, and revised heat and speed mechanics.

Licensed under the [GPL-3.0](LICENSE).
