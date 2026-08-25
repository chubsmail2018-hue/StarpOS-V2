// ===========================================================================
//  starpOS Voice Control Center - native build of Voice.bat
//
//  Usage: Voice.exe [primary_log] [reserved] [secondary_log]
//
//  Rebuild with (one line):
//    C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /nologo /target:exe
//      /out:Voice.exe
//      /r:C:\Windows\Microsoft.NET\assembly\GAC_MSIL\System.Speech\v4.0_4.0.0.0__31bf3856ad364e35\System.Speech.dll
//      Voice.cs
// ===========================================================================
using System;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using System.Speech.Recognition;
using System.Speech.Synthesis;
using System.Threading;

namespace StarpOS
{
    internal static class Voice
    {
        private const string CmdName = "starpOS";
        private const string CmdOpen = "Open File";
        private const string CmdExit = "Exit";

        // "starpOS" is a coined word, so the stock desktop recogniser almost
        // never matches it on its own. Every spoken form below is accepted and
        // folded back onto one of the three real commands.
        private static readonly Dictionary<string, string> Aliases = BuildAliases();

        private static Dictionary<string, string> BuildAliases()
        {
            Dictionary<string, string> map =
                new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

            Map(map, CmdName, "starpOS", "star pos", "star p o s", "star oh s",
                              "star boss", "computer", "system", "hello",
                              "are you there");
            Map(map, CmdOpen, "open file", "open files", "file explorer",
                              "open explorer", "show files", "list files");
            Map(map, CmdExit, "exit", "quit", "close", "shut down", "goodbye",
                              "stop listening");
            return map;
        }

        // Indexer assignment, not Add: two phrases that collide once casing is
        // ignored must not take the whole program down at startup.
        private static void Map(Dictionary<string, string> map, string command,
                                params string[] phrases)
        {
            foreach (string phrase in phrases) map[phrase] = command;
        }

        private static string _log1 = string.Empty;
        private static string _log3 = string.Empty;
        private static SpeechSynthesizer _tts;
        private static SpeechRecognitionEngine _asr;
        private static bool _micReady;
        private static bool _asrRunning;
        private static bool _micSilent;
        private static string _ttsError;

        // How long a completely dead capture device is tolerated before the
        // session stops pretending it can hear and hands over to the keyboard.
        private const int SilenceGraceSeconds = 15;

        // Quiet gap after speaking, so the machine never hears itself.
        private const int SpeechSettleMs = 900;

        private static readonly object _sync = new object();
        private static string _heard;
        private static string _lastReject;
        private static float _level;

        private static int Main(string[] args)
        {
            try { Console.Title = "starpOS Voice Recognition System"; }
            catch { /* no console title when output is redirected */ }

            // Mirrors the Voice.bat argument slots: %1 and %3 are log targets.
            if (args.Length > 0) _log1 = args[0];
            if (args.Length > 2) _log3 = args[2];

            _tts = CreateSynthesizer();
            _micReady = TryStartRecognizer();

            // Speak immediately so a broken audio path is obvious at launch
            // rather than looking like a recogniser that simply never fires.
            Say("starpOS voice control online.");

            while (true)
            {
                DrawBanner();

                string spoken = _micReady ? ListenMic() : ListenTyped();

                // Silence, timeout or a cancelled prompt just re-arms the listener.
                if (string.IsNullOrEmpty(spoken)) continue;

                string command = Canonical(spoken.Trim());
                if (command == null) { Unknown(spoken.Trim()); continue; }

                if (command == CmdName) Greeting();
                else if (command == CmdOpen) FileExplorer();
                else if (command == CmdExit) { Shutdown(); return 0; }
            }
        }

        private static string Canonical(string spoken)
        {
            string command;
            return Aliases.TryGetValue(spoken, out command) ? command : null;
        }

        // -------------------------------------------------------------------
        // Setup
        // -------------------------------------------------------------------
        private static SpeechSynthesizer CreateSynthesizer()
        {
            try
            {
                SpeechSynthesizer tts = new SpeechSynthesizer();
                tts.SetOutputToDefaultAudioDevice();
                if (tts.GetInstalledVoices().Count == 0)
                {
                    _ttsError = "No speech voices are installed on this machine.";
                    return null;
                }
                return tts;
            }
            catch (Exception ex)
            {
                _ttsError = ex.Message;
                return null;
            }
        }

        private static bool TryStartRecognizer()
        {
            try
            {
                Choices choices = new Choices();
                foreach (string phrase in Aliases.Keys) choices.Add(phrase);

                GrammarBuilder builder = new GrammarBuilder();
                builder.Append(choices);

                _asr = new SpeechRecognitionEngine();
                _asr.LoadGrammar(new Grammar(builder));
                _asr.SetInputToDefaultAudioDevice();

                _asr.SpeechRecognized += OnRecognized;
                _asr.SpeechRecognitionRejected += OnRejected;
                _asr.AudioLevelUpdated += OnAudioLevel;
                return true;
            }
            catch
            {
                // No recognizer for this culture, or no microphone attached.
                if (_asr != null) { try { _asr.Dispose(); } catch { } _asr = null; }
                return false;
            }
        }

        private static void OnRecognized(object sender, SpeechRecognizedEventArgs e)
        {
            if (e.Result == null) return;
            lock (_sync)
            {
                _heard = e.Result.Text;
                _lastReject = null;
            }
        }

        private static void OnRejected(object sender, SpeechRecognitionRejectedEventArgs e)
        {
            // Surface near-misses so a mic that is working but not matching is
            // visibly different from a mic that is not picking anything up.
            string text = (e.Result == null || string.IsNullOrEmpty(e.Result.Text))
                ? "(unclear)"
                : e.Result.Text;
            float conf = e.Result == null ? 0f : e.Result.Confidence;
            lock (_sync) { _lastReject = text + "  (confidence " + conf.ToString("0.00") + ")"; }
        }

        private static void OnAudioLevel(object sender, AudioLevelUpdatedEventArgs e)
        {
            lock (_sync) { _level = e.AudioLevel; }
        }

        private static void StartAsr()
        {
            if (_asrRunning) return;
            try { _asr.RecognizeAsync(RecognizeMode.Multiple); _asrRunning = true; }
            catch { _micReady = false; }
        }

        private static void StopAsr()
        {
            if (!_asrRunning) return;
            try { _asr.RecognizeAsyncCancel(); } catch { }
            _asrRunning = false;
            Thread.Sleep(150); // let the engine release the capture device
        }

        // -------------------------------------------------------------------
        // Interface
        // -------------------------------------------------------------------
        private static void DrawBanner()
        {
            SafeClear();
            Console.WriteLine("===============================================================================");
            Console.WriteLine("                     starpOS VOICE RECOGNITION CONTROL CENTER");
            Console.WriteLine("===============================================================================");
            Console.WriteLine();
            Console.WriteLine(_micReady
                ? "  [ STATUS ] Microphone active. Listening for your spoken commands..."
                : "  [ STATUS ] Speech engine unavailable. Typed command panel engaged.");
            if (_tts == null)
                Console.WriteLine("  [ WARNING ] Voice output is OFF: " + (_ttsError ?? "unknown reason"));
            if (_micSilent)
                Console.WriteLine("  [ WARNING ] Microphone reaching this app is silent - type commands below.");
            Console.WriteLine();
            Console.WriteLine("  COMMANDS (say any wording on a line):");
            Console.WriteLine("   1. \"starpOS\"    / \"computer\" / \"hello\"      - vocal greeting.");
            Console.WriteLine("   2. \"Open File\"  / \"file explorer\"           - list the folder.");
            Console.WriteLine("   3. \"Exit\"       / \"quit\" / \"goodbye\"        - close the engine.");
            Console.WriteLine();
            Console.WriteLine("===============================================================================");
            Console.WriteLine();
        }

        private static void SafeClear()
        {
            try
            {
                Console.BackgroundColor = ConsoleColor.Black;
                Console.ForegroundColor = ConsoleColor.Yellow;
                Console.Clear();
            }
            catch { /* redirected output cannot be cleared or coloured */ }
        }

        // -------------------------------------------------------------------
        // Input
        // -------------------------------------------------------------------
        private static string ListenMic()
        {
            Console.WriteLine("  [ LISTENING ] Say a command, or press any key to type one instead.");
            Console.WriteLine();

            // A scripted or piped session has no console to poll for keys.
            if (ConsoleInputRedirected()) return ListenTyped();

            lock (_sync) { _heard = null; _lastReject = null; _level = 0f; }
            StartAsr();
            if (!_micReady) return null;

            DateTime started = DateTime.UtcNow;
            float peak = 0f;

            while (true)
            {
                string got;
                float level;
                lock (_sync) { got = _heard; level = _level; }
                if (got != null) { StopAsr(); Console.WriteLine(); Console.WriteLine(); return got; }
                if (level > peak) peak = level;

                if (KeyPressed())
                {
                    StopAsr();
                    Console.WriteLine();
                    Console.WriteLine();
                    return ListenTyped();
                }

                // An open capture device that never registers a single sample is
                // the difference between "you said it wrong" and "Windows is not
                // sending us any audio at all". Say which, instead of listening
                // forever at a microphone that cannot hear.
                if (!_micSilent && peak <= 0f
                    && (DateTime.UtcNow - started).TotalSeconds >= SilenceGraceSeconds)
                {
                    // Flagged, not acted on: someone who simply has not spoken
                    // yet must not be dragged out of voice mode.
                    _micSilent = true;
                    Console.WriteLine();
                    Console.WriteLine();
                    Console.WriteLine("  [ NOTICE ] No sound has reached the microphone yet. If that is");
                    Console.WriteLine("             unexpected, check it is plugged in, unmuted, and set as");
                    Console.WriteLine("             the default recording device. Press any key to type.");
                    Console.WriteLine();
                }

                DrawMeter(peak);
                Thread.Sleep(120);
            }
        }

        // A live input meter plus the last near-miss: between them they show
        // whether the microphone is hearing anything and whether what it heard
        // came close to a command.
        private static void DrawMeter(float peak)
        {
            float level;
            string reject;
            lock (_sync) { level = _level; reject = _lastReject; }

            int filled = (int)Math.Round(Math.Min(level, 100f) / 100f * 20f);
            string bar = new string('#', filled) + new string('.', 20 - filled);
            string line = "  MIC [" + bar + "] " + ((int)level).ToString().PadLeft(3);
            if (peak <= 0f) line += "   (no signal yet)";
            if (reject != null) line += "   last heard: " + reject;

            try
            {
                if (line.Length > Console.BufferWidth - 1) line = line.Substring(0, Console.BufferWidth - 1);
                Console.Write("\r" + line.PadRight(Console.BufferWidth - 1));
            }
            catch { /* narrow or redirected console: skip the meter */ }
        }

        private static bool ConsoleInputRedirected()
        {
            try { return Console.IsInputRedirected; }
            catch { return true; }
        }

        private static bool KeyPressed()
        {
            try
            {
                if (!Console.KeyAvailable) return false;
                while (Console.KeyAvailable) Console.ReadKey(true); // drain
                return true;
            }
            catch
            {
                return false;
            }
        }

        private static string ListenTyped()
        {
            Console.Write("  starpOS voice> ");
            try { return Console.ReadLine(); }
            catch { return CmdExit; } // No stdin available; do not spin forever.
        }

        // -------------------------------------------------------------------
        // Commands
        // -------------------------------------------------------------------
        private static void Greeting()
        {
            Log("User spoke name keyword: starpOS");
            SafeClear();
            Console.WriteLine("[ VOICE ] Command Recognized: \"starpOS\"");
            Console.WriteLine();
            Say("Yes Boss. I am listening. All starpOS core systems are fully online "
                + "and tracking your speech parameters smoothly.");
        }

        private static void FileExplorer()
        {
            Log("User spoke file command: Open File");
            SafeClear();
            Console.WriteLine("[ VOICE ] Command Recognized: \"Open File\"");
            Console.WriteLine();
            Say("Opening file explorer application window now.");
            Console.WriteLine("=== FILE EXPLORER ===");
            Console.WriteLine();

            try
            {
                // Same target as Voice.bat: the folder above this program.
                string here = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
                DirectoryInfo parent = Directory.GetParent(here);
                string target = parent == null ? here : parent.FullName;

                Console.WriteLine("  " + target);
                Console.WriteLine();
                foreach (string entry in Directory.GetDirectories(target))
                    Console.WriteLine("  [DIR]  " + Path.GetFileName(entry));
                foreach (string entry in Directory.GetFiles(target))
                    Console.WriteLine("         " + Path.GetFileName(entry));
            }
            catch (Exception ex)
            {
                Console.WriteLine("  [ ERROR ] Directory unreadable: " + ex.Message);
            }

            Console.WriteLine();
            Console.WriteLine("Press any key to continue . . .");
            SafePause();
        }

        private static void Unknown(string spoken)
        {
            Log("Unrecognized command: " + spoken);
            SafeClear();
            Console.WriteLine("[ VOICE ] Unrecognized Command Matrix: \"" + spoken + "\"");
            Console.WriteLine();
            Say("Command not recognized. Please try again.");
            Thread.Sleep(1200);
        }

        private static void Shutdown()
        {
            Log("User closed the voice engine");
            SafeClear();
            Console.WriteLine("[ VOICE ] Shutting down voice engine...");
            Say("Exiting voice control system.");
            StopAsr();
            try { if (_asr != null) _asr.Dispose(); } catch { }
            try { if (_tts != null) _tts.Dispose(); } catch { }
        }

        private static void SafePause()
        {
            try { Console.ReadKey(true); }
            catch { try { Console.ReadLine(); } catch { } }
        }

        // -------------------------------------------------------------------
        // Output helpers
        // -------------------------------------------------------------------
        private static void Say(string text)
        {
            if (_tts == null)
            {
                Console.WriteLine("  [ WARNING ] Cannot speak: " + (_ttsError ?? "no synthesizer"));
                return;
            }

            // The recogniser must not listen to the machine's own voice, or the
            // greeting retriggers a command the moment it is spoken.
            bool wasRunning = _asrRunning;
            StopAsr();
            try { _tts.Speak(text); }
            catch (Exception ex)
            {
                _ttsError = ex.Message;
                Console.WriteLine("  [ WARNING ] Speech output failed: " + ex.Message);
            }
            // Speak() returns as the last sample is queued, not as the speakers
            // go quiet. Re-arming instantly lets the tail of our own sentence
            // back into the microphone, and every reply contains the wake word.
            Thread.Sleep(SpeechSettleMs);
            if (wasRunning) StartAsr();
        }

        private static void Log(string message)
        {
            WriteLog(_log1, message);
            WriteLog(_log3, message);
        }

        private static void WriteLog(string path, string message)
        {
            if (string.IsNullOrEmpty(path)) return;
            try
            {
                File.AppendAllText(path,
                    "[" + DateTime.Now.ToString("HH:mm:ss.ff") + "] [VOICE_CMD] "
                    + message + Environment.NewLine);
            }
            catch { /* a bad log path must never take the session down */ }
        }
    }
}
