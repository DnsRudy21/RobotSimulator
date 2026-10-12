using System.Text.Json.Serialization;
namespace RobotSimulator.Core;

public readonly record struct Vector3d(double X, double Y, double Z)
{
    public static Vector3d Zero => new(0,0,0);
    [JsonIgnore] public bool IsFinite => double.IsFinite(X) && double.IsFinite(Y) && double.IsFinite(Z);
    [JsonIgnore] public double Length => Math.Sqrt(Dot(this));
    public double Dot(Vector3d b) => X*b.X+Y*b.Y+Z*b.Z;
    public Vector3d Cross(Vector3d b) => new(Y*b.Z-Z*b.Y,Z*b.X-X*b.Z,X*b.Y-Y*b.X);
    public static Vector3d operator +(Vector3d a,Vector3d b) => new(a.X+b.X,a.Y+b.Y,a.Z+b.Z);
    public static Vector3d operator -(Vector3d a,Vector3d b) => new(a.X-b.X,a.Y-b.Y,a.Z-b.Z);
    public static Vector3d operator *(Vector3d a,double s) => new(a.X*s,a.Y*s,a.Z*s);
    public Vector3d Unit() => Length > 1e-14 ? this*(1/Length) : Zero;
    public double[] Array() => [X,Y,Z];
}

/// <summary>Unit quaternion, double precision. Composition a*b applies b first.</summary>
public readonly record struct Rotation3d(double W, double X, double Y, double Z)
{
    public static Rotation3d Identity => new(1,0,0,0);
    [JsonIgnore] public bool IsValid => double.IsFinite(W+X+Y+Z) && Math.Abs(W*W+X*X+Y*Y+Z*Z-1)<1e-8;
    [JsonIgnore] public Rotation3d Inverse => new(W,-X,-Y,-Z);
    public static Rotation3d AxisAngle(Vector3d axis,double angle)
    {
        if (!axis.IsFinite || Math.Abs(axis.Length-1)>1e-8 || !double.IsFinite(angle)) throw new ArgumentException("Invalid rotation");
        double s=Math.Sin(angle/2); return new(Math.Cos(angle/2),axis.X*s,axis.Y*s,axis.Z*s);
    }
    public static Rotation3d operator *(Rotation3d a,Rotation3d b) => new(
        a.W*b.W-a.X*b.X-a.Y*b.Y-a.Z*b.Z,
        a.W*b.X+a.X*b.W+a.Y*b.Z-a.Z*b.Y,
        a.W*b.Y-a.X*b.Z+a.Y*b.W+a.Z*b.X,
        a.W*b.Z+a.X*b.Y-a.Y*b.X+a.Z*b.W);
    public Vector3d Apply(Vector3d v)
    {
        var q=new Vector3d(X,Y,Z); var t=q.Cross(v)*2; return v+t*W+q.Cross(t);
    }
    public Vector3d Log()
    {
        double sign=W<0?-1:1;
        var v=new Vector3d(X*sign,Y*sign,Z*sign);
        double length=v.Length;
        return length<1e-14 ? v*2 : v*(2*Math.Atan2(length,Math.Abs(W))/length);
    }
    public static Rotation3d FromRpy(Vector3d rpy) => AxisAngle(new(0,0,1),rpy.Z)*AxisAngle(new(0,1,0),rpy.Y)*AxisAngle(new(1,0,0),rpy.X);
    public Vector3d Rpy() => new(Math.Atan2(2*(W*X+Y*Z),1-2*(X*X+Y*Y)),
        Math.Asin(Math.Clamp(2*(W*Y-Z*X),-1,1)),Math.Atan2(2*(W*Z+X*Y),1-2*(Y*Y+Z*Z)));
    public static Rotation3d Interpolate(Rotation3d a,Rotation3d b,double fraction)
    {
        var relative=(b*a.Inverse).Log(); double angle=relative.Length;
        return angle<1e-12 ? a : AxisAngle(relative.Unit(),angle*fraction)*a;
    }
}

public readonly record struct Pose3d(Vector3d Position, Rotation3d Rotation)
{
    public static Pose3d Identity => new(Vector3d.Zero,Rotation3d.Identity);
    [JsonIgnore] public bool IsValid => Position.IsFinite && Position.Length <= 100 && Rotation.IsValid;
    [JsonIgnore] public Pose3d Inverse => new(Rotation.Inverse.Apply(Position*-1),Rotation.Inverse);
    public static Pose3d operator *(Pose3d a,Pose3d b) => new(a.Position+a.Rotation.Apply(b.Position),a.Rotation*b.Rotation);
    public static Pose3d Interpolate(Pose3d a,Pose3d b,double fraction) => new(a.Position+(b.Position-a.Position)*fraction,Rotation3d.Interpolate(a.Rotation,b.Rotation,fraction));
    public void Validate() { if (!IsValid) throw new ArgumentException("Pose must be finite with a unit quaternion, within 100 m"); }
}

public sealed record JointDefinition(Vector3d Origin, Vector3d Axis, JointLimits Limits);

public static class RobotGeometry
{
    public const double PositionTolerance=0.0001;
    public const double OrientationTolerance=Math.PI/1800;
    public static Pose3d GripperTcp => new(new(0.12,0,0),Rotation3d.Identity);
    private static JointDefinition Joint(Vector3d origin,Vector3d axis,double maximum) => new(origin,axis,new(-maximum*Math.PI/180,maximum*Math.PI/180));
    public static IReadOnlyList<JointDefinition> Joints { get; } = Array.AsReadOnly(new[]{
        Joint(new(0,0,0.40),new(0,0,1),170), Joint(new(0,0,0.18),new(0,1,0),90),
        Joint(new(0,0,0.55),new(0,1,0),135), Joint(new(0.43,0,0),new(1,0,0),180),
        Joint(new(0.12,0,0),new(0,1,0),120), Joint(new(0.10,0,0),new(1,0,0),180)});
    // The flange frame is J6, at the root of the visual 70 mm flange.
    public static Pose3d Flange(IReadOnlyList<double> angles) => Chain(angles)[5];
    public static Pose3d[] Chain(IReadOnlyList<double> angles)
    {
        Validate(angles); var result=new Pose3d[6]; var pose=Pose3d.Identity;
        for(int i=0;i<6;i++) { pose *= new Pose3d(Joints[i].Origin,Rotation3d.AxisAngle(Joints[i].Axis,angles[i])); result[i]=pose; }
        return result;
    }
    public static void Validate(IReadOnlyList<double> angles)
    {
        if(angles is null||angles.Count!=6) throw new ArgumentException("Six angles required");
        for(int i=0;i<6;i++) if(!Joints[i].Limits.Contains(angles[i])) throw new ArgumentException($"J{i+1} outside limits");
    }
    public static Vector3d ToGodot(Vector3d v) => new(v.X,v.Z,-v.Y);
}
