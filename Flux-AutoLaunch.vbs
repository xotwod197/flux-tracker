' ============================================================
' Flux PWA Launcher - Startup Script
' Waits for the PowerShell backend to be ready, then launches
' the Flux PWA window. Place this in your Startup folder.
'
' Supports PWAs installed via Chrome or Edge. Falls back to
' opening the URL in the default browser if no PWA is found.
' ============================================================

Option Explicit

Dim objShell, objHTTP, strURL, iAttempts, bReady, iMaxAttempts
Dim objFSO, strStartMenu, objFolder, objFile
Dim arrPWAPaths, strPath, bLaunched

strURL       = "http://localhost:7789/api/status"
iMaxAttempts = 20   ' 20 attempts x 500ms = 10 second max wait
bReady       = False
bLaunched    = False

Set objShell = CreateObject("WScript.Shell")
Set objFSO   = CreateObject("Scripting.FileSystemObject")

' ----- Wait for backend to be ready -----
For iAttempts = 1 To iMaxAttempts
    On Error Resume Next
    Set objHTTP = CreateObject("MSXML2.XMLHTTP")
    objHTTP.Open "GET", strURL, False
    objHTTP.Send
    If Err.Number = 0 And objHTTP.Status = 200 Then
        bReady = True
        Exit For
    End If
    Err.Clear
    On Error GoTo 0
    WScript.Sleep 500
Next

' If backend never came up, quietly exit
If Not bReady Then
    WScript.Quit 0
End If

' ----- Look for a Flux PWA shortcut in common locations -----
strStartMenu = objShell.SpecialFolders("StartMenu")

' Possible PWA install locations (Chrome and Edge, user-level start menus)
arrPWAPaths = Array( _
    strStartMenu & "\Programs\Chrome Apps", _
    strStartMenu & "\Programs", _
    objShell.ExpandEnvironmentStrings("%APPDATA%") & "\Microsoft\Windows\Start Menu\Programs\Chrome Apps", _
    objShell.ExpandEnvironmentStrings("%APPDATA%") & "\Microsoft\Windows\Start Menu\Programs" _
)

' Search each location for a shortcut with "flux" in the name
For Each strPath In arrPWAPaths
    If bLaunched Then Exit For
    If objFSO.FolderExists(strPath) Then
        Set objFolder = objFSO.GetFolder(strPath)
        For Each objFile In objFolder.Files
            If LCase(objFSO.GetExtensionName(objFile.Name)) = "lnk" Then
                If InStr(LCase(objFile.Name), "flux") > 0 Then
                    objShell.Run """" & objFile.Path & """", 1, False
                    bLaunched = True
                    Exit For
                End If
            End If
        Next
    End If
Next

' If no PWA shortcut found, try Desktop
If Not bLaunched Then
    Dim strDesktop
    strDesktop = objShell.SpecialFolders("Desktop")
    If objFSO.FileExists(strDesktop & "\Flux.lnk") Then
        objShell.Run """" & strDesktop & "\Flux.lnk" & """", 1, False
        bLaunched = True
    End If
End If

' Last resort - open the URL in the default browser
If Not bLaunched Then
    objShell.Run strURL, 1, False
End If

Set objShell = Nothing
Set objFSO   = Nothing
