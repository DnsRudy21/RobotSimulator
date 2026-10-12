namespace RobotSimulator.Core;

public enum PlanningState { Idle, Verifying, Ready, Cancelled, Failed }

/// <summary>Serialized value boundary: no mutable project or Godot objects cross to the worker.</summary>
public sealed record PlanningSnapshot(string ProjectJson, string CellJson, string Key, int MovementIndex = -1)
{
    public RobotProject CreateProject() => ProjectStorage.Deserialize(ProjectJson);
    public TrainingCell CreateCell(RobotProject project) => TrainingCell.FromSnapshot(project.Cell, CellJson);
    private readonly double[] from=[];
    public double[] From { get=>from.ToArray(); init=>from=value.ToArray(); }
}

public sealed class PreparedProgram
{
    internal IReadOnlyList<RobotInstruction> Instructions { get; }
    internal Dictionary<int,(double[] from,Trajectory plan)> Plans { get; } = [];
    public int MovementCount => Plans.Count;
    internal PreparedProgram(IReadOnlyList<RobotInstruction> instructions) => Instructions=instructions;
}

public static class ProgramPlanner
{
    public static PreparedProgram Calculate(PlanningSnapshot snapshot, CancellationToken token, Action<string> progress)
    {
        token.ThrowIfCancellationRequested();
        var project=snapshot.CreateProject(); var cell=snapshot.CreateCell(project);
        var compiled=RobotLanguage.Compile(project, cancellationToken:token); var result=new PreparedProgram(compiled);
        var q=snapshot.From.ToArray();
        for(int i=0;i<compiled.Count;i++) {
            token.ThrowIfCancellationRequested(); var instruction=compiled[i];
            if(snapshot.MovementIndex>=0&&i!=snapshot.MovementIndex)continue;
            if(instruction.Op is not ("MOVEJ" or "MOVEL"))continue;
            progress($"Calculando {instruction.Location} · {instruction.Op} ({i+1}/{compiled.Count})");
            try {
                var point=project.Points.Single(p=>p.Id==instruction.Args[0]);
                var plan=Trajectory.Plan(project,q,point,instruction.Op=="MOVEL",RobotLanguage.Number(instruction.Args[1],0.1,120,instruction.Location),token);
                // Sampling each knot alone misses curved FK sweeps between large joint increments.
                var previous=q;
                foreach(var sample in plan.PlannedSamples) {
                    token.ThrowIfCancellationRequested();
                    var collision=cell.CheckSweep(previous,sample,RobotGeometry.GripperTcp,token);
                    if(collision!=null)throw new InvalidOperationException(collision);
                    previous=sample;
                }
                result.Plans[i]=(q.ToArray(),plan); q=plan.At(plan.Duration);
            } catch(InvalidOperationException e) { throw new InvalidOperationException(instruction.Location+": "+e.Message,e); }
        }
        return result;
    }
}

/// <summary>Owner-thread coordinator. Workers only see snapshots; task completion is never a callback into UI.</summary>
public sealed class PlanningCoordinator : IAsyncDisposable
{
    private readonly Func<PlanningSnapshot,CancellationToken,Action<string>,PreparedProgram> calculate;
    private readonly List<(Task task,CancellationTokenSource source)> tasks=[];
    private Task<PreparedProgram>? current;
    private CancellationTokenSource? source;
    private long revision;
    private long requestRevision;
    private bool disposed;
    private string activity="";
    public PlanningState State { get; private set; }
    public string Activity => Volatile.Read(ref activity);
    public string Error { get; private set; } = "";
    public double DurationMilliseconds { get; private set; }
    private readonly System.Diagnostics.Stopwatch watch=new();
    public PlanningSnapshot? Snapshot { get; private set; }
    public PlanningCoordinator(Func<PlanningSnapshot,CancellationToken,Action<string>,PreparedProgram>? calculator=null) => calculate=calculator??ProgramPlanner.Calculate;
    public void Request(PlanningSnapshot snapshot)
    {
        ObjectDisposedException.ThrowIf(disposed,this); Cancel();
        Snapshot=snapshot with { From=snapshot.From.ToArray() }; source=new(); var token=source.Token;
        var ownRevision=++revision; requestRevision=ownRevision; Error=""; State=PlanningState.Verifying;
        Volatile.Write(ref activity,"Verificando · preparando trayectos"); watch.Restart();
        var isolated=Snapshot;
        current=Task.Run(()=>calculate(isolated,token,message=> { if(Interlocked.Read(ref revision)==ownRevision)Volatile.Write(ref activity,message); }),token);
        tasks.Add((current,source)); Reap();
    }
    private void Reap()
    {
        for(int i=tasks.Count-1;i>=0;i--)if(tasks[i].task.IsCompleted&&tasks[i].task!=current) {
            _=tasks[i].task.Exception; tasks[i].source.Dispose(); tasks.RemoveAt(i);
        }
    }
    public PreparedProgram? Poll(string key)
    {
        Reap(); if(State!=PlanningState.Verifying||current==null)return null;
        if(Snapshot?.Key!=key) { Cancel("Solicitud invalidada: cambió proyecto, postura o entorno"); return null; }
        if(!current.IsCompleted)return null;
        watch.Stop(); DurationMilliseconds=watch.Elapsed.TotalMilliseconds;
        if(requestRevision!=revision||source!.IsCancellationRequested) { Cancel(); return null; }
        if(current.IsCanceled) { Cancel(); return null; }
        if(current.IsFaulted) {
            Error=current.Exception!.Flatten().InnerExceptions[0].ToString(); State=PlanningState.Failed;
            Volatile.Write(ref activity,"Verificación fallida: "+current.Exception.Flatten().InnerExceptions[0].Message); return null;
        }
        State=PlanningState.Ready; Volatile.Write(ref activity,"Programa y trayectos verificados desde la postura actual");
        return current.Result;
    }
    public void Cancel(string reason="Planificación cancelada; se requiere una nueva acción")
    {
        Interlocked.Increment(ref revision); source?.Cancel();
        if(State is PlanningState.Verifying or PlanningState.Ready) { State=PlanningState.Cancelled; Volatile.Write(ref activity,reason); }
    }
    public void Consume() { Cancel(); State=PlanningState.Idle; Volatile.Write(ref activity,""); }
    public async ValueTask DisposeAsync()
    {
        if(disposed)return; disposed=true; Cancel("Planificador cerrado");
        foreach(var item in tasks) { try { await item.task.ConfigureAwait(false); } catch(Exception) { _=item.task.Exception; } item.source.Dispose(); }
        tasks.Clear(); current=null; source=null;
    }
}
