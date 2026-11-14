#Requires AutoHotkey v2.0
#NoTrayIcon
#o::Send "#{Tab}"
#Enter::
{
    Run 'wt.exe -w new -d C:\Users\davis\'
    WinWait "ahk_exe WindowsTerminal.exe"
    WinActivate "ahk_exe WindowsTerminal.exe"
}
#q::
{
    if WinExist("ahk_exe Taskmgr.exe")
        WinClose("ahk_exe Taskmgr.exe")
    else
        Send("!{F4}")
}
#F::Send "{F11}"
#e::
{
	if (WinGetMinMax("A") = 1)
		WinRestore "A"
	else
		WinMaximize "A"
}

