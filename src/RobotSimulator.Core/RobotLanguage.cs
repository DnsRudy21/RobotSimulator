using System.Globalization;
namespace RobotSimulator.Core;

public sealed record RobotInstruction(string Op,string[] Args,string Location,int Jump=-1);
public static class RobotLanguage
{
    private static readonly HashSet<string> Signals = ["grip","belt","present","holding","delivered"];
    public static IReadOnlyList<RobotInstruction> Compile(RobotProject project,string name="main",CancellationToken cancellationToken=default)
    {
        cancellationToken.ThrowIfCancellationRequested(); project.Validate(); var output=new List<RobotInstruction>(); Expand(name,project,output,[],0,cancellationToken); return output.AsReadOnly();
    }
    private static void Expand(string name,RobotProject project,List<RobotInstruction> output,List<string> stack,int depth,CancellationToken token)
    {
        if(depth>8||stack.Contains(name))throw new ArgumentException($"CALL {name}: recursión o profundidad >8");
        if(!project.Programs.TryGetValue(name,out var text))throw new ArgumentException($"CALL: programa {name} no existe");
        var lines=text.Replace("\r","").Split('\n'); stack=[..stack,name];
        ExpandRange(0,lines.Length,lines,name,project,output,stack,depth,token);
    }
    private static void ExpandRange(int start,int end,string[] lines,string name,RobotProject project,List<RobotInstruction> output,List<string> stack,int depth,CancellationToken token,int blockDepth=0,int repeatFactor=1)
    {
        if(blockDepth>32)throw new ArgumentException("Máximo 32 bloques anidados");
        for(int i=start;i<end;i++)
        {
            token.ThrowIfCancellationRequested();
            string clean=lines[i].Split('#')[0].Trim(); if(clean.Length==0)continue;
            var parts=clean.Split((char[]?)null,StringSplitOptions.RemoveEmptyEntries); string op=parts[0].ToUpperInvariant(); var args=parts.Skip(1).ToArray(); string location=$"{name}:{i+1}";
            void Require(bool condition,string message) { if(!condition)throw new ArgumentException($"{location}: {message}"); }
            switch(op)
            {
                case "MOVEJ": case "MOVEL":
                    Require(args.Length==2,"MOVEJ/MOVEL ID duración_s");
                    Require(project.Points.Any(p=>p.Id==args[0]),"Punto no encontrado"); Number(args[1],0.1,120,location); output.Add(new(op,args,location)); break;
                case "SET_OUTPUT":
                    Require(args.Length==2&&args[0] is "grip" or "belt"&&args[1] is "0" or "1","SET_OUTPUT grip|belt 0|1"); output.Add(new(op,args,location)); break;
                case "WAIT_INPUT":
                    Require(args.Length==3&&Signals.Contains(args[0])&&args[1] is "0" or "1","WAIT_INPUT señal 0|1 timeout_s"); Number(args[2],0.01,120,location); output.Add(new(op,args,location)); break;
                case "WAIT":
                    Require(args.Length==1,"WAIT duración_s"); Number(args[0],0.01,120,location); output.Add(new(op,args,location)); break;
                case "CALL":
                    Require(args.Length==1,"CALL programa"); Expand(args[0],project,output,stack,depth+1,token); break;
                case "IF":
                {
                    Require(args.Length==2&&Signals.Contains(args[0])&&args[1] is "0" or "1","IF señal 0|1");
                    int finish=FindEnd(lines,i,end,"IF","ENDIF",out int alternate); int condition=output.Count; output.Add(new(op,args,location));
                    ExpandRange(i+1,alternate<0?finish:alternate,lines,name,project,output,stack,depth,token,blockDepth+1,repeatFactor);
                    if(alternate>=0) {
                        int jump=output.Count; output.Add(new("JUMP",[],location)); output[condition]=output[condition] with { Jump=output.Count };
                        ExpandRange(alternate+1,finish,lines,name,project,output,stack,depth,token,blockDepth+1,repeatFactor); output[jump]=output[jump] with { Jump=output.Count };
                    } else output[condition]=output[condition] with { Jump=output.Count };
                    i=finish; break;
                }
                case "REPEAT":
                {
                    Require(args.Length==1&&int.TryParse(args[0],NumberStyles.None,CultureInfo.InvariantCulture,out _),"REPEAT entero 1…100");
                    int repetitions=int.Parse(args[0],CultureInfo.InvariantCulture); Require(repetitions is >=1 and <=100,"REPEAT fuera de rango");
                    Require(repeatFactor*repetitions<=10000,"Producto de repeticiones >10000");
                    int finish=FindEnd(lines,i,end,"REPEAT","ENDREPEAT",out _);
                    for(int repeat=0;repeat<repetitions;repeat++)ExpandRange(i+1,finish,lines,name,project,output,stack,depth,token,blockDepth+1,repeatFactor*repetitions);
                    i=finish; break;
                }
                default: throw new ArgumentException($"{location}: instrucción no soportada o cierre fuera de bloque: {op}");
            }
            if(output.Count>10000)throw new ArgumentException($"{location}: máximo 10000 instrucciones expandidas");
        }
    }
    private static int FindEnd(string[] lines,int start,int end,string opening,string closing,out int alternate)
    {
        int nesting=0; alternate=-1;
        for(int i=start+1;i<end;i++) {
            var tokens=lines[i].Split('#')[0].Trim().Split((char[]?)null,StringSplitOptions.RemoveEmptyEntries); if(tokens.Length==0)continue; var op=tokens[0].ToUpperInvariant();
            if(op==opening)nesting++;
            if(op==closing) { if(nesting==0) { if(tokens.Length!=1)throw new ArgumentException($"línea {i+1}: cierre sin argumentos"); return i; } nesting--; }
            if(opening=="IF"&&op=="ELSE"&&nesting==0) { if(alternate>=0||tokens.Length!=1)throw new ArgumentException($"línea {i+1}: ELSE inválido"); alternate=i; }
        }
        throw new ArgumentException($"línea {start+1}: falta {closing}");
    }
    public static double Number(string value,double minimum,double maximum,string location)
    {
        if(!double.TryParse(value,NumberStyles.Float,CultureInfo.InvariantCulture,out double result)||!double.IsFinite(result)||result<minimum||result>maximum)throw new ArgumentException($"{location}: número fuera de {minimum}…{maximum}, use punto decimal"); return result;
    }
}
