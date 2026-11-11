# Deadly Premonition Recompilation on macOS (experimental)

A native Apple Silicon build of the **USA** version of DPRecomp 2.0.14. It draws through ReXGlue's Vulkan renderer on MoltenVK (Apple's Metal underneath), with no Windows layer and no Rosetta. On an M4 MacBook Air it runs at or near 60 fps in the places tested so far, the forest and the town included.

## What you need

- A Mac with Apple Silicon (M1 or later) and macOS 13.3 Ventura or later. Intel Macs are not supported.
- Your own disc image (`.iso`) of the **USA** Xbox 360 release of Deadly Premonition. The European (PAL) release does not work on the Mac yet: its recompiled code can only be generated from a PAL disc.
- About 6 GB of free space for the extracted game files.

## Playing

1. Unzip `DPRecomp-2.0.14-USA-macOS-arm64.zip` and move **Deadly Premonition Recomp** to your Applications folder.
2. Open it. The app is not notarized by Apple (that needs a paid developer account), so the first time macOS refuses to open it. Go to **System Settings → Privacy & Security**, find the message about Deadly Premonition Recomp near the bottom, click **Open Anyway** and confirm. This is needed only once.
3. The first launch asks for your disc image. Click **Select disc image...**, choose your `.iso` and click **Install**. Extracting takes a few minutes. Click **Continue** and the game restarts by itself.

In the game: **F4** opens the settings overlay (changes apply live; *Save to config* keeps them), **F3** the performance overlay, **F7** achievements. Keyboard and mouse work out of the box; controllers (Xbox, PlayStation, 8BitDo and most others) work through SDL.

## Where your files are

Everything the app writes lives in `~/Library/Application Support/DPRecomp`. To open it, in Finder choose **Go → Go to Folder...** (⇧⌘G) and paste that path.

| | |
|---|---|
| `assets/` | the game files extracted from your disc |
| `userdata/` | saves, profile and the shader cache |
| `deadlyprem.toml` | settings, including the key bindings (`keybind_*`) |
| `logs/` | one log per launch; attach the newest to a bug report |
| `textures/` | texture replacements ([how they work](../README.md#keyboard-prompts-and-texture-modding)) |
| `gamecontrollerdb.txt` | SDL's controller mappings |

Deleting the folder resets the app, saves included. The app itself is never written to.

## Known limitations

- **Button prompts show Xbox buttons.** On Windows the launcher draws the keyboard prompts from your key bindings; there is no launcher on the Mac yet. Settings are changed with F4 or in `deadlyprem.toml`.
- The first visit to an area builds its shaders, which can hitch for a moment. They are saved, so later visits are smooth.
- The same rendering issues as the Windows emulated path, such as flat cloud blotches in some outdoor scenes (#10).
- No native renderer and no FSR: both are Direct3D 12 only.
- Tested so far on one Mac (M4 MacBook Air, 16 GB). Reports from other Macs are very welcome: the Mac model, the scene, the frame rate and the newest log. To see the frame rate, start the game from Terminal with Apple's Metal HUD:
  ```
  MTL_HUD_ENABLED=1 "/Applications/Deadly Premonition Recomp.app/Contents/MacOS/deadlyprem_usa"
  ```

## Building from source

<details>
<summary><b>Click to expand</b></summary>

1. Install the Xcode Command Line Tools (`xcode-select --install`) and, with Homebrew, `brew install cmake ninja molten-vk vulkan-loader vulkan-headers`.
2. Build and install the ReXGlue SDK at commit `0c7b01a` with DPRecomp's SDK patch ([`docs/sdk-patches`](sdk-patches)) and the macOS changes (the `dp-mac` branch of the SDK used for this port): `cmake --preset mac-arm64`, then build and install the `Release` and `RelWithDebInfo` configurations with `cmake --build --preset mac-arm64-release` and `cmake --install out/build/mac-arm64 --config Release` (likewise for RelWithDebInfo).
3. Extract your USA disc into `usa/assets/` (for example with the app's installer, then copy `~/Library/Application Support/DPRecomp/assets`) and run the recompiler in `usa/`: `<SDK install>/bin/rexglue codegen deadlyprem_manifest.toml`.
4. Configure and build the game in `usa/`:
   ```
   cmake --preset mac-arm64-release -DCMAKE_PREFIX_PATH=<SDK install> \
     -DCMAKE_OSX_DEPLOYMENT_TARGET=13.3 \
     -DCMAKE_C_COMPILER=/usr/bin/clang -DCMAKE_CXX_COMPILER=/usr/bin/clang++
   cmake --build out/build/mac-arm64-release -j6 --target deadlyprem
   ```
   The native renderer is left out on the Mac (`DP_NATIVE_RENDERER`, on only on Windows).
5. Package the app: `GAMECONTROLLERDB=<path to gamecontrollerdb.txt> tools/mac/make-app.sh` writes `dist/Deadly Premonition Recomp.app` and the zip. The controller database is optional ([SDL_GameControllerDB](https://github.com/mdqinc/SDL_GameControllerDB)); the Mac default settings are `tools/mac/deadlyprem.toml`.

A build folder also runs as is: `out/build/mac-arm64-release/deadlyprem_usa`, with the game files in an `assets` folder next to it and `tools/mac/deadlyprem.toml` copied there. Saves, settings and logs then stay in that folder, as on Windows.
</details>
