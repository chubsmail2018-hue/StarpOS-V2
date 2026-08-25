' ===========================================================================
'  listen.vbs  -  starpOS voice input gateway
' ===========================================================================
'  Pops up a single input box and prints whatever was typed to standard
'  output, so a batch file can capture it. This is the reusable version of
'  the temp-file InputBox block inside voise2.bat.
'
'  Capture the answer from batch:
'
'     set "spoken="
'     for /f "delims=" %%A in ('cscript //nologo listen.vbs') do set "spoken=%%A"
'     if "%spoken%"=="" goto cancelled
'
'  Custom prompt and window title:
'
'     cscript //nologo listen.vbs "What is your name?" "starpOS Setup"
'
'  Third argument pre-fills the box with a default answer:
'
'     cscript //nologo listen.vbs "Theme?" "starpOS Settings" "1F"
'
'  EXIT CODES
'     0  the user typed something, it was printed to stdout
'     1  the user pressed Cancel or left the box empty (nothing printed)
' ===========================================================================

Option Explicit

Dim args, prompt, boxTitle, preset, answer

Set args = WScript.Arguments

prompt   = "Speak or type your command below:"
boxTitle = "starpOS Voice Input Portal"
preset   = ""

If args.Count > 0 Then prompt   = args(0)
If args.Count > 1 Then boxTitle = args(1)
If args.Count > 2 Then preset   = args(2)

answer = InputBox(prompt, boxTitle, preset)

' InputBox gives back an empty string for both Cancel and an empty OK.
' Either way there is nothing to act on, so report it the same way.
If IsNull(answer) Then
    WScript.Quit 1
End If

answer = Trim(answer)

If answer = "" Then
    WScript.Quit 1
End If

WScript.Echo answer
WScript.Quit 0
