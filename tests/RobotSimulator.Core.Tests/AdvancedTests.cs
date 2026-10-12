using RobotSimulator.Core;

static class AdvancedTests
{
    static int count;
    internal static void Check(bool value,string message="assertion") { if(!value)throw new Exception(message); }
    internal static void Near(double actual,double expected,double tolerance=1e-9) => Check(Math.Abs(actual-expected)<=tolerance,$"{actual} != {expected}");
    internal static void Test(string name,Action action) { action(); count++; Console.WriteLine("PASS "+name); }
    internal static void Reject(Action action) { try { action(); } catch(Exception e) when(e is ArgumentException or InvalidOperationException or System.Text.Json.JsonException) { return; } throw new Exception("Expected rejection"); }
    public static void Run()
    {
        Test("M2B rigid inverse, TCP, frame and non-moving selections",()=>{
            var rotation=Rotation3d.AxisAngle(new(0,0,1),Math.PI/2);
            var a=new Pose3d(new(1,2,3),rotation); var b=new Pose3d(new(0.2,0,0),Rotation3d.Identity);
            var combined=a*b; Near(combined.Position.X,1); Near(combined.Position.Y,2.2); Near(combined.Position.Z,3);
            Near((a.Inverse*a).Position.Length,0); Near((a.Inverse*a).Rotation.Log().Length,0);
            var project=new RobotProject(); var q=new double[6]; var tcp=project.ExpressTcp(q); Near(tcp.Position.X,0.77); Near(tcp.Position.Z,1.13);
            project.UpdateReference(false,"piece",new(new(0.1,0.2,0.3),rotation)); project.ActiveFrame="piece";
            var local=project.ExpressTcp(q); Near(local.Position.X,-0.2); Near(local.Position.Y,-0.67); Near(local.Position.Z,0.83);
            Check(q.All(x=>x==0)); var p=project.Teach("prueba",PointKind.Cartesian,q);
            Reject(()=>project.UpdateReference(false,"piece",Pose3d.Identity));
            var copy=ProjectStorage.Deserialize(ProjectStorage.Serialize(project)); Check(copy.Points[0].Id==p.Id); Near((copy.WorldTarget(copy.Points[0]).Position-tcp.Position).Length,0);
            Reject(()=>ProjectStorage.Deserialize("{}".Replace("{}","{\"SchemaVersion\":99}")));
            Reject(()=>project.UpdateReference(true,"tool",new(new(double.NaN,0,0),Rotation3d.Identity)));
        });
        Test("M2C local IK pose, continuity and singular/unreachable rejection",()=>{
            var tool=new Pose3d(new(0.12,0,0),Rotation3d.Identity);
            double[][] cases=[[0,0,0,0,0,0],[0.4,0.5,-0.3,0.2,0.4,-0.2],[-0.2,-0.3,0.5,-0.3,-0.2,0.2],[0.1,0.8,0.3,0,0.2,0],[2.9,0.4,-0.3,0.2,0.4,0.1]];
            foreach(var q in cases) {
                var target=RobotGeometry.Flange(q)*tool; var seed=q.Select(x=>x+0.03).ToArray();
                var result=InverseKinematics.Solve(target,seed,tool); Check(result.Success,result.Message+" "+result.PositionError);
                var actual=RobotGeometry.Flange(result.Angles)*tool;
                Check((target.Position-actual.Position).Length<RobotGeometry.PositionTolerance);
                Check((target.Rotation*actual.Rotation.Inverse).Log().Length<RobotGeometry.OrientationTolerance);
                Check(result.Angles.Zip(seed,(a,b)=>Math.Abs(a-b)).Max()<0.2,"branch jump");
            }
            var far=InverseKinematics.Solve(new(new(5,0,1),Rotation3d.Identity),cases[1],tool);
            Check(!far.Success); Check(far.Angles.SequenceEqual(cases[1]));
            Reject(()=>InverseKinematics.Solve(new(new(double.NaN,0,0),Rotation3d.Identity),cases[0],tool));
            // Near singular zero pose must either converge accurately or reject without changing seed.
            var singular=new double[6]; var goal=RobotGeometry.Flange(singular)*tool;
            var tiny=InverseKinematics.Solve(new(goal.Position+new Vector3d(0,0,0.001),goal.Rotation),singular,tool);
            Check(tiny.Success?tiny.PositionError<RobotGeometry.PositionTolerance:tiny.Angles.SequenceEqual(singular));
        });
        Test("M2C cartesian held permissions and independent frame direction",()=>{
            var sim=new RobotSimulation(); sim.JogController.SetPositions([0.1,0.55,0.3,0.2,0.35,-0.2]);
            sim.Project.UpdateReference(false,"piece",new(Vector3d.Zero,Rotation3d.AxisAngle(new(0,0,1),Math.PI/2))); sim.Project.ActiveFrame="piece";
            Check(!sim.CartesianJog(0,1)); sim.Enable(true); Check(sim.CartesianJog(0,1)); var before=sim.Tcp;
            sim.Step(0.02); var after=sim.Tcp; Near(after.Position.X,before.Position.X,0.0001); Near(after.Position.Y-before.Position.Y,0.05*0.25*0.02,0.00002);
            Check((after.Rotation*before.Rotation.Inverse).Log().Length<RobotGeometry.OrientationTolerance);
            sim.Enable(false); var released=sim.JogController.Positions; sim.Step(0.02); Check(released.SequenceEqual(sim.JogController.Positions));
            sim.Enable(true); sim.CartesianJog(3,1); sim.Focus(false); Check(!sim.Moving); sim.Focus(true); Check(!sim.CartesianJog(3,1));
        });
        Console.WriteLine($"{count} advanced test groups passed");
    }
}
