using RobotSimulator.Core;
using System.Diagnostics;
using static AdvancedTests;

static class ConsolidationTests
{
    static void Test(string name,Action action) => AdvancedTests.Test(name,action);
    static void Reject(Action action) => AdvancedTests.Reject(action);
    static void Until(Func<bool> done) { var watch=Stopwatch.StartNew(); var spin=new SpinWait(); while(!done()) { if(watch.Elapsed.TotalSeconds>15)throw new Exception("Bounded wait timed out"); spin.SpinOnce(); } }
    static PlanningSnapshot Snapshot(RobotProject p,double[]? q=null) => new(ProjectStorage.Serialize(p),new TrainingCell(p.Cell).SnapshotJson(),"fixed") { From=q??new double[6] };
    static void Drain(RobotSimulation sim) => Until(()=> { sim.PollPlanning(); return sim.Planning.State!=PlanningState.Verifying; });
    public static void Run()
    {
        Test("C1 cancellation, substitution, stale completion, exception and disposal gates",()=> {
            using var entered=new ManualResetEventSlim(); using var release=new ManualResetEventSlim();
            var p=new RobotProject(); p.Programs["main"]="WAIT 0.01";
            int calls=0; using var secondDone=new ManualResetEventSlim();
            var c=new PlanningCoordinator((s,t,progress)=> {
                if(Interlocked.Increment(ref calls)==1) { entered.Set(); if(!release.Wait(10000))throw new Exception("gate timeout"); }
                var result=ProgramPlanner.Calculate(s,CancellationToken.None,progress); if(calls>=2)secondDone.Set(); return result;
            });
            c.Request(Snapshot(p)); Check(entered.Wait(5000)); c.Cancel(); Check(c.Poll("fixed")==null&&c.State==PlanningState.Cancelled);
            c.Request(Snapshot(p)); Check(secondDone.Wait(5000)); PreparedProgram? plan=null; Until(()=> { plan=c.Poll("fixed"); return c.State==PlanningState.Ready; }); Check(plan!=null);
            release.Set(); c.DisposeAsync().AsTask().GetAwaiter().GetResult(); // Old worker intentionally ignores token: cannot override current result.
            Reject(()=>c.Request(Snapshot(p)));
            var failure=new PlanningCoordinator((s,t,progress)=>throw new InvalidOperationException("worker marker")); failure.Request(Snapshot(p));
            Until(()=> { failure.Poll("fixed"); return failure.State==PlanningState.Failed; }); Check(failure.Error.Contains("worker marker")&&failure.Error.Contains("InvalidOperationException")); failure.DisposeAsync().AsTask().Wait();
            var running=new RobotSimulation(); running.Project.Programs["main"]="WAIT 2"; running.SetMode(OperatingMode.Automatic); running.Start(); running.DisposeAsync().AsTask().Wait(); Check(running.State==ControllerState.Ready&&!running.Moving); Reject(()=>running.Step(.01));
        });
        Test("C1 project/point/frame/environment changes and stop/focus/emergency prevent late start",()=> {
            foreach(string change in new[]{"program","point","frame","environment","stop","focus","emergency","door","close"}) {
                using var entered=new ManualResetEventSlim(); using var release=new ManualResetEventSlim();
                var sim=new RobotSimulation((s,t,progress)=> { entered.Set(); release.Wait(t); return ProgramPlanner.Calculate(s,t,progress); });
                sim.ReplaceProject(DemoExample.Create()); sim.Project.Programs["main"]="WAIT 0.01"; sim.SetMode(OperatingMode.Automatic); sim.RequestPlanning(true);
                Check(entered.Wait(5000));
                switch(change) {
                    case "program": sim.Project.Programs["main"]="WAIT 0.02"; break;
                    case "point": sim.Project.Points[0].Angles[0]=0.01; break;
                    case "frame": sim.Project.Frames["piece"]=new(new(0.01,0,0),Rotation3d.Identity); break;
                    case "environment": sim.Project.Cell.ObstacleEnabled=false; break;
                    case "stop": sim.Stop(); break;
                    case "focus": sim.Focus(false); break;
                    case "emergency": sim.EmergencyStop(true); break;
                    case "door": sim.Door(false); break;
                    case "close": var closing=sim.DisposeAsync().AsTask(); release.Set(); closing.Wait(); break;
                }
                if(change!="close") { sim.PollPlanning(); release.Set(); sim.DisposeAsync().AsTask().Wait(); }
                Check(sim.State!=ControllerState.Running&&!sim.Moving,change+" caused late start");
            }
        });
        Test("C1 cooperative representative cancellation <=100 ms and equivalent complete plans",()=> {
            var p=DemoExample.Create(); var snapshot=Snapshot(p); var expected=ProgramPlanner.Calculate(snapshot,CancellationToken.None,_=>{});
            var coordinator=new PlanningCoordinator(); coordinator.Request(snapshot); PreparedProgram? actual=null;
            Until(()=> { actual=coordinator.Poll("fixed"); return coordinator.State!=PlanningState.Verifying; }); Check(actual!=null&&actual.MovementCount==expected.MovementCount);
            coordinator.DisposeAsync().AsTask().Wait();
            using var token=new CancellationTokenSource(); using var entered=new ManualResetEventSlim();
            p.Programs["main"]="REPEAT 20\nMOVEJ approach 2\nMOVEL pick 2\nMOVEL lift 2\nENDREPEAT";
            var workload=Snapshot(p); var task=Task.Run(()=>ProgramPlanner.Calculate(workload,token.Token,_=>entered.Set()));
            Check(entered.Wait(5000)); var watch=Stopwatch.StartNew(); token.Cancel(); try { task.GetAwaiter().GetResult(); throw new Exception("Ignored cancellation"); } catch(OperationCanceledException) { }
            double latency=watch.Elapsed.TotalMilliseconds; Console.WriteLine($"METRIC cancellation {latency:F3} ms"); Check(latency<=100,$"Cancellation exceeded100ms: {latency}");
            var sync=new RobotSimulation(); sync.ReplaceProject(DemoExample.Create()); sync.SetMode(OperatingMode.Automatic); sync.SetSpeed(1); sync.Start();
            var asyncSim=new RobotSimulation(); asyncSim.ReplaceProject(DemoExample.Create()); asyncSim.SetMode(OperatingMode.Automatic); asyncSim.SetSpeed(1); asyncSim.RequestPlanning(true); Drain(asyncSim);
            for(int i=0;i<2000&&sync.State==ControllerState.Running;i++) { sync.Step(1.0/60); asyncSim.Step(1.0/60); Check(sync.JogController.Positions.Zip(asyncSim.JogController.Positions,(a,b)=>Math.Abs(a-b)).Max()<1e-10); }
            Check(sync.Cell.Delivered&&asyncSim.Cell.Delivered&&asyncSim.State==ControllerState.Ready); asyncSim.DisposeAsync().AsTask().Wait(); sync.DisposeAsync().AsTask().Wait();
        });
        Test("C2 fixed-seed local IK campaign with rotated frame/displaced TCP and rejection",()=> {
            var random=new Random(20261011); int successes=0; double maxP=0,maxR=0;
            for(int i=0;i<120;i++) {
                var q=new double[]{(random.NextDouble()-.5)*2,.4+random.NextDouble()*.4,.25+random.NextDouble()*.4,(random.NextDouble()-.5)*.6,.2+random.NextDouble()*.5,(random.NextDouble()-.5)*.6};
                var tool=new Pose3d(new(.12,.025,-.015),Rotation3d.FromRpy(new(.1,-.2,.15)));
                var frame=new Pose3d(new(.1,-.2,.05),Rotation3d.FromRpy(new(.2,.1,-.4)));
                var local=frame.Inverse*RobotGeometry.Flange(q)*tool; var target=frame*local;
                var seed=q.Select(a=>a+(random.NextDouble()-.5)*.04).ToArray(); var r=InverseKinematics.Solve(target,seed,tool);
                if(!r.Success)continue; successes++; RobotGeometry.Validate(r.Angles);
                var fk=RobotGeometry.Flange(r.Angles)*tool; double pe=(fk.Position-target.Position).Length,re=(fk.Rotation*target.Rotation.Inverse).Log().Length;
                maxP=Math.Max(maxP,pe); maxR=Math.Max(maxR,re); Check(pe<.0001&&re<Math.PI/1800); Check(r.Angles.Zip(seed,(a,b)=>Math.Abs(a-b)).Max()<.1,"local branch jump");
            }
            Check(successes==120,$"Supported nearby campaign {successes}/120");
            var unreachable=new Pose3d(new(3,3,3),Rotation3d.Identity); var rejected=InverseKinematics.Solve(unreachable,new double[6],RobotGeometry.GripperTcp); Check(!rejected.Success&&rejected.Angles.All(a=>a==0)&&rejected.Message.Contains("residual"));
            Console.WriteLine($"METRIC IK seed20261011 {successes}/120, maxP={maxP:E3}m maxR={maxR:E3}rad");
        });
        Test("C3 thin obstacle sweep, dynamic free piece, allowed pickup and changed environment",()=> {
            var p=DemoExample.Create(); p.Cell.Source=new(2,0,.2); p.Cell.Destination=new(2,1,.2); p.Cell.Obstacle=new(.45,.45,1.13); p.Cell.ObstacleHalfSize=new(.001,.15,.15);
            var cell=new TrainingCell(p.Cell); double[] from=new double[6],to=[Math.PI/2,0,0,0,0,0]; Check(cell.Check(from,RobotGeometry.GripperTcp)==null&&cell.Check(to,RobotGeometry.GripperTcp)==null);
            Check(cell.CheckSweep(from,to,RobotGeometry.GripperTcp)?.Contains("obstáculo")==true);
            var example=DemoExample.Create(); var pickup=example.Points.Single(x=>x.Id=="pick").Angles; var contact=new TrainingCell(example.Cell); Check(contact.Check(pickup,RobotGeometry.GripperTcp)==null,"allowed pickup contact");
            var sim=new RobotSimulation(); sim.ReplaceProject(example); sim.SetMode(OperatingMode.Automatic); sim.RequestPlanning(); Drain(sim); Check(sim.Planning.State==PlanningState.Ready,sim.Status);
            sim.Project.Cell.Obstacle=RobotGeometry.Flange(from).Position; sim.RequestPlanning(true); Drain(sim); Check(sim.Planning.State==PlanningState.Failed&&sim.State!=ControllerState.Running,"changed environment reused plan"); sim.DisposeAsync().AsTask().Wait();
        });
        Test("C2 limits/singular seed/orientation, complete MoveL and interior rejection",()=> {
            foreach(int axis in new[]{0,3,5}) {
                double[] q=[.2,.55,.55,.1,.3,.1]; q[axis]=RobotGeometry.Joints[axis].Limits.MaximumRadians-.01;
                var pose=RobotGeometry.Flange(q)*RobotGeometry.GripperTcp;
                var result=InverseKinematics.Solve(pose,q,RobotGeometry.GripperTcp); Check(result.Success); RobotGeometry.Validate(result.Angles);
            }
            var singular=InverseKinematics.Solve(RobotGeometry.Flange(new double[6])*RobotGeometry.GripperTcp,new double[6],RobotGeometry.GripperTcp); Check(singular.Success); // Already at target, not evidence of crossing singularity.
            var p=DemoExample.Create(); var from=p.Points.Single(x=>x.Id=="approach").Angles;
            var point=p.Points.Single(x=>x.Id=="pick"); var linear=Trajectory.Plan(p,from,point,true,.1);
            double[] previous=linear.At(0),velocity=new double[6]; double maxV=0,maxA=0; const double dt=.001;
            for(double t=dt;t<linear.Duration;t+=dt) {
                var q=linear.At(t); RobotGeometry.Validate(q); var actual=RobotGeometry.Flange(q)*p.Tool;
                double normalized=t/linear.Duration,s=normalized*normalized*normalized*(10+normalized*(-15+6*normalized));
                var expected=Pose3d.Interpolate(linear.StartTcp,linear.EndTcp,s);
                Check((actual.Position-expected.Position).Length<.0001&&(actual.Rotation*expected.Rotation.Inverse).Log().Length<Math.PI/1800);
                for(int j=0;j<6;j++) { double v=(q[j]-previous[j])/dt; maxV=Math.Max(maxV,Math.Abs(v)); if(t>dt)maxA=Math.Max(maxA,Math.Abs(v-velocity[j])/dt); velocity[j]=v; }
                previous=q;
            }
            Check(maxV<Trajectory.MaximumJointSpeed*1.01&&maxA<Trajectory.MaximumJointAcceleration*1.01,$"MOVEL v/a {maxV}/{maxA}");
            var acrossStart=from.ToArray(); acrossStart[0]=-.3;
            var end=from.ToArray(); end[0]=2.8; var remote=p.Teach("Across axis",PointKind.Joint,end);
            // Both endpoint poses are exact FK references; the line crosses an unsupported interior.
            Check(InverseKinematics.Solve(RobotGeometry.Flange(end)*p.Tool,end,p.Tool).Success);
            string reason=""; try { Trajectory.Plan(p,acrossStart,remote,true,2); } catch(InvalidOperationException e) { reason=e.Message; }
            Check(reason.Contains("MOVEL"),"Reachable endpoints must not imply feasible line: "+reason); Console.WriteLine("METRIC interior rejection "+reason);
        });
        Test("C3 moving part, model change during execution and physical TCP envelope",()=> {
            var p=new RobotProject(); p.Cell.Source=new(.55,-.5,1.13); p.Cell.Destination=new(2,1,.2); p.Cell.ObstacleEnabled=false;
            var sim=new RobotSimulation(); sim.ReplaceProject(p); sim.Enable(true); sim.ManualOutput("belt",true);
            for(int i=0;i<60&&sim.State==ControllerState.Ready;i++)sim.Step(.1);
            Check(sim.State==ControllerState.Faulted&&sim.Alarm.Contains("pieza libre")&&!sim.Cell.Belt,"moving part: "+sim.Alarm);
            var running=new RobotSimulation(); running.Project.Programs["main"]="WAIT 2"; running.SetMode(OperatingMode.Automatic); running.Start(); running.Project.Cell.ObstacleEnabled=false; running.Step(.01);
            Check(running.State==ControllerState.Faulted&&running.Alarm.Contains("entorno"));
            var example=DemoExample.Create(); var cell=new TrainingCell(example.Cell);
            double[] q=[0,.55,.55,0,.2,0]; Check(cell.Check(q,RobotGeometry.GripperTcp)==null);
            example.Tools["tool"]=new(new(2,0,0),Rotation3d.Identity);
            Check(cell.Check(q,RobotGeometry.GripperTcp)==null,"logical TCP changes physical geometry");
            var isolated=new CellSettings { Source=new(2,0,.2),Destination=new(2,1,.2),ObstacleEnabled=false };
            // Independent planar reference: wrist at x=-.55 sin(.6)+.55 cos(1.2), z=.58+.55 cos(.6)-.55 sin(1.2).
            double wristX=-.55*Math.Sin(.6)+.55*Math.Cos(1.2),wristZ=.58+.55*Math.Cos(.6)-.55*Math.Sin(1.2);
            Check(Math.Abs(wristX)<.12+.05&&wristZ>.4&&wristZ<.58);
            var self=new TrainingCell(isolated).Check([0,-.6,1.8,0,0,0],RobotGeometry.GripperTcp);
            Check(self?.Contains("Autocolisión 1/5")==true,"selected self pair: "+self);
            var corner=new CellSettings { Source=new(2,0,.2),Destination=new(2,1,.2),Obstacle= new(.794,.024,1.154),ObstacleHalfSize=new(.001,.001,.001) };
            // Zero TCP=(.77,0,1.13). Box at (24,24,24)mm is inside a 50mm cube corner, outside the old 35mm sphere.
            Check(Math.Sqrt(3)*.023>.035&&.024<.025);
            Check(new TrainingCell(corner).Check(new double[6],RobotGeometry.GripperTcp)?.Contains("pieza/pinza")==true,"missed cube corner");
        });
        Test("C1 actual branch replanning is cancellable and explicit resume replans",()=> {
            var sim=new RobotSimulation(); var a=sim.Project.Teach("A",PointKind.Joint,[.1,.2,.1,0,.2,0]); var b=sim.Project.Teach("B",PointKind.Joint,[.2,.3,.2,0,.2,0]);
            sim.Project.Programs["main"]=$"IF present 0\nMOVEJ {a.Id} 2\nELSE\nMOVEJ {b.Id} 2\nENDIF";
            sim.SetMode(OperatingMode.Automatic); sim.SetSpeed(1); sim.RequestPlanning(true); Drain(sim); Check(sim.State==ControllerState.Running,sim.Status);
            sim.Step(.01); sim.Step(.01); Check(sim.Planning.State==PlanningState.Verifying,"actual branch didn't replan");
            sim.CancelVerification(); Check(sim.State==ControllerState.Paused&&!sim.Moving); sim.Step(.01); Check(sim.Planning.State==PlanningState.Cancelled);
            sim.Resume(); sim.Step(.01); Drain(sim);
            for(int i=0;i<1000&&sim.State==ControllerState.Running;i++)sim.Step(.01);
            Check(sim.State==ControllerState.Ready,sim.Status); Check(sim.JogController.Positions.Zip(b.Angles,(x,y)=>Math.Abs(x-y)).Max()<1e-10);
            sim.DisposeAsync().AsTask().Wait();
        });
    }
}
