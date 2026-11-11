#Requires AutoHotkey v2.0

Loop Files A_ScriptDir "\*.ahk" {
    if (A_LoopFileFullPath != A_ScriptFullPath)
        Run A_LoopFileFullPath
}