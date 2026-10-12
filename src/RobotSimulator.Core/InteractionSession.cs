namespace RobotSimulator.Core;

/// <summary>Device-independent input ownership. Industrial permissions remain in RobotSimulation.</summary>
public sealed class InteractionSession(RobotSimulation simulation)
{
    public string Source { get; private set; } = "Desktop";
    public bool Available { get; private set; } = true;
    public bool DeviceAvailable { get; private set; } = true;
    private bool released = true;
    private bool held;
    public bool Held => held;
    public void Cancel() { held=false; released=false; simulation.Enable(false); simulation.StopJog(); }
    public void SelectSource(string source)
    {
        if(string.IsNullOrWhiteSpace(source))throw new ArgumentException("Fuente requerida");
        if(source==Source)return;
        Cancel(); simulation.CancelVerification(); if(simulation.State==ControllerState.Running)simulation.Pause(); Source=source;
    }
    public void Session(bool active,bool focused)
    {
        bool next=active&&focused;
        if(next==Available)return;
        Available=next; Cancel(); simulation.Focus(next);
    }
    public void Device(bool tracked,bool present)
    {
        bool next=tracked&&present;
        if(next==DeviceAvailable)return;
        DeviceAvailable=next; Cancel(); if(!next)simulation.CancelVerification();
        // Device loss affects held commands; session loss separately suspends execution.
    }
    public void Enable(string source,bool pressed)
    {
        if(source!=Source)return;
        if(!pressed) { held=false; released=true; simulation.Enable(false); return; }
        if(!Available||!DeviceAvailable||!released)return;
        released=false; simulation.Enable(true); held=simulation.JogController.Enabled;
    }
    public bool Jog(string source,int axis,int direction,bool cartesian)
    {
        if(source!=Source||!Available||!DeviceAvailable||!held)return false;
        return cartesian?simulation.CartesianJog(axis,direction):simulation.Jog(axis,direction);
    }
    public void EndJog(string source) { if(source==Source)simulation.StopJog(); }
}
