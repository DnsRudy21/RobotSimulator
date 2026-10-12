<p align="center">
  <img src="docs/media/banner.svg" alt="RobotSimulator — Teach. Program. Understand." width="100%">
</p>

<p align="center">
  <strong>Learn industrial robotics by doing.</strong><br>
  Teach points, write programs and understand how a virtual cell recovers from a fault.
</p>

<p align="center">
  <a href="README.md">Español</a> · <a href="README.en.md">English</a> ·
  <a href="docs/DEMO_GUIDE.en.md">Try the demo</a> · <a href="docs/STATUS.md">Project status</a>
</p>

---

## From a first position to a first cycle

**RobotSimulator is an educational Windows demo.** Students use a virtual six-axis robot and a teach pendant to practise concepts they can carry forward when learning equipment from different manufacturers.

The goal is to understand movement, teaching, programming and recovery. The interface uses general concepts and keeps the operating mode, execution controls and alarms visible. **The learner interface is currently in Spanish.**

![Robot and teach pendant in desktop mode](docs/media/desktop.png)

## What you can practise

| Experience | Activity |
|---|---|
| **Move and teach** | Select joint or Cartesian motion, hold enabling input and store points. |
| **Choose references** | Configure the tool and movement reference frame. |
| **Program** | Combine motion, waits, signals, conditions, loops and subprograms. |
| **Run and observe** | Verify a program, step through it or run a pick-and-place cycle. |
| **Diagnose and recover** | Inspect sensors, alarms and events; remove the cause and reset without automatic restart. |
| **Save your work** | Store points, references and programs in local JSON projects. |

## Two ways to try it, one robot

**Desktop:** an orbit camera, mouse and keyboard. Recommended for getting started.

**Simulated spatial interaction:** an in-world panel, ray selection and a virtual keyboard. This exercises the immersive interaction route without a headset.

![The same cell with spatial interaction](docs/media/spatial.png)

> **VR status:** a PC-connected OpenXR adapter is implemented, but hardware validation is pending. Spatial emulation does not validate VR or guarantee compatibility with every headset.

## Try it in 10 minutes

If you have the Windows package:

1. Extract **the entire folder**; keep all companion files beside the executable.
2. Open `RobotSimulator.exe` and select **Escritorio** (Desktop).
3. Open **Práctica y guía** and load the editable example.
4. Inspect points and the program; select **Automático**, verify and start the cycle.
5. Follow the [getting started guide](docs/DEMO_GUIDE.en.md) to try a fault and complete recovery.

The source download does not contain the executable. Follow the [build instructions](docs/DEVELOPMENT.md) to generate your Windows package in `exports/windows-release-immersive/`.

The self-contained Windows x64 package does not require the Godot editor or a separate .NET installation. No account or connection is required during practice. Execution has been checked on the development machine; a clean second PC still needs testing. [Requirements](docs/REQUIREMENTS.md).

## Explore the complete cycle

The demo supports **a successful operation and a recoverable fault**. Alongside the motion, it is possible to inspect the reference frame, point, active instruction and condition that allows execution to continue.

The pendant separates **Mover y enseñar** (Move and teach) from **Programa** (Program). Execution and safety controls remain accessible. A Spanish virtual keyboard supports editing within the spatial route.

<details>
<summary>View the virtual keyboard</summary>

![Spanish virtual keyboard on the spatial surface](docs/media/keyboard.png)

</details>

## Development

The **C# core** is independent of Godot. **Godot .NET** presents the cell and handles interaction. Desktop and spatial assemblies share calculations, programs and states.

Verified environment: **Godot .NET 4.7.2**, **.NET SDK 10.0.401**, Windows x64. Packages are pinned; no essential paid dependencies. Pass `-GodotPath` for a different installation path.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Build-And-Test.ps1 -GodotPath "C:\path\Godot_console.exe"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Export-Demo.ps1 -GodotPath "C:\path\Godot_console.exe"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Smoke-Demo.ps1 -IsolatedCopy
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Package-Demo.ps1
```

[Build and development details](docs/DEVELOPMENT.md). Scripts invoke Godot and .NET directly.

## Status and limits

The current baseline passed **34 core test groups**, interface regressions and **344 spatial workflow checks**. Actual render captures were inspected. Local desktop and emulation samples ran around 60 FPS with VSync; these are not VR performance measurements. [Validation](docs/VALIDATION.md) · [Performance](docs/PERFORMANCE.md).

This demo **does not replace an industrial robot, safety training or certification**. Inverse kinematics has a local domain; grasping and collisions are educational approximations. No physical equipment is controlled. Headset operation, comfort and learning outcomes remain unvalidated.

## Explore

| Goal | Documentation |
|---|---|
| Try the demo for the first time | [Getting started](docs/DEMO_GUIDE.en.md) |
| Check implemented and pending work | [Status](docs/STATUS.md) · [Roadmap](docs/ROADMAP.md) |
| Build or package | [Development](docs/DEVELOPMENT.md) · [Distribution](docs/EXPORT.md) |
| Understand desktop and XR reuse | [Architecture](docs/ARCHITECTURE.md) · [Spatial architecture](docs/XR_ARCHITECTURE.md) |
| Record headset testing | [Hardware checklist](docs/XR_HARDWARE_VALIDATION.md) |
| Review dependencies and credits | [Dependencies](docs/DEPENDENCIES.md) · [Attributions](assets/ATTRIBUTIONS.md) |

### Rights

No license has been selected for the project's own code. It is not presented as open source under a specific license. Godot and .NET notices are preserved in [assets/notices](assets/notices) and included in the Windows package.
