namespace RobotSimulator.Core;

/// <summary>Session observations, not a validated assessment of learning.</summary>
public sealed class GuidedPractice
{
    private readonly HashSet<string> observed=[];
    public bool Guided { get; private set; }
    private static readonly (string id,string description)[] Steps=[
        ("references","Preparar y seleccionar TCP/frame"),("teach","Enseñar al menos un punto propio"),
        ("program","Crear o modificar un programa"),("verify","Verificar programa/trayectos"),
        ("step","Completar una instrucción paso a paso"),("cycle","Entregar pieza por ejecución del programa"),
        ("fault","Provocar/identificar una falla registrada"),("recovery","Retirar causa y restablecer sin rearranque"),
        ("save","Guardar proyecto validado"),("load","Cargar proyecto detenido")];
    public void Start(bool guided) { Guided=guided; observed.Clear(); }
    public void Observe(string fact) { if(Guided)observed.Add(fact); }
    public bool Has(string fact) => observed.Contains(fact);
    public string Report() => (Guided?"PRÁCTICA GUIADA":"MODO LIBRE")+" · evidencia de esta sesión\n"+
        string.Join('\n',Steps.Select(s=>$"{(observed.Contains(s.id)?"✓":"○")} {s.description}"))+
        "\nAcepta programas y puntos diferentes si la pieza llega al destino. Revisión docente pendiente; no certifica aprendizaje ni seguridad.";
}
