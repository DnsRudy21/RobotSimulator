namespace RobotSimulator.Core;

public sealed class Trajectory
{
    public const double MaximumJointSpeed=Math.PI/6;
    public const double MaximumJointAcceleration=Math.PI/3;
    private readonly double[][] samples;
    public double Duration { get; }
    public bool IsLinear { get; }
    public Pose3d StartTcp { get; }
    public Pose3d EndTcp { get; }
    public IReadOnlyList<double[]> Samples => samples.Select(q=>(double[])q.Clone()).ToArray();
    internal IReadOnlyList<double[]> PlannedSamples => samples;
    private Trajectory(double[][] values,double duration,bool linear,Pose3d start,Pose3d end)
    { samples=values; Duration=duration; IsLinear=linear; StartTcp=start; EndTcp=end; }
    public static Trajectory Plan(RobotProject project,IReadOnlyList<double> from,TaughtPoint point,bool linear,double requestedDuration,CancellationToken cancellationToken=default)
    {
        if(!double.IsFinite(requestedDuration)||requestedDuration<0.1||requestedDuration>120)throw new ArgumentException("Duración 0.1…120 s");
        RobotGeometry.Validate(from); RobotGeometry.Validate(point.Angles);
        var tool=project.Tools[point.ToolId]; var start=RobotGeometry.Flange(from)*tool;
        double[] target;
        Pose3d end;
        if(point.Kind==PointKind.Joint) { target=point.Angles.ToArray(); end=RobotGeometry.Flange(target)*tool; }
        else { end=project.WorldTarget(point); var result=InverseKinematics.Solve(end,from,tool,cancellationToken:cancellationToken); if(!result.Success)throw new InvalidOperationException(result.Message); target=result.Angles; }
        double maxDelta=target.Zip(from,(a,b)=>Math.Abs(a-b)).Max();
        int count=(int)Math.Ceiling(Math.Max(maxDelta/0.002,Math.Max((end.Position-start.Position).Length/0.001,(end.Rotation*start.Rotation.Inverse).Log().Length/0.002)))+2;
        if(count>2000)throw new InvalidOperationException("Trayecto supera dominio de 2000 muestras");
        var samples=new double[count+1][]; samples[0]=from.ToArray();
        for(int i=1;i<=count;i++) {
            cancellationToken.ThrowIfCancellationRequested();
            double s=(double)i/count;
            if(!linear)samples[i]=from.Zip(target,(a,b)=>a+(b-a)*s).ToArray();
            else {
                var result=InverseKinematics.Solve(Pose3d.Interpolate(start,end,s),samples[i-1],tool,cancellationToken:cancellationToken);
                if(!result.Success)throw new InvalidOperationException($"MOVEL muestra {i}/{count}: {result.Message}");
                if(result.Angles.Zip(samples[i-1],(a,b)=>Math.Abs(a-b)).Max()>0.04)throw new InvalidOperationException("MOVEL: discontinuidad cerca de singularidad");
                samples[i]=result.Angles;
                var midpoint=samples[i].Zip(samples[i-1],(a,b)=>(a+b)*0.5).ToArray(); var actual=RobotGeometry.Flange(midpoint)*tool;
                var expected=Pose3d.Interpolate(start,end,(i-0.5)/count);
                if((actual.Position-expected.Position).Length>RobotGeometry.PositionTolerance||(actual.Rotation*expected.Rotation.Inverse).Log().Length>RobotGeometry.OrientationTolerance)throw new InvalidOperationException("MOVEL: error de interpolación fuera de tolerancia");
            }
        }
        double derivative=0,second=0;
        for(int i=1;i<=count;i++)for(int j=0;j<6;j++) {
            derivative=Math.Max(derivative,Math.Abs(samples[i][j]-samples[i-1][j])*count);
            if(i>1)second=Math.Max(second,Math.Abs(samples[i][j]-2*samples[i-1][j]+samples[i-2][j])*count*count);
        }
        // Reserve half the acceleration budget for the 0.5/s override ramp.
        double duration=Math.Max(requestedDuration,Math.Max(1.875*derivative/MaximumJointSpeed,Math.Sqrt(2*(5.774*derivative+3.516*second)/MaximumJointAcceleration)));
        if(duration>120)throw new InvalidOperationException("Trayectoria requiere más de 120 s; cambie puntos");
        return new(samples,duration,linear,start,end);
    }
    public double[] At(double elapsed)
    {
        double t=Math.Clamp(elapsed/Duration,0,1),s=t*t*t*(10+t*(-15+6*t)); return AtFraction(s);
    }
    public double[] AtFraction(double s)
    {
        double index=Math.Clamp(s,0,1)*(samples.Length-1); int lower=Math.Min((int)index,samples.Length-2); double f=index-lower;
        return samples[lower].Zip(samples[lower+1],(a,b)=>a+(b-a)*f).ToArray();
    }
}
