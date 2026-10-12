namespace RobotSimulator.Core;

public sealed record SimulationEvent(double Time,string Message);
public sealed class RobotSimulation : IAsyncDisposable
{
    public PlanningCoordinator Planning { get; }
    private bool pendingStart, pendingStep, pendingMovement;
    private string? armedKey;
    private string executionModel="";
    private bool disposed;
    private string ModelKey() => System.Text.Json.JsonSerializer.Serialize(new { Project.Cell,Project.Tools,Project.Frames,Project.Points,Project.Programs });
    public RobotSimulation(Func<PlanningSnapshot,CancellationToken,Action<string>,PreparedProgram>? planner=null) { Cell=new(Project.Cell); Planning=new(planner); }
    public ValueTask DisposeAsync() { if(disposed)return ValueTask.CompletedTask; disposed=true; Stop(); return Planning.DisposeAsync(); }
    public void CancelPlanning() { Planning.Cancel(); pendingStart=false; pendingMovement=false; armedKey=null; preparedPlans.Clear(); }
    public void CancelVerification() { if(State==ControllerState.Running&&Planning.State==PlanningState.Verifying)Pause(); CancelPlanning(); Status="Planificación cancelada; se requiere una nueva acción"; }
    private PlanningSnapshot Snapshot(int movement=-1) {
        string json=ProjectStorage.Serialize(Project), cell=Cell.SnapshotJson(); var q=JogController.Positions;
        string key=json+cell+string.Join(',',q.Select(v=>v.ToString("R",System.Globalization.CultureInfo.InvariantCulture)))+$"|{Mode}|{focused}|{DoorClosed}|{Emergency}|{InterlockEnabled}";
        return new(json,cell,key,movement) { From=q };
    }
    public void RequestPlanning(bool start=false,bool step=false) {
        RequireEditable();
        if(start&&(Mode!=OperatingMode.Automatic||!Safe||!focused||State is ControllerState.Faulted or ControllerState.EmergencyStopped))throw new InvalidOperationException("Inicio requiere automático, foco, reset y causas seguras");
        StopJog(); JogController.SetEnabled(false);
        var snapshot=Snapshot();
        if(start&&armedKey==snapshot.Key&&Planning.State==PlanningState.Ready) { BeginPrepared(step); return; }
        pendingStart=start; pendingStep=step; pendingMovement=false; armedKey=null; Planning.Request(snapshot);
        Status="Verificando · puede cancelar";
    }
    private void BeginPrepared(bool step) {
        executionModel=ModelKey();
        index=0; trajectory=null; elapsed=0; singleStep=step; appliedOverride=0;
        State=ControllerState.Running; Status="Ejecutando"; Log("Inicio de main"); armedKey=null;
    }
    public void PollPlanning() {
        if(Planning.State!=PlanningState.Verifying)return;
        string key;
        try { key=Snapshot().Key; }
        catch(Exception e) when(e is ArgumentException or System.Text.Json.JsonException or KeyNotFoundException) {
            CancelPlanning(); Status="Solicitud invalidada: datos actuales inválidos · "+e.Message; return;
        }
        var result=Planning.Poll(key);
        if(result==null) {
            if(Planning.State is PlanningState.Cancelled or PlanningState.Failed) {
                pendingStart=false; armedKey=null; preparedPlans.Clear();
                Status=Planning.Activity; if(pendingMovement) { pendingMovement=false; Fault(Status); }
            }
            return;
        }
        foreach(var p in result.Plans)preparedPlans[p.Key]=p.Value;
        if(pendingMovement) { pendingMovement=false; Status="Replanificación lista"; return; }
        instructions=result.Instructions; armedKey=Planning.Snapshot!.Key; Status=Planning.Activity; Practice.Observe("verify"); Log(Status);
        if(pendingStart) { pendingStart=false; if(Safe&&focused&&Mode==OperatingMode.Automatic&&State==ControllerState.Ready)BeginPrepared(pendingStep); else CancelPlanning(); }
    }
    public ManualJogController JogController { get; } = new();
    public RobotProject Project { get; private set; } = new();
    public TrainingCell Cell { get; private set; }
    public GuidedPractice Practice { get; } = new();
    public OperatingMode Mode { get; private set; }
    public ControllerState State { get; private set; } = ControllerState.Ready;
    public string Status { get; private set; } = "Listo · modo manual";
    public string Alarm { get; private set; } = "";
    public bool DoorClosed { get; private set; } = true;
    public bool Emergency { get; private set; }
    public bool InterlockEnabled { get; private set; } = true;
    public double Time { get; private set; }
    public double Override { get; private set; } = 0.25;
    public IReadOnlyList<SimulationEvent> Events => events.AsReadOnly();
    private readonly List<SimulationEvent> events=[];
    private bool focused=true;
    private int cartAxis=-1,cartDirection;
    private IReadOnlyList<RobotInstruction> instructions=[];
    private int index;
    private bool singleStep;
    private Trajectory? trajectory;
    private double elapsed;
    private double appliedOverride;
    private double[]? resumePose;
    private readonly Dictionary<int,(double[] from,Trajectory plan)> preparedPlans=[];
    public bool Moving => JogController.IsMoving||cartAxis>=0||(State==ControllerState.Running&&trajectory!=null);
    public string ActiveInstruction => index<instructions.Count?instructions[index].Location+" · "+instructions[index].Op:"—";
    public Pose3d Tcp => RobotGeometry.Flange(JogController.Positions)*Project.Tool;
    public Pose3d GripperPose => RobotGeometry.Flange(JogController.Positions)*RobotGeometry.GripperTcp;
    public Pose3d DisplayPose => Project.Frame.Inverse*Tcp;
    private void Log(string message) { events.Add(new(Time,message)); if(events.Count>500)events.RemoveAt(0); }
    private bool Safe => !Emergency&&(DoorClosed||!InterlockEnabled);
    private bool ManualAllowed => Planning.State!=PlanningState.Verifying&&Mode==OperatingMode.Manual&&focused&&JogController.Enabled&&Safe&&State!=ControllerState.Faulted&&State!=ControllerState.EmergencyStopped;
    public void Enable(bool held) { JogController.SetEnabled(held&&Planning.State!=PlanningState.Verifying&&Safe&&Mode==OperatingMode.Manual&&focused&&State==ControllerState.Ready); if(!held)StopJog(); }
    public void Focus(bool value) { focused=value; JogController.SetFocused(value); if(!value) { CancelPlanning(); StopJog(); if(State==ControllerState.Running)Pause(); } }
    public void SetMode(OperatingMode mode) { if(!Enum.IsDefined(mode))throw new ArgumentException("Modo inválido"); Stop(); Mode=mode; JogController.SetMode(mode); Status="Modo "+(mode==OperatingMode.Manual?"manual":"automático"); Log(Status); }
    public void SetSpeed(double fraction) { JogController.SetSpeed(fraction); Override=fraction; }
    public void ManualOutput(string id,bool value) { RequireEditable(); if(!ManualAllowed)throw new InvalidOperationException("Acción manual requiere manual, foco, habilitación, reset y causas seguras"); Cell.Write(id,value,GripperPose); Log($"Salida manual {id}={(value?1:0)}"); }
    public void SetSensorFault(bool active) { Cell.SensorFault=active; Log(active?"Falla de sensor introducida":"Falla de sensor retirada"); }
    public void RemovePart() { RequireEditable(); Cell.RemovePart(); Log("Pieza retirada para ejercicio"); }
    public void ResetCell() { RequireEditable(); Cell.Reset(); Log("Celda repuesta (sin iniciar programa)"); }
    public bool Jog(int axis,int direction)
    {
        StopJog(); if(!ManualAllowed) { Status="Jog bloqueado: manual, foco, habilitación y condiciones seguras"; return false; }
        bool result=JogController.BeginJog(axis,direction); Status=JogController.Status; return result;
    }
    public bool CartesianJog(int axis,int direction)
    {
        StopJog(); if(axis is <0 or >5 || direction is not (-1 or 1))throw new ArgumentException("Eje/sentido inválido");
        if(!ManualAllowed) { Status="Jog cartesiano bloqueado por permisos"; return false; }
        cartAxis=axis; cartDirection=direction; Status="Jog cartesiano "+new[]{"X","Y","Z","Rx","Ry","Rz"}[axis]; return true;
    }
    public void StopJog() { JogController.Stop(); cartAxis=-1; }
    public void Door(bool closed) { DoorClosed=closed; Log(closed?"Puerta cerrada":"Puerta abierta"); if(!closed) { if(InterlockEnabled)Fault("Enclavamiento: puerta abierta"); else Log("RIESGO: puerta abierta con enclavamiento retirado"); } }
    public void EmergencyStop(bool active) { Emergency=active; Log(active?"Paro de emergencia activo":"Causa de emergencia retirada"); if(active) { Fault("Paro de emergencia virtual"); State=ControllerState.EmergencyStopped; } }
    public void SetInterlock(bool enabled) { RequireEditable(); InterlockEnabled=enabled; Log(enabled?"Enclavamiento habilitado":"PRÁCTICA DE RIESGO: enclavamiento retirado"); if(enabled&&!DoorClosed)Fault("Enclavamiento: puerta abierta"); }
    public void Reset()
    {
        if(!Safe)throw new InvalidOperationException("Reset bloqueado: causa activa");
        bool hadFault=State is ControllerState.Faulted or ControllerState.EmergencyStopped;
        Stop(); Alarm=""; State=ControllerState.Ready; JogController.SetEnabled(false); Status="Restablecido; se requiere una nueva acción de inicio"; Log(Status);
        if(hadFault)Practice.Observe("recovery");
    }
    private void Fault(string message) { CancelPlanning(); StopJog(); trajectory=null; Cell.StopActuators(); JogController.SetEnabled(false); State=ControllerState.Faulted; Alarm=message; Status=message; Log("ALARMA: "+message); Practice.Observe("fault"); }
    public void Stop()
    {
        CancelPlanning();
        StopJog(); trajectory=null; elapsed=0; index=0; instructions=[]; preparedPlans.Clear(); resumePose=null; Cell.StopActuators(); JogController.SetEnabled(false);
        if(State is not (ControllerState.Faulted or ControllerState.EmergencyStopped))State=ControllerState.Ready;
        Status="Detenido; inicio ejecutará desde la primera instrucción";
    }
    public void Pause()
    {
        if(State!=ControllerState.Running)return;
        CancelPlanning();
        State=ControllerState.Paused; resumePose=JogController.Positions; Cell.StopActuators(); Status="Pausa · postura conservada; reanudar requiere acción"; Log(Status);
    }
    public void Resume(bool step=false)
    {
        if(State!=ControllerState.Paused||!Safe||!focused)throw new InvalidOperationException("No se puede reanudar en este estado");
        if(resumePose==null||resumePose.Zip(JogController.Positions,(a,b)=>Math.Abs(a-b)).Max()>1e-8) { Fault("Postura cambiada: detener y verificar de nuevo"); return; }
        singleStep=step; State=ControllerState.Running; Status="Reanudado"; Log(Status);
    }
    public void RequireEditable() { if(State is ControllerState.Running or ControllerState.Paused)throw new InvalidOperationException("Programa activo: detenga antes de editar"); if(Moving)throw new InvalidOperationException("Detenga jog antes de editar"); }
    public void ValidateProgram() { RequireEditable(); var compiled=RobotLanguage.Compile(Project); VerifyTrajectories(compiled); Status="Programa y trayectos verificados desde la postura actual"; Log(Status); Practice.Observe("verify"); }
    private void VerifyTrajectories(IReadOnlyList<RobotInstruction> compiled)
    {
        preparedPlans.Clear();
        var result=ProgramPlanner.Calculate(Snapshot(),CancellationToken.None,_=>{});
        foreach(var item in result.Plans)preparedPlans[item.Key]=item.Value;
    }
    public void Start(bool step=false)
    {
        RequireEditable(); if(Mode!=OperatingMode.Automatic||!Safe||!focused||State is ControllerState.Faulted or ControllerState.EmergencyStopped)throw new InvalidOperationException("Inicio requiere automático, foco, reset y causas seguras");
        var compiled=RobotLanguage.Compile(Project); VerifyTrajectories(compiled); StopJog(); instructions=compiled; index=0; trajectory=null; elapsed=0; singleStep=step;
        appliedOverride=0; State=ControllerState.Running; Status="Ejecutando"; Log("Inicio de main");
        executionModel=ModelKey();
    }
    public void ReplaceProject(RobotProject project)
    {
        RequireEditable(); project.Validate(); RobotLanguage.Compile(project);
        bool faultLatched=State is ControllerState.Faulted or ControllerState.EmergencyStopped;
        Stop(); Project=project; Cell=new(project.Cell); if(!faultLatched) { Alarm=""; State=ControllerState.Ready; }
        Mode=OperatingMode.Manual; JogController.SetMode(Mode);
        Status=faultLatched?"Proyecto cargado detenido; alarma enclavada: retire causa y Reset":"Proyecto cargado detenido; postura actual conservada"; Log(Status);
    }
    public void Step(double dt)
    {
        ObjectDisposedException.ThrowIf(disposed,this);
        if(!double.IsFinite(dt)||dt<=0||dt>0.1) { Stop(); throw new ArgumentOutOfRangeException(nameof(dt)); }
        Time+=dt;
        PollPlanning();
        if(!Safe) { StopJog(); return; }
        try {
            if(State==ControllerState.Running)Execute(dt);
            else if(cartAxis>=0)StepCartesian(dt);
            else if(JogController.IsMoving) {
                var previous=JogController.Positions; JogController.Step(dt); var next=JogController.Positions;
                var collision=Cell.CheckSweep(previous,next,RobotGeometry.GripperTcp); if(collision!=null) { JogController.SetPositions(previous); Fault(collision); } else Status=JogController.Status;
            }
            bool beltMoving=Cell.Belt; Cell.Step(dt,GripperPose);
            if(beltMoving) { var dynamicCollision=Cell.Check(JogController.Positions,RobotGeometry.GripperTcp); if(dynamicCollision!=null)Fault("Dispositivo dinámico: "+dynamicCollision); }
        } catch(Exception e) when(e is ArgumentException or InvalidOperationException) { Fault(e.Message); }
    }
    private void StepCartesian(double dt)
    {
        if(!ManualAllowed) { StopJog(); return; }
        var axes=new[]{new Vector3d(1,0,0),new Vector3d(0,1,0),new Vector3d(0,0,1)};
        var worldAxis=Project.Frame.Rotation.Apply(axes[cartAxis%3]); var target=Tcp;
        if(cartAxis<3)target=target with { Position=target.Position+worldAxis*(cartDirection*0.05*Override*dt) };
        else target=target with { Rotation=Rotation3d.AxisAngle(worldAxis,cartDirection*Math.PI/12*Override*dt)*target.Rotation };
        var previous=JogController.Positions; var result=InverseKinematics.Solve(target,previous,Project.Tool);
        if(!result.Success||result.Angles.Zip(previous,(a,b)=>Math.Abs(a-b)).Max()>Math.PI/6*dt*1.05) { StopJog(); Status="Jog detenido: IK/límite/singularidad; cambie postura con jog articular"; return; }
        var collision=Cell.CheckSweep(previous,result.Angles,RobotGeometry.GripperTcp);
        if(collision!=null) { Fault(collision); return; }
        JogController.SetPositions(result.Angles);
    }
    private void Execute(double dt)
    {
        if(ModelKey()!=executionModel) { Fault("Proyecto/entorno cambiado durante ejecución; detener y verificar de nuevo · "+ActiveInstruction); return; }
        if(index>=instructions.Count) { State=ControllerState.Ready; instructions=[]; preparedPlans.Clear(); Planning.Consume(); Status="Programa terminado"; Log(Status); if(Cell.Delivered)Practice.Observe("cycle"); return; }
        var instruction=instructions[index]; bool finished=false;
        switch(instruction.Op) {
            case "MOVEJ": case "MOVEL":
                var point=Project.Points.Single(p=>p.Id==instruction.Args[0]);
                if(trajectory==null) {
                    if(Planning.State==PlanningState.Verifying)return;
                    var from=JogController.Positions;
                    if(preparedPlans.TryGetValue(index,out var prepared)&&prepared.from.Zip(from,(a,b)=>Math.Abs(a-b)).Max()<1e-8)trajectory=prepared.plan;
                    else {
                        pendingMovement=true; Planning.Request(Snapshot(index)); Status="Replanificando "+instruction.Location; return;
                    }
                    Project.ActiveTool=point.ToolId; elapsed=0;
                }
                appliedOverride += Math.Clamp(Override-appliedOverride,-0.5*dt,0.5*dt);
                elapsed+=dt*appliedOverride; var next=trajectory.At(elapsed); var sweep=Cell.CheckSweep(JogController.Positions,next,RobotGeometry.GripperTcp);
                if(sweep!=null)throw new InvalidOperationException(instruction.Location+": "+sweep);
                JogController.SetPositions(next); finished=elapsed>=trajectory.Duration; break;
            case "SET_OUTPUT": Cell.Write(instruction.Args[0],instruction.Args[1]=="1",GripperPose); Log(instruction.Location+": "+string.Join(' ',instruction.Args)); finished=true; break;
            case "WAIT": elapsed+=dt; finished=elapsed>=RobotLanguage.Number(instruction.Args[0],0.01,120,instruction.Location); break;
            case "WAIT_INPUT":
                elapsed+=dt; finished=Cell.Read(instruction.Args[0])==(instruction.Args[1]=="1");
                if(!finished&&elapsed>=RobotLanguage.Number(instruction.Args[2],0.01,120,instruction.Location))throw new InvalidOperationException(instruction.Location+": timeout esperando "+instruction.Args[0]); break;
            case "IF": if(Cell.Read(instruction.Args[0])!=(instruction.Args[1]=="1")) { index=instruction.Jump; return; } finished=true; break;
            case "JUMP": index=instruction.Jump; return;
            default: throw new InvalidOperationException(instruction.Location+": instrucción interna desconocida");
        }
        Status=instruction.Location+" · "+instruction.Op;
        if(finished) {
            index++; trajectory=null; elapsed=0;
            if(singleStep) { State=ControllerState.Paused; resumePose=JogController.Positions; Status="Paso terminado · "+ActiveInstruction; Practice.Observe("step"); }
        }
    }
}
