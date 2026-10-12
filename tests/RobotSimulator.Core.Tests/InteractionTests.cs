using RobotSimulator.Core;
internal static class InteractionTests
{
    public static void Run()
    {
        static void Check(bool x) { if(!x)throw new Exception("Interaction assertion"); }
        foreach(var source in new[]{"Desktop","Emulation","OpenXR"}) {
            var s=new RobotSimulation(); var input=new InteractionSession(s); input.SelectSource(source); input.Enable(source,false); input.Enable(source,true); Check(input.Jog(source,0,1,false)); s.Step(0.02); Check(s.JogController.Position(0)>0); input.Device(false,true); Check(!s.Moving); input.Device(true,true); input.Enable(source,true); Check(!input.Jog(source,0,1,false)); input.Enable(source,false); input.Enable(source,true); Check(input.Jog(source,0,1,false)); input.SelectSource("Other"); Check(!s.Moving); input.Enable(source,true); Check(!input.Held); input.Session(false,false); input.Session(true,true); input.Enable("Other",true); Check(!input.Jog("Other",0,1,false)); input.Enable("Other",false); input.Enable("Other",true); Check(input.Jog("Other",0,1,false)); input.Cancel(); Check(!s.Moving);
            s.DisposeAsync().AsTask().GetAwaiter().GetResult();
        }
        Console.WriteLine("PASS I1/I2 ownership, device loss, session restoration and equivalent sources");
        using(var entered=new ManualResetEventSlim()) using(var release=new ManualResetEventSlim()) {
            var s=new RobotSimulation((snapshot,token,progress)=>{ entered.Set(); if(!release.Wait(5000))throw new Exception("test gate timeout"); return ProgramPlanner.Calculate(snapshot,CancellationToken.None,progress); });
            s.Project.Programs["main"]="WAIT 0.1"; s.SetMode(OperatingMode.Automatic); var input=new InteractionSession(s); input.SelectSource("OpenXR"); s.RequestPlanning(true); Check(entered.Wait(3000)); input.Session(false,false); release.Set(); s.DisposeAsync().AsTask().GetAwaiter().GetResult(); Check(s.State!=ControllerState.Running);
        }
        { var s=new RobotSimulation(); s.Project.Programs["main"]="WAIT 1"; s.SetMode(OperatingMode.Automatic); s.Start(); var input=new InteractionSession(s); input.Session(false,false); Check(s.State==ControllerState.Paused); input.Session(true,true); Check(s.State==ControllerState.Paused); s.DisposeAsync().AsTask().GetAwaiter().GetResult(); }
        Console.WriteLine("PASS I2 in-flight stale worker, session pause and no automatic resume");
        var directory=Path.Combine(Path.GetTempPath(),"RobotSimulator-repository-"+Guid.NewGuid().ToString("N"));
        var repo=new LocalProjectRepository(directory); var p=new RobotProject(); p.Programs["main"]="WAIT 0.1"; repo.Save("Práctica uno",p,false); Check(repo.List().Length==1); Check(repo.Load("Práctica uno").Programs["main"]=="WAIT 0.1");
        foreach(var invalid in new[]{"../outside","NUL","a/b",""}) { bool rejected=false; try {repo.Save(invalid,p,false);}catch(ArgumentException){rejected=true;} Check(rejected); }
        bool conflict=false; try {repo.Save("Práctica uno",p,false);}catch(InvalidOperationException){conflict=true;} Check(conflict); repo.Save("Práctica uno",p,true); File.WriteAllText(Path.Combine(directory,"corrupt.json"),"{}"); bool bad=false; try{repo.Load("corrupt");}catch(Exception){bad=true;}Check(bad);
        // Only this test's explicitly created temporary directory is removed.
        Check(Path.GetFullPath(directory).StartsWith(Path.GetFullPath(Path.GetTempPath()),StringComparison.OrdinalIgnoreCase));
        Directory.Delete(directory,true); Console.WriteLine("PASS I5 managed JSON repository, names, conflicts and corruption");
    }
}
