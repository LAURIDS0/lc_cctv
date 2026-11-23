# lc_cctv

Break into a building's security room and watch its cameras live. Built on [lc_hack](https://github.com/LAURIDS0/lc_hack): every security room is a computer in the world, with the camera server (NVR) and the cameras behind it.

The player uses the guard's computer, finds the NVR's login (its web panel gives it away), logs in, becomes root and reads the camera list with every camera's IP and password. The cameras are on their own network that only the NVR can reach, so the player opens them from the NVR:

```
view 10.70.2.101
```

Every camera opens in its own window, and several can be open at once. The window that was clicked last is live: the game shows that camera through it. The others freeze on their last picture with a timestamp, until they are clicked.

## Documentation

Read it on [lc-development.com/docs](https://lc-development.com/docs/#/lc_cctv).

## Requirements

- [lc_hack](https://github.com/LAURIDS0/lc_hack) 1.7.0 or newer (camera machines and `view`)
- [ox_lib](https://github.com/overextended/ox_lib)
- [screenshot-basic](https://github.com/citizenfx/screenshot-basic) (optional: the last picture of a camera that is no longer live)

## Installation

1. Download the [latest release](https://github.com/LAURIDS0/lc_cctv/releases/latest) or clone the repository into your `resources` folder.

   ```
   git clone https://github.com/LAURIDS0/lc_cctv.git
   ```

2. Start it after lc_hack in your `server.cfg`.

   ```cfg
   ensure ox_lib
   ensure screenshot-basic
   ensure lc_hack
   ensure lc_cctv
   ```

3. Add your security rooms and their cameras to `sites` in `config.lua`, or try it first with `/cctvtest` (admin), which creates a security room where you stand with four cameras looking at it.

   ```lua
   sites = {
       {
           name = 'bank',
           label = 'Pacific Standard',
           coords = vec3(264.5, 219.8, 101.7),
           cameras = {
               { label = 'Lobby', coords = vec3(240.2, 213.5, 110.5), rotation = vec3(-20.0, 0.0, 250.0), fov = 70.0 },
               { label = 'Vault', coords = vec3(255.1, 228.6, 103.9), rotation = vec3(-30.0, 0.0, 160.0), fov = 60.0 },
           },
       },
   },
   ```

   `rotation` is `vec3(pitch, roll, heading)`: a negative pitch looks down.

## Config

| Option | Default | Description |
| --- | --- | --- |
| `item` | `false` | ox_inventory item needed to use a security computer |
| `attempts` | `3` | Wrong passwords allowed per hack |
| `desktop` | `'random'` | The guard's desktop (the camera windows need one) |
| `refresh` | `3600` | Seconds between new networks and passwords, `false` for never |
| `testCommand` | `{ name = 'cctvtest', restricted = 'group.admin' }` | Creates a test site, `false` for none |
| `sites` | | The security rooms and their cameras |

## License

This project is licensed under the [GNU Lesser General Public License v3.0](LICENSE).

Copyright (c) 2026 LC Development
