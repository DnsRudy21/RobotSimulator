# Getting started with RobotSimulator

A guide for anyone trying the demo for the first time. No prior experience with this project is required. The application interface is in Spanish; menu labels below match the application.

## Open the application

Extract the complete Windows package and open `RobotSimulator.exe`, keeping its companion files together. Choose **Escritorio** (Desktop) to begin with mouse and keyboard. No editor installation or login is required.

The source download does not include the executable. Follow [build instructions](DEVELOPMENT.md) to generate it in `exports/windows-release-immersive/`.

## 1. Load and explore the example

Under **Práctica y guía**, select **Cargar ejemplo editable**. The example contains points and a pick-and-place program.

- **Mover y enseñar** displays taught points and their details.
- **Referencias…** shows the tool and base reference frame.
- **Programa** shows instructions and the text editor.

The cell is entirely virtual. It provides practice with general concepts: references, points, motion, signals and recovery, to support later study of equipment from different manufacturers.

## 2. Verify and run

Select **Automático**, then **Verificar**. Wait for the result; verification may take a few seconds. Select **Iniciar** and observe the active instruction and pick-and-place cycle.

**Paso** completes one instruction and pauses. **Pausa/Reanudar** pauses or resumes; **Detener** stops execution. If an alarm appears, **Diagnóstico** shows signals and events.

## 3. Try a sensor fault

With execution stopped, open **Escenario** and select **Reponer celda** before enabling **Introducir falla de sensor de presencia**. Verify and run the example again.

The sensor wait ends in a timeout alarm. Inspect the signal and events under **Diagnóstico**. Disable the fault, remove the cause and select **Restablecer**. Reset does not automatically restart execution; a new start command is required.

Virtual stops, alarms and collisions are educational approximations, not certified industrial safety functions.

## 4. Move and teach a point

With execution stopped and no active alarm, choose **Manual**. Under **Mover y enseñar**, choose a joint and suitable speed. Hold enabling input plus a direction, release to stop, enter a name and select **Enseñar punto**.

Desktop keyboard jog uses **Space + Left/Right** when no text field or detail panel has focus. Changing joint or reference cancels enabling; release and press again. Jog is blocked during text editing.

## 5. Save and load in desktop mode

Open **Proyecto** and select **Guardar JSON**. The default path, `user://robot-demo.json`, is inside the application's data directory. Saving to this path replaces an existing file; change the filename first to keep separate versions.

**Cargar JSON** loads from the specified path. Loading leaves execution stopped in Manual and preserves latched alarms. An invalid file does not replace the current project.

Save before closing or changing modes. Each launch creates a session; unsaved work does not automatically transfer between desktop and spatial mode.

## 6. Try spatial interaction

Open a new session and choose **Interacción espacial simulada**. Load the example under **Práctica y guía** to repeat the cycle.

Mouse aims, click selects, held Space enables manual motion, right mouse simulates looking and the wheel scrolls. Editable fields open a Spanish virtual keyboard with accents, numbers, cursor and selection.

Under **Proyecto**, enter a name and select **Guardar / guardar como**. Existing files require overwrite confirmation. Select a file and **Cargar seleccionado** to load it.

This mode works without a headset. Hardware validation of OpenXR is pending; emulation does not establish VR compatibility. [Spatial guide](XR_DEMO_GUIDE.md).

## Explore further

Edit an instruction or point and verify again to observe how the path and conditions change. Completing this guide does not establish learning outcomes or replace training with real equipment.

An optional [usability evaluation form](HUMAN_VALIDATION.md) is available. [Requirements](REQUIREMENTS.md) · [Status and limits](STATUS.md).
