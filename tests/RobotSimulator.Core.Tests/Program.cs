using RobotSimulator.Core;

int passed = 0;
void Test(string name, Action action) { action(); passed++; Console.WriteLine($"PASS {name}"); }
void Assert(bool value) { if (!value) throw new Exception("Assertion failed"); }
void Near(double actual, double expected) => Assert(Math.Abs(actual - expected) < 1e-10);
void Reject(Action action) { try { action(); } catch (ArgumentException) { return; } throw new Exception("Expected rejection"); }
ManualJogController Ready() { var c = new ManualJogController(); c.SetEnabled(true); return c; }
Test("independent speed: 30 deg/s at 50% for 2 s = 30 deg", () => {
    var c = Ready(); c.SetSpeed(0.5); c.BeginJog(0,1); for(int i=0;i<120;i++) c.Step(1.0/60);
    Near(c.Position(0),Math.PI/6); for(int i=1;i<6;i++) Near(c.Position(i),0);
});
Test("all joint limits, both signs and reverse recovery", () => {
    double[] upper = [170,90,135,180,120,180];
    for(int j=0;j<6;j++) foreach(int sign in new[]{-1,1}) {
        var c = Ready(); c.SetSpeed(1); c.BeginJog(j,sign);
        for(int i=0;i<1000;i++) c.Step(0.1);
        Near(c.Position(j),sign*upper[j]*Math.PI/180); Assert(!c.IsMoving);
        c.BeginJog(j,-sign); c.Step(0.1); Near(c.Position(j),(sign*upper[j]-sign*3)*Math.PI/180);
    }
});
Test("permissions and no automatic restart", () => {
    var c = new ManualJogController(); Assert(!c.BeginJog(0,1)); c.SetEnabled(true); Assert(c.BeginJog(0,1));
    c.SetMode(OperatingMode.Automatic); c.SetEnabled(true); Assert(!c.BeginJog(0,1));
    c.SetMode(OperatingMode.Manual); Assert(!c.BeginJog(0,1));
    c.SetFocused(false); c.SetEnabled(true); Assert(!c.BeginJog(0,1)); c.SetFocused(true); Assert(!c.IsMoving);
});
Test("release, enabling loss and focus loss stop immediately", () => {
    foreach(int cause in new[]{0,1,2}) { var c=Ready(); c.BeginJog(2,1); c.Step(0.1); double p=c.Position(2);
        if(cause==0)c.Stop(); else if(cause==1)c.SetEnabled(false); else c.SetFocused(false);
        c.Step(0.1); Near(c.Position(2),p); Assert(!c.IsMoving);
        c.SetFocused(true); c.SetEnabled(true); c.Step(0.1); Near(c.Position(2),p);
    }
});
Test("invalid commands stop and reject", () => {
    var c=Ready();
    foreach(double v in new[]{double.NaN,double.PositiveInfinity,0,-1,1.01}) { c.BeginJog(0,1); Reject(()=>c.SetSpeed(v)); Assert(!c.IsMoving); }
    foreach(double v in new[]{double.NaN,double.PositiveInfinity,0,-1,0.11}) { c.BeginJog(0,1); Reject(()=>c.Step(v)); Assert(!c.IsMoving); }
    foreach(int j in new[]{-1,6}) { c.BeginJog(0,1); Reject(()=>c.BeginJog(j,1)); Assert(!c.IsMoving); }
    Reject(()=>c.BeginJog(0,0)); Reject(()=>c.SetMode((OperatingMode)99));
});
Test("JointLimits invalid numbers and boundaries", () => {
    Reject(()=>new JointLimits(double.NaN,1)); Reject(()=>new JointLimits(1,-1)); Reject(()=>new JointLimits(0,double.PositiveInfinity));
    var l=new JointLimits(-1,1); Assert(l.Contains(-1)&&l.Contains(1)&&!l.Contains(double.NaN)&&!l.Contains(1.001));
});
Test("M2A independent zero, yaw, shoulder and combined FK", () => {
    var p=RobotGeometry.Flange(new double[6]); Near(p.Position.X,0.65); Near(p.Position.Y,0); Near(p.Position.Z,1.13);
    var yaw=RobotGeometry.Flange([Math.PI/2,0,0,0,0,0]); Near(yaw.Position.X,0); Near(yaw.Position.Y,0.65); Near(yaw.Position.Z,1.13);
    var shoulder=RobotGeometry.Flange([0,Math.PI/2,0,0,0,0]); Near(shoulder.Position.X,0.55); Near(shoulder.Position.Z,-0.07);
    double a=0.3,b=-0.4,c=0.5;
    var combined=RobotGeometry.Flange([a,b,c,0,0,0]);
    double x=0.55*Math.Sin(b)+0.65*Math.Cos(b+c), z=0.58+0.55*Math.Cos(b)-0.65*Math.Sin(b+c);
    Near(combined.Position.X,x*Math.Cos(a)); Near(combined.Position.Y,x*Math.Sin(a)); Near(combined.Position.Z,z);
    var forward=combined.Rotation.Apply(new(1,0,0)); Near(forward.X,Math.Cos(a)*Math.Cos(b+c)); Near(forward.Y,Math.Sin(a)*Math.Cos(b+c)); Near(forward.Z,-Math.Sin(b+c));
    Reject(()=>RobotGeometry.Flange([0,0,0])); Reject(()=>RobotGeometry.Flange([0,double.NaN,0,0,0,0]));
});
Console.WriteLine($"{passed} test groups passed");
AdvancedTests.Run();
DemoTests.Run();
ConsolidationTests.Run();
InteractionTests.Run();
