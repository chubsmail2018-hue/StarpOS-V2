' ===========================================================================
'  speak.vbs  -  starpOS shared speech engine
' ===========================================================================
'  Replaces the "write a temp .vbs, run it, delete it" block that every
'  starpOS script repeats. Call this instead:
'
'     cscript //nologo speak.vbs "Hardware verification successful."
'
'  Optional extras:
'     cscript //nologo speak.vbs "Slow and loud." -4 100
'                                 ^text          ^rate  ^volume
'
'     rate   -10 (slowest) to 10 (fastest), default 0
'     volume 0 to 100, default 100
'
'  It never stops the caller. No sound card, no voice installed or a bad
'  argument just means nothing is spoken and the exit code is non-zero.
'
'  EXIT CODES
'     0  spoken
'     1  no text given
'     2  SAPI voice engine unavailable  (STARP-0501)
'     3  the voice engine refused the text
' ===========================================================================

Option Explicit

Dim args, phrase, rate, volume, voice

Set args = WScript.Arguments

If args.Count < 1 Then
    WScript.StdErr.WriteLine "[ STARP-0501 ] speak.vbs: no text to speak."
    WScript.StdErr.WriteLine "               usage: cscript //nologo speak.vbs ""text"" [rate] [volume]"
    WScript.Quit 1
End If

phrase = args(0)

' Defaults, then override from the optional arguments if they are sane.
rate = 0
volume = 100

If args.Count > 1 Then
    If IsNumeric(args(1)) Then rate = CInt(args(1))
End If
If args.Count > 2 Then
    If IsNumeric(args(2)) Then volume = CInt(args(2))
End If

If rate < -10 Then rate = -10
If rate > 10 Then rate = 10
If volume < 0 Then volume = 0
If volume > 100 Then volume = 100

' The voice object is the part that fails on a machine with no speech
' support, so it gets its own guard.
On Error Resume Next
Set voice = CreateObject("SAPI.SpVoice")
If Err.Number <> 0 Then
    WScript.StdErr.WriteLine "[ STARP-0501 ] speak.vbs: SAPI voice engine unavailable."
    WScript.Quit 2
End If

voice.Rate = rate
voice.Volume = volume
Err.Clear

voice.Speak phrase
If Err.Number <> 0 Then
    WScript.StdErr.WriteLine "[ STARP-0501 ] speak.vbs: the voice engine refused that text."
    WScript.Quit 3
End If

On Error GoTo 0
WScript.Quit 0
