// ===========================================================================
//  starpOS AI ASSISTANT - native build   /   ai.exe
// ===========================================================================
//  The GUI face of ai.bat. Same assistant, same data, different shell:
//  every file this reads and writes is the one the batch version uses, so
//  a quest added here is on the list there and a lesson taught there
//  answers here.
//
//  WHAT IT WEARS
//
//  Kohaku's look, ported properly rather than approximated. The console
//  version had sixteen colours to work with and had to suggest the design;
//  this one has the real palettes - twelve presets, ten colour tokens each,
//  the values lifted straight out of theme/jasper_theme.gd, which is the
//  fork of Kohaku's own theme file.
//
//  The two axes are still separate, for the reason Kohaku keeps them
//  separate: THEME changes hue, BOX changes the border, and neither may
//  touch the other, so every preset reads as the same machine in a
//  different colour.
//
//  Rebuild with (one line):
//    C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /nologo
//      /target:winexe /out:ai.exe
//      /r:System.Drawing.dll /r:System.Windows.Forms.dll
//      /r:C:\Windows\Microsoft.NET\assembly\GAC_MSIL\System.Speech\v4.0_4.0.0.0__31bf3856ad364e35\System.Speech.dll
//      ai.cs
//
//  Or just run:  build_ai.bat
//
//  Written for the C# 5 compiler that ships with Windows. No interpolated
//  strings, no null-conditionals, nothing that needs a newer csc - the
//  point of this file is that it builds on the machine it runs on, with
//  no download and no internet, which is the same promise Kohaku makes.
// ===========================================================================

using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Globalization;
using System.IO;
using System.Text;
using System.Threading;
using System.Windows.Forms;

namespace StarpOS
{
    // =======================================================================
    //  PALETTE
    //  One preset is ten colours. The names are Kohaku's token names, kept
    //  as they are so a palette can be copied between the two projects
    //  without translating anything.
    // =======================================================================
    internal sealed class Palette
    {
        public readonly string Name;
        public readonly Color BgDeep, BgPanel, BgSub, AccentCyan, AccentAmber;
        public readonly Color TextMain, TextDim, AccentMagenta, AccentGreen, LineBlue;

        public Palette(string name, int deep, int panel, int sub, int cyan, int amber,
                       int main, int dim, int magenta, int green, int line)
        {
            Name = name;
            BgDeep = Rgb(deep); BgPanel = Rgb(panel); BgSub = Rgb(sub);
            AccentCyan = Rgb(cyan); AccentAmber = Rgb(amber);
            TextMain = Rgb(main); TextDim = Rgb(dim);
            AccentMagenta = Rgb(magenta); AccentGreen = Rgb(green); LineBlue = Rgb(line);
        }

        // Deliberately outside the palette: every preset can restyle the
        // whole app, but none of them may make a fault look healthy.
        public Color Alarm
        {
            get { return Color.FromArgb(255, 255, 82, 82); }
        }

        private static Color Rgb(int v)
        {
            return Color.FromArgb(unchecked((int)(0xFF000000 | (uint)v)));
        }
    }

    internal static class Theme
    {
        // Straight out of the Godot theme file. Order is the order they are
        // offered in; "deep code" is the one that comes up first because it
        // is the one the assistant is usually wearing.
        public static readonly Palette[] All = new Palette[]
        {
            new Palette("deep code",   0x010503, 0x030B06, 0x051209, 0x4CFF73, 0xD9FF59, 0xD9FFE0, 0x73B885, 0x99FFD9, 0x59FF80, 0x47CC6B),
            // PLACEHOLDER VALUES, and the only ones here that are.
            // ATTACK belongs to Kohaku and its real palette is in her repo,
            // which is not on this machine. What is documented about it is
            // the part that matters and is kept: green is pushed towards
            // yellow, because a normal green stops reading as "done" once
            // the room around it is red. Drop the true values in here and
            // nothing else needs touching.
            new Palette("attack",      0x140404, 0x210707, 0x2E0A0A, 0xFF4242, 0xFFB84C, 0xFFECEC, 0xC08A8A, 0xFF73B2, 0xD9F266, 0xBF4C4C),
            new Palette("diamond",     0x040B11, 0x08141C, 0x0D1F29, 0x59F2F2, 0xFFD159, 0xE6FCFF, 0x85B8C7, 0xBF8CFF, 0x66FFB2, 0x59BFE6),
            new Palette("creeper",     0x090E09, 0x0F1A0F, 0x172617, 0x5CE661, 0xF2C740, 0xF0FFEB, 0x94B88F, 0xE673FF, 0x73FF80, 0x66B26B),
            new Palette("nether",      0x130505, 0x210A08, 0x2E0F0B, 0xFF7A29, 0xFFCC40, 0xFFEBD9, 0xC78C73, 0xFF598C, 0xD9F266, 0xD96138),
            new Palette("redstone",    0x0B0A0B, 0x161314, 0x211D1F, 0xFF4242, 0xFFB84C, 0xF5EDED, 0x9E9494, 0xFF73B2, 0x80F280, 0xBF4C4C),
            new Palette("web slinger", 0x05060E, 0x0B0E1A, 0x121626, 0xFF3847, 0xFFBF40, 0xF2F5FF, 0x8C9ED1, 0xFF668C, 0x73F299, 0x4773FF),
            new Palette("arc reactor", 0x05080A, 0x0A0F13, 0x0F171C, 0x73EBFF, 0xFFB833, 0xEBF7FF, 0x8CADBF, 0xFF7359, 0x66F2A6, 0xD99E38),
            new Palette("phonk",       0x08030B, 0x0E0616, 0x160921, 0xC759FF, 0xFFB24C, 0xF7EBFF, 0x9E80BF, 0xFF40B8, 0x73FFB8, 0x944CEB),
            new Palette("neon dojo",   0x070408, 0x0E0810, 0x160C18, 0xFF4C9E, 0xFFD14C, 0xFFF0FA, 0xB28CA8, 0x66F2FF, 0x8CFF99, 0x59D9F2),
            new Palette("savanna",     0x0E0B06, 0x1A140B, 0x251D11, 0xFFAD38, 0xFFD96B, 0xFFF5E0, 0xBFA680, 0xFF8561, 0x9EE059, 0xB88C47),
            new Palette("ice biome",   0x080C12, 0x0F1720, 0x17222E, 0x8CE6FF, 0xFFD98C, 0xF2FCFF, 0x9EBFD9, 0xB2B2FF, 0x8CFFD9, 0x80C7F2),
            new Palette("galaxy",      0x05030A, 0x0A0714, 0x0F0B1D, 0x9999FF, 0xFFCC73, 0xF2F0FF, 0x9994CC, 0xFF80E6, 0x80FFCC, 0x807AEB)
        };

        public static Palette Current = All[0];

        public static bool Set(string name)
        {
            if (name == null) return false;
            string want = name.Trim().ToLowerInvariant();
            for (int i = 0; i < All.Length; i++)
            {
                if (All[i].Name == want) { Current = All[i]; return true; }
            }
            return false;
        }
    }

    // =======================================================================
    //  BOX STYLE - the second look axis. A preset may not change this and
    //  this may not change a colour.
    // =======================================================================
    internal enum BoxStyle { Reticle, Sharp, Round, Hairline, Blade }

    // =======================================================================
    //  VIEW MODES - the same nodes, arranged four ways.
    //    Board    grouped by category, the Kohaku arrangement
    //    Tiled    every node the same size, packed, no grouping
    //    Page     one line each, like an index you read down
    //    Desktop  wherever you dragged it, and it stays there
    // =======================================================================
    internal enum ViewMode { Board, Tiled, Page, Desktop }

    // =======================================================================
    //  PLACES - the call sign table, read from the same places.cfg the
    //  batch version reads. The category comes off the "# --- name ---"
    //  headers in that file, so the grouping on the board is edited in the
    //  same place as the codes.
    // =======================================================================
    internal sealed class Place
    {
        public string Code = "";
        public string Kind = "node";
        public bool Numbered;
        public string[] Words = new string[0];
        public string About = "";
        public string Category = "OTHER";

        public string Say
        {
            get { return Words.Length > 0 ? Words[0] : Code; }
        }
    }

    internal static class Places
    {
        public static readonly List<Place> All = new List<Place>();

        public static void Load(string path)
        {
            All.Clear();
            if (!File.Exists(path)) return;
            string category = "OTHER";
            string[] lines = File.ReadAllLines(path);
            for (int i = 0; i < lines.Length; i++)
            {
                string line = lines[i].Trim();
                if (line.Length == 0) continue;
                if (line[0] == '#')
                {
                    // "# --- the machine ----" is a category heading. Anything
                    // else beginning with # is prose and is skipped.
                    string h = line.TrimStart('#', ' ', '-').TrimEnd(' ', '-');
                    if (h.Length > 0 && h.Length < 28 && line.Contains("---"))
                        category = h.ToUpperInvariant();
                    continue;
                }
                string[] c = line.Split('|');
                if (c.Length < 5) continue;
                Place p = new Place();
                p.Code = c[0].Trim().ToUpperInvariant();
                p.Kind = c[1].Trim().ToLowerInvariant();
                p.Numbered = c[2].Trim() == "1";
                p.Words = c[3].Split(',');
                for (int w = 0; w < p.Words.Length; w++) p.Words[w] = p.Words[w].Trim();
                p.About = c[4].Trim();
                p.Category = category;
                All.Add(p);
            }
        }

        public static Place ByCode(string code)
        {
            if (code == null) return null;
            string want = code.Trim().ToUpperInvariant();
            for (int i = 0; i < All.Count; i++)
                if (All[i].Code == want) return All[i];
            return null;
        }

        // Kohaku matches a words entry as a SUBSTRING, not on word
        // boundaries. That rule came across with the table and the table was
        // written to survive it - see the header of places.cfg.
        public static Place ByWords(string sentence)
        {
            string s = " " + sentence.ToLowerInvariant() + " ";
            Place best = null;
            int bestLen = 0;
            for (int i = 0; i < All.Count; i++)
            {
                Place p = All[i];
                for (int w = 0; w < p.Words.Length; w++)
                {
                    string word = p.Words[w];
                    if (word.Length < 2) continue;
                    if (s.IndexOf(word, StringComparison.Ordinal) >= 0 && word.Length > bestLen)
                    {
                        best = p;
                        bestLen = word.Length;
                    }
                }
            }
            return best;
        }
    }

    // =======================================================================
    //  STORE - one list node, one file, the format ai.bat writes:
    //      state|added|text        state is OPEN or DONE
    // =======================================================================
    internal sealed class Item
    {
        public bool Done;
        public string Added = "";
        public string Text = "";
    }

    internal static class Store
    {
        public static string Path(string code)
        {
            return System.IO.Path.Combine(Paths.Data, "kh_" + code.ToUpperInvariant() + ".txt");
        }

        public static List<Item> Load(string code)
        {
            List<Item> list = new List<Item>();
            string p = Path(code);
            if (!File.Exists(p)) return list;
            string[] lines = File.ReadAllLines(p);
            for (int i = 0; i < lines.Length; i++)
            {
                string line = lines[i];
                if (line.Length == 0 || line[0] == '#') continue;
                string[] c = line.Split('|');
                if (c.Length < 3) continue;
                Item it = new Item();
                it.Done = c[0].Trim().ToUpperInvariant() == "DONE";
                it.Added = c[1];
                it.Text = c[2];
                list.Add(it);
            }
            return list;
        }

        public static void Save(string code, List<Item> list)
        {
            StringBuilder sb = new StringBuilder();
            sb.AppendLine("# starpOS " + code.ToUpperInvariant() +
                          " store. One item per line: state|added|text");
            sb.AppendLine("# state is OPEN or DONE. Written by ai.bat and ai.exe.");
            for (int i = 0; i < list.Count; i++)
            {
                sb.AppendLine((list[i].Done ? "DONE|" : "OPEN|") +
                              list[i].Added + "|" + list[i].Text);
            }
            Paths.EnsureData();
            File.WriteAllText(Path(code), sb.ToString());
        }

        public static void Add(string code, string text)
        {
            List<Item> list = Load(code);
            Item it = new Item();
            it.Done = false;
            it.Added = DateTime.Now.ToString("ddd MM/dd/yyyy", CultureInfo.InvariantCulture);
            it.Text = text.Replace("|", "");
            list.Add(it);
            Save(code, list);
        }

        public static int OpenCount(string code)
        {
            List<Item> list = Load(code);
            int n = 0;
            for (int i = 0; i < list.Count; i++) if (!list[i].Done) n++;
            return n;
        }
    }

    // =======================================================================
    //  PATHS, MEMORY, STREAMS, BRAIN
    //  All of it pointed at the same files ai.bat uses.
    // =======================================================================
    internal static class Paths
    {
        public static string Sys = "";
        public static string Data = "";

        public static void Init()
        {
            Sys = AppDomain.CurrentDomain.BaseDirectory;
            Data = System.IO.Path.GetFullPath(System.IO.Path.Combine(Sys, "..\\data"));
            EnsureData();
        }

        public static void EnsureData()
        {
            try { if (!Directory.Exists(Data)) Directory.CreateDirectory(Data); }
            catch { }
        }

        public static string Places { get { return System.IO.Path.Combine(Sys, "places.cfg"); } }
        public static string Config { get { return System.IO.Path.Combine(Sys, "starpos.cfg"); } }
        public static string Memory { get { return System.IO.Path.Combine(Data, "ai_memory.db"); } }
        public static string Brain { get { return System.IO.Path.Combine(Data, "ai_brain.db"); } }
        public static string Unknown { get { return System.IO.Path.Combine(Data, "ai_unknown.txt"); } }
        public static string History { get { return System.IO.Path.Combine(Data, "ai_history.log"); } }
    }

    internal static class Mem
    {
        public static string Get(string key)
        {
            if (!File.Exists(Paths.Memory)) return null;
            string[] lines = File.ReadAllLines(Paths.Memory);
            for (int i = 0; i < lines.Length; i++)
            {
                string line = lines[i];
                if (line.Length == 0 || line[0] == '#') continue;
                int bar = line.IndexOf('|');
                if (bar <= 0) continue;
                if (string.Equals(line.Substring(0, bar), key, StringComparison.OrdinalIgnoreCase))
                    return line.Substring(bar + 1);
            }
            return null;
        }

        public static void Set(string key, string value)
        {
            List<string> keep = new List<string>();
            if (File.Exists(Paths.Memory))
            {
                string[] lines = File.ReadAllLines(Paths.Memory);
                for (int i = 0; i < lines.Length; i++)
                {
                    string line = lines[i];
                    int bar = line.IndexOf('|');
                    if (line.Length > 0 && line[0] != '#' && bar > 0 &&
                        string.Equals(line.Substring(0, bar), key, StringComparison.OrdinalIgnoreCase))
                        continue;
                    keep.Add(line);
                }
            }
            else
            {
                keep.Add("# starpOS AI memory. One key pair per line, pipe separated.");
                keep.Add("# Written by ai.bat and ai.exe. Safe to edit by hand or delete.");
            }
            keep.Add(key + "|" + value);
            Paths.EnsureData();
            File.WriteAllLines(Paths.Memory, keep.ToArray());
        }
    }

    internal static class Streams
    {
        // The four append only streams, the same shape JASPER reports to
        // Kohaku with. Nothing leaves the machine.
        public static void Write(string kind, string value)
        {
            try
            {
                Paths.EnsureData();
                string p = System.IO.Path.Combine(Paths.Data, "kh_" + kind + ".jsonl");
                string line = "{\"t\":\"" + DateTime.Now.ToString("ddd MM/dd/yyyy HH:mm:ss",
                    CultureInfo.InvariantCulture) + "\",\"k\":\"" + kind + "\",\"v\":\"" +
                    value.Replace("\"", "'") + "\"}";
                File.AppendAllText(p, line + Environment.NewLine);
            }
            catch { }
        }
    }

    internal sealed class Lesson
    {
        public string Pattern = "";
        public string Answer = "";
        public int Hits;
    }

    internal static class Brain
    {
        public static List<Lesson> Load()
        {
            List<Lesson> list = new List<Lesson>();
            if (!File.Exists(Paths.Brain)) return list;
            string[] lines = File.ReadAllLines(Paths.Brain);
            for (int i = 0; i < lines.Length; i++)
            {
                string line = lines[i];
                if (line.Length == 0 || line[0] == '#') continue;
                string[] c = line.Split('|');
                if (c.Length < 2) continue;
                Lesson l = new Lesson();
                l.Pattern = c[0];
                l.Answer = c[1];
                if (c.Length > 2) int.TryParse(c[2], out l.Hits);
                list.Add(l);
            }
            return list;
        }

        public static void Save(List<Lesson> list)
        {
            StringBuilder sb = new StringBuilder();
            sb.AppendLine("# starpOS AI learned answers.   pattern|answer|times used");
            sb.AppendLine("# Taught with the teach command, in ai.bat or ai.exe.");
            sb.AppendLine("# Remove a lesson with:  unteach PATTERN");
            for (int i = 0; i < list.Count; i++)
                sb.AppendLine(list[i].Pattern + "|" + list[i].Answer + "|" + list[i].Hits);
            Paths.EnsureData();
            File.WriteAllText(Paths.Brain, sb.ToString());
        }

        public static void Teach(string pattern, string answer)
        {
            List<Lesson> list = Load();
            string p = pattern.Replace("|", "").Trim();
            for (int i = list.Count - 1; i >= 0; i--)
                if (string.Equals(list[i].Pattern, p, StringComparison.OrdinalIgnoreCase))
                    list.RemoveAt(i);
            Lesson l = new Lesson();
            l.Pattern = p;
            l.Answer = answer.Replace("|", "").Trim();
            l.Hits = 0;
            list.Add(l);
            Save(list);
        }

        public static string Match(string sentence)
        {
            List<Lesson> list = Load();
            string s = " " + sentence.ToLowerInvariant() + " ";
            for (int i = 0; i < list.Count; i++)
            {
                if (list[i].Pattern.Length < 2) continue;
                if (s.IndexOf(list[i].Pattern.ToLowerInvariant(), StringComparison.Ordinal) >= 0)
                {
                    list[i].Hits++;
                    Save(list);
                    return list[i].Answer;
                }
            }
            return null;
        }
    }
}

namespace StarpOS
{
    // =======================================================================
    //  THE BOARD WINDOW
    //  Kohaku's home screen is a wall of nodes and the nodes are the
    //  navigation. Nothing here replaces the board with a page: a node
    //  draws on top of it and Escape puts it away again.
    // =======================================================================
    internal sealed class BoardForm : Form
    {
        private const int BarH = 46;
        private const int CmdH = 52;
        private const int Pad = 22;

        private sealed class Tile
        {
            public Rectangle R;
            public Place P;
            public int Count;
        }

        private readonly List<Tile> _tiles = new List<Tile>();
        private readonly List<Rectangle> _checkBoxes = new List<Rectangle>();
        private readonly List<int> _checkIndex = new List<int>();
        private readonly List<Rectangle> _swatches = new List<Rectangle>();
        private Rectangle _closeBtn, _minBtn, _backBtn;

        private TextBox _input;
        private string _reply = "";
        private bool _replyIsAlert;
        private string _openCode;
        private int _openN;
        private int _scroll;
        private int _scrollNeeded;
        private ViewMode _view = ViewMode.Board;
        private readonly Dictionary<string, Point> _desktopPos = new Dictionary<string, Point>();
        private string _dragCode;
        private Point _dragGrab;
        private string _maybeDragCode;
        private Point _mouseDownAt;
        private bool _dragStarted;
        private Rectangle _scrollTrack, _scrollThumb;
        private bool _draggingThumb;
        private int _thumbGrab;
        private readonly List<Rectangle> _ruleBoxes = new List<Rectangle>();
        private readonly List<int> _ruleIndex = new List<int>();
        private bool _asking;
        private bool _autoAsk = true;
        private string _mindAnswer;
        private string _pendingQuestion;
        private DateTime _askedAt;
        private BoxStyle _box = BoxStyle.Reticle;
        private bool _voiceOn = true;
        private string _voiceNote = "";
        private string _userName;
        private string _osName = "starpOS";
        private string _osVer = "";
        private bool _dragging;
        private Point _dragFrom;
        private int _hover = -1;

        private Font _fBody, _fBold, _fSmall, _fHead, _fMark;
        private System.Speech.Synthesis.SpeechSynthesizer _voice;

        private readonly string _startCommand;

        public BoardForm() : this(null) { }

        public BoardForm(string startCommand)
        {
            _startCommand = startCommand;
            Paths.Init();
            Places.Load(Paths.Places);
            LoadConfig();
            LoadRememberedLook();

            Text = "starpOS AI";
            FormBorderStyle = FormBorderStyle.None;
            Rectangle wa = Screen.PrimaryScreen.WorkingArea;
            int cw = Math.Min(1140, wa.Width - 40);
            int ch = Math.Min(780, wa.Height - 40);
            StartPosition = FormStartPosition.Manual;
            ClientSize = new Size(cw, ch);
            Location = new Point(wa.X + (wa.Width - cw) / 2,
                                 wa.Y + (wa.Height - ch) / 2);
            MinimumSize = new Size(820, 520);
            KeyPreview = true;
            DoubleBuffered = true;
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint |
                     ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);

            _fBody = new Font("Consolas", 10.5f);
            _fBold = new Font("Consolas", 10.5f, FontStyle.Bold);
            _fSmall = new Font("Consolas", 8.75f);
            _fHead = new Font("Consolas", 13f, FontStyle.Bold);
            _fMark = new Font("Consolas", 15f, FontStyle.Bold);

            _input = new TextBox();
            _input.BorderStyle = BorderStyle.None;
            _input.Font = new Font("Consolas", 12f);
            _input.BackColor = Theme.Current.BgSub;
            _input.ForeColor = Theme.Current.TextMain;
            _input.KeyDown += InputKeyDown;
            Controls.Add(_input);

            try
            {
                _voice = new System.Speech.Synthesis.SpeechSynthesizer();
            }
            catch
            {
                _voice = null;
                _voiceOn = false;
                _voiceNote = "STARP-0501";
            }

            System.Windows.Forms.Timer clock = new System.Windows.Forms.Timer();
            clock.Interval = 1000;
            clock.Tick += delegate { Invalidate(new Rectangle(0, 0, ClientSize.Width, BarH)); };
            clock.Start();

            LayoutInput();
            Resize += delegate { LayoutInput(); Invalidate(); };

            Minds.Load(System.IO.Path.Combine(Paths.Sys, "minds.cfg"));
            Rules.Load(System.IO.Path.Combine(Paths.Sys, "rules.cfg"));
            LoadDesktop();
            string savedView = Mem.Get("view");
            if (!string.IsNullOrEmpty(savedView))
            {
                if (savedView == "tiled") _view = ViewMode.Tiled;
                else if (savedView == "page") _view = ViewMode.Page;
                else if (savedView == "desktop") _view = ViewMode.Desktop;
            }
            string savedAuto = Mem.Get("autoask");
            if (savedAuto == "0") _autoAsk = false;

            Application.AddMessageFilter(new WheelFilter(this));
            StartBackgroundProbe();

            _userName = Mem.Get("name");
            if (string.IsNullOrEmpty(_userName))
                Say("STARP online. This is the board. Two letters opens anything on it.", false);
            else
                Say("Welcome back, " + _userName + ". The board is up and I am listening.", false);
            Streams.Write("use", "ai.exe opened");
        }

        protected override void OnShown(EventArgs e)
        {
            base.OnShown(e);
            _input.Focus();
            if (!string.IsNullOrEmpty(_startCommand)) Execute(_startCommand);
        }

        // -------------------------------------------------------------------
        //  SETTINGS THAT SURVIVE A RESTART - the same keys ai.bat writes
        // -------------------------------------------------------------------
        private void LoadConfig()
        {
            if (!File.Exists(Paths.Config)) return;
            string[] lines = File.ReadAllLines(Paths.Config);
            for (int i = 0; i < lines.Length; i++)
            {
                string line = lines[i].Trim();
                if (line.Length == 0 || line[0] == '#') continue;
                int eq = line.IndexOf('=');
                if (eq <= 0) continue;
                string k = line.Substring(0, eq).Trim();
                string v = line.Substring(eq + 1).Trim();
                if (k == "OS_NAME") _osName = v;
                else if (k == "OS_VERSION") _osVer = v;
            }
        }

        private void LoadRememberedLook()
        {
            string t = Mem.Get("themename");
            if (!string.IsNullOrEmpty(t)) Theme.Set(t);
            string b = Mem.Get("box");
            if (!string.IsNullOrEmpty(b)) SetBox(b);
        }

        private bool SetBox(string name)
        {
            switch (name.Trim().ToLowerInvariant())
            {
                case "reticle": _box = BoxStyle.Reticle; return true;
                case "sharp": _box = BoxStyle.Sharp; return true;
                case "round": _box = BoxStyle.Round; return true;
                case "hairline": _box = BoxStyle.Hairline; return true;
                case "blade": _box = BoxStyle.Blade; return true;
            }
            return false;
        }

        private void LayoutInput()
        {
            _input.BackColor = Theme.Current.BgSub;
            _input.ForeColor = Theme.Current.TextMain;
            _input.SetBounds(Pad + 26, ClientSize.Height - CmdH + 15,
                             ClientSize.Width - Pad * 2 - 34, 22);
        }

        // ===================================================================
        //  PAINT
        // ===================================================================
        private string _paintError;

        protected override void OnPaint(PaintEventArgs e)
        {
            try { PaintAll(e); }
            catch (Exception ex)
            {
                _paintError = ex.GetType().Name + ": " + ex.Message;
                try
                {
                    e.Graphics.Clear(Theme.Current.BgDeep);
                    using (SolidBrush b = new SolidBrush(Theme.Current.Alarm))
                        e.Graphics.DrawString("This screen could not be drawn.",
                            _fBold, b, 24, 24);
                    using (SolidBrush b = new SolidBrush(Theme.Current.TextMain))
                        e.Graphics.DrawString(_paintError, _fBody, b, 24, 50);
                    using (SolidBrush b = new SolidBrush(Theme.Current.TextDim))
                        e.Graphics.DrawString("Press esc to go back to the board.",
                            _fBody, b, 24, 76);
                }
                catch { }
            }
        }

        private void PaintAll(PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.TextRenderingHint = System.Drawing.Text.TextRenderingHint.ClearTypeGridFit;
            Palette c = Theme.Current;

            g.Clear(c.BgDeep);
            DrawBar(g, c);

            Rectangle body = new Rectangle(0, BarH, ClientSize.Width,
                                           ClientSize.Height - BarH - CmdH - 24);
            _tiles.Clear();
            _checkBoxes.Clear();
            _checkIndex.Clear();
            _ruleBoxes.Clear();
            _ruleIndex.Clear();
            _swatches.Clear();
            _backBtn = Rectangle.Empty;

            g.SetClip(body);
            if (_openCode == null)
            {
                switch (_view)
                {
                    case ViewMode.Tiled: DrawTiled(g, c, body); break;
                    case ViewMode.Page: DrawPage(g, c, body); break;
                    case ViewMode.Desktop: DrawDesktop(g, c, body); break;
                    default: DrawBoard(g, c, body); break;
                }
            }
            else DrawNode(g, c, body);
            g.ResetClip();

            DrawScrollBar(g, c, body);
            DrawCommandBar(g, c);
        }

        private void DrawBar(Graphics g, Palette c)
        {
            Rectangle r = new Rectangle(0, 0, ClientSize.Width, BarH);
            using (SolidBrush b = new SolidBrush(c.BgPanel)) g.FillRectangle(b, r);
            using (Pen p = new Pen(c.LineBlue)) g.DrawLine(p, 0, BarH - 1, ClientSize.Width, BarH - 1);

            // the orb. Green while everything answers, amber when the voice is out.
            Color orb = _voiceOn ? c.AccentGreen : c.AccentAmber;
            using (SolidBrush b = new SolidBrush(orb))
                g.FillEllipse(b, Pad, BarH / 2 - 5, 10, 10);
            using (SolidBrush b = new SolidBrush(Color.FromArgb(60, orb)))
                g.FillEllipse(b, Pad - 4, BarH / 2 - 9, 18, 18);

            using (SolidBrush b = new SolidBrush(c.TextMain))
                g.DrawString("STARP", _fMark, b, Pad + 22, 10);

            string chips = "voice " + (_voiceOn ? "on" : "off") +
                           "     theme " + Theme.Current.Name +
                           "     box " + _box.ToString().ToLowerInvariant() +
                           "     view " + _view.ToString().ToLowerInvariant() +
                           "     " + DateTime.Now.ToString("HH:mm") +
                           "     " + _osName + " " + _osVer;
            using (SolidBrush b = new SolidBrush(c.TextDim))
                g.DrawString(chips, _fSmall, b, Pad + 120, 16);

            // a second orb for the models, so their state is never a surprise
            Mind dm = Minds.Default();
            if (dm != null)
            {
                Color md = dm.Online ? c.AccentCyan : c.AccentMagenta;
                using (SolidBrush b = new SolidBrush(md))
                    g.FillEllipse(b, ClientSize.Width - 250, BarH / 2 - 4, 8, 8);
                string mindChip;
                if (_asking)
                {
                    int secs = (int)(DateTime.Now - _askedAt).TotalSeconds;
                    mindChip = "thinking " + secs.ToString(CultureInfo.InvariantCulture) + "s";
                }
                else mindChip = dm.Online ? dm.Name : "no mind";
                using (SolidBrush b = new SolidBrush(c.TextDim))
                    g.DrawString(mindChip, _fSmall, b, ClientSize.Width - 236, 16);
            }

            _closeBtn = new Rectangle(ClientSize.Width - 38, 12, 22, 22);
            _minBtn = new Rectangle(ClientSize.Width - 68, 12, 22, 22);
            using (SolidBrush b = new SolidBrush(c.TextDim))
            {
                g.DrawString("x", _fBold, b, _closeBtn.X + 6, _closeBtn.Y + 2);
                g.DrawString("-", _fBold, b, _minBtn.X + 7, _minBtn.Y + 2);
            }
        }

        // -------------------------------------------------------------------
        //  THE BOX AXIS. Same panel, five machines. A theme cannot touch it
        //  and it cannot touch a theme.
        // -------------------------------------------------------------------
        // Everything that scrolls is drawn inside one of these. Reset with
        // Unclip when the pinned furniture goes back on top.
        private void ClipBody(Graphics g, Rectangle r, int top, int bottomInset)
        {
            int h = r.Bottom - bottomInset - top;
            if (h < 10) h = 10;
            g.SetClip(new Rectangle(r.X + 1, top, r.Width - 2, h));
        }

        private void Unclip(Graphics g)
        {
            g.ResetClip();
        }

        private void DrawBox(Graphics g, Rectangle r, Color fill, Color line, bool accent)
        {
            using (SolidBrush b = new SolidBrush(fill))
            {
                if (_box == BoxStyle.Round)
                {
                    using (GraphicsPath path = RoundRect(r, 10)) g.FillPath(b, path);
                }
                else g.FillRectangle(b, r);
            }

            using (Pen p = new Pen(line))
            {
                switch (_box)
                {
                    case BoxStyle.Round:
                        using (GraphicsPath path = RoundRect(r, 10)) g.DrawPath(p, path);
                        break;
                    case BoxStyle.Sharp:
                        g.DrawRectangle(p, r);
                        break;
                    case BoxStyle.Hairline:
                        p.DashStyle = DashStyle.Dot;
                        g.DrawRectangle(p, r);
                        break;
                    case BoxStyle.Blade:
                        using (SolidBrush ab = new SolidBrush(line))
                            g.FillRectangle(ab, r.X, r.Y, 3, r.Height);
                        break;
                    case BoxStyle.Reticle:
                        int t = 9;
                        g.DrawLine(p, r.X, r.Y, r.X + t, r.Y);
                        g.DrawLine(p, r.X, r.Y, r.X, r.Y + t);
                        g.DrawLine(p, r.Right, r.Y, r.Right - t, r.Y);
                        g.DrawLine(p, r.Right, r.Y, r.Right, r.Y + t);
                        g.DrawLine(p, r.X, r.Bottom, r.X + t, r.Bottom);
                        g.DrawLine(p, r.X, r.Bottom, r.X, r.Bottom - t);
                        g.DrawLine(p, r.Right, r.Bottom, r.Right - t, r.Bottom);
                        g.DrawLine(p, r.Right, r.Bottom, r.Right, r.Bottom - t);
                        break;
                }
            }
        }

        private static GraphicsPath RoundRect(Rectangle r, int rad)
        {
            GraphicsPath p = new GraphicsPath();
            p.AddArc(r.X, r.Y, rad * 2, rad * 2, 180, 90);
            p.AddArc(r.Right - rad * 2, r.Y, rad * 2, rad * 2, 270, 90);
            p.AddArc(r.Right - rad * 2, r.Bottom - rad * 2, rad * 2, rad * 2, 0, 90);
            p.AddArc(r.X, r.Bottom - rad * 2, rad * 2, rad * 2, 90, 90);
            p.CloseFigure();
            return p;
        }

        // ===================================================================
        //  THE BOARD
        // ===================================================================
        private void DrawBoard(Graphics g, Palette c, Rectangle body)
        {
            int x = Pad, y = body.Y + 18 - _scroll;
            string category = null;
            int col = 0;
            int tileW = (ClientSize.Width - Pad * 2 - 24) / 4;
            int tileH = 48;

            for (int i = 0; i < Places.All.Count; i++)
            {
                Place p = Places.All[i];
                if (p.Category != category)
                {
                    category = p.Category;
                    if (col != 0) { y += tileH + 8; col = 0; }
                    y += 10;
                    using (SolidBrush b = new SolidBrush(c.AccentCyan))
                        g.DrawString(category, _fSmall, b, x, y);
                    y += 18;
                }

                Rectangle r = new Rectangle(x + col * (tileW + 8), y, tileW, tileH);
                Tile t = new Tile();
                t.R = r;
                t.P = p;
                t.Count = (p.Kind == "node" || p.Kind == "learn") ? Store.OpenCount(p.Code) : -1;
                _tiles.Add(t);

                bool hot = _hover == _tiles.Count - 1;
                DrawBox(g, r, hot ? c.BgSub : c.BgPanel, hot ? c.AccentCyan : c.LineBlue, false);

                using (SolidBrush b = new SolidBrush(c.AccentAmber))
                    g.DrawString(p.Code, _fBold, b, r.X + 12, r.Y + 8);
                using (SolidBrush b = new SolidBrush(c.TextMain))
                    g.DrawString(Clip(p.Say, 18), _fBody, b, r.X + 46, r.Y + 8);
                using (SolidBrush b = new SolidBrush(c.TextDim))
                    g.DrawString(Clip(p.About, (tileW - 30) / 6), _fSmall, b, r.X + 12, r.Y + 30);

                if (t.Count > 0)
                {
                    string badge = t.Count.ToString(CultureInfo.InvariantCulture);
                    using (SolidBrush b = new SolidBrush(c.AccentGreen))
                        g.DrawString(badge, _fBold, b, r.Right - 24, r.Y + 8);
                }

                col++;
                if (col == 4) { col = 0; y += tileH + 8; }
            }
            SetScrollExtent(y + _scroll + tileH + 24, body.Bottom);

            if (Places.All.Count == 0)
            {
                using (SolidBrush b = new SolidBrush(c.AccentAmber))
                    g.DrawString("places.cfg is missing from the system folder.  STARP-0402",
                                 _fBody, b, Pad, body.Y + 40);
            }
        }

        // ===================================================================
        //  A NODE
        // ===================================================================
        private void DrawNode(Graphics g, Palette c, Rectangle body)
        {
            if (_openCode == "#INFO")
            {
                Rectangle ir = new Rectangle(Pad, body.Y + 14,
                                             ClientSize.Width - Pad * 2, body.Height - 28);
                DrawBox(g, ir, c.BgPanel, c.LineBlue, true);
                using (SolidBrush b = new SolidBrush(c.AccentCyan))
                    g.DrawString(_infoTitle, _fHead, b, ir.X + 20, ir.Y + 16);
                _backBtn = new Rectangle(ir.Right - 90, ir.Y + 16, 70, 24);
                using (SolidBrush b = new SolidBrush(c.TextDim))
                    g.DrawString("[ esc ]", _fSmall, b, _backBtn.X + 6, _backBtn.Y + 5);
                DrawInfo(g, c, ir, ir.Y + 62);
                return;
            }

            Place p = Places.ByCode(_openCode);
            if (p == null) { _openCode = null; return; }

            Rectangle r = new Rectangle(Pad, body.Y + 14,
                                        ClientSize.Width - Pad * 2, body.Height - 28);
            DrawBox(g, r, c.BgPanel, c.LineBlue, true);

            using (SolidBrush b = new SolidBrush(c.AccentCyan))
                g.DrawString(p.Say.ToUpperInvariant(), _fHead, b, r.X + 20, r.Y + 16);
            using (SolidBrush b = new SolidBrush(c.AccentAmber))
                g.DrawString(p.Code, _fBold, b, r.X + 20, r.Y + 44);
            using (SolidBrush b = new SolidBrush(c.TextDim))
                g.DrawString(p.About, _fBody, b, r.X + 56, r.Y + 44);

            _backBtn = new Rectangle(r.Right - 90, r.Y + 16, 70, 24);
            using (SolidBrush b = new SolidBrush(c.TextDim))
                g.DrawString("[ esc ]", _fSmall, b, _backBtn.X + 6, _backBtn.Y + 5);

            int y = r.Y + 84;
            switch (p.Code)
            {
                case "SE": DrawSettings(g, c, r, y); return;
                case "MX": DrawMeters(g, c, r, y); return;
                case "NV": DrawNerves(g, c, r, y); return;
                case "DV": DrawDevice(g, c, r, y); return;
                case "KH": DrawStatus(g, c, r, y); return;
                case "LF": DrawLife(g, c, r, y); return;
                case "DR": DrawDrives(g, c, r, y); return;
                case "MD": DrawDoctor(g, c, r, y); return;
                case "LM": DrawMinds(g, c, r, y); return;
                case "AU": DrawRules(g, c, r, y); return;
                case "TH": DrawTeachGuide(g, c, r, y); return;
            }
            DrawList(g, c, p, r, y);
        }

        private void DrawList(Graphics g, Palette c, Place p, Rectangle r, int y)
        {
            List<Item> items = Store.Load(p.Code);
            if (items.Count == 0)
            {
                using (SolidBrush b = new SolidBrush(c.TextDim))
                    g.DrawString("Nothing on this list yet. Type:   " + p.Code +
                                 " add and then what goes on it", _fBody, b, r.X + 24, y);
            }

            ClipBody(g, r, y - 6, 46);
            for (int i = 0; i < items.Count; i++)
            {
                int ly = y + i * 26 - _scroll;
                if (ly < r.Y + 78 || ly > r.Bottom - 60) continue;
                Rectangle box = new Rectangle(r.X + 24, ly + 2, 14, 14);
                _checkBoxes.Add(box);
                _checkIndex.Add(i);
                using (Pen pen = new Pen(items[i].Done ? c.AccentGreen : c.TextDim))
                    g.DrawRectangle(pen, box);
                if (items[i].Done)
                {
                    using (Pen pen = new Pen(c.AccentGreen, 2f))
                    {
                        g.DrawLine(pen, box.X + 3, box.Y + 7, box.X + 6, box.Y + 10);
                        g.DrawLine(pen, box.X + 6, box.Y + 10, box.X + 11, box.Y + 3);
                    }
                }
                using (SolidBrush b = new SolidBrush(items[i].Done ? c.TextDim : c.TextMain))
                    g.DrawString((i + 1).ToString(CultureInfo.InvariantCulture) + ".  " + items[i].Text,
                                 _fBody, b, r.X + 48, ly);
            }

            Unclip(g);
            SetScrollExtent(y + items.Count * 26 + 24, r.Bottom - 46);
            using (SolidBrush b = new SolidBrush(c.TextDim))
                g.DrawString(p.Code + " add TEXT      put something on it            " +
                             p.Code + " done N   tick it off            " +
                             p.Code + " drop N   remove it",
                             _fSmall, b, r.X + 24, r.Bottom - 34);
        }

        private void DrawSettings(Graphics g, Palette c, Rectangle r, int y)
        {
            using (SolidBrush b = new SolidBrush(c.TextDim))
                g.DrawString("Thirteen palettes and five border sets. Click a palette, " +
                             "or type:  theme attack", _fBody, b, r.X + 24, y);
            y += 34;

            int sw = 150, sh = 62, col = 0;
            for (int i = 0; i < Theme.All.Length; i++)
            {
                Palette p = Theme.All[i];
                Rectangle sr = new Rectangle(r.X + 24 + col * (sw + 10), y, sw, sh);
                _swatches.Add(sr);
                using (SolidBrush b = new SolidBrush(p.BgPanel)) g.FillRectangle(b, sr);
                using (Pen pen = new Pen(p == Theme.Current ? p.AccentCyan : c.LineBlue,
                                         p == Theme.Current ? 2f : 1f))
                    g.DrawRectangle(pen, sr);
                using (SolidBrush b = new SolidBrush(p.AccentCyan))
                    g.FillRectangle(b, sr.X + 10, sr.Y + 10, 26, 6);
                using (SolidBrush b = new SolidBrush(p.AccentAmber))
                    g.FillRectangle(b, sr.X + 42, sr.Y + 10, 18, 6);
                using (SolidBrush b = new SolidBrush(p.AccentGreen))
                    g.FillRectangle(b, sr.X + 66, sr.Y + 10, 18, 6);
                using (SolidBrush b = new SolidBrush(p.TextMain))
                    g.DrawString(p.Name, _fSmall, b, sr.X + 10, sr.Y + 28);
                using (SolidBrush b = new SolidBrush(p.TextDim))
                    g.DrawString("the quick brown", _fSmall, b, sr.X + 10, sr.Y + 44);

                col++;
                if (col == 5) { col = 0; y += sh + 10; }
            }

            y += sh + 26;
            using (SolidBrush b = new SolidBrush(c.AccentCyan))
                g.DrawString("BORDERS", _fSmall, b, r.X + 24, y);
            using (SolidBrush b = new SolidBrush(c.TextDim))
                g.DrawString("reticle    sharp    round    hairline    blade" +
                             "          type:  box blade", _fBody, b, r.X + 24, y + 18);
            using (SolidBrush b = new SolidBrush(c.TextDim))
                g.DrawString("VOICE      " + (_voiceOn ? "on" : "off " + _voiceNote) +
                             "        type:  voice off", _fBody, b, r.X + 24, y + 46);
        }

        private void DrawMeters(Graphics g, Palette c, Rectangle r, int y)
        {
            using (SolidBrush b = new SolidBrush(c.TextDim))
                g.DrawString("A rack of live readings. Nothing here is invented.",
                             _fBody, b, r.X + 24, y);
            y += 36;

            ulong total, avail;
            if (Native.MemoryStatus(out total, out avail) && total > 0)
            {
                int pc = (int)(100 - (avail * 100 / total));
                Meter(g, c, r.X + 24, y, "MEMORY", pc,
                      (avail / 1048576).ToString(CultureInfo.InvariantCulture) + " MB free of " +
                      (total / 1048576).ToString(CultureInfo.InvariantCulture) + " MB");
                y += 46;
            }

            try
            {
                DriveInfo d = new DriveInfo(System.IO.Path.GetPathRoot(Paths.Sys));
                if (d.IsReady)
                {
                    int pc = (int)(100 - (d.AvailableFreeSpace * 100 / d.TotalSize));
                    Meter(g, c, r.X + 24, y, "DISK", pc,
                          (d.AvailableFreeSpace / 1073741824).ToString(CultureInfo.InvariantCulture) +
                          " GB free on " + d.Name);
                    y += 46;
                }
            }
            catch { }

            int quests = Store.OpenCount("QS");
            Meter(g, c, r.X + 24, y, "QUESTS", Math.Min(100, quests * 10),
                  quests.ToString(CultureInfo.InvariantCulture) + " open");
            y += 46;

            int lessons = Brain.Load().Count;
            Meter(g, c, r.X + 24, y, "LESSONS", Math.Min(100, lessons * 5),
                  lessons.ToString(CultureInfo.InvariantCulture) + " taught");
            y += 46;

            int up = Environment.TickCount / 60000;
            using (SolidBrush b = new SolidBrush(c.TextDim))
                g.DrawString("Windows has been up " + up.ToString(CultureInfo.InvariantCulture) +
                             " minutes.", _fSmall, b, r.X + 24, y);
        }

        private void Meter(Graphics g, Palette c, int x, int y, string label, int pc, string note)
        {
            using (SolidBrush b = new SolidBrush(c.TextMain))
                g.DrawString(label, _fBold, b, x, y);
            Rectangle track = new Rectangle(x + 110, y + 3, 420, 12);
            using (SolidBrush b = new SolidBrush(c.BgSub)) g.FillRectangle(b, track);
            int w = (int)(track.Width * (pc / 100.0));
            Color fill = pc > 85 ? c.Alarm : (pc > 60 ? c.AccentAmber : c.AccentGreen);
            using (SolidBrush b = new SolidBrush(fill))
                g.FillRectangle(b, track.X, track.Y, w, track.Height);
            using (Pen p = new Pen(c.LineBlue)) g.DrawRectangle(p, track);
            using (SolidBrush b = new SolidBrush(c.TextMain))
                g.DrawString(pc.ToString(CultureInfo.InvariantCulture) + "%", _fBody, b,
                             track.Right + 12, y);
            using (SolidBrush b = new SolidBrush(c.TextDim))
                g.DrawString(note, _fSmall, b, track.Right + 62, y + 2);
        }

        private void DrawNerves(Graphics g, Palette c, Rectangle r, int y)
        {
            using (SolidBrush b = new SolidBrush(c.TextDim))
                g.DrawString("One faculty at a time, and whether it is working.",
                             _fBody, b, r.X + 24, y);
            y += 36;
            Nerve(g, c, r.X + 24, ref y, "SPEECH", Paths.Places != null && _voice != null,
                  "System.Speech, the voice");
            Nerve(g, c, r.X + 24, ref y, "PLACES", File.Exists(Paths.Places),
                  "places.cfg, the call signs");
            Nerve(g, c, r.X + 24, ref y, "MEMORY", File.Exists(Paths.Memory),
                  "ai_memory.db, what she is told");
            Nerve(g, c, r.X + 24, ref y, "LEARNING", File.Exists(Paths.Brain),
                  "ai_brain.db, what she was taught");
            Nerve(g, c, r.X + 24, ref y, "CONSOLE", File.Exists(System.IO.Path.Combine(Paths.Sys, "ai.bat")),
                  "ai.bat, the other face of her");
            Nerve(g, c, r.X + 24, ref y, "DATA", Directory.Exists(Paths.Data),
                  "the data folder, everything she keeps");
        }

        private void Nerve(Graphics g, Palette c, int x, ref int y, string name, bool ok, string note)
        {
            using (SolidBrush b = new SolidBrush(ok ? c.AccentGreen : c.Alarm))
                g.DrawString(ok ? "[ OK ]" : "[ DOWN ]", _fBold, b, x, y);
            using (SolidBrush b = new SolidBrush(c.TextMain))
                g.DrawString(name, _fBold, b, x + 90, y);
            using (SolidBrush b = new SolidBrush(c.TextDim))
                g.DrawString(note, _fBody, b, x + 210, y);
            y += 28;
        }

        private void DrawDevice(Graphics g, Palette c, Rectangle r, int y)
        {
            Row(g, c, r.X + 24, ref y, "Machine", Environment.MachineName);
            Row(g, c, r.X + 24, ref y, "Windows user", Environment.UserName);
            Row(g, c, r.X + 24, ref y, "Processors", Environment.ProcessorCount.ToString(CultureInfo.InvariantCulture));
            Row(g, c, r.X + 24, ref y, "OS", Environment.OSVersion.VersionString);
            Row(g, c, r.X + 24, ref y, "64 bit", Environment.Is64BitOperatingSystem ? "yes" : "no");
            Row(g, c, r.X + 24, ref y, "starpOS at", Paths.Sys);
            Row(g, c, r.X + 24, ref y, "Data at", Paths.Data);
        }

        private void DrawStatus(Graphics g, Palette c, Rectangle r, int y)
        {
            Row(g, c, r.X + 24, ref y, "Name", "STARP");
            Row(g, c, r.X + 24, ref y, "Shell", "ai.exe, the native build");
            Row(g, c, r.X + 24, ref y, "Other face", "ai.bat, same data, same lessons");
            Row(g, c, r.X + 24, ref y, "Call signs", Places.All.Count.ToString(CultureInfo.InvariantCulture) + " loaded");
            Row(g, c, r.X + 24, ref y, "Lessons", Brain.Load().Count.ToString(CultureInfo.InvariantCulture) + " taught");
            Row(g, c, r.X + 24, ref y, "Voice", _voiceOn ? "on" : "off " + _voiceNote);
            Row(g, c, r.X + 24, ref y, "Theme", Theme.Current.Name + " / " + _box.ToString().ToLowerInvariant());
            Row(g, c, r.X + 24, ref y, "Right now", DateTime.Now.ToString("ddd dd MMM yyyy  HH:mm", CultureInfo.InvariantCulture));
            y += 16;
            using (SolidBrush b = new SolidBrush(c.TextDim))
                g.DrawString("Nothing is sent anywhere. There is no account and no key.",
                             _fBody, b, r.X + 24, y);
        }

        private void DrawLife(Graphics g, Palette c, Rectangle r, int y)
        {
            Row(g, c, r.X + 24, ref y, "Quests open", Store.OpenCount("QS").ToString(CultureInfo.InvariantCulture));
            Row(g, c, r.X + 24, ref y, "Wins logged", Store.OpenCount("WN").ToString(CultureInfo.InvariantCulture));
            Row(g, c, r.X + 24, ref y, "Log entries", Store.OpenCount("LC").ToString(CultureInfo.InvariantCulture));
            Row(g, c, r.X + 24, ref y, "Want list", Store.OpenCount("WL").ToString(CultureInfo.InvariantCulture));
            Row(g, c, r.X + 24, ref y, "Ideas", Store.OpenCount("KI").ToString(CultureInfo.InvariantCulture));
            y += 12;
            using (SolidBrush b = new SolidBrush(c.AccentCyan))
                g.DrawString("THE CHECKLIST", _fSmall, b, r.X + 24, y);
            y += 22;
            List<Item> qs = Store.Load("QS");
            if (qs.Count == 0)
            {
                using (SolidBrush b = new SolidBrush(c.TextDim))
                    g.DrawString("Nothing on it. Type:  QS add ring the school",
                                 _fBody, b, r.X + 24, y);
            }
            for (int i = 0; i < qs.Count && i < 10; i++)
            {
                using (SolidBrush b = new SolidBrush(qs[i].Done ? c.TextDim : c.TextMain))
                    g.DrawString((qs[i].Done ? "[x]  " : "[ ]  ") + qs[i].Text,
                                 _fBody, b, r.X + 24, y);
                y += 24;
            }
        }

        private void Row(Graphics g, Palette c, int x, ref int y, string label, string value)
        {
            using (SolidBrush b = new SolidBrush(c.TextDim))
                g.DrawString(label, _fBody, b, x, y);
            using (SolidBrush b = new SolidBrush(c.TextMain))
                g.DrawString(value, _fBody, b, x + 180, y);
            y += 26;
        }

        private void DrawCommandBar(Graphics g, Palette c)
        {
            Rectangle r = new Rectangle(0, ClientSize.Height - CmdH, ClientSize.Width, CmdH);
            using (SolidBrush b = new SolidBrush(c.BgPanel)) g.FillRectangle(b, r);
            using (Pen p = new Pen(c.LineBlue)) g.DrawLine(p, 0, r.Y, ClientSize.Width, r.Y);

            Rectangle field = new Rectangle(Pad, r.Y + 10, ClientSize.Width - Pad * 2, 32);
            using (SolidBrush b = new SolidBrush(c.BgSub)) g.FillRectangle(b, field);
            using (SolidBrush b = new SolidBrush(c.AccentCyan))
                g.DrawString(">", _fBold, b, field.X + 8, field.Y + 6);

            if (!string.IsNullOrEmpty(_reply))
            {
                using (SolidBrush b = new SolidBrush(c.BgDeep))
                    g.FillRectangle(b, 0, r.Y - 24, ClientSize.Width, 24);
                using (SolidBrush b = new SolidBrush(_replyIsAlert ? c.AccentAmber : c.AccentGreen))
                    g.DrawString(Clip(_reply, (ClientSize.Width - 60) / 7), _fBody, b,
                                 Pad, r.Y - 22);
            }
        }

        private static string Clip(string s, int n)
        {
            if (s == null) return "";
            if (n < 4) n = 4;
            return s.Length <= n ? s : s.Substring(0, n - 1) + "-";
        }

        // ===================================================================
        //  INPUT
        // ===================================================================
        private void InputKeyDown(object sender, KeyEventArgs e)
        {
            if (e.KeyCode != Keys.Enter) return;
            e.SuppressKeyPress = true;
            string text = _input.Text;
            _input.Text = "";
            Execute(text);
        }

        protected override void OnKeyDown(KeyEventArgs e)
        {
            int page = ClientSize.Height - BarH - CmdH - 80;
            switch (e.KeyCode)
            {
                case Keys.Escape:
                    if (_openCode != null) { _openCode = null; _scroll = 0; Invalidate(); }
                    e.Handled = true;
                    return;
                case Keys.PageDown: ScrollBy(page); e.Handled = true; return;
                case Keys.PageUp: ScrollBy(-page); e.Handled = true; return;
                case Keys.End:
                    if (e.Control) { _scroll = ScrollMax(); Invalidate(); e.Handled = true; return; }
                    break;
                case Keys.Home:
                    if (e.Control) { _scroll = 0; Invalidate(); e.Handled = true; return; }
                    break;
                case Keys.F2: CycleView(); e.Handled = true; return;
                case Keys.F5: Invalidate(); e.Handled = true; return;
            }
            base.OnKeyDown(e);
        }

        // The filter catches the wheel before this ever fires, but a form
        // that ignores its own wheel event would be a trap for the next
        // person reading this.
        protected override void OnMouseWheel(MouseEventArgs e)
        {
            ScrollBy(-e.Delta / 2);
        }

        protected override void OnMouseMove(MouseEventArgs e)
        {
            if (_draggingThumb)
            {
                int max = ScrollMax();
                int travel = _scrollTrack.Height - _scrollThumb.Height;
                if (travel > 0)
                {
                    int at = e.Y - _scrollTrack.Y - _thumbGrab;
                    if (at < 0) at = 0;
                    if (at > travel) at = travel;
                    _scroll = (int)((double)at / travel * max);
                    Invalidate();
                }
                return;
            }
            if (_maybeDragCode != null && !_dragStarted)
            {
                int dx = e.X - _mouseDownAt.X, dy = e.Y - _mouseDownAt.Y;
                if (dx * dx + dy * dy > 16)
                {
                    _dragStarted = true;
                    _dragCode = _maybeDragCode;
                }
            }
            if (_dragCode != null)
            {
                int nx = e.X - _dragGrab.X, ny = e.Y - _dragGrab.Y + _scroll;
                if (nx < 4) nx = 4;
                if (ny < BarH + 4) ny = BarH + 4;
                if (nx > ClientSize.Width - 60) nx = ClientSize.Width - 60;
                _desktopPos[_dragCode] = new Point(nx, ny);
                Invalidate();
                return;
            }
            if (_dragging)
            {
                Location = new Point(Location.X + e.X - _dragFrom.X, Location.Y + e.Y - _dragFrom.Y);
                return;
            }
            int was = _hover;
            _hover = -1;
            if (_openCode == null)
            {
                for (int i = 0; i < _tiles.Count; i++)
                    if (_tiles[i].R.Contains(e.Location)) { _hover = i; break; }
            }
            if (was != _hover) Invalidate();
            base.OnMouseMove(e);
        }

        protected override void OnMouseDown(MouseEventArgs e)
        {
            if (_closeBtn.Contains(e.Location)) { Close(); return; }
            if (_scrollThumb != Rectangle.Empty && _scrollThumb.Contains(e.Location))
            {
                _draggingThumb = true;
                _thumbGrab = e.Y - _scrollThumb.Y;
                return;
            }
            // In desktop view a press is not yet a click: it becomes a drag
            // if the mouse moves, and an open if it does not.
            if (_openCode == null && _view == ViewMode.Desktop)
            {
                for (int i = 0; i < _tiles.Count; i++)
                {
                    if (_tiles[i].R.Contains(e.Location))
                    {
                        _maybeDragCode = _tiles[i].P.Code;
                        _mouseDownAt = e.Location;
                        _dragStarted = false;
                        _dragGrab = new Point(e.X - _tiles[i].R.X, e.Y - _tiles[i].R.Y);
                        return;
                    }
                }
            }
            if (_openCode == "AU")
            {
                for (int i = 0; i < _ruleBoxes.Count; i++)
                {
                    if (_ruleBoxes[i].Contains(e.Location))
                    {
                        int idx = _ruleIndex[i];
                        if (idx < Rules.All.Count)
                        {
                            Rules.All[idx].Enabled = !Rules.All[idx].Enabled;
                            Rules.Save();
                            Say("Rule " + (Rules.All[idx].Enabled ? "on" : "off") + ".", false);
                        }
                        return;
                    }
                }
            }
            if (_minBtn.Contains(e.Location)) { WindowState = FormWindowState.Minimized; return; }
            if (e.Y < BarH) { _dragging = true; _dragFrom = e.Location; return; }
            if (_backBtn.Contains(e.Location)) { _openCode = null; _scroll = 0; Invalidate(); return; }

            if (_openCode == null)
            {
                for (int i = 0; i < _tiles.Count; i++)
                {
                    if (_tiles[i].R.Contains(e.Location))
                    {
                        Open(_tiles[i].P.Code, 0);
                        return;
                    }
                }
            }
            else if (_openCode == "SE")
            {
                for (int i = 0; i < _swatches.Count && i < Theme.All.Length; i++)
                {
                    if (_swatches[i].Contains(e.Location))
                    {
                        Theme.Current = Theme.All[i];
                        Mem.Set("themename", Theme.Current.Name);
                        LayoutInput();
                        Say("Theme is " + Theme.Current.Name + " now, and I will still be wearing it next time.", false);
                        return;
                    }
                }
            }
            else
            {
                Place p = Places.ByCode(_openCode);
                if (p != null)
                {
                    List<Item> items = Store.Load(p.Code);
                    for (int i = 0; i < _checkBoxes.Count; i++)
                    {
                        if (_checkBoxes[i].Contains(e.Location))
                        {
                            int idx = _checkIndex[i];
                            if (idx >= items.Count) break;
                            items[idx].Done = !items[idx].Done;
                            Store.Save(p.Code, items);
                            if (items[idx].Done) Streams.Write("win", items[idx].Text);
                            Invalidate();
                            return;
                        }
                    }
                }
            }
            base.OnMouseDown(e);
        }

        protected override void OnMouseUp(MouseEventArgs e)
        {
            _dragging = false;
            _draggingThumb = false;
            if (_dragCode != null)
            {
                SaveDesktop();
                _dragCode = null;
            }
            else if (_maybeDragCode != null && !_dragStarted)
            {
                // pressed and released without moving: that is a click
                string code = _maybeDragCode;
                _maybeDragCode = null;
                Open(code, 0);
                _input.Focus();
                return;
            }
            _maybeDragCode = null;
            _dragStarted = false;
            _input.Focus();
            base.OnMouseUp(e);
        }

        // ===================================================================
        //  SAYING THINGS
        // ===================================================================
        // Knocking on a model takes up to a few seconds, which is far too
        // long to do on the thread that draws the window.
        private void StartBackgroundProbe()
        {
            Thread t = new Thread(delegate()
            {
                for (int i = 0; i < Minds.All.Count; i++) Minds.Probe(Minds.All[i]);
                List<string> fired = Rules.Evaluate();
                try
                {
                    BeginInvoke((MethodInvoker)delegate
                    {
                        if (fired.Count > 0) Say(fired[0], true);
                        Invalidate();
                    });
                }
                catch { }
            });
            t.IsBackground = true;
            t.Start();
        }

        private void Say(string text, bool alert)
        {
            _reply = text;
            _replyIsAlert = alert;
            Invalidate();
            if (_voiceOn && _voice != null)
            {
                try { _voice.SpeakAsyncCancelAll(); _voice.SpeakAsync(text); }
                catch { _voiceOn = false; _voiceNote = "STARP-0501"; }
            }
        }

        private void Open(string code, int n)
        {
            Place p = Places.ByCode(code);
            if (p == null) { Say("There is no call sign " + code + ".", true); return; }
            _openCode = p.Code;
            _openN = n;
            _scroll = 0;
            Streams.Write("use", p.Code + " " + p.Say);
            if (n > 0)
            {
                List<Item> items = Store.Load(p.Code);
                if (n <= items.Count) Say(p.Code + n.ToString(CultureInfo.InvariantCulture) +
                                          "  ::  " + items[n - 1].Text, false);
                else Say("There is no item " + n.ToString(CultureInfo.InvariantCulture) +
                         " on the " + p.Say + " list.", true);
            }
            else Say(p.About, false);
            Invalidate();
        }


        // ===================================================================
        //  SCROLLING
        //  A form only gets the wheel when the form itself has focus, and
        //  the focus lives in the command field where it belongs. So the
        //  wheel is caught before Windows delivers it anywhere.
        // ===================================================================
        internal sealed class WheelFilter : IMessageFilter
        {
            private readonly BoardForm _form;
            public WheelFilter(BoardForm form) { _form = form; }

            public bool PreFilterMessage(ref Message m)
            {
                const int WM_MOUSEWHEEL = 0x020A;
                if (m.Msg != WM_MOUSEWHEEL) return false;
                // Scroll when the pointer is over the window, focused or not.
                // Requiring focus is the behaviour that made this feel broken.
                if (_form.IsDisposed) return false;
                Point at = _form.PointToClient(Cursor.Position);
                if (!_form.ClientRectangle.Contains(at)) return false;
                int delta = (short)(((int)(long)m.WParam) >> 16);
                _form.ScrollBy(-delta / 2);
                return true;
            }
        }

        public void ScrollBy(int amount)
        {
            int max = ScrollMax();
            if (max <= 0) { if (_scroll != 0) { _scroll = 0; Invalidate(); } return; }
            int was = _scroll;
            _scroll += amount;
            if (_scroll > max) _scroll = max;
            if (_scroll < 0) _scroll = 0;
            if (was != _scroll) Invalidate();
        }

        private int ScrollMax()
        {
            return _scrollNeeded < 0 ? 0 : _scrollNeeded;
        }

        // Both arguments are screen Y as they would be with scroll at zero.
        private void SetScrollExtent(int contentBottom, int visibleBottom)
        {
            int need = contentBottom - visibleBottom;
            _scrollNeeded = need < 0 ? 0 : need;
        }

        // A bar you can see and drag, because a window that scrolls without
        // saying so looks broken.
        private void DrawScrollBar(Graphics g, Palette c, Rectangle body)
        {
            int max = ScrollMax();
            if (max <= 0) { _scrollThumb = Rectangle.Empty; return; }
            _scrollTrack = new Rectangle(ClientSize.Width - 10, body.Y + 4, 6, body.Height - 8);
            using (SolidBrush b = new SolidBrush(c.BgSub))
                g.FillRectangle(b, _scrollTrack);

            double shown = (double)body.Height / (body.Height + max);
            int thumbH = (int)(_scrollTrack.Height * shown);
            if (thumbH < 28) thumbH = 28;
            int travel = _scrollTrack.Height - thumbH;
            int at = max == 0 ? 0 : (int)((double)_scroll / max * travel);
            _scrollThumb = new Rectangle(_scrollTrack.X, _scrollTrack.Y + at,
                                         _scrollTrack.Width, thumbH);
            using (SolidBrush b = new SolidBrush(_draggingThumb ? c.AccentCyan : c.LineBlue))
                g.FillRectangle(b, _scrollThumb);

            if (_scroll < max)
            {
                using (SolidBrush b = new SolidBrush(c.AccentAmber))
                    g.DrawString("more below", _fSmall, b,
                                 ClientSize.Width - 108, body.Bottom - 16);
            }
        }

        // ===================================================================
        //  VIEW MODES
        //  The same nodes, arranged four ways. Kohaku's board is one of
        //  them, not the only one.
        // ===================================================================
        private void CycleView()
        {
            switch (_view)
            {
                case ViewMode.Board: _view = ViewMode.Tiled; break;
                case ViewMode.Tiled: _view = ViewMode.Page; break;
                case ViewMode.Page: _view = ViewMode.Desktop; break;
                default: _view = ViewMode.Board; break;
            }
            SetView(_view);
        }

        private void SetView(ViewMode v)
        {
            _view = v;
            _scroll = 0;
            Mem.Set("view", v.ToString().ToLowerInvariant());
            Say("View is " + v.ToString().ToLowerInvariant() + " now.", false);
            Invalidate();
        }

        private void DrawTiled(Graphics g, Palette c, Rectangle body)
        {
            int tileW = 168, tileH = 44, gap = 8;
            int cols = Math.Max(3, (ClientSize.Width - Pad * 2 + gap) / (tileW + gap));
            int x0 = Pad, y = body.Y + 14 - _scroll;
            for (int i = 0; i < Places.All.Count; i++)
            {
                Place p = Places.All[i];
                int col = i % cols, row = i / cols;
                Rectangle r = new Rectangle(x0 + col * (tileW + gap),
                                            y + row * (tileH + gap), tileW, tileH);
                RegisterTile(r, p);
                bool hot = _hover == _tiles.Count - 1;
                DrawBox(g, r, hot ? c.BgSub : c.BgPanel, hot ? c.AccentCyan : c.LineBlue, false);
                using (SolidBrush b = new SolidBrush(c.AccentAmber))
                    g.DrawString(p.Code, _fBold, b, r.X + 10, r.Y + 12);
                using (SolidBrush b = new SolidBrush(c.TextMain))
                    g.DrawString(Clip(p.Say, 15), _fBody, b, r.X + 44, r.Y + 12);
                int n = CountFor(p);
                if (n > 0)
                    using (SolidBrush b = new SolidBrush(c.AccentGreen))
                        g.DrawString(n.ToString(CultureInfo.InvariantCulture), _fBold, b,
                                     r.Right - 22, r.Y + 12);
            }
            int rows = (Places.All.Count + cols - 1) / cols;
            SetScrollExtent(body.Y + 14 + rows * (tileH + gap) + 24, body.Bottom);
        }

        private void DrawPage(Graphics g, Palette c, Rectangle body)
        {
            int y = body.Y + 14 - _scroll;
            string cat = null;
            for (int i = 0; i < Places.All.Count; i++)
            {
                Place p = Places.All[i];
                if (p.Category != cat)
                {
                    cat = p.Category;
                    y += 16;
                    if (y > body.Y && y < body.Bottom)
                    {
                        using (SolidBrush b = new SolidBrush(c.AccentCyan))
                            g.DrawString(cat, _fBold, b, Pad + 6, y);
                        using (Pen pen = new Pen(c.LineBlue))
                            g.DrawLine(pen, Pad + 6, y + 20, ClientSize.Width - Pad - 20, y + 20);
                    }
                    y += 30;
                }
                Rectangle r = new Rectangle(Pad + 6, y, ClientSize.Width - Pad * 2 - 26, 26);
                RegisterTile(r, p);
                if (y > body.Y - 26 && y < body.Bottom)
                {
                    bool hot = _hover == _tiles.Count - 1;
                    if (hot)
                        using (SolidBrush b = new SolidBrush(c.BgSub)) g.FillRectangle(b, r);
                    using (SolidBrush b = new SolidBrush(c.AccentAmber))
                        g.DrawString(p.Code, _fBold, b, r.X + 6, r.Y + 4);
                    using (SolidBrush b = new SolidBrush(c.TextMain))
                        g.DrawString(p.Say, _fBody, b, r.X + 52, r.Y + 4);
                    using (SolidBrush b = new SolidBrush(c.TextDim))
                        g.DrawString(p.About, _fBody, b, r.X + 220, r.Y + 4);
                    int n = CountFor(p);
                    if (n > 0)
                        using (SolidBrush b = new SolidBrush(c.AccentGreen))
                            g.DrawString(n.ToString(CultureInfo.InvariantCulture), _fBold, b,
                                         r.Right - 26, r.Y + 4);
                }
                y += 26;
            }
            SetScrollExtent(y + _scroll + 24, body.Bottom);
        }

        // Free positions, dragged with the mouse and remembered between
        // sessions in kh_desktop.cfg.
        private void DrawDesktop(Graphics g, Palette c, Rectangle body)
        {
            int tileW = 180, tileH = 52;
            for (int i = 0; i < Places.All.Count; i++)
            {
                Place p = Places.All[i];
                Point at = DesktopPoint(p.Code, i, body);
                Rectangle r = new Rectangle(at.X, at.Y - _scroll, tileW, tileH);
                RegisterTile(r, p);
                bool hot = _hover == _tiles.Count - 1;
                bool held = _dragCode == p.Code;
                DrawBox(g, r, held ? c.BgSub : (hot ? c.BgSub : c.BgPanel),
                        held ? c.AccentAmber : (hot ? c.AccentCyan : c.LineBlue), false);
                using (SolidBrush b = new SolidBrush(c.AccentAmber))
                    g.DrawString(p.Code, _fBold, b, r.X + 10, r.Y + 8);
                using (SolidBrush b = new SolidBrush(c.TextMain))
                    g.DrawString(Clip(p.Say, 16), _fBody, b, r.X + 44, r.Y + 8);
                using (SolidBrush b = new SolidBrush(c.TextDim))
                    g.DrawString(Clip(p.About, 24), _fSmall, b, r.X + 10, r.Y + 30);
            }
            _scrollNeeded = 0;
            using (SolidBrush b = new SolidBrush(c.TextDim))
                g.DrawString("drag anything anywhere. it stays where you put it.",
                             _fSmall, b, Pad, body.Bottom - 18);
        }

        private Point DesktopPoint(string code, int index, Rectangle body)
        {
            if (_desktopPos.ContainsKey(code)) return _desktopPos[code];
            int cols = Math.Max(3, (ClientSize.Width - Pad * 2) / 196);
            int col = index % cols, row = index / cols;
            Point at = new Point(Pad + col * 196, body.Y + 14 + row * 62);
            _desktopPos[code] = at;
            return at;
        }

        private void LoadDesktop()
        {
            _desktopPos.Clear();
            string p = System.IO.Path.Combine(Paths.Data, "kh_desktop.cfg");
            if (!File.Exists(p)) return;
            try
            {
                string[] lines = File.ReadAllLines(p);
                for (int i = 0; i < lines.Length; i++)
                {
                    string line = lines[i].Trim();
                    if (line.Length == 0 || line[0] == '#') continue;
                    string[] c = line.Split('|');
                    int x, y;
                    if (c.Length >= 3 &&
                        int.TryParse(c[1], out x) && int.TryParse(c[2], out y))
                        _desktopPos[c[0].Trim().ToUpperInvariant()] = new Point(x, y);
                }
            }
            catch { }
        }

        private void SaveDesktop()
        {
            try
            {
                Paths.EnsureData();
                StringBuilder sb = new StringBuilder();
                sb.AppendLine("# Where each node sits in desktop view.  code|x|y");
                sb.AppendLine("# Delete this file to put everything back in rows.");
                foreach (KeyValuePair<string, Point> kv in _desktopPos)
                    sb.AppendLine(kv.Key + "|" + kv.Value.X.ToString(CultureInfo.InvariantCulture) +
                                  "|" + kv.Value.Y.ToString(CultureInfo.InvariantCulture));
                File.WriteAllText(System.IO.Path.Combine(Paths.Data, "kh_desktop.cfg"), sb.ToString());
            }
            catch { }
        }

        private void RegisterTile(Rectangle r, Place p)
        {
            Tile t = new Tile();
            t.R = r;
            t.P = p;
            t.Count = CountFor(p);
            _tiles.Add(t);
        }

        private int CountFor(Place p)
        {
            if (p.Kind != "node" && p.Kind != "learn") return -1;
            return Store.OpenCount(p.Code);
        }

        // ===================================================================
        //  DRIVES  -  what is actually plugged into this machine
        // ===================================================================
        private void DrawDrives(Graphics g, Palette c, Rectangle r, int y)
        {
            List<DriveRow> rows = Drives.All();
            using (SolidBrush b = new SolidBrush(c.TextDim))
                g.DrawString(rows.Count.ToString(CultureInfo.InvariantCulture) +
                             " attached. Hard disks, removable sticks and disc drives alike.",
                             _fBody, b, r.X + 24, y);
            y += 34;

            ClipBody(g, r, y - 6, 26);
            for (int i = 0; i < rows.Count; i++)
            {
                DriveRow d = rows[i];
                int ry = y + i * 74 - _scroll;
                if (ry < r.Y + 70 || ry > r.Bottom - 40) continue;

                using (SolidBrush b = new SolidBrush(c.AccentAmber))
                    g.DrawString(d.Letter, _fHead, b, r.X + 24, ry);
                using (SolidBrush b = new SolidBrush(c.TextMain))
                    g.DrawString(d.Kind, _fBold, b, r.X + 96, ry + 3);
                using (SolidBrush b = new SolidBrush(c.TextDim))
                    g.DrawString(d.Ready ? (string.IsNullOrEmpty(d.Label) ? "no label" : d.Label)
                                         : d.Label, _fBody, b, r.X + 230, ry + 3);
                if (d.Ready && !string.IsNullOrEmpty(d.Format))
                    using (SolidBrush b = new SolidBrush(c.TextDim))
                        g.DrawString(d.Format, _fSmall, b, r.X + 430, ry + 5);

                if (d.Ready && d.Size > 0)
                {
                    Rectangle track = new Rectangle(r.X + 96, ry + 30, 420, 12);
                    using (SolidBrush b = new SolidBrush(c.BgSub)) g.FillRectangle(b, track);
                    int w = (int)(track.Width * (d.UsedPercent / 100.0));
                    Color fill = d.UsedPercent > 90 ? c.Alarm
                               : (d.UsedPercent > 75 ? c.AccentAmber : c.AccentGreen);
                    using (SolidBrush b = new SolidBrush(fill))
                        g.FillRectangle(b, track.X, track.Y, w, track.Height);
                    using (Pen pen = new Pen(c.LineBlue)) g.DrawRectangle(pen, track);
                    using (SolidBrush b = new SolidBrush(c.TextMain))
                        g.DrawString(Drives.Gb(d.Free) + " free of " + Drives.Gb(d.Size) +
                                     "   -   " + d.UsedPercent.ToString(CultureInfo.InvariantCulture) +
                                     "% used", _fSmall, b, track.Right + 14, ry + 30);
                }
                else
                {
                    using (SolidBrush b = new SolidBrush(c.TextDim))
                        g.DrawString("nothing in it", _fSmall, b, r.X + 96, ry + 30);
                }
            }
            Unclip(g);
            SetScrollExtent(y + rows.Count * 74 + 24, r.Bottom - 26);
        }

        // ===================================================================
        //  THE DOCTOR  -  one pass over everything that can break
        // ===================================================================
        private void DrawDoctor(Graphics g, Palette c, Rectangle r, int y)
        {
            if (Doctor.LastRun == DateTime.MinValue)
            {
                using (SolidBrush b = new SolidBrush(c.TextDim))
                    g.DrawString("Nothing checked yet. Type  md run  to examine everything.",
                                 _fBody, b, r.X + 24, y);
                _scrollNeeded = 0;
                return;
            }

            int good = Doctor.Count(Health.Good), warn = Doctor.Count(Health.Warn),
                bad = Doctor.Count(Health.Bad);
            using (SolidBrush b = new SolidBrush(bad > 0 ? c.Alarm
                                   : (warn > 0 ? c.AccentAmber : c.AccentGreen)))
                g.DrawString(bad > 0 ? "SOMETHING IS BROKEN"
                           : (warn > 0 ? "WORKING, WITH THINGS WORTH KNOWING" : "ALL WELL"),
                             _fBold, b, r.X + 24, y);
            using (SolidBrush b = new SolidBrush(c.TextDim))
                g.DrawString(good.ToString(CultureInfo.InvariantCulture) + " good   " +
                             warn.ToString(CultureInfo.InvariantCulture) + " worth a look   " +
                             bad.ToString(CultureInfo.InvariantCulture) + " broken       checked at " +
                             Doctor.LastRun.ToString("HH:mm:ss", CultureInfo.InvariantCulture) +
                             "       md run  does it again",
                             _fSmall, b, r.X + 24, y + 22);
            y += 50;

            ClipBody(g, r, y - 6, 26);
            string group = null;
            int drawn = 0;
            for (int i = 0; i < Doctor.Results.Count; i++)
            {
                Check ck = Doctor.Results[i];
                if (ck.Group != group)
                {
                    group = ck.Group;
                    drawn++;
                    int gy = y + drawn * 22 + i * 22 - _scroll;
                    if (gy > r.Y + 70 && gy < r.Bottom - 30)
                        using (SolidBrush b = new SolidBrush(c.AccentCyan))
                            g.DrawString(group, _fSmall, b, r.X + 24, gy);
                }
                int ly = y + drawn * 22 + i * 22 + 18 - _scroll;
                if (ly < r.Y + 70 || ly > r.Bottom - 30) continue;

                Color dot = ck.State == Health.Good ? c.AccentGreen
                          : (ck.State == Health.Warn ? c.AccentAmber : c.Alarm);
                using (SolidBrush b = new SolidBrush(dot))
                    g.FillEllipse(b, r.X + 34, ly + 5, 8, 8);
                using (SolidBrush b = new SolidBrush(c.TextMain))
                    g.DrawString(Clip(ck.Name, 30), _fBody, b, r.X + 50, ly);
                using (SolidBrush b = new SolidBrush(c.TextDim))
                    g.DrawString(Clip(ck.Detail, 74), _fBody, b, r.X + 300, ly);
                using (SolidBrush b = new SolidBrush(c.TextDim))
                    g.DrawString(ck.Ms.ToString(CultureInfo.InvariantCulture) + " ms",
                                 _fSmall, b, r.Right - 70, ly + 2);
            }
            Unclip(g);
            SetScrollExtent(y + drawn * 22 + Doctor.Results.Count * 22 + 40, r.Bottom - 26);
        }

        // ===================================================================
        //  MINDS  -  the models, and whether they are answering
        // ===================================================================
        private void DrawMinds(Graphics g, Palette c, Rectangle r, int y)
        {
            using (SolidBrush b = new SolidBrush(c.TextDim))
                g.DrawString("Every model she may ask. Two given the same question rarely " +
                             "answer the same way,", _fBody, b, r.X + 24, y);
            using (SolidBrush b = new SolidBrush(c.TextDim))
                g.DrawString("which is the whole reason for having more than one.",
                             _fBody, b, r.X + 24, y + 20);
            y += 54;

            ClipBody(g, r, y - 6, 110);
            for (int i = 0; i < Minds.All.Count; i++)
            {
                Mind m = Minds.All[i];
                int my = y + i * 62 - _scroll;
                if (my < r.Y + 70 || my > r.Bottom - 70) continue;

                Color dot = !m.Enabled ? c.TextDim : (m.Online ? c.AccentGreen : c.Alarm);
                using (SolidBrush b = new SolidBrush(dot))
                    g.FillEllipse(b, r.X + 26, my + 6, 10, 10);
                using (SolidBrush b = new SolidBrush(c.TextMain))
                    g.DrawString(m.Name, _fBold, b, r.X + 46, my);
                using (SolidBrush b = new SolidBrush(c.AccentAmber))
                    g.DrawString(m.Model, _fBody, b, r.X + 150, my);
                using (SolidBrush b = new SolidBrush(c.TextDim))
                    g.DrawString(m.Kind + "   " + m.Endpoint, _fSmall, b, r.X + 46, my + 22);

                string state;
                if (!m.Enabled) state = "switched off";
                else if (m.Online) state = "answering in " +
                    m.LatencyMs.ToString(CultureInfo.InvariantCulture) + " ms";
                else state = "no answer   " + m.LastError;
                using (SolidBrush b = new SolidBrush(dot))
                    g.DrawString(state, _fBody, b, r.X + 400, my);
                using (SolidBrush b = new SolidBrush(c.TextDim))
                    g.DrawString(m.Local ? "on this machine, nothing leaves it"
                                         : "REMOTE - answers leave this machine",
                                 _fSmall, b, r.X + 400, my + 22);
            }

            Unclip(g);
            int fy = r.Bottom - 92;
            using (Pen pen = new Pen(c.LineBlue)) g.DrawLine(pen, r.X + 24, fy - 10, r.Right - 24, fy - 10);
            using (SolidBrush b = new SolidBrush(c.TextDim))
            {
                g.DrawString("ask WHAT          ask the first mind that answers", _fBody, b, r.X + 24, fy);
                g.DrawString("council WHAT      ask every enabled mind and show them side by side",
                             _fBody, b, r.X + 24, fy + 22);
                g.DrawString("auto on / off     let her answer unmatched questions by herself" +
                             "        now: " + (_autoAsk ? "ON" : "off"), _fBody, b, r.X + 24, fy + 44);
            }
            SetScrollExtent(y + Minds.All.Count * 62 + 16, r.Bottom - 110);
        }

        // ===================================================================
        //  AUTOMATIONS  -  what she is allowed to do without being asked
        // ===================================================================
        private void DrawRules(Graphics g, Palette c, Rectangle r, int y)
        {
            using (SolidBrush b = new SolidBrush(c.TextDim))
                g.DrawString("A rule is one sentence: WHEN something is true, DO one thing.",
                             _fBody, b, r.X + 24, y);
            using (SolidBrush b = new SolidBrush(c.TextDim))
                g.DrawString("Every one is listed here with what it last did. She never acts " +
                             "out of sight.", _fBody, b, r.X + 24, y + 20);
            y += 56;

            ClipBody(g, r, y - 6, 64);
            for (int i = 0; i < Rules.All.Count; i++)
            {
                Rule ru = Rules.All[i];
                int ry = y + i * 46 - _scroll;
                if (ry < r.Y + 70 || ry > r.Bottom - 60) continue;

                Rectangle box = new Rectangle(r.X + 26, ry + 3, 14, 14);
                _ruleBoxes.Add(box);
                _ruleIndex.Add(i);
                using (Pen pen = new Pen(ru.Enabled ? c.AccentGreen : c.TextDim))
                    g.DrawRectangle(pen, box);
                if (ru.Enabled)
                    using (Pen pen = new Pen(c.AccentGreen, 2f))
                    {
                        g.DrawLine(pen, box.X + 3, box.Y + 7, box.X + 6, box.Y + 10);
                        g.DrawLine(pen, box.X + 6, box.Y + 10, box.X + 11, box.Y + 3);
                    }

                using (SolidBrush b = new SolidBrush(ru.Enabled ? c.TextMain : c.TextDim))
                    g.DrawString("WHEN " + ru.When.Replace("_", " ") + " " +
                                 ru.Threshold.ToString(CultureInfo.InvariantCulture) +
                                 "   THEN " + ru.Then.Replace("_", " "),
                                 _fBody, b, r.X + 50, ry);
                using (SolidBrush b = new SolidBrush(c.TextDim))
                    g.DrawString(ru.Note + "        last fired: " + ru.LastFired,
                                 _fSmall, b, r.X + 50, ry + 20);
            }

            Unclip(g);
            int fy = r.Bottom - 46;
            using (Pen pen = new Pen(c.LineBlue)) g.DrawLine(pen, r.X + 24, fy - 10, r.Right - 24, fy - 10);
            using (SolidBrush b = new SolidBrush(c.TextDim))
                g.DrawString("click a box to switch a rule on or off      au check  runs them all now" +
                             "      the file is rules.cfg", _fBody, b, r.X + 24, fy);
            SetScrollExtent(y + Rules.All.Count * 46 + 16, r.Bottom - 64);
        }

        // ===================================================================
        //  THE TEACHING GUIDE
        //  Four steps, and it works out which one you are actually on by
        //  looking at what is really there rather than asking.
        // ===================================================================
        private void DrawTeachGuide(Graphics g, Palette c, Rectangle r, int y)
        {
            int lessons = Brain.Load().Count;
            int used = 0;
            List<Lesson> all = Brain.Load();
            for (int i = 0; i < all.Count; i++) if (all[i].Hits > 0) used++;
            int waiting = 0;
            try { if (File.Exists(Paths.Unknown)) waiting = File.ReadAllLines(Paths.Unknown).Length; }
            catch { }

            bool s1 = waiting > 0 || !string.IsNullOrEmpty(_lastUnknown);
            bool s2 = s1;
            bool s3 = lessons > 0;
            bool s4 = used > 0;
            int at = !s1 ? 1 : (!s3 ? 3 : (!s4 ? 4 : 5));

            using (SolidBrush b = new SolidBrush(c.TextDim))
                g.DrawString("Teaching her is four steps. You are on step " +
                             (at > 4 ? 4 : at).ToString(CultureInfo.InvariantCulture) + ".",
                             _fBody, b, r.X + 24, y);
            y += 32;

            string example = string.IsNullOrEmpty(_lastUnknown) ? "what is the wifi password" : _lastUnknown;
            if (example.Length > 34) example = example.Substring(0, 33) + "-";

            Step(g, c, r, ref y, 1, s1, "ASK HER SOMETHING SHE DOES NOT KNOW",
                 "Type any question. If nothing built in matches, she says so",
                 "and writes it down.", "try:   what is the wifi password");

            Step(g, c, r, ref y, 2, s2, "WATCH WHAT SHE DOES WITH IT",
                 "The question goes on the pile at " + waiting.ToString(CultureInfo.InvariantCulture) +
                 " waiting. Nothing is lost,",
                 "and the last one is always ready to be answered.",
                 waiting > 0 ? "on the pile now:   " + example : "nothing waiting yet");

            Step(g, c, r, ref y, 3, s3, "TEACH HER THE ANSWER",
                 "Two ways. Both write one line into ai_brain.db.",
                 "She holds " + lessons.ToString(CultureInfo.InvariantCulture) + " lessons right now.",
                 "teach " + example + " = your answer");

            Step(g, c, r, ref y, 4, s4, "ASK AGAIN AND SEE IT WORK",
                 "Ask it any way round. She matches on the words inside the",
                 "sentence, so it does not have to be word for word." ,
                 used > 0 ? used.ToString(CultureInfo.InvariantCulture) +
                            " of her lessons have fired at least once"
                          : "none of her lessons have fired yet");

            y += 10;
            using (Pen pen = new Pen(c.LineBlue)) g.DrawLine(pen, r.X + 24, y, r.Right - 24, y);
            y += 14;
            using (SolidBrush b = new SolidBrush(c.AccentCyan))
                g.DrawString("AND WHEN SHE ANSWERS FOR HERSELF", _fBold, b, r.X + 24, y);
            y += 24;
            using (SolidBrush b = new SolidBrush(c.TextMain))
                g.DrawString("With auto " + (_autoAsk ? "ON" : "off") +
                             ", a question nothing matches goes to a model instead of a shrug.",
                             _fBody, b, r.X + 24, y);
            y += 22;
            using (SolidBrush b = new SolidBrush(c.TextMain))
                g.DrawString("She shows you the answer, and  teach that  saves it as a lesson " +
                             "in her own words.", _fBody, b, r.X + 24, y);
            y += 22;
            using (SolidBrush b = new SolidBrush(c.TextDim))
                g.DrawString("That is the whole loop: she does not know, a model tells her, " +
                             "you approve it, she knows.", _fBody, b, r.X + 24, y);
            y += 26;
            using (SolidBrush b = new SolidBrush(c.TextDim))
                g.DrawString("AU is the rest of it - the things she does with no question asked " +
                             "at all.", _fBody, b, r.X + 24, y);
            SetScrollExtent(y + 40, r.Bottom - 20);
        }

        private void Step(Graphics g, Palette c, Rectangle r, ref int y, int n, bool done,
                          string title, string line1, string line2, string example)
        {
            Rectangle box = new Rectangle(r.X + 24, y, 26, 26);
            Color edge = done ? c.AccentGreen : c.TextDim;
            using (Pen pen = new Pen(edge, done ? 2f : 1f)) g.DrawRectangle(pen, box);
            using (SolidBrush b = new SolidBrush(edge))
                g.DrawString(done ? "v" : n.ToString(CultureInfo.InvariantCulture),
                             _fBold, b, box.X + 8, box.Y + 4);

            using (SolidBrush b = new SolidBrush(done ? c.AccentGreen : c.TextMain))
                g.DrawString(title, _fBold, b, box.Right + 14, y + 1);
            using (SolidBrush b = new SolidBrush(c.TextDim))
                g.DrawString(line1, _fBody, b, box.Right + 14, y + 22);
            using (SolidBrush b = new SolidBrush(c.TextDim))
                g.DrawString(line2, _fBody, b, box.Right + 14, y + 40);
            using (SolidBrush b = new SolidBrush(c.AccentAmber))
                g.DrawString(example, _fBody, b, box.Right + 14, y + 60);
            y += 92;
        }

        // ===================================================================
        //  ASKING A MODEL, WITHOUT FREEZING THE WINDOW
        // ===================================================================
        private void AskMind(string question, bool council)
        {
            if (Minds.All.Count == 0) { Say("No models are configured. The file is minds.cfg.", true); return; }
            if (_asking) { Say("Still waiting on the last question.", true); return; }
            _asking = true;
            _askedAt = DateTime.Now;
            _pendingQuestion = question;
            Say((council ? "Asking every mind: " : "Asking: ") + Clip(question, 44) + " ...", false);

            Thread t = new Thread(delegate()
            {
                List<string> answers = new List<string>();
                List<string> names = new List<string>();
                for (int i = 0; i < Minds.All.Count; i++)
                {
                    Mind m = Minds.All[i];
                    if (!m.Enabled) continue;
                    Minds.Probe(m);
                    if (!m.Online) continue;
                    // A cold model on a small machine can take minutes to load,
                    // and keep_alive means only the first one pays it.
                    string a = Minds.Ask(m, question, 240000);
                    if (!string.IsNullOrEmpty(a))
                    {
                        answers.Add(a.Trim());
                        names.Add(m.Name + "  " + m.Model);
                        if (!council) break;
                    }
                }
                try
                {
                    BeginInvoke((MethodInvoker)delegate
                    {
                        _asking = false;
                        if (answers.Count == 0)
                        {
                            int waited = (int)(DateTime.Now - _askedAt).TotalSeconds;
                            Say("No answer after " + waited.ToString(CultureInfo.InvariantCulture) +
                                "s. Usually the model is bigger than free MEMORY - not disk - " +
                                "so it pages. Run  md run  and read the MINDS lines.", true);
                            return;
                        }
                        if (council && answers.Count > 1)
                        {
                            List<string> lines = new List<string>();
                            lines.Add("$" + question);
                            lines.Add("");
                            for (int i = 0; i < answers.Count; i++)
                            {
                                lines.Add("#" + names[i]);
                                WrapInto(lines, answers[i], 92);
                                lines.Add("");
                            }
                            lines.Add("$Two answers to one question. Believe neither on its own.");
                            ShowInfo("THE COUNCIL", lines);
                            Say(answers.Count.ToString(CultureInfo.InvariantCulture) +
                                " minds answered. Both are on screen.", false);
                            return;
                        }
                        _mindAnswer = answers[0];
                        List<string> one = new List<string>();
                        one.Add("$" + question);
                        one.Add("");
                        one.Add("#" + names[0]);
                        WrapInto(one, answers[0], 92);
                        one.Add("");
                        one.Add("$She did not know this. It came from a model, not from her.");
                        one.Add("$Type   teach that   to keep it as a lesson in her own memory.");
                        ShowInfo("AN ANSWER FROM A MODEL", one);
                        Say("Answered by " + names[0] + ".  teach that  keeps it.", false);
                    });
                }
                catch { }
            });
            t.IsBackground = true;
            t.Start();
        }

        private static void WrapInto(List<string> lines, string text, int width)
        {
            if (text == null) return;
            string[] paras = text.Replace("\r", "").Split('\n');
            for (int p = 0; p < paras.Length; p++)
            {
                string s = paras[p].Trim();
                if (s.Length == 0) { lines.Add(""); continue; }
                while (s.Length > width)
                {
                    int cut = s.LastIndexOf(' ', Math.Min(width, s.Length - 1));
                    if (cut < 20) cut = Math.Min(width, s.Length - 1);
                    lines.Add("  " + s.Substring(0, cut));
                    s = s.Substring(cut).TrimStart();
                }
                if (s.Length > 0) lines.Add("  " + s);
            }
        }

        // ===================================================================
        //  THE ROUTER
        //  The same order ai.bat uses, for the same reason: a real command
        //  beats a call sign, a call sign beats plain English, and a lesson
        //  is only reached when nothing built in matched.
        // ===================================================================
        private string _lastUnknown;

        private void Execute(string raw)
        {
            if (raw == null) return;
            string text = raw.Trim();
            if (text.Length == 0) return;

            try
            {
                Paths.EnsureData();
                File.AppendAllText(Paths.History, "[" + DateTime.Now.ToString(
                    "ddd MM/dd/yyyy HH:mm:ss", CultureInfo.InvariantCulture) + "] " +
                    text + Environment.NewLine);
            }
            catch { }

            try { Route(text); }
            catch (Exception ex)
            {
                Say(ex.GetType().Name + ": " + ex.Message, true);
            }
        }

        private void Route(string text)
        {
            string[] parts = text.Split(new char[] { ' ' }, 2);
            string first = parts[0].ToLowerInvariant();
            string rest = parts.Length > 1 ? parts[1].Trim() : "";
            string low = text.ToLowerInvariant();

            // ---- real commands ------------------------------------------
            if (first == "help" || first == "?" || low == "what can you do")
            { ShowHelp(); return; }
            if (first == "board" || first == "home")
            {
                _openCode = null; _scroll = 0;
                Say("The board.", false);
                return;
            }
            if (first == "codes" || first == "callsigns") { ShowCodes(); return; }
            if (first == "view")
            {
                if (rest == "board") SetView(ViewMode.Board);
                else if (rest == "tiled" || rest == "tile") SetView(ViewMode.Tiled);
                else if (rest == "page") SetView(ViewMode.Page);
                else if (rest == "desktop" || rest == "free") SetView(ViewMode.Desktop);
                else if (rest.Length == 0) CycleView();
                else Say("Views are board, tiled, page and desktop.", true);
                _openCode = null;
                return;
            }
            if (first == "ask") { AskMind(rest, false); return; }
            if (first == "council" || first == "both") { AskMind(rest, true); return; }
            if (first == "auto")
            {
                _autoAsk = rest != "off";
                Mem.Set("autoask", _autoAsk ? "1" : "0");
                Say(_autoAsk
                    ? "Auto is on. A question I cannot match goes to a model."
                    : "Auto is off. I will just say when I do not know.", false);
                return;
            }
            if (first == "features" || first == "fifty") { ShowFeatures(); return; }
            if (first == "brain" || first == "learned") { ShowBrain(); return; }
            if (first == "exit" || first == "quit" || first == "bye" || first == "goodbye")
            {
                Close();
                return;
            }
            if (first == "theme")
            {
                if (rest.Length == 0) { Open("SE", 0); return; }
                if (Theme.Set(rest))
                {
                    Mem.Set("themename", Theme.Current.Name);
                    LayoutInput();
                    Say("Theme is " + Theme.Current.Name + " now, and I will still be wearing it next time.", false);
                }
                else Say("There is no theme called " + rest + ". Open SE for the twelve.", true);
                return;
            }
            if (first == "box" || first == "border")
            {
                if (SetBox(rest))
                {
                    Mem.Set("box", _box.ToString().ToLowerInvariant());
                    Say("Border set is " + _box.ToString().ToLowerInvariant() + " now.", false);
                }
                else Say("Borders are reticle, sharp, round, hairline and blade.", true);
                return;
            }
            if (first == "voice")
            {
                if (rest == "off") { _voiceOn = false; Say("Voice off. I will keep answering on screen.", false); }
                else if (_voice == null) Say("There is no speech engine on this machine. STARP-0501", true);
                else { _voiceOn = true; Say("Voice back on.", false); }
                return;
            }
            if (first == "name")
            {
                if (rest.Length == 0) { Say("Tell me who you are:  name Scott", true); return; }
                _userName = rest;
                Mem.Set("name", rest);
                Say("Good to meet you, " + rest + ". I will remember that.", false);
                return;
            }
            if (first == "teach" || first == "learn") { Teach(rest); return; }
            if (first == "unteach")
            {
                List<Lesson> list = Brain.Load();
                int before = list.Count;
                for (int i = list.Count - 1; i >= 0; i--)
                    if (string.Equals(list[i].Pattern, rest, StringComparison.OrdinalIgnoreCase))
                        list.RemoveAt(i);
                Brain.Save(list);
                Say(before == list.Count
                    ? "No lesson called " + rest + "."
                    : "Forgotten. I no longer answer to " + rest + ".", before == list.Count);
                return;
            }

            // ---- a bare call sign, with an optional digit ----------------
            string codeWord = first.ToUpperInvariant();
            int n = 0;
            if (codeWord.Length > 2)
            {
                string tail = codeWord.Substring(2);
                int parsed;
                if (int.TryParse(tail, NumberStyles.Integer, CultureInfo.InvariantCulture, out parsed))
                {
                    codeWord = codeWord.Substring(0, 2);
                    n = parsed;
                }
            }
            Place place = Places.ByCode(codeWord);
            if (place != null)
            {
                string[] sub = rest.Split(new char[] { ' ' }, 2);
                string verb = sub[0].ToLowerInvariant();
                string payload = sub.Length > 1 ? sub[1].Trim() : "";
                bool isList = place.Kind == "node" || place.Kind == "learn";

                if (place.Code == "MD" && (verb == "run" || verb == "check" || verb == ""))
                {
                    if (verb == "run" || verb == "check")
                    {
                        Say("Examining everything ...", false);
                        Doctor.RunAll();
                        int bad = Doctor.Count(Health.Bad), warn = Doctor.Count(Health.Warn);
                        Say(bad > 0
                            ? (bad == 1 ? "One thing is broken."
                                        : bad.ToString(CultureInfo.InvariantCulture) + " things are broken.")
                            : (warn > 0 ? (warn == 1 ? "One thing is worth a look."
                                          : warn.ToString(CultureInfo.InvariantCulture) +
                                            " things are worth a look.")
                                        : "Everything is well."),
                            bad > 0 || warn > 0);
                        _openCode = "MD";
                        _scroll = 0;
                        Invalidate();
                        return;
                    }
                }
                if (place.Code == "AU" && (verb == "check" || verb == "run"))
                {
                    List<string> fired = Rules.Evaluate();
                    Say(fired.Count == 0 ? "No rule had anything to say."
                                         : fired[0], fired.Count > 0);
                    _openCode = "AU";
                    Invalidate();
                    return;
                }
                if (place.Code == "LM" && (verb == "probe" || verb == "check"))
                {
                    StartBackgroundProbe();
                    Say("Knocking on every model ...", false);
                    _openCode = "LM";
                    Invalidate();
                    return;
                }

                if (isList && (verb == "add" || verb == "new"))
                {
                    if (payload.Length == 0) { Say("Add what. Try:  " + place.Code + " add ring the school", true); return; }
                    Store.Add(place.Code, payload);
                    Streams.Write("use", place.Code + " add");
                    _openCode = place.Code;
                    Say("On the " + place.Say + " list.", false);
                    Invalidate();
                    return;
                }
                if (isList && (verb == "done" || verb == "tick" || verb == "drop" || verb == "remove"))
                {
                    int idx;
                    if (!int.TryParse(payload, NumberStyles.Integer, CultureInfo.InvariantCulture, out idx))
                    { Say("Which one. Try:  " + place.Code + " " + verb + " 2", true); return; }
                    List<Item> items = Store.Load(place.Code);
                    if (idx < 1 || idx > items.Count)
                    { Say("There is no item " + payload + " on the " + place.Say + " list.", true); return; }
                    string what = items[idx - 1].Text;
                    if (verb == "done" || verb == "tick")
                    {
                        items[idx - 1].Done = true;
                        Streams.Write("win", what);
                        Say("Ticked off. " + what, false);
                    }
                    else
                    {
                        items.RemoveAt(idx - 1);
                        Say("Gone.", false);
                    }
                    Store.Save(place.Code, items);
                    _openCode = place.Code;
                    Invalidate();
                    return;
                }
                Open(place.Code, n);
                return;
            }

            // ---- plain English for a node -------------------------------
            Place byWords = Places.ByWords(low);
            if (byWords != null) { Open(byWords.Code, 0); return; }

            // ---- everything she was taught ------------------------------
            string lesson = Brain.Match(low);
            if (lesson != null) { Say(lesson, false); return; }

            // ---- the shrug, written down so it can be taught later -------
            _lastUnknown = text;
            try
            {
                Paths.EnsureData();
                File.AppendAllText(Paths.Unknown, text + Environment.NewLine);
            }
            catch { }
            Streams.Write("ask", text);

            // Auto is the whole point of having a model attached: rather than
            // shrug, she asks one, shows the answer, and waits to be told
            // whether it is worth keeping.
            Mind ready = Minds.Default();
            if (_autoAsk && ready != null && ready.Enabled)
            {
                AskMind(text, false);
                return;
            }
            Say("I do not know that one yet. Tell me:  teach " + Clip(text, 22) +
                " = your answer", true);
        }

        private void Teach(string rest)
        {
            if (rest.Length == 0)
            {
                if (!string.IsNullOrEmpty(_lastUnknown))
                    Say("Teach me the answer to \"" + Clip(_lastUnknown, 30) +
                        "\" with:  teach " + Clip(_lastUnknown, 20) + " = your answer", true);
                else
                    Say("Teach me like this:  teach who is scott = he wrote this system", true);
                return;
            }
            if (string.Equals(rest, "that", StringComparison.OrdinalIgnoreCase))
            {
                if (string.IsNullOrEmpty(_mindAnswer) || string.IsNullOrEmpty(_pendingQuestion))
                {
                    Say("Nothing to keep yet. Ask her something she does not know first.", true);
                    return;
                }
                string keepAnswer = _mindAnswer.Replace("\r", " ").Replace("\n", " ").Trim();
                if (keepAnswer.Length > 300) keepAnswer = keepAnswer.Substring(0, 297) + "...";
                Brain.Teach(_pendingQuestion, keepAnswer);
                Say("Kept. She answers that herself now, with no model involved.", false);
                _mindAnswer = null;
                _lastUnknown = null;
                return;
            }

            int eq = rest.IndexOf('=');
            string pattern, answer;
            if (eq > 0)
            {
                pattern = rest.Substring(0, eq).Trim();
                answer = rest.Substring(eq + 1).Trim();
            }
            else if (!string.IsNullOrEmpty(_lastUnknown))
            {
                pattern = _lastUnknown;
                answer = rest;
            }
            else
            {
                Say("I need both halves:  teach the wifi = it is on the router", true);
                return;
            }
            if (pattern.Length < 3) { Say("That pattern is too short to match on.", true); return; }
            if (answer.Length == 0) { Say("The answer half is empty.", true); return; }
            Brain.Teach(pattern, answer);
            _lastUnknown = null;
            Say("Learned. Anything containing \"" + pattern + "\" gets that answer now.", false);
        }

        // ===================================================================
        //  THE TEXT PANELS - help, the codes card, the fifty, the lessons
        // ===================================================================
        private string _infoTitle;
        private List<string> _infoLines;

        private void ShowInfo(string title, List<string> lines)
        {
            _infoTitle = title;
            _infoLines = lines;
            _openCode = "#INFO";
            _scroll = 0;
            Invalidate();
        }

        private void ShowHelp()
        {
            List<string> l = new List<string>();
            l.Add("$Two letters opens a node. That is the whole idea.");
            l.Add("");
            l.Add("#THE BOARD");
            l.Add("  board            the wall of nodes, and home");
            l.Add("  codes            the call sign card, all of them");
            l.Add("  PR   QS   NT     open one. PR1 picks the first item");
            l.Add("  QS add TEXT      put something on a list");
            l.Add("  QS done 2        tick it off.   QS drop 2 removes it");
            l.Add("  click a tile     the same as typing its code");
            l.Add("  click a box      ticks that line off");
            l.Add("  esc              puts the node away");
            l.Add("");
            l.Add("#PLAIN ENGLISH");
            l.Add("  bring my quests to main        show me the meters");
            l.Add("  what is on the want list       how are you");
            l.Add("");
            l.Add("#LEARNING");
            l.Add("  teach Q = A      teach her one answer");
            l.Add("  teach ANSWER     answers the last thing she missed");
            l.Add("  brain            every lesson she holds");
            l.Add("  unteach PATTERN  make her forget one");
            l.Add("");
            l.Add("#THE LOOK");
            l.Add("  theme attack     thirteen palettes, or open SE and click one");
            l.Add("  box blade        five border sets");
            l.Add("  voice off        stop her speaking");
            l.Add("");
            l.Add("#ELSEWHERE");
            l.Add("  features         the fifty things that came from Kohaku");
            l.Add("  name Scott       tell her who you are");
            l.Add("  bye              close the window");
            l.Add("");
            l.Add("$ai.bat is the same assistant in a console. Same lists, same");
            l.Add("$lessons, same memory - it reads and writes these very files.");
            ShowInfo("HELP", l);
        }

        private void ShowCodes()
        {
            List<string> l = new List<string>();
            l.Add("$Every call sign, read out of places.cfg. Add a line to that");
            l.Add("$file and it appears here, on the board, and in ai.bat.");
            l.Add("");
            string cat = null;
            for (int i = 0; i < Places.All.Count; i++)
            {
                Place p = Places.All[i];
                if (p.Category != cat)
                {
                    cat = p.Category;
                    l.Add("");
                    l.Add("#" + cat);
                }
                string code = p.Code.PadRight(6);
                string say = p.Say;
                if (say.Length > 20) say = say.Substring(0, 19) + "-";
                l.Add("  " + code + say.PadRight(22) + p.About);
            }
            ShowInfo("CALL SIGNS", l);
        }

        private void ShowFeatures()
        {
            List<string> l = new List<string>();
            l.Add("$What came across from Kohaku, and what this build added.");
            l.Add("");
            l.Add("#THE LOOK, NOW IT HAS REAL COLOUR");
            l.Add("  Thirteen palettes, ten colour tokens each, the values taken");
            l.Add("  from the Godot theme file rather than guessed at.");
            l.Add("  Five border sets on their own axis - a palette cannot");
            l.Add("  change a border and a border cannot change a colour.");
            l.Add("  The orb, the status bar, and a frameless window.");
            l.Add("");
            l.Add("#THE BOARD");
            l.Add("  A wall of node tiles, grouped the way places.cfg groups");
            l.Add("  them, with a live count on any list that has something on");
            l.Add("  it. Click a tile or type its code. Nothing replaces the");
            l.Add("  board - a node draws on top and esc puts it away.");
            l.Add("");
            l.Add("#THE GRAMMAR");
            l.Add("  33 call signs, numbered ones like PR1, plain English for");
            l.Add("  every one of them, and substring matching, which is the");
            l.Add("  rule Kohaku's table was written to survive.");
            l.Add("");
            l.Add("#THE PANELS");
            l.Add("  Lists you can tick with the mouse. Meters drawn off real");
            l.Add("  memory and disk readings. Nerves, device, her status, the");
            l.Add("  life hub, and a settings page you change by clicking.");
            l.Add("");
            l.Add("#SHARED WITH THE CONSOLE");
            l.Add("  places.cfg, ai_memory.db, ai_brain.db, every kh_ store and");
            l.Add("  all four guardian streams. Teach her in one, she knows it");
            l.Add("  in the other.");
            ShowInfo("THE FIFTY", l);
        }

        private void ShowBrain()
        {
            List<string> lessons = new List<string>();
            List<Lesson> all = Brain.Load();
            lessons.Add("$Everything she has been taught, and how often it fires.");
            lessons.Add("");
            if (all.Count == 0)
            {
                lessons.Add("  Nothing yet. Teach her with:  teach question = answer");
            }
            for (int i = 0; i < all.Count; i++)
            {
                string pat = all[i].Pattern;
                if (pat.Length > 28) pat = pat.Substring(0, 27) + "-";
                lessons.Add("  " + all[i].Hits.ToString(CultureInfo.InvariantCulture).PadLeft(4) +
                            "   " + pat.PadRight(30) + all[i].Answer);
            }
            ShowInfo("LESSONS", lessons);
        }

        // A line beginning # is a heading, $ is dim prose, anything else is
        // body. Cheap, and it keeps the content above readable as content.
        private void DrawInfo(Graphics g, Palette c, Rectangle r, int y)
        {
            if (_infoLines == null) return;
            SetScrollExtent(y + _infoLines.Count * 20 + 24, r.Bottom - 30);
            ClipBody(g, r, y - 6, 30);
            for (int i = 0; i < _infoLines.Count; i++)
            {
                int ly = y + i * 20 - _scroll;
                if (ly < r.Y + 76 || ly > r.Bottom - 24) continue;
                string line = _infoLines[i];
                if (line.Length == 0) continue;
                if (line[0] == '#')
                {
                    using (SolidBrush b = new SolidBrush(c.AccentCyan))
                        g.DrawString(line.Substring(1), _fBold, b, r.X + 24, ly);
                }
                else if (line[0] == '$')
                {
                    using (SolidBrush b = new SolidBrush(c.TextDim))
                        g.DrawString(line.Substring(1), _fBody, b, r.X + 24, ly);
                }
                else
                {
                    using (SolidBrush b = new SolidBrush(c.TextMain))
                        g.DrawString(line, _fBody, b, r.X + 24, ly);
                }
            }
            Unclip(g);
            using (SolidBrush b = new SolidBrush(c.TextDim))
                g.DrawString("wheel, page up and page down all scroll      " +
                             "esc goes back to the board", _fSmall, b, r.X + 24, r.Bottom - 22);
        }
    }

    // =======================================================================
    //  The one piece of Windows that managed code cannot answer on its own.
    // =======================================================================
    internal static class Native
    {
        [System.Runtime.InteropServices.StructLayout(
            System.Runtime.InteropServices.LayoutKind.Sequential)]
        private struct MemoryStatusEx
        {
            public uint Length;
            public uint MemoryLoad;
            public ulong TotalPhys;
            public ulong AvailPhys;
            public ulong TotalPageFile;
            public ulong AvailPageFile;
            public ulong TotalVirtual;
            public ulong AvailVirtual;
            public ulong AvailExtendedVirtual;
        }

        [System.Runtime.InteropServices.DllImport("kernel32.dll", SetLastError = true)]
        [return: System.Runtime.InteropServices.MarshalAs(
            System.Runtime.InteropServices.UnmanagedType.Bool)]
        private static extern bool GlobalMemoryStatusEx(ref MemoryStatusEx buffer);

        public static bool MemoryStatus(out ulong totalBytes, out ulong availBytes)
        {
            ulong ignoredA, ignoredB;
            return MemoryStatus(out totalBytes, out availBytes, out ignoredA, out ignoredB);
        }

        // The commit numbers matter as much as the physical ones: a model
        // larger than free RAM still runs if Windows can page it, it just
        // runs slowly. A model larger than the commit limit cannot run at all.
        public static bool MemoryStatus(out ulong totalBytes, out ulong availBytes,
                                        out ulong totalCommit, out ulong availCommit)
        {
            totalBytes = 0;
            availBytes = 0;
            totalCommit = 0;
            availCommit = 0;
            try
            {
                MemoryStatusEx m = new MemoryStatusEx();
                m.Length = (uint)System.Runtime.InteropServices.Marshal.SizeOf(typeof(MemoryStatusEx));
                if (!GlobalMemoryStatusEx(ref m)) return false;
                totalBytes = m.TotalPhys;
                availBytes = m.AvailPhys;
                totalCommit = m.TotalPageFile;
                availCommit = m.AvailPageFile;
                return true;
            }
            catch { return false; }
        }
    }

    internal static class Program
    {
        // ai.exe            opens on the board
        // ai.exe QS         opens straight onto a node
        // ai.exe "QS add ring the school"   does the thing and shows it
        [STAThread]
        private static void Main(string[] args)
        {
            string start = null;
            if (args != null && args.Length > 0)
                start = string.Join(" ", args).Trim();
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new BoardForm(start));
        }
    }
}
