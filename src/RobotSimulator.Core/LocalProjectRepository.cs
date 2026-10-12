using System.Text.RegularExpressions;
namespace RobotSimulator.Core;

/// <summary>Managed names over the existing JSON serializer; no platform UI or second format.</summary>
public sealed class LocalProjectRepository
{
    public string DirectoryPath { get; }
    public LocalProjectRepository(string directory) { DirectoryPath=Path.GetFullPath(directory); Directory.CreateDirectory(DirectoryPath); }
    public string[] List() => Directory.EnumerateFiles(DirectoryPath,"*.json").Select(Path.GetFileNameWithoutExtension).OfType<string>().Order(StringComparer.OrdinalIgnoreCase).ToArray();
    private string Resolve(string name)
    {
        if(name!=name.Trim()||name.Length is <1 or >60||!Regex.IsMatch(name,@"^[\p{L}\p{N}_ -]+$")||name.EndsWith(' ')||Regex.IsMatch(name,@"^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$",RegexOptions.IgnoreCase))throw new ArgumentException("Nombre de proyecto: letras, números, espacios, guion; 1–60 caracteres");
        return Path.Combine(DirectoryPath,name+".json");
    }
    public bool Exists(string name) => File.Exists(Resolve(name));
    public void Save(string name,RobotProject project,bool replace)
    {
        string path=Resolve(name); if(File.Exists(path)&&!replace)throw new InvalidOperationException("Proyecto existente: confirme sustitución");
        RobotLanguage.Compile(project); ProjectStorage.Save(path,project);
    }
    public RobotProject Load(string name) => ProjectStorage.Load(Resolve(name));
}
