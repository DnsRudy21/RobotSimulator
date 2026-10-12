using System.Text.Json;
using System.Text.Json.Serialization;

namespace RobotSimulator.Core;

public enum PointKind { Joint, Cartesian }
public sealed class TaughtPoint
{
    [JsonRequired] public string Id { get; set; } = "";
    [JsonRequired] public string Name { get; set; } = "";
    [JsonRequired] public PointKind Kind { get; set; }
    [JsonRequired] public double[] Angles { get; set; } = new double[6];
    [JsonRequired] public Pose3d Pose { get; set; } = Pose3d.Identity;
    [JsonRequired] public string ToolId { get; set; } = "tool";
    [JsonRequired] public string FrameId { get; set; } = "base";
}

public sealed class RobotProject
{
    [JsonRequired] public int SchemaVersion { get; set; } = 1;
    [JsonRequired] public string RobotId { get; set; } = "generic-six-axis-v1";
    [JsonRequired] public Dictionary<string,Pose3d> Tools { get; set; } = new() { ["flange"]=Pose3d.Identity, ["tool"]=new(new(0.12,0,0),Rotation3d.Identity) };
    [JsonRequired] public Dictionary<string,Pose3d> Frames { get; set; } = new() { ["base"]=Pose3d.Identity, ["piece"]=Pose3d.Identity };
    [JsonRequired] public string ActiveTool { get; set; } = "tool";
    [JsonRequired] public string ActiveFrame { get; set; } = "base";
    [JsonRequired] public List<TaughtPoint> Points { get; set; } = [];
    [JsonRequired] public Dictionary<string,string> Programs { get; set; } = new() { ["main"]="" };
    [JsonRequired] public CellSettings Cell { get; set; } = new();
    [JsonIgnore] public Pose3d Tool => Tools[ActiveTool];
    [JsonIgnore] public Pose3d Frame => Frames[ActiveFrame];
    public Pose3d ExpressTcp(IReadOnlyList<double> angles) => Frame.Inverse*RobotGeometry.Flange(angles)*Tool;
    public Pose3d WorldTarget(TaughtPoint point) => Frames[point.FrameId]*point.Pose;
    public TaughtPoint Teach(string name,PointKind kind,IReadOnlyList<double> angles)
    {
        ValidateName(name); RobotGeometry.Validate(angles);
        if(!Enum.IsDefined(kind))throw new ArgumentException("Invalid point type");
        var point=new TaughtPoint { Id="p_"+Guid.NewGuid().ToString("N"),Name=name,Kind=kind,Angles=angles.ToArray(),Pose=ExpressTcp(angles),ToolId=ActiveTool,FrameId=ActiveFrame };
        Points.Add(point); return point;
    }
    public void UpdateReference(bool tool,string id,Pose3d pose)
    {
        ValidateId(id); pose.Validate();
        if(Points.Any(p=>tool?p.ToolId==id:p.FrameId==id)) throw new InvalidOperationException("Referencia usada por puntos: cree otra referencia o elimine/reenseñe los puntos primero");
        if(!tool && id=="base" && pose!=Pose3d.Identity)throw new InvalidOperationException("La base del robot es fija; edite la referencia de pieza");
        (tool?Tools:Frames)[id]=pose;
    }
    public static void ValidateName(string name) { if(string.IsNullOrWhiteSpace(name)||name.Length>60||name.Any(char.IsControl))throw new ArgumentException("Nombre requerido, máximo 60 caracteres"); }
    public static void ValidateId(string id) { if(string.IsNullOrEmpty(id)||id.Length>64||id.Any(c=>!char.IsAsciiLetterOrDigit(c)&&c!='_'))throw new ArgumentException("ID inválido (letras ASCII, números o _)"); }
    public void Validate()
    {
        if(SchemaVersion!=1 || RobotId!="generic-six-axis-v1")throw new ArgumentException("Versión o robot no soportado");
        if(Tools is null || Frames is null || Points is null || Programs is null || Cell is null)throw new ArgumentException("Estructura incompleta");
        if(Tools.Count is <1 or >32 || Frames.Count is <1 or >32 || Points.Count>500 || Programs.Count is <1 or >32)throw new ArgumentException("Tamaño fuera del dominio");
        foreach(var reference in Tools.Concat(Frames)) { ValidateId(reference.Key); reference.Value.Validate(); }
        if(!Tools.ContainsKey(ActiveTool)||!Frames.ContainsKey(ActiveFrame)||!Frames.TryGetValue("base",out var basis)||basis!=Pose3d.Identity)throw new ArgumentException("Referencias activas/base inválidas");
        var ids=new HashSet<string>();
        foreach(var p in Points) { if(p is null)throw new ArgumentException("Punto nulo"); ValidateId(p.Id); ValidateName(p.Name); if(!ids.Add(p.Id)||!Enum.IsDefined(p.Kind)||!Tools.ContainsKey(p.ToolId)||!Frames.ContainsKey(p.FrameId))throw new ArgumentException("Punto/referencias inválidos"); RobotGeometry.Validate(p.Angles); p.Pose.Validate(); }
        foreach(var p in Programs) { ValidateId(p.Key); if(p.Value is null || p.Value.Length>32000)throw new ArgumentException("Programa demasiado grande"); }
        if(!Programs.ContainsKey("main"))throw new ArgumentException("Falta programa main");
        Cell.Validate();
    }
}

public sealed class CellSettings
{
    [JsonRequired] public Vector3d Source { get; set; } = new(0.6,0,0.3);
    [JsonRequired] public Rotation3d PartRotation { get; set; } = Rotation3d.Identity;
    [JsonRequired] public Vector3d Destination { get; set; } = new(0.6,0.4,0.3);
    [JsonRequired] public Vector3d Obstacle { get; set; } = new(-0.6,-0.5,0.7);
    [JsonRequired] public bool ObstacleEnabled { get; set; } = true;
    // Optional schema-1 extension: older projects retain the original 200 mm cube.
    public Vector3d ObstacleHalfSize { get; set; } = new(0.1,0.1,0.1);
    public void Validate() {
        foreach(var v in new[]{Source,Destination,Obstacle}) if(!v.IsFinite||v.Length>3||v.Z<0.04)throw new ArgumentException("Celda fuera del dominio de 3 m / debajo del suelo");
        if(!PartRotation.IsValid)throw new ArgumentException("Orientación de pieza inválida");
        if(!ObstacleHalfSize.IsFinite||new[]{ObstacleHalfSize.X,ObstacleHalfSize.Y,ObstacleHalfSize.Z}.Any(v=>v<0.001||v>1))throw new ArgumentException("Semitamaño obstáculo 1…1000 mm por eje");
    }
}

public static class ProjectStorage
{
    public const int MaximumBytes=1_000_000;
    public static JsonSerializerOptions Options { get; } = new() { WriteIndented=true, UnmappedMemberHandling=JsonUnmappedMemberHandling.Disallow, Converters={ new JsonStringEnumConverter() }, MaxDepth=32 };
    public static string Serialize(RobotProject project) {
        project.Validate(); string result=JsonSerializer.Serialize(project,Options);
        if(System.Text.Encoding.UTF8.GetByteCount(result)>MaximumBytes)throw new ArgumentException("Archivo mayor que 1 MB"); return result;
    }
    public static RobotProject Deserialize(string json)
    {
        if(System.Text.Encoding.UTF8.GetByteCount(json)>MaximumBytes)throw new ArgumentException("Archivo mayor que 1 MB");
        using var document=JsonDocument.Parse(json,new JsonDocumentOptions { MaxDepth=32 });
        RejectDuplicateProperties(document.RootElement);
        var result=JsonSerializer.Deserialize<RobotProject>(json,Options)??throw new ArgumentException("Proyecto vacío"); result.Validate(); return result;
    }
    private static void RejectDuplicateProperties(JsonElement node)
    {
        if(node.ValueKind==JsonValueKind.Object) {
            var names=new HashSet<string>(StringComparer.Ordinal);
            foreach(var p in node.EnumerateObject()) { if(!names.Add(p.Name))throw new ArgumentException("Propiedad/ID duplicado: "+p.Name); RejectDuplicateProperties(p.Value); }
        } else if(node.ValueKind==JsonValueKind.Array)foreach(var child in node.EnumerateArray())RejectDuplicateProperties(child);
    }
    public static void Save(string path,RobotProject project)
    {
        string text=Serialize(project), temporary=path+"."+Guid.NewGuid().ToString("N")+".tmp";
        try { File.WriteAllText(temporary,text,new System.Text.UTF8Encoding(false)); File.Move(temporary,path,true); }
        finally { if(File.Exists(temporary))File.Delete(temporary); } // Only our own temporary file.
    }
    public static RobotProject Load(string path) {
        var info=new FileInfo(path); if(info.Length>MaximumBytes)throw new ArgumentException("Archivo mayor que 1 MB"); return Deserialize(File.ReadAllText(path));
    }
}
