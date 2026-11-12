; switching to numbered desktops
#1::SwitchToDesktop(0)
#2::SwitchToDesktop(1)
#3::SwitchToDesktop(2)

global dll := A_ScriptDir "\VirtualDesktopAccessor.dll"

; window tracking
global DesktopWindows := Map()
global FocusIndex := Map()

global CurrentDesktop := 0

DllCall("LoadLibrary", "Str", dll, "Ptr")

DetectHiddenWindows(true)
InitDesktopWindows()

; init
InitDesktopWindows(){
    global dll, DesktopWindows, FocusIndex, CurrentDesktop

    CurrentDesktop := DllCall(
        dll "\GetWindowDesktopNumber", "Ptr", WinExist("A"), "Int"
    )
    ; getting open windows per desktop
    for desktop in [0,1,2]{
        FocusIndex[desktop] := 0
        DesktopWindows[desktop] := []
        RefreshDesktopWindows(desktop)
    }

    ; setting what should be the focused window on this desktop
    hwnd := WinExist("A")
    index := FindWindowIndex(DesktopWindows[CurrentDesktop], hwnd)
    if index
        FocusIndex[CurrentDesktop] := index
}

FindWindowIndex(windows, hwnd){
    for index, window in windows{
        if (window = hwnd)
            return index
    }
    return 0
}

RefreshDesktopWindows(desktop){
    global dll, DesktopWindows, FocusIndex, CurrentDesktop
    oldWindows := DesktopWindows[desktop]
    newWindows := []
   ; adding previous windows 
    for hwnd in oldWindows{
        if ( WinExist("ahk_id " hwnd)
            && DllCall("IsWindowVisible", "Ptr", hwnd)
            && DllCall(dll "\GetWindowDesktopNumber", "Ptr", hwnd, "Int") = desktop) {
                newWindows.Push(hwnd)
            }
    }
    ; adding new windows
    for hwnd in WinGetList() {
        if ( DllCall("IsWindowVisible", "Ptr", hwnd)
            && DllCall(dll "\GetWindowDesktopNumber", "Ptr", hwnd, "Int") = desktop
            && !FindWindowIndex(newWindows, hwnd)) {
                newWindows.Push(hwnd)
            }
    }

    DesktopWindows[desktop] := newWindows
    
    if (newWindows.Length = 0)
        FocusIndex[desktop] := 0
    else if (FocusIndex[desktop] > newWindows.length)
        FocusIndex[desktop] := newWindows.length
}

SwitchToDesktop(num) {
   global dll, CurrentDesktop, DesktopWindows, FocusIndex

    ; Update current desktop's focused window
    hwnd := WinExist("A")
    RefreshDesktopWindows(CurrentDesktop)

    index := FindWindowIndex(DesktopWindows[CurrentDesktop], hwnd)
    if index
        FocusIndex[CurrentDesktop] := index

    ; Switch desktop
    DllCall(dll "\GoToDesktopNumber", "Int", num, "Int")
    CurrentDesktop := num

    Sleep(150)

    RefreshDesktopWindows(num)

    ; Activate focused window
    index := FocusIndex[num]

    if (index > 0 && index <= DesktopWindows[num].Length)
        WinActivate("ahk_id " DesktopWindows[num][index])
    else if DesktopWindows[num].Length {
        FocusIndex[num] := 1
        WinActivate("ahk_id " DesktopWindows[num][1])
    }
}

; Move active window to another desktop
#+1::MoveCurrentWindowToDesktopNum(0)
#+2::MoveCurrentWindowToDesktopNum(1)
#+3::MoveCurrentWindowToDesktopNum(2)

MoveCurrentWindowToDesktopNum(num) {
    global dll, CurrentDesktop, DesktopWindows, FocusIndex

    hwnd := WinExist("A")
    if !hwnd || num = CurrentDesktop
        return

    source := CurrentDesktop

    ; Refresh both desktop lists
    RefreshDesktopWindows(source)
    RefreshDesktopWindows(num)

    ; Remove window from source desktop
    oldIndex := FindWindowIndex(DesktopWindows[source], hwnd)

    if oldIndex {
        DesktopWindows[source].RemoveAt(oldIndex)

        ; Adjust source focus index
        if (DesktopWindows[source].Length = 0) {
            FocusIndex[source] := 0
        } else if (oldIndex < FocusIndex[source]) {
            FocusIndex[source] -= 1
        } else if (oldIndex = FocusIndex[source]) {
            FocusIndex[source] := Min(oldIndex, DesktopWindows[source].Length)
        }
    }

    ; Move window
    DllCall(dll "\MoveWindowToDesktopNumber", "Ptr", hwnd, "Int", num)

    ; Add window to destination desktop
    DesktopWindows[num].Push(hwnd)

    ; Moved window becomes destination focus priority
    FocusIndex[num] := DesktopWindows[num].Length

    ; Activate next window on source desktop
    Sleep(150)

    if (FocusIndex[source] > 0)
        WinActivate("ahk_id " DesktopWindows[source][FocusIndex[source]])
}


PrintDesktopWindows() {
    global DesktopWindows, FocusIndex, CurrentDesktop

    output := "`n========== DESKTOP WINDOWS ==========`n"

    for desktop, windows in DesktopWindows {
        output .= "`nDesktop " desktop
            . (desktop = CurrentDesktop ? " [CURRENT]" : "")
            . "`n"

        for index, hwnd in windows {
            title := WinGetTitle("ahk_id " hwnd)
            exe := WinGetProcessName("ahk_id " hwnd)

            marker := (index = FocusIndex[desktop]) ? " <-- FOCUSED" : ""

            output .= "  [" index "] " exe
                . " | " title
                . marker
                . "`n"
        }
    }

    output .= "`n=====================================`n"

    FileAppend(output, "C:\Users\davis\Documents\AutoHotkey\desktops.log")
}
#+d::PrintDesktopWindows()


#j::CycleWindowFocus(-1) ; previous window
#k::CycleWindowFocus(1)  ; next window
CycleWindowFocus(direction) {
    global DesktopWindows, FocusIndex, CurrentDesktop

    windows := DesktopWindows[CurrentDesktop]
    count := windows.Length

    if (count = 0)
        return

    ; Move focus index, wrapping around
    FocusIndex[CurrentDesktop] += direction

    if (FocusIndex[CurrentDesktop] > count)
        FocusIndex[CurrentDesktop] := 1
    else if (FocusIndex[CurrentDesktop] < 1)
        FocusIndex[CurrentDesktop] := count

    ; Activate selected window
    hwnd := windows[FocusIndex[CurrentDesktop]]

    if WinExist("ahk_id " hwnd)
        WinActivate("ahk_id " hwnd)
}
