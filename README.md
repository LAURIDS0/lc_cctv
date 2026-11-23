# lc_cctv

Hack a building's security room and turn its cameras off for a while. Built on [lc_hack](https://github.com/LAURIDS0/lc_hack): every security room is a computer in the world, with the camera server (NVR) behind it.

The player uses the guard's computer, finds the NVR's login (its web panel gives it away: in the page source, in install notes it links to, or in a note on the guard's desktop), logs in with `ssh`, finds the root password and becomes root. The cameras in the building's area go off, and your other scripts can ask if a place is blind. Every time, the network is built again with new passwords in new places.

## Documentation

Read it on [lc-development.com/docs](https://lc-development.com/docs/#/lc_cctv).

## Requirements

- [lc_hack](https://github.com/LAURIDS0/lc_hack) 1.5.0 or newer
- [ox_lib](https://github.com/overextended/ox_lib)

## Installation

1. Download the [latest release](https://github.com/LAURIDS0/lc_cctv/releases/latest) or clone the repository into your `resources` folder.

   ```
   git clone https://github.com/LAURIDS0/lc_cctv.git
   ```

2. Start it after lc_hack in your `server.cfg`.

   ```cfg
   ensure ox_lib
   ensure lc_hack
   ensure lc_cctv
   ```

3. Add your security rooms to `sites` in `config.lua`, or try it first with `/cctvtest` (admin):

   ```lua
   sites = {
       {
           name = 'bank',
           label = 'Pacific Standard',
           coords = vec3(264.5, 219.8, 101.7),                         -- the guard's computer
           area = { coords = vec3(255.0, 225.0, 101.0), radius = 60.0 }, -- what its cameras cover
       },
   },
   ```

## Using it from other scripts

Server:

```lua
local blind, site = exports.lc_cctv:isAreaBlind(coords)  -- is this position out of sight?
local areas = exports.lc_cctv:getBlindAreas()             -- every area whose cameras are off
exports.lc_cctv:disableCameras('bank', 120)               -- turn a site's cameras off (e.g. after a power cut)
exports.lc_cctv:restoreCameras('bank')                    -- turn them back on

AddEventHandler('lc_cctv:disabled', function(site, duration, source) end)
AddEventHandler('lc_cctv:restored', function(site) end)
```

Client:

```lua
local blind, site = exports.lc_cctv:isBlind()        -- the player's position, or pass coords
RegisterNetEvent('lc_cctv:disabled', function(site, duration) end)
```

The list of blind areas is also in `GlobalState.lc_cctv`. Use it to skip camera alerts in your dispatch script while an area is blind.

## Config

| Option | Default | Description |
| --- | --- | --- |
| `item` | `false` | ox_inventory item needed to use a security computer |
| `attempts` | `3` | Wrong passwords allowed per hack |
| `desktop` | `'random'` | The guard's desktop, `false` for a terminal only |
| `duration` | `300` | Seconds the cameras stay off |
| `cooldown` | `1800` | Seconds before a site can be hacked again |
| `testCommand` | `{ name = 'cctvtest', restricted = 'group.admin' }` | Creates a test site, `false` for none |
| `sites` | | The security rooms |
| `onDisabled` / `onRestored` | | Called when cameras go off and come back on |

A site: `name`, `label`, `coords`, `area`, and optionally `cameras` (how many the NVR lists), `duration`, `cooldown`, `desktop`, `radius` and `screen`.

## License

This project is licensed under the [GNU Lesser General Public License v3.0](LICENSE).

Copyright (c) 2026 LC Development
