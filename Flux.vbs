' ============================================================
' Flux Task Tracker - Silent Launcher
' Double-click this file to start Flux without a console window
' ============================================================

Option Explicit

Dim objShell, objFSO, strScriptPath, strPSScript, strCmd

Set objShell = CreateObject("WScript.Shell")
Set objFSO   = CreateObject("Scripting.FileSystemObject")

' Get the folder this VBS lives in
strScriptPath = objFSO.GetParentFolderName(WScript.ScriptFullName)
strPSScript   = strScriptPath & "\Start-Flux.ps1"

' Verify the PowerShell script exists
If Not objFSO.FileExists(strPSScript) Then
    MsgBox "Cannot find Start-Flux.ps1 in:" & vbCrLf & strScriptPath, _
           vbCritical, "Flux Launcher"
    WScript.Quit 1
End If

' Build the command
' -WindowStyle Hidden   -> no flashing console
' -ExecutionPolicy Bypass -> runs even if policy restricts scripts
strCmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & strPSScript & """"

' 0 = hidden window, False = don't wait for it to finish
objShell.Run strCmd, 0, False

Set objShell = Nothing
Set objFSO   = Nothing
