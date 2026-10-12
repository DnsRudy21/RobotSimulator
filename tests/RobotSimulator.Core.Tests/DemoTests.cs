using RobotSimulator.Core;
using static AdvancedTests;

static class DemoTests
{
    static void Test(string name,Action action) => AdvancedTests.Test(name,action);
    static void Reject(Action action) => AdvancedTests.Reject(action);
    static void Near(double actual,double expected,double tolerance=1e-9) => AdvancedTests.Near(actual,expected,tolerance);
    static RobotSimulation Example()
    {
        var simulation=new RobotSimulation(); simulation.ReplaceProject(DemoExample.Create()); simulation.SetSpeed(1); simulation.SetMode(OperatingMode.Automatic); return simulation;
    }
    static void Complete(RobotSimulation simulation,int max=30000)
    {
        for(int i=0;i<max&&simulation.State==ControllerState.Running;i++)simulation.Step(1.0/60);
        Check(simulation.State==ControllerState.Ready,simulation.Status);
    }
    public static void Run()
    {
        Test("M3A parser: all operations, locations and bounded errors",()=>{
            var p=DemoExample.Create(); var code=RobotLanguage.Compile(p); Check(code.Any(i=>i.Op=="MOVEJ")&&code.Any(i=>i.Op=="MOVEL")&&code.Any(i=>i.Op=="IF"));
            foreach(string text in new[]{"UNKNOWN","WAIT NaN","WAIT_INPUT present 1","SET_OUTPUT unknown 1","CALL main","MOVEJ missing 2","REPEAT 101\nWAIT 1\nENDREPEAT","IF present 1\nWAIT 1","WAIT 1\nENDIF","REPEAT 100\nREPEAT 100\nREPEAT 100\nENDREPEAT\nENDREPEAT\nENDREPEAT"}) {
                p.Programs["main"]=text; Reject(()=>RobotLanguage.Compile(p));
            }
            p.Programs["main"]="IF present 1\nWAIT 0.1\nELSE\nWAIT 0.2\nENDIF\nREPEAT 2\nCALL sub\nENDREPEAT"; p.Programs["sub"]="WAIT 0.3";
            var valid=RobotLanguage.Compile(p); Check(valid.Count(i=>i.Location=="sub:1")==2); Check(valid.Single(i=>i.Op=="IF").Jump>=0);
        });
        Test("M3B MoveJ limits, smooth profile and MoveL sampled position/orientation",()=>{
            var project=DemoExample.Create(); var from=project.Points.Single(p=>p.Id=="approach").Angles; var pick=project.Points.Single(p=>p.Id=="pick");
            var linear=Trajectory.Plan(project,from,pick,true,2); var tool=project.Tools[pick.ToolId];
            double maxPosition=0,maxRotation=0;
            for(int i=0;i<=2000;i++) {
                double fraction=i/2000.0; var actual=RobotGeometry.Flange(linear.AtFraction(fraction))*tool;
                var expected=Pose3d.Interpolate(linear.StartTcp,linear.EndTcp,fraction);
                maxPosition=Math.Max(maxPosition,(actual.Position-expected.Position).Length); maxRotation=Math.Max(maxRotation,(actual.Rotation*expected.Rotation.Inverse).Log().Length);
            }
            Check(maxPosition<0.0001,$"MOVEL error {maxPosition}"); Check(maxRotation<Math.PI/1800);
            var joint=Trajectory.Plan(project,new double[6],project.Points.Single(p=>p.Id=="approach"),false,0.1);
            double dt=0.001; var last=joint.At(0); double[] velocity=new double[6]; double maxSpeed=0,maxAcceleration=0;
            for(double t=dt;t<=joint.Duration;t+=dt) {
                var next=joint.At(t);
                for(int j=0;j<6;j++) { double v=(next[j]-last[j])/dt; maxSpeed=Math.Max(maxSpeed,Math.Abs(v)); if(t>dt)maxAcceleration=Math.Max(maxAcceleration,Math.Abs(v-velocity[j])/dt); velocity[j]=v; }
                RobotGeometry.Validate(next); last=next;
            }
            Check(maxSpeed<=Trajectory.MaximumJointSpeed*1.001); Check(maxAcceleration<=Trajectory.MaximumJointAcceleration*1.001);
            Check(joint.At(0).SequenceEqual(new double[6])); Near(joint.At(joint.Duration)[1],0.55);
            Console.WriteLine($"METRIC MOVEL max position error {maxPosition:E3} m; rotation {maxRotation:E3} rad");
        });
        Test("M3A executor branch, repeat, CALL, timeout, step, pause and stop",()=>{
            var sim=new RobotSimulation(); sim.Project.Programs["main"]="IF present 1\nCALL sub\nELSE\nWAIT_INPUT delivered 1 0.1\nENDIF\nREPEAT 2\nWAIT 0.02\nENDREPEAT"; sim.Project.Programs["sub"]="WAIT 0.02";
            sim.SetMode(OperatingMode.Automatic); sim.Start(true); sim.Step(0.02); Check(sim.State==ControllerState.Paused);
            Reject(()=>sim.RequireEditable()); sim.Resume(); Complete(sim); Check(sim.Alarm=="");
            sim.Project.Programs["main"]="WAIT 2"; sim.Start(); sim.Step(0.1); sim.Pause(); var q=sim.JogController.Positions;
            for(int i=0;i<10;i++)sim.Step(0.1); Check(sim.State==ControllerState.Paused&&sim.JogController.Positions.SequenceEqual(q));
            sim.Resume(); sim.Stop(); Check(sim.State==ControllerState.Ready); sim.Step(0.1); Check(!sim.Moving);
            sim.Project.Programs["main"]="WAIT_INPUT delivered 1 0.1"; sim.Start(); sim.Step(0.1); Check(sim.State==ControllerState.Faulted&&sim.Alarm.Contains("timeout"));
            sim.Reset(); Check(sim.State==ControllerState.Ready&&!sim.Moving);
        });
        Test("M4A editable program executes full geometric pick and place",()=>{
            var sim=Example(); var timer=System.Diagnostics.Stopwatch.StartNew(); sim.ValidateProgram(); sim.Start(); Complete(sim);
            Check(sim.Cell.Delivered,sim.Status); Check(!sim.Cell.Holding&&!sim.Cell.Belt); Near((sim.Cell.PartPosition-sim.Project.Cell.Destination).Length,0,0.0001);
            Check(sim.Events.Any(e=>e.Message.Contains("grip 1"))&&sim.Events.Any(e=>e.Message.Contains("grip 0")));
            Console.WriteLine($"METRIC full cycle simulated {sim.Time:F2}s, test wall {timer.Elapsed.TotalSeconds:F2}s");
        });
        Test("M4A absent piece, bad grasp, sensor timeout and recovery",()=>{
            var sim=Example(); sim.Cell.RemovePart(); sim.Start(); for(int i=0;i<200;i++)sim.Step(1.0/60); Check(sim.State==ControllerState.Faulted&&sim.Alarm.Contains("present"));
            sim.Cell.Reset(); sim.Reset(); Check(!sim.Moving); sim.Cell.SensorFault=true; sim.Start(); for(int i=0;i<200;i++)sim.Step(1.0/60); Check(sim.State==ControllerState.Faulted&&sim.Alarm.Contains("timeout"));
            sim.Cell.SensorFault=false; sim.Reset(); sim.Start(); Complete(sim); Check(sim.Cell.Delivered);
            var invalid=Example(); Reject(()=>invalid.Cell.Write("grip",true,invalid.Tcp)); Check(!invalid.Cell.Holding);
        });
        Test("M4B safety causes, reset without restart and risk event",()=>{
            var sim=new RobotSimulation(); sim.Project.Programs["main"]="WAIT 2"; sim.SetMode(OperatingMode.Automatic); sim.Start(); sim.Door(false);
            Check(sim.State==ControllerState.Faulted&&!sim.Moving); Reject(sim.Reset); sim.Door(true); sim.Reset(); Check(sim.State==ControllerState.Ready&&!sim.Moving);
            sim.Start(); sim.EmergencyStop(true); Check(sim.State==ControllerState.EmergencyStopped); Reject(sim.Reset); sim.EmergencyStop(false); sim.Reset(); Check(!sim.Moving);
            sim.SetMode(OperatingMode.Manual); sim.SetInterlock(false); sim.Door(false); Check(sim.State==ControllerState.Ready&&sim.Events.Any(e=>e.Message.Contains("RIESGO")));
            sim.Enable(true); Check(sim.Jog(0,1)); sim.Door(true);
            Reject(()=>sim.SetInterlock(true)); // Configuration is locked during jog.
            sim.StopJog(); sim.SetInterlock(true); sim.Enable(true); Check(sim.Jog(0,1));
            sim.Door(false); Check(!sim.Moving&&!sim.JogController.Enabled);
            sim.ReplaceProject(DemoExample.Create()); Check(sim.State==ControllerState.Faulted); Reject(sim.Reset);
            sim.Door(true); sim.Enable(true); Check(!sim.Jog(0,1)); sim.Reset(); Check(!sim.Moving);
        });
        Test("M4B sampled collision between valid endpoints",()=>{
            var p=DemoExample.Create(); var start=new double[6]; var finish=new double[]{Math.PI/2,0,0,0,0,0};
            p.Cell.Source=new(2,0,0.2); p.Cell.Destination=new(2,1,0.2); p.Cell.Obstacle=new(0.40,0.40,1.13);
            var cell=new TrainingCell(p.Cell); Check(cell.Check(start,p.Tool)==null); Check(cell.Check(finish,p.Tool)==null);
            Check(cell.CheckSweep(start,finish,p.Tool)!=null,"missed between-end collision");
        });
        Test("M3B JSON roundtrip, corruption, unknown fields and load no restart",()=>{
            var p=DemoExample.Create(); var serialized=ProjectStorage.Serialize(p); var copy=ProjectStorage.Deserialize(serialized); Check(copy.Programs["main"]==p.Programs["main"]&&copy.Points.Count==7);
            Reject(()=>ProjectStorage.Deserialize(serialized.Replace("generic-six-axis-v1","invalid"))); Reject(()=>ProjectStorage.Deserialize(serialized.Replace("\"SchemaVersion\": 1","\"SchemaVersion\": 2")));
            Reject(()=>ProjectStorage.Deserialize("{\"unexpected\":1}")); Reject(()=>ProjectStorage.Deserialize("{}")); Reject(()=>ProjectStorage.Deserialize("{bad")); Reject(()=>ProjectStorage.Deserialize(new string('x',1_000_001)));
            Reject(()=>ProjectStorage.Deserialize(serialized.Replace("\"SchemaVersion\": 1","\"SchemaVersion\": 1, \"SchemaVersion\": 1")));
            Reject(()=>ProjectStorage.Deserialize(serialized.Replace("\"Tools\": {","\"Tools\": null, \"discarded\": {")));
            var sim=new RobotSimulation(); sim.ReplaceProject(copy); Check(sim.Mode==OperatingMode.Manual&&sim.State==ControllerState.Ready&&!sim.Moving);
            string file=Path.Combine(Path.GetTempPath(),"RobotSimulator-test-"+Guid.NewGuid().ToString("N")+".json");
            try { ProjectStorage.Save(file,p); Check(ProjectStorage.Load(file).Points[0].Id==p.Points[0].Id); }
            finally { File.Delete(file); }
        });
        Test("M4A changing learner points changes delivered destination",()=>{
            var project=DemoExample.Create();
            foreach(var p in project.Points.Where(p=>p.Id is "transfer" or "place" or "withdraw")) {
                p.Angles[0]=0.6; p.Pose=project.Frames[p.FrameId].Inverse*RobotGeometry.Flange(p.Angles)*project.Tools[p.ToolId];
            }
            var changed=project.Points.Single(p=>p.Id=="place").Pose.Position; var original=project.Cell.Destination;
            Check((changed-original).Length>0.08); project.Cell.Destination=changed;
            var sim=new RobotSimulation(); sim.ReplaceProject(project); sim.SetSpeed(1); sim.SetMode(OperatingMode.Automatic); sim.Start(); Complete(sim);
            Check(sim.Cell.Delivered); Near((sim.Cell.PartPosition-changed).Length,0,0.0001);
        });
        Test("M3B normal trajectory, override acceleration and dt ranges",()=>{
            foreach(double dt in new[]{1.0/30,1.0/120}) {
                var sim=new RobotSimulation(); sim.ReplaceProject(DemoExample.Create()); sim.Project.Programs["main"]="MOVEJ approach 0.1"; sim.SetMode(OperatingMode.Automatic); sim.SetSpeed(1); sim.Start();
                var q=sim.JogController.Positions; var velocity=new double[6]; double maxV=0,maxA=0;
                for(int i=0;i<3000&&sim.State==ControllerState.Running;i++) {
                    if(i==30)sim.SetSpeed(0.5); if(i==60)sim.SetSpeed(1);
                    sim.Step(dt); var next=sim.JogController.Positions;
                    for(int j=0;j<6;j++) { double v=(next[j]-q[j])/dt; maxV=Math.Max(maxV,Math.Abs(v)); if(i>0)maxA=Math.Max(maxA,Math.Abs(v-velocity[j])/dt); velocity[j]=v; } q=next;
                }
                Check(sim.State==ControllerState.Ready,sim.Status); Check(maxV<=Trajectory.MaximumJointSpeed*1.01); Check(maxA<=Trajectory.MaximumJointAcceleration*1.01,$"acceleration {maxA}");
            }
            var paused=Example(); paused.Project.Programs["main"]="MOVEJ approach 3"; paused.Start(); paused.Step(0.1); paused.Pause(); var original=paused.JogController.Positions;
            paused.JogController.SetPositions([0.01,0,0,0,0,0]); paused.Resume(); Check(paused.State==ControllerState.Faulted&&paused.Alarm.Contains("Postura")); Check(!paused.Moving);
            paused.Reset(); Check(!paused.Moving); Reject(()=>paused.Step(double.NaN));
        });
        Test("M3B write permission errors and failed save preserve existing file",()=>{
            if(!OperatingSystem.IsWindows()) { Console.WriteLine("SKIP Windows read-only replace test on non-Windows"); return; }
            string file=Path.Combine(Path.GetTempPath(),"RobotSimulator-permission-"+Guid.NewGuid().ToString("N")+".json");
            try {
                File.WriteAllText(file,"original"); File.SetAttributes(file,FileAttributes.ReadOnly);
                bool rejected=false; try { ProjectStorage.Save(file,DemoExample.Create()); }catch(UnauthorizedAccessException) { rejected=true; }
                Check(rejected); Check(File.ReadAllText(file)=="original");
            } finally { File.SetAttributes(file,FileAttributes.Normal); File.Delete(file); }
        });
        Test("M4 logical TCP cannot teleport the physical grasp and belt follows signals",()=>{
            var sim=Example(); sim.SetMode(OperatingMode.Manual); sim.Enable(true);
            var fixedPose=sim.GripperPose; sim.Project.ActiveTool="flange"; Check((sim.Tcp.Position-fixedPose.Position).Length>0.1);
            sim.ManualOutput("belt",true); var before=sim.Cell.PartPosition; sim.Step(0.1); Near(sim.Cell.PartPosition.Y-before.Y,0.01); Near(sim.Cell.BeltTravel,0.01);
            sim.ManualOutput("belt",false); Reject(()=>sim.ManualOutput("grip",true)); Check(!sim.Cell.Holding);
            sim.EmergencyStop(true); sim.Enable(true); Reject(()=>sim.ManualOutput("belt",true)); Check(!sim.Cell.Belt);
        });
        Test("M5 observation facts, clear on new practice and distinct valid solutions",()=>{
            var practice=new GuidedPractice(); practice.Start(true); practice.Observe("teach"); Check(practice.Has("teach")&&practice.Report().Contains("✓ Enseñar")); practice.Start(true); Check(!practice.Has("teach")); practice.Start(false); practice.Observe("teach"); Check(!practice.Has("teach"));
        });
    }
}
