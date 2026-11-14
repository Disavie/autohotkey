#Requires AutoHotkey v2.0
#SingleInstance Force
#NoTrayIcon

; ==========================================
; Virtual Desktop Overlay
; ==========================================

; Load shared VirtualDesktopAccessor DLL
global dll := A_ScriptDir "\VirtualDesktopAccessor.dll"

if !FileExist(dll) {
    ExitApp()
}

DllCall("LoadLibrary", "Str", dll, "Ptr")

; Create overlay GUI
global DesktopIndicator := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
DesktopIndicator.BackColor := "20242B"

DesktopIndicator.SetFont("s8 cA0A8B5", "Segoe UI")
DesktopIndicator.AddText("x6 y4 w78 h15 Center", "DESKTOP")

DesktopIndicator.SetFont("s20 cFFFFFF Bold", "Segoe UI")
global DesktopNumberText := DesktopIndicator.AddText(
    "x6 y17 w78 h32 Center", "01"
)
; Find the leftmost monitor
MonitorGetCount()
MonitorGetWorkArea(1, &Left, &Top, &Right, &Bottom)

Loop MonitorGetCount() {
    MonitorGetWorkArea(A_Index, &L, &T, &R, &B)

    if (L < Left) {
        Left := L
        Top := T
    }
}

; Position in top-left corner
IndicatorX := Left
IndicatorY := Top 

DesktopIndicator.Show(
    "NA x" IndicatorX " y" IndicatorY " w90 h55"
)

; Poll current desktop
SetTimer(UpdateDesktopIndicator, 150)
SetTimer(CheckFullscreen, 250)


CheckFullscreen() {
    global DesktopIndicator

    static wasHidden := false

    ; Get current virtual desktop
    currentDesktop := DllCall(
        dll "\GetCurrentDesktopNumber",
        "Int"
    )

    fullscreenFound := false

    ; Enumerate all top-level windows
    for hwnd in WinGetList() {

        ; Ignore invisible windows
        if !DllCall("IsWindowVisible", "Ptr", hwnd)
            continue

        ; Ignore minimized windows
        try {
            if (WinGetMinMax("ahk_id " hwnd) = -1)
                continue
        } catch {
            continue
        }
        ; Ignore our own overlay
        if (hwnd = DesktopIndicator.Hwnd)
            continue

        ; Check virtual desktop membership
        windowDesktop := DllCall(
            dll "\GetWindowDesktopNumber",
            "Ptr", hwnd,
            "Int"
        )

        if (windowDesktop != currentDesktop)
            continue

        ; Get window position
        try WinGetPos(&X, &Y, &W, &H, "ahk_id " hwnd)
        catch
            continue

        ; Find monitor containing window
        Loop MonitorGetCount() {
            MonitorGet(A_Index, &L, &T, &R, &B)

            if (X <= L && Y <= T && X + W >= R && Y + H >= B) {
                fullscreenFound := true
                break
            }
        }

        if fullscreenFound
            break
    }

    ; Only change visibility when necessary
    if (fullscreenFound && !wasHidden) {
        DesktopIndicator.Hide()
        wasHidden := true
    }
    else if (!fullscreenFound && wasHidden) {
        DesktopIndicator.Show("NA")
        wasHidden := false
    }
}

UpdateDesktopIndicator() {
    global dll, DesktopNumberText

    current := DllCall(
        dll "\GetCurrentDesktopNumber",
        "Int"
    )

    DesktopNumberText.Text := Format("{:02}", current + 1)
}

