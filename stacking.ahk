; switching to numbered desktops
#NoTrayIcon

#1::SwitchToDesktop(0)
#2::SwitchToDesktop(1)
#3::SwitchToDesktop(2)

global dll := A_ScriptDir "\VirtualDesktopAccessor.dll"

; window tracking
global DesktopWindows := Map()
global FocusIndex := Map()

global CurrentDesktop := 0

DllCall("LoadLibrary", "Str", dll, "Ptr")
; Launch desktop indicator

Run('"' A_AhkPath '" "' A_ScriptDir '\overlay.ahk"')

DetectHiddenWindows(true)

InitDesktopWindows()
InstallWindowHooks()

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
$#k::{
    CycleWindowFocus(1)  ; next window
    return
}
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

global hWindowEventHook := 0
global hForegroundHook := 0
global WindowEventCallback := 0

InstallWindowHooks() {
    global WindowEventCallback
    global hWindowEventHook, hForegroundHook

    ; Keep callback alive for as long as the hooks exist
    WindowEventCallback := CallbackCreate(HandleWinEvent, , 7)

    ; Window create, destroy, and show events
    hWindowEventHook := DllCall(
        "SetWinEventHook",
        "UInt", 0x8000, ; EVENT_OBJECT_CREATE
        "UInt", 0x8002, ; EVENT_OBJECT_SHOW
        "Ptr", 0,
        "Ptr", WindowEventCallback,
        "UInt", 0,
        "UInt", 0,
        "UInt", 0,
        "Ptr"
    )

    ; Foreground window changes
    hForegroundHook := DllCall(
        "SetWinEventHook",
        "UInt", 0x0003, ; EVENT_SYSTEM_FOREGROUND
        "UInt", 0x0003,
        "Ptr", 0,
        "Ptr", WindowEventCallback,
        "UInt", 0,
        "UInt", 0,
        "UInt", 0,
        "Ptr"
    )
}


HandleWinEvent(hHook, event, hwnd, idObject, idChild, thread, time) {
    ; Only interested in actual top-level windows
    if (!hwnd || idObject != 0 || idChild != 0)
        return

    if (DllCall("GetAncestor", "Ptr", hwnd, "UInt", 2, "Ptr") != hwnd)
        return

    switch event {
        case 0x8000: ; CREATE
            SetTimer(AddWindowToStack.Bind(hwnd), -300)

        case 0x8002: ; SHOW
            SetTimer(AddWindowToStack.Bind(hwnd), -100)

        case 0x8001: ; DESTROY
            SetTimer(RemoveWindowFromStack.Bind(hwnd), -50)

        case 0x0003: ; FOREGROUND
            SetTimer(UpdateFocusedWindow.Bind(hwnd), -50)
    }
}

AddWindowToStack(hwnd) {
    global dll, DesktopWindows, FocusIndex

    if !WinExist("ahk_id " hwnd)
        return

    if !DllCall("IsWindowVisible", "Ptr", hwnd)
        return

    ; Determine which desktop owns this window
    desktop := DllCall(
        dll "\GetWindowDesktopNumber",
        "Ptr", hwnd,
        "Int"
    )

    if !DesktopWindows.Has(desktop)
        return

    windows := DesktopWindows[desktop]

    ; Don't add duplicates
    if FindWindowIndex(windows, hwnd)
        return

    ; Append new window
    windows.Push(hwnd)

    ; Make it the new focus target
    FocusIndex[desktop] := windows.Length
}


UpdateFocusedWindow(hwnd) {
    global dll, DesktopWindows, FocusIndex

    if !WinExist("ahk_id " hwnd)
        return

    desktop := DllCall(
        dll "\GetWindowDesktopNumber",
        "Ptr", hwnd,
        "Int"
    )

    if !DesktopWindows.Has(desktop)
        return

    ; Add it if it hasn't been discovered yet
    index := FindWindowIndex(DesktopWindows[desktop], hwnd)

    if !index {
        DesktopWindows[desktop].Push(hwnd)
        index := DesktopWindows[desktop].Length
    }

    ; Update focus priority
    FocusIndex[desktop] := index
}


RemoveWindowFromStack(hwnd) {
    global DesktopWindows, FocusIndex

    for desktop, windows in DesktopWindows {
        index := FindWindowIndex(windows, hwnd)

        if !index
            continue

        windows.RemoveAt(index)

        ; Adjust focus index
        if (windows.Length = 0) {
            FocusIndex[desktop] := 0
        } else if (index < FocusIndex[desktop]) {
            FocusIndex[desktop] -= 1
        } else if (index = FocusIndex[desktop]) {
            FocusIndex[desktop] := Min(index, windows.Length)
        }

        return
    }
} 
