namespace RobotSimulator.Core;

// Vocabulario inicial; las transiciones aún no están implementadas.
public enum ControllerState
{
    NotReady, Ready, Running, Paused, Faulted, EmergencyStopped
}
