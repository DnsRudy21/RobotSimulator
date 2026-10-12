namespace RobotSimulator.Core;

/// <summary>Articulación rotacional; ángulos en radianes.</summary>
public readonly record struct JointLimits
{
    public double MinimumRadians { get; }
    public double MaximumRadians { get; }

    public JointLimits(double minimumRadians, double maximumRadians)
    {
        if (!double.IsFinite(minimumRadians) || !double.IsFinite(maximumRadians)
            || minimumRadians > maximumRadians)
            throw new ArgumentException("Joint limits must be finite and ordered.");
        MinimumRadians = minimumRadians;
        MaximumRadians = maximumRadians;
    }

    public bool Contains(double radians) => double.IsFinite(radians)
        && radians >= MinimumRadians && radians <= MaximumRadians;
}
