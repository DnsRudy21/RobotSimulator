namespace RobotSimulator.Core;

public sealed record IkResult(bool Success, double[] Angles, string Message, double PositionError, double OrientationError);

/// <summary>Local damped least squares solver, seeded from current configuration.</summary>
public static class InverseKinematics
{
    public static IkResult Solve(Pose3d target, IReadOnlyList<double> seed, Pose3d tool, int iterations=240, CancellationToken cancellationToken=default)
    {
        target.Validate(); tool.Validate(); RobotGeometry.Validate(seed);
        if(iterations is < 1 or > 1000) throw new ArgumentOutOfRangeException(nameof(iterations));
        var q=seed.ToArray(); double pe=double.PositiveInfinity, re=double.PositiveInfinity;
        const double weight=0.3, h=1e-5;
        for(int iteration=0;iteration<iterations;iteration++)
        {
            cancellationToken.ThrowIfCancellationRequested();
            var actual=RobotGeometry.Flange(q)*tool;
            var dp=target.Position-actual.Position;
            var dr=(target.Rotation*actual.Rotation.Inverse).Log(); pe=dp.Length; re=dr.Length;
            if(pe<=1e-5 && re<=1e-4) return new(true,q,"IK local convergente",pe,re);
            double[] e=[dp.X,dp.Y,dp.Z,dr.X*weight,dr.Y*weight,dr.Z*weight];
            var j=new double[6,6];
            for(int axis=0;axis<6;axis++)
            {
                var shifted=(double[])q.Clone(); double dh=q[axis]+h<=RobotGeometry.Joints[axis].Limits.MaximumRadians?h:-h;
                shifted[axis]+=dh; var pose=RobotGeometry.Flange(shifted)*tool;
                var p=(pose.Position-actual.Position)*(1/dh); var r=(pose.Rotation*actual.Rotation.Inverse).Log()*(weight/dh);
                var col=new[]{p.X,p.Y,p.Z,r.X,r.Y,r.Z}; for(int row=0;row<6;row++)j[row,axis]=col[row];
            }
            // (J^T J + lambda^2 I) dq = J^T error. Increase damping near poor steps.
            bool improved=false; double baseline=pe*pe+weight*weight*re*re;
            foreach(double damping in new[]{0.002,0.02,0.1})
            {
                var a=new double[6,6]; var b=new double[6];
                for(int row=0;row<6;row++) for(int k=0;k<6;k++) {
                    b[row]+=j[k,row]*e[k]; for(int col=0;col<6;col++)a[row,col]+=j[k,row]*j[k,col];
                }
                for(int k=0;k<6;k++)a[k,k]+=damping*damping;
                var change=LinearSolve(a,b); double maximum=change.Max(Math.Abs); double scale=maximum>0.12?0.12/maximum:1;
                for(int attempt=0;attempt<8;attempt++,scale*=0.5)
                {
                    var candidate=new double[6];
                    for(int k=0;k<6;k++)candidate[k]=Math.Clamp(q[k]+change[k]*scale,RobotGeometry.Joints[k].Limits.MinimumRadians,RobotGeometry.Joints[k].Limits.MaximumRadians);
                    var pose=RobotGeometry.Flange(candidate)*tool;
                    double np=(target.Position-pose.Position).Length, nr=(target.Rotation*pose.Rotation.Inverse).Log().Length;
                    if(np*np+weight*weight*nr*nr < baseline-1e-18) { q=candidate; improved=true; break; }
                }
                if(improved)break;
            }
            if(!improved)break;
        }
        var finalPose=RobotGeometry.Flange(q)*tool;
        pe=(target.Position-finalPose.Position).Length; re=(target.Rotation*finalPose.Rotation.Inverse).Log().Length;
        return new(false,seed.ToArray(),$"IK no resuelta: dominio local/límite/singularidad; residual {pe*1000:F3} mm / {re*180/Math.PI:F3}°",pe,re);
    }

    private static double[] LinearSolve(double[,] matrix,double[] vector)
    {
        var a=(double[,])matrix.Clone(); var b=(double[])vector.Clone(); int n=b.Length;
        for(int k=0;k<n;k++) {
            int pivot=k; for(int i=k+1;i<n;i++) if(Math.Abs(a[i,k])>Math.Abs(a[pivot,k]))pivot=i;
            for(int j=k;j<n;j++) (a[k,j],a[pivot,j])=(a[pivot,j],a[k,j]); (b[k],b[pivot])=(b[pivot],b[k]);
            double value=a[k,k]; if(Math.Abs(value)<1e-20)throw new InvalidOperationException("Singular linear system");
            for(int j=k;j<n;j++)a[k,j]/=value; b[k]/=value;
            for(int i=0;i<n;i++)if(i!=k) { double factor=a[i,k]; for(int j=k;j<n;j++)a[i,j]-=factor*a[k,j]; b[i]-=factor*b[k]; }
        }
        return b;
    }
}
