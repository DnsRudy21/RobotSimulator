namespace RobotSimulator.Core;

public static class DemoExample
{
    public static RobotProject Create()
    {
        var p=new RobotProject();
        TaughtPoint Point(string id,string name,double[] q,PointKind kind) { var result=p.Teach(name,kind,q); result.Id=id; return result; }
        Point("home","Inicio",[0,0,0,0,0,0],PointKind.Joint);
        Point("approach","Aproximación recogida",[0,0.55,0.55,0,0.2,0],PointKind.Joint);
        var pick=Point("pick","Recogida",[0,0.8,0.3,0,0.2,0],PointKind.Cartesian);
        Point("lift","Retirada recogida",[0,0.55,0.55,0,0.2,0],PointKind.Cartesian);
        Point("transfer","Aproximación destino",[0.45,0.55,0.55,0,0.2,0],PointKind.Joint);
        var place=Point("place","Entrega",[0.45,0.8,0.3,0,0.2,0],PointKind.Cartesian);
        Point("withdraw","Retirada destino",[0.45,0.55,0.55,0,0.2,0],PointKind.Cartesian);
        p.Cell.Source=pick.Pose.Position; p.Cell.PartRotation=pick.Pose.Rotation; p.Cell.Destination=place.Pose.Position;
        p.Programs["pickup"]="MOVEJ approach 3\nMOVEL pick 2\nSET_OUTPUT grip 1\nWAIT_INPUT holding 1 2\nMOVEL lift 2";
        p.Programs["main"]="SET_OUTPUT belt 0\nWAIT_INPUT present 1 3\nIF present 1\nCALL pickup\nELSE\nWAIT_INPUT present 1 3\nENDIF\nMOVEJ transfer 3\nMOVEL place 2\nSET_OUTPUT grip 0\nWAIT_INPUT delivered 1 3\nMOVEL withdraw 2\nMOVEJ home 3\nREPEAT 2\nWAIT 0.1\nENDREPEAT";
        p.Validate(); RobotLanguage.Compile(p); return p;
    }
}
