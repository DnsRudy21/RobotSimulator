using Godot;
using System;
using System.Linq;
using System.Collections.Generic;
using RobotSimulator.Core;

public partial class JogBridge : Node
{
    private readonly RobotSimulation simulation = new();
    private ManualJogController controller => simulation.JogController;
    private string lastError = "";
    private bool windowFocused = true;
    private InteractionSession? interaction;
    private InteractionSession InputSession => interaction ??= new(simulation);
    private LocalProjectRepository? repository;
    private LocalProjectRepository Repository => repository ??= new(ProjectSettings.GlobalizePath(ProjectSettings.GetSetting("application/config/projects_directory","user://projects").AsString()));
    public string InputSource() => InputSession.Source;
    public void SelectSource(string source) => InputSession.SelectSource(source);
    public void CancelInput() => InputSession.Cancel();
    public void SessionAvailability(bool active,bool focused) { windowFocused=active&&focused; InputSession.Session(active,focused); }
    public void DeviceAvailability(bool tracked,bool present) => InputSession.Device(tracked,present);
    public bool InputAvailable() => InputSession.Available&&InputSession.DeviceAvailable;
    public bool InputHeld() => InputSession.Held;
    public string[] ProjectNames() { try { return Repository.List(); } catch(Exception e) when(e is System.IO.IOException or UnauthorizedAccessException) { lastError=e.Message; return []; } }
    public bool ProjectExists(string name) { try { return Repository.Exists(name); } catch(ArgumentException e) {lastError=e.Message;return false;} }
    public bool SaveNamedProject(string name,bool replace) => Try(()=> { simulation.RequireEditable(); Repository.Save(name,simulation.Project,replace); simulation.Practice.Observe("save"); });
    public bool LoadNamedProject(string name) => Try(()=> {simulation.ReplaceProject(Repository.Load(name)); simulation.Practice.Observe("load"); });
    public bool NewProject() => Try(()=>simulation.ReplaceProject(new RobotProject()));
    public override void _Ready() => GD.Print("M0: Godot → C# → Core integrado");
    public override void _PhysicsProcess(double delta) => simulation.Step(delta);
    public override void _ExitTree() { _=simulation.DisposeAsync(); }
    public string PlanningStatus() => simulation.Planning.State.ToString();
    public string PlanningActivity() => simulation.Planning.Activity;
    public string PlanningError() => simulation.Planning.Error;
    public double PlanningMilliseconds() => simulation.Planning.DurationMilliseconds;
    public void CancelVerification() => simulation.CancelVerification();
    public void PollVerification() => simulation.PollPlanning();
    public void Enable(bool held) => InputSession.Enable(InputSession.Source,held);
    public void Focus(bool focused) { if(InputSession.Source=="OpenXR")return; SessionAvailability(focused,focused); }
    public double SpeedPercent() => simulation.Override*100;
    // Read-only presentation hints; the invoked Core command remains authoritative.
    public string ActionHint(string action)
    {
        if(!InputSession.DeviceAvailable)return "Controlador/seguimiento no disponible; suelte y vuelva a pulsar";
        if(!windowFocused)return "Regrese a la ventana y vuelva a habilitar";
        bool safe=!simulation.Emergency&&(simulation.DoorClosed||!simulation.InterlockEnabled);
        if(action=="reset")return safe?"":"Retire la causa activa";
        if(action=="edit"||action=="verify") { try { simulation.RequireEditable(); } catch(InvalidOperationException e) { return e.Message; } return action=="verify"&&simulation.Planning.State==PlanningState.Verifying?"Espere o cancele la planificación":""; }
        if(!safe)return "Retire la causa de seguridad y restablezca";
        if(simulation.State is ControllerState.Faulted or ControllerState.EmergencyStopped)return "Retire la causa y restablezca la alarma";
        if(simulation.Planning.State==PlanningState.Verifying)return "Espere o cancele la planificación";
        if(action=="jog")return simulation.Mode!=OperatingMode.Manual?"Jog requiere Manual":simulation.State!=ControllerState.Ready?"Detenga el programa antes de mover":"";
        if(action=="output") { var edit=ActionHint("edit"); if(edit!="")return edit; return simulation.Mode!=OperatingMode.Manual||!controller.Enabled?"Salidas requieren Manual y habilitación mantenida":""; }
        if(action=="start"||action=="step")return simulation.Mode!=OperatingMode.Automatic?"Inicio/Paso requieren Automático":simulation.State!=ControllerState.Ready&&(action!="step"||simulation.State!=ControllerState.Paused)?"Use Pausa/Reanudar o Stop":"";
        if(action=="pause")return simulation.State is ControllerState.Running or ControllerState.Paused?"":"No hay programa activo";
        return "";
    }
    public string ExecutionContext()
    {
        string active=simulation.ActiveInstruction;
        if(active=="—")return "Ejecución: main · sin instrucción activa";
        var location=active.Split(" · ")[0]; int separator=location.LastIndexOf(':');
        if(separator>0&&int.TryParse(location[(separator+1)..],out int line)&&simulation.Project.Programs.TryGetValue(location[..separator],out string? program)) {
            var lines=program.Split('\n'); if(line>0&&line<=lines.Length) {
                string command=lines[line-1].Trim(); var tokens=command.Split((char[]?)null,StringSplitOptions.RemoveEmptyEntries);
                if(tokens.Length>=4&&tokens[0]=="WAIT_INPUT")return $"{location} · espera {tokens[1]}={tokens[2]}, actual={(simulation.Cell.Read(tokens[1])?1:0)}, timeout {tokens[3]} s";
                return $"{location} · {command}";
            }
        }
        return active;
    }
    public void Speed(double percent) => Try(()=>simulation.SetSpeed(percent / 100));
    public bool Jog(int joint, int direction) { lastError=""; return InputSession.Jog(InputSession.Source,joint,direction,false); }
    public bool CartJog(int axis,int direction) { lastError=""; return InputSession.Jog(InputSession.Source,axis,direction,true); }
    public void StopJog() => simulation.StopJog();
    public double Angle(int joint) => controller.Position(joint);
    public double LowerLimit(int joint) => controller.Limits(joint).MinimumRadians;
    public double UpperLimit(int joint) => controller.Limits(joint).MaximumRadians;
    public string ReadStatus() => string.IsNullOrEmpty(lastError)?simulation.Status:lastError;
    public bool Moving() => simulation.Moving;
    private static Vector3 Convert(Vector3d v) { var p=RobotGeometry.ToGodot(v); return new((float)p.X,(float)p.Y,(float)p.Z); }
    public Vector3 JointOrigin(int joint) => Convert(RobotGeometry.Joints[joint].Origin);
    public Vector3 JointAxis(int joint) => Convert(RobotGeometry.Joints[joint].Axis);
    public Vector3 FlangePosition() => Convert(RobotGeometry.Flange(controller.Positions).Position);
    public Basis FlangeBasis()
    {
        var r=RobotGeometry.Flange(controller.Positions).Rotation;
        return new(Convert(r.Apply(new(1,0,0))),Convert(r.Apply(new(0,0,1))),Convert(r.Apply(new(0,-1,0))));
    }
    private bool Try(Action action)
    {
        try { action(); lastError=""; return true; }
        catch(Exception e) when(e is ArgumentException or InvalidOperationException or KeyNotFoundException or System.IO.IOException or UnauthorizedAccessException or System.Text.Json.JsonException) { lastError=e.Message; return false; }
    }
    private static Pose3d PoseFromUi(double[] values)
    {
        if(values.Length!=6||values.Any(v=>!double.IsFinite(v)))throw new ArgumentException("Seis valores finitos requeridos");
        var pose=new Pose3d(new(values[0]/1000,values[1]/1000,values[2]/1000),Rotation3d.FromRpy(new(values[3]*Math.PI/180,values[4]*Math.PI/180,values[5]*Math.PI/180))); pose.Validate(); return pose;
    }
    private static double[] PoseUi(Pose3d pose) { var rpy=pose.Rotation.Rpy(); return [pose.Position.X*1000,pose.Position.Y*1000,pose.Position.Z*1000,rpy.X*180/Math.PI,rpy.Y*180/Math.PI,rpy.Z*180/Math.PI]; }
    public double[] TcpReadout() => PoseUi(simulation.DisplayPose);
    public string ActiveTool() => simulation.Project.ActiveTool;
    public string ActiveFrame() => simulation.Project.ActiveFrame;
    public string[] ToolIds() => simulation.Project.Tools.Keys.ToArray();
    public string[] FrameIds() => simulation.Project.Frames.Keys.ToArray();
    public bool SelectReference(string tool,string frame) => Try(()=> { simulation.RequireEditable(); simulation.CancelPlanning(); if(!simulation.Project.Tools.ContainsKey(tool)||!simulation.Project.Frames.ContainsKey(frame))throw new ArgumentException("Referencia inexistente"); simulation.Project.ActiveTool=tool; simulation.Project.ActiveFrame=frame; simulation.Practice.Observe("references"); });
    public double[] ReferenceValues(bool tool,string id) => PoseUi((tool?simulation.Project.Tools:simulation.Project.Frames)[id]);
    public bool EditReference(bool tool,string id,double[] values) => Try(()=>{ simulation.RequireEditable(); simulation.CancelPlanning(); simulation.Project.UpdateReference(tool,id,PoseFromUi(values)); });
    public bool TeachPoint(string name,bool cartesian) => Try(()=> { simulation.RequireEditable(); simulation.CancelPlanning(); simulation.Project.Teach(name,cartesian?PointKind.Cartesian:PointKind.Joint,controller.Positions); simulation.Practice.Observe("teach"); });
    public string PointsJson() => System.Text.Json.JsonSerializer.Serialize(simulation.Project.Points.Select(p=>new { p.Id,p.Name,Kind=p.Kind.ToString(),p.ToolId,p.FrameId,Values=p.Kind==PointKind.Joint?p.Angles.Select(a=>a*180/Math.PI).ToArray():PoseUi(p.Pose) }));
    public bool EditPoint(string id,string name,double[] values) => Try(()=> {
        simulation.RequireEditable(); simulation.CancelPlanning(); RobotProject.ValidateName(name); var p=simulation.Project.Points.Single(p=>p.Id==id);
        if(values.Length!=6)throw new ArgumentException("Seis valores requeridos");
        if(p.Kind==PointKind.Joint) { var q=values.Select(v=>v*Math.PI/180).ToArray(); RobotGeometry.Validate(q); p.Angles=q; p.Pose=simulation.Project.Frames[p.FrameId].Inverse*RobotGeometry.Flange(q)*simulation.Project.Tools[p.ToolId]; }
        else { var pose=PoseFromUi(values); var world=simulation.Project.Frames[p.FrameId]*pose; var result=InverseKinematics.Solve(world,p.Angles,simulation.Project.Tools[p.ToolId]); if(!result.Success)throw new InvalidOperationException(result.Message); p.Pose=pose; p.Angles=result.Angles; }
        p.Name=name;
    });
    public bool DeletePoint(string id) => Try(()=> {
        simulation.RequireEditable(); simulation.CancelPlanning(); if(simulation.Project.Programs.Values.Any(text=>text.Split((char[]?)null,StringSplitOptions.RemoveEmptyEntries).Contains(id)))throw new InvalidOperationException("Punto usado por programa: retire sus instrucciones antes de borrar");
        var p=simulation.Project.Points.Single(p=>p.Id==id); simulation.Project.Points.Remove(p);
    });
    public string ProgramText(string id) => simulation.Project.Programs.GetValueOrDefault(id,"");
    public string[] ProgramIds() => simulation.Project.Programs.Keys.ToArray();
    public bool EditProgram(string id,string text) => Try(()=> { simulation.RequireEditable(); RobotProject.ValidateId(id); if(text.Length>32000)throw new ArgumentException("Máximo 32000 caracteres"); if(simulation.Project.Programs.GetValueOrDefault(id,"")!=text) { simulation.CancelPlanning(); simulation.Practice.Observe("program"); simulation.Project.Programs[id]=text; } });
    public bool Verify() => Try(()=>simulation.RequestPlanning());
    public bool Mode(bool automatic) => Try(()=>simulation.SetMode(automatic?OperatingMode.Automatic:OperatingMode.Manual));
    public string ReadMode() => simulation.Mode==OperatingMode.Automatic?"Automático":"Manual";
    public string ReadState() => simulation.State.ToString();
    public string Instruction() => simulation.ActiveInstruction;
    public bool Run(bool singleStep) => Try(()=> { if(simulation.State==ControllerState.Paused)simulation.Resume(singleStep); else simulation.RequestPlanning(true,singleStep); });
    public void PauseProgram() => simulation.Pause();
    public void StopProgram() => simulation.Stop();
    public bool ResetAlarm() => Try(simulation.Reset);
    public bool SaveProject(string path) => Try(()=> { simulation.RequireEditable(); simulation.CancelPlanning(); RobotLanguage.Compile(simulation.Project); ProjectStorage.Save(path,simulation.Project); simulation.Practice.Observe("save"); });
    public bool LoadProject(string path) => Try(()=> { simulation.ReplaceProject(ProjectStorage.Load(path)); simulation.Practice.Observe("load"); });
    public Vector3 TcpPosition() => Convert(simulation.Tcp.Position);
    public Vector3 PartPosition() => Convert(simulation.Cell.PartPosition);
    public Basis PartBasis() {
        var r=simulation.Cell.PartRotation; return new(Convert(r.Apply(new(1,0,0))),Convert(r.Apply(new(0,0,1))),Convert(r.Apply(new(0,-1,0))));
    }
    public bool PartExists() => simulation.Cell.PartExists;
    public bool Signal(string id) => simulation.Cell.Read(id);
    public double BeltTravel() => simulation.Cell.BeltTravel;
    public bool Output(string id,bool value) => Try(()=>simulation.ManualOutput(id,value));
    public void Door(bool closed) => simulation.Door(closed);
    public void Emergency(bool active) => simulation.EmergencyStop(active);
    public bool Interlock(bool enabled) => Try(()=>simulation.SetInterlock(enabled));
    public bool DoorIsClosed() => simulation.DoorClosed;
    public bool EmergencyActive() => simulation.Emergency;
    public bool InterlockActive() => simulation.InterlockEnabled;
    public bool SensorFaultActive() => simulation.Cell.SensorFault;
    public bool SensorFault(bool active) => Try(()=>simulation.SetSensorFault(active));
    public bool RemovePart() => Try(simulation.RemovePart);
    public bool ResetCell() => Try(simulation.ResetCell);
    public string EventLog() => string.Join('\n',simulation.Events.Select(e=>$"{e.Time:F2}s · {e.Message}"));
    public string AlarmText() => simulation.Alarm;
    public Vector3 SourcePosition() => Convert(simulation.Project.Cell.Source);
    public Vector3 DestinationPosition() => Convert(simulation.Project.Cell.Destination);
    public Vector3 ObstaclePosition() => Convert(simulation.Project.Cell.Obstacle);
    public Vector3 ObstacleSize() { var v=simulation.Project.Cell.ObstacleHalfSize*2; return new((float)v.X,(float)v.Z,(float)v.Y); }
    public bool ObstacleEnabled() => simulation.Project.Cell.ObstacleEnabled;
    public bool EditDestination(double[] values) => Try(()=> {
        simulation.RequireEditable(); simulation.CancelPlanning(); if(values.Length!=3)throw new ArgumentException("XYZ requerido"); var candidate=new Vector3d(values[0]/1000,values[1]/1000,values[2]/1000);
        if(!candidate.IsFinite||candidate.Length>3||candidate.Z<0.05)throw new ArgumentException("Destino fuera del dominio"); simulation.Project.Cell.Destination=candidate;
    });
    public bool LoadExample() => Try(()=>simulation.ReplaceProject(DemoExample.Create()));
    public bool PracticeMode(bool guided) => Try(()=> { simulation.RequireEditable(); simulation.CancelPlanning(); simulation.Practice.Start(guided); });
    public string PracticeReport() => simulation.Practice.Report();
}
