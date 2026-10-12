namespace RobotSimulator.Core;

public interface ISignalDevice { bool Read(string signal); void Write(string signal,bool value,Pose3d tcp); }
public interface ICollisionScene { string? Check(IReadOnlyList<double> angles,Pose3d tool); }
public interface IVisionExtension { } // Reserved contract; no implementation/UI in this demo.
public interface IProcessExtension { }

public sealed class TrainingCell : ISignalDevice, ICollisionScene
{
    public static double PartEnvelopeRadius => Math.Sqrt(3)*0.025; // Circumscribes the 50 mm cube at any orientation.
    private CellSettings settings;
    public Vector3d PartPosition { get; private set; }
    public Rotation3d PartRotation { get; private set; }
    public bool PartExists { get; private set; } = true;
    public bool Holding { get; private set; }
    public bool Delivered { get; private set; }
    public bool Grip { get; private set; }
    public bool Belt { get; private set; }
    public bool SensorFault { get; set; }
    public double BeltTravel { get; private set; }
    public TrainingCell(CellSettings config) { settings=config; Reset(); }
    // Dynamic state is copied as values, never shared with the worker.
    public string SnapshotJson() => System.Text.Json.JsonSerializer.Serialize(new CellSnapshot(PartPosition,PartRotation,PartExists,Holding,Delivered,Grip,Belt,SensorFault,BeltTravel));
    private sealed record CellSnapshot(Vector3d Position,Rotation3d Rotation,bool Exists,bool Holding,bool Delivered,bool Grip,bool Belt,bool SensorFault,double Travel);
    public static TrainingCell FromSnapshot(CellSettings config,string json) {
        var s=System.Text.Json.JsonSerializer.Deserialize<CellSnapshot>(json)!;
        return new(config) { PartPosition=s.Position,PartRotation=s.Rotation,PartExists=s.Exists,Holding=s.Holding,Delivered=s.Delivered,Grip=s.Grip,Belt=s.Belt,SensorFault=s.SensorFault,BeltTravel=s.Travel };
    }
    public void Reset() { settings.Validate(); PartPosition=settings.Source; PartRotation=settings.PartRotation; PartExists=true; Holding=false; Delivered=false; Grip=false; Belt=false; SensorFault=false; BeltTravel=0; }
    public void RemovePart() { if(Holding)throw new InvalidOperationException("No retire pieza sostenida"); PartExists=false; }
    public bool Read(string signal) => signal switch {
        "present"=>!SensorFault&&PartExists&&!Holding&&(PartPosition-settings.Source).Length<0.055,
        "holding"=>Holding,"delivered"=>Delivered,"grip"=>Grip,"belt"=>Belt,
        _=>throw new ArgumentException("Señal no soportada: "+signal)};
    public void Write(string signal,bool value,Pose3d tcp)
    {
        if(signal=="belt") { Belt=value; return; }
        if(signal!="grip")throw new ArgumentException("Salida no soportada: "+signal);
        if(value) {
            if(!Holding && (!PartExists||Belt||(PartPosition-tcp.Position).Length>0.04||(PartRotation*tcp.Rotation.Inverse).Log().Length>Math.PI/12))
                throw new InvalidOperationException("Agarre inválido: pieza ausente, banda en marcha, distancia >40 mm u orientación >15°");
            Holding=true; Grip=true; PartPosition=tcp.Position; PartRotation=tcp.Rotation;
        } else {
            if(Holding) { PartPosition=tcp.Position; PartRotation=tcp.Rotation; Delivered=(PartPosition-settings.Destination).Length<=0.08; }
            Holding=false; Grip=false;
        }
    }
    public void Step(double dt,Pose3d tcp)
    {
        if(Belt)BeltTravel+=0.1*dt;
        if(Holding) { PartPosition=tcp.Position; PartRotation=tcp.Rotation; }
        else if(Belt&&PartExists&&!Delivered) PartPosition += new Vector3d(0,0.1*dt,0);
    }
    public void StopActuators() => Belt=false; // Holding remains; stop cannot release the part.

    private IEnumerable<(string name,Vector3d min,Vector3d max)> Obstacles()
    {
        foreach(var station in new[]{("estación de recogida",settings.Source),("estación de destino",settings.Destination)}) {
            double halfY=station.Item1=="estación de recogida"?0.22:0.11;
            yield return (station.Item1,new(station.Item2.X-0.11,station.Item2.Y-halfY,0),new(station.Item2.X+0.11,station.Item2.Y+halfY,station.Item2.Z-0.045));
        }
        if(settings.ObstacleEnabled)yield return ("obstáculo de práctica",settings.Obstacle-settings.ObstacleHalfSize,settings.Obstacle+settings.ObstacleHalfSize);
    }
    public string? Check(IReadOnlyList<double> angles,Pose3d tool)
    {
        var chain=RobotGeometry.Chain(angles);
        var starts=new[]{chain[0].Position,chain[1].Position,chain[2].Position,chain[3].Position,chain[4].Position,chain[5].Position};
        var ends=new[]{chain[1].Position,chain[2].Position,chain[3].Position,chain[4].Position,chain[5].Position,(chain[5]*tool).Position};
        double[] radii=[0.12,0.10,0.09,0.06,0.05,0.025];
        var obstacles=Obstacles().ToArray();
        var balls=new List<Vector3d>[6];
        for(int link=0;link<6;link++) {
            balls[link]=[]; int steps=Math.Max(1,(int)Math.Ceiling((ends[link]-starts[link]).Length/0.01));
            for(int i=0;i<=steps;i++) {
                var p=starts[link]+(ends[link]-starts[link])*((double)i/steps); balls[link].Add(p);
                if(p.Z-radii[link]<0) return $"Colisión con suelo en volumen {link+1}";
                foreach(var obstacle in obstacles) if(SphereBox(p,radii[link]+0.005,obstacle.min,obstacle.max)) return $"Colisión {obstacle.name}, volumen {link+1}";
                // The free part is dynamic. Only the wrist/gripper near an aligned pickup may contact it.
                if(PartExists&&!Holding) {
                    var gripper=chain[5]*RobotGeometry.GripperTcp;
                    bool pickupContact=link>=4&&!Belt&&(gripper.Position-PartPosition).Length<=0.09&&(gripper.Rotation*PartRotation.Inverse).Log().Length<=Math.PI/12;
                    if(!pickupContact&&(p-PartPosition).Length<radii[link]+PartEnvelopeRadius)return $"Colisión pieza libre, volumen {link+1}";
                }
            }
        }
        foreach(var pair in new[]{(0,4),(0,5),(1,4),(1,5)})
            foreach(var a in balls[pair.Item1])foreach(var b in balls[pair.Item2])
                if((a-b).Dot(a-b) < Math.Pow(radii[pair.Item1]+radii[pair.Item2],2))return $"Autocolisión {pair.Item1+1}/{pair.Item2+1}";
        // Always check this envelope, including preflight before a future grasp.
        foreach(var obstacle in obstacles)if(SphereBox((chain[5]*tool).Position,PartEnvelopeRadius,obstacle.min,obstacle.max))return "Colisión de volumen pieza/pinza con "+obstacle.name;
        return null;
    }
    private static bool SphereBox(Vector3d p,double r,Vector3d min,Vector3d max) {
        var closest=new Vector3d(Math.Clamp(p.X,min.X,max.X),Math.Clamp(p.Y,min.Y,max.Y),Math.Clamp(p.Z,min.Z,max.Z)); return (p-closest).Dot(p-closest)<r*r;
    }
    public string? CheckSweep(IReadOnlyList<double> from,IReadOnlyList<double> to,Pose3d tool,CancellationToken cancellationToken=default)
    {
        int count=Math.Max(1,(int)Math.Ceiling(from.Zip(to,(a,b)=>Math.Abs(a-b)).Max()/0.002));
        for(int i=0;i<=count;i++) { cancellationToken.ThrowIfCancellationRequested(); var q=from.Zip(to,(a,b)=>a+(b-a)*i/count).ToArray(); var collision=Check(q,tool); if(collision!=null)return $"Barrido {i}/{count}: {collision}"; } return null;
    }
}
