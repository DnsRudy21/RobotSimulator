using Godot;
using Microsoft.Win32;
using System;
using System.IO;
public partial class OpenXrRuntimeProbe : Node
{
    public bool IsConfigured()
    {
        if(!OperatingSystem.IsWindows())return false;
        foreach(var hive in new[]{"HKEY_CURRENT_USER","HKEY_LOCAL_MACHINE"}) {
            try { var path=Registry.GetValue(hive+@"\SOFTWARE\Khronos\OpenXR\1","ActiveRuntime",null) as string; if(path!=null&&File.Exists(path))return true; }
            catch(Exception e) when(e is System.Security.SecurityException or IOException or UnauthorizedAccessException) { }
        }
        return false;
    }
}
