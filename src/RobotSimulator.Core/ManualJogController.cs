namespace RobotSimulator.Core;

public enum OperatingMode { Manual, Automatic }

/// <summary>Educational velocity jog. SI units, no acceleration or safety certification.</summary>
public sealed class ManualJogController
{
    public const double MaximumSpeed = Math.PI / 6; // 30 degrees/s
    private readonly double[] positions = new double[6];
    private readonly JointLimits[] limits = RobotGeometry.Joints.Select(j=>j.Limits).ToArray();
    private int activeJoint = -1;
    private int direction;
    private double speedFraction = 0.25;
    private bool enabled;
    private bool focused = true;
    private OperatingMode mode;
    public bool IsMoving => activeJoint >= 0;
    public bool Enabled => enabled;
    public string Status { get; private set; } = "Mantenga habilitación y un sentido de jog";
    public double Position(int joint) => positions[CheckJoint(joint)];
    public JointLimits Limits(int joint) => limits[CheckJoint(joint)];
    private static int CheckJoint(int joint) => joint is >= 0 and < 6 ? joint : throw new ArgumentOutOfRangeException(nameof(joint));
    public double[] Positions => (double[])positions.Clone();
    public void SetPositions(IReadOnlyList<double> values) { RobotGeometry.Validate(values); Stop(); for(int i=0;i<6;i++) positions[i]=values[i]; }

    public void SetEnabled(bool value) { if (!value && (enabled || IsMoving)) Stop(); enabled = value; }
    public void SetFocused(bool value) { focused = value; if (!value) { enabled = false; Stop(); } }
    public void SetMode(OperatingMode value)
    {
        if (!Enum.IsDefined(value)) { Stop(); throw new ArgumentOutOfRangeException(nameof(value)); }
        mode = value; enabled = false; Stop();
    }
    public void SetSpeed(double fraction)
    {
        if (!double.IsFinite(fraction) || fraction <= 0 || fraction > 1)
        { Stop(); throw new ArgumentOutOfRangeException(nameof(fraction)); }
        speedFraction = fraction;
    }
    public bool BeginJog(int joint, int sense)
    {
        Stop(); // Rejecting a new command cannot leave an earlier one running.
        CheckJoint(joint);
        if (sense != -1 && sense != 1) throw new ArgumentOutOfRangeException(nameof(sense));
        if (!enabled || !focused || mode != OperatingMode.Manual)
        { Status = "Jog bloqueado: requiere modo manual, foco y habilitación"; return false; }
        activeJoint = joint; direction = sense;
        Status = $"Jog J{joint + 1} {(sense > 0 ? "+" : "−")}";
        return true;
    }
    public void Stop() { activeJoint = -1; direction = 0; Status = "Detenido"; }
    public void Step(double seconds)
    {
        if (!double.IsFinite(seconds) || seconds <= 0 || seconds > 0.1)
        { Stop(); throw new ArgumentOutOfRangeException(nameof(seconds)); }
        if (!IsMoving) return;
        int joint = activeJoint;
        double requested = positions[joint] + direction * MaximumSpeed * speedFraction * seconds;
        positions[joint] = Math.Clamp(requested, limits[joint].MinimumRadians, limits[joint].MaximumRadians);
        if (requested <= limits[joint].MinimumRadians || requested >= limits[joint].MaximumRadians)
        { Stop(); Status = $"Límite alcanzado en J{joint + 1}; seleccione sentido contrario"; }
    }
}
