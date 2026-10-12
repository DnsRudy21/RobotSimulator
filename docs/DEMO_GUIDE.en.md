# A demonstration for teaching colleagues · 10 minutes

The learner interface is in Spanish. This guide gives the important menu labels as they appear in the application.

1. **Prepare.** Extract the complete Windows package, open `RobotSimulator.exe`, select **Escritorio**. Keep all companion files together; no editor or login is needed.
2. **Explain the purpose.** Practise transferable robotics concepts: reference frames, taught points, instructions, signals and fault recovery. The entire cell is virtual.
3. **Inspect the example.** In **Práctica y guía**, load the editable example. Inspect points under **Mover y enseñar**, tool/base under **Referencias…**, and the instruction sequence under **Programa**.
4. **Run.** Select **Automático**, **Verificar**, wait for the result, then **Iniciar**. Observe the active instruction and pick-and-place cycle. Compare **Paso** (Step), **Pausa/Reanudar** (Pause/Resume) and **Detener** (Stop).
5. **Introduce a fault.** In **Escenario**, reset/replenish the cell before activating the sensor fault. Run the example again, wait for its sensor timeout, then inspect **Diagnóstico**. Remove the fault and cause, then **Restablecer** (Reset). Reset does not automatically restart execution.
6. **Teach.** Return to **Manual**, choose a joint, hold enabling input plus direction, release, then teach a point. A change of joint/reference cancels enabling; release and press again. Desktop keyboard jog uses Space plus Left/Right when no text field or detail panel has focus.
7. **Show spatial interaction.** Reopen the demo and select **Interacción espacial simulada**. Mouse aims, click selects, Space represents enabling, right mouse simulates looking and the wheel scrolls. Editing opens the Spanish virtual keyboard. Under **Proyecto**, name and save a project; overwriting requires confirmation. Load it to demonstrate persistence without requiring a desktop file dialog.

Ask colleagues whether teaching, programming and fault recovery are understandable. Record observations in [HUMAN_VALIDATION](HUMAN_VALIDATION.md); leave results blank until an actual person performs the task.

Do not describe spatial emulation as validated VR. No headset, clean second PC, comfort or learning-outcome test has been completed. Educational stops/collisions are not certified industrial safety functions.
