// ===========================================================================
//  starpOS AI  -  the machine room
// ===========================================================================
//  Everything in here is engine, not screen: drives, the doctor, the LLM
//  minds and the rules that let her act on her own. ai.cs draws it.
//
//  Compiled together with ai.cs by build_ai.cmd. Kept apart because a file
//  you can read in one sitting is worth more than a file that holds
//  everything.
// ===========================================================================

using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Net;
using System.Text;
using System.Threading;

namespace StarpOS
{
    // =======================================================================
    //  A VERY SMALL JSON READER
    //  Only ever asked to pull one string value out of a reply that this
    //  program just asked for. It is not a parser and does not pretend to
    //  be one - if the shape of a reply ever gets complicated, replace this
    //  rather than teach it to cope.
    // =======================================================================
    internal static class Json
    {
        public static string Escape(string s)
        {
            if (s == null) return "";
            StringBuilder sb = new StringBuilder(s.Length + 16);
            for (int i = 0; i < s.Length; i++)
            {
                char ch = s[i];
                switch (ch)
                {
                    case '"': sb.Append("\\\""); break;
                    case '\\': sb.Append("\\\\"); break;
                    case '\n': sb.Append("\\n"); break;
                    case '\r': sb.Append("\\r"); break;
                    case '\t': sb.Append("\\t"); break;
                    default:
                        if (ch < 32) sb.Append("\\u").Append(((int)ch).ToString("x4"));
                        else sb.Append(ch);
                        break;
                }
            }
            return sb.ToString();
        }

        // Finds "key" : "value" and returns the unescaped value.
        public static string GetString(string json, string key)
        {
            if (string.IsNullOrEmpty(json)) return null;
            string needle = "\"" + key + "\"";
            int i = json.IndexOf(needle, StringComparison.Ordinal);
            while (i >= 0)
            {
                int p = i + needle.Length;
                while (p < json.Length && (json[p] == ' ' || json[p] == ':' || json[p] == '\t')) p++;
                if (p < json.Length && json[p] == '"')
                {
                    p++;
                    StringBuilder sb = new StringBuilder();
                    while (p < json.Length)
                    {
                        char ch = json[p];
                        if (ch == '\\' && p + 1 < json.Length)
                        {
                            char n = json[p + 1];
                            if (n == 'n') sb.Append('\n');
                            else if (n == 'r') { }
                            else if (n == 't') sb.Append('\t');
                            else if (n == 'u' && p + 5 < json.Length)
                            {
                                int code;
                                if (int.TryParse(json.Substring(p + 2, 4),
                                    NumberStyles.HexNumber, CultureInfo.InvariantCulture, out code))
                                    sb.Append((char)code);
                                p += 4;
                            }
                            else sb.Append(n);
                            p += 2;
                            continue;
                        }
                        if (ch == '"') return sb.ToString();
                        sb.Append(ch);
                        p++;
                    }
                    return sb.ToString();
                }
                i = json.IndexOf(needle, i + 1, StringComparison.Ordinal);
            }
            return null;
        }

        // "key": 1234567  - no quotes, so GetString cannot see it.
        public static long GetLong(string json, string key, int from)
        {
            if (string.IsNullOrEmpty(json)) return -1;
            string needle = "\"" + key + "\"";
            int i = json.IndexOf(needle, from, StringComparison.Ordinal);
            if (i < 0) return -1;
            int p = i + needle.Length;
            while (p < json.Length && (json[p] == ' ' || json[p] == ':')) p++;
            int start = p;
            while (p < json.Length && (char.IsDigit(json[p]))) p++;
            if (p == start) return -1;
            long v;
            if (long.TryParse(json.Substring(start, p - start), out v)) return v;
            return -1;
        }

        // Every value of a repeated key, which is how model lists arrive.
        public static List<string> GetStrings(string json, string key)
        {
            List<string> found = new List<string>();
            if (string.IsNullOrEmpty(json)) return found;
            string needle = "\"" + key + "\"";
            int i = json.IndexOf(needle, StringComparison.Ordinal);
            while (i >= 0)
            {
                string one = GetString(json.Substring(i), key);
                if (!string.IsNullOrEmpty(one) && !found.Contains(one)) found.Add(one);
                i = json.IndexOf(needle, i + 1, StringComparison.Ordinal);
            }
            return found;
        }
    }

    // =======================================================================
    //  DRIVES
    //  What is actually plugged into this machine. A real OS knows; so
    //  should this one.
    // =======================================================================
    internal sealed class DriveRow
    {
        public string Letter = "";
        public string Kind = "";
        public string Label = "";
        public string Format = "";
        public bool Ready;
        public long Size;
        public long Free;

        public int UsedPercent
        {
            get
            {
                if (Size <= 0) return 0;
                return (int)(100 - (Free * 100L / Size));
            }
        }
    }

    internal static class Drives
    {
        public static List<DriveRow> All()
        {
            List<DriveRow> rows = new List<DriveRow>();
            DriveInfo[] found;
            try { found = DriveInfo.GetDrives(); }
            catch { return rows; }

            for (int i = 0; i < found.Length; i++)
            {
                DriveRow r = new DriveRow();
                DriveInfo d = found[i];
                r.Letter = d.Name;
                switch (d.DriveType)
                {
                    case DriveType.Fixed: r.Kind = "hard disk"; break;
                    case DriveType.Removable: r.Kind = "removable"; break;
                    case DriveType.CDRom: r.Kind = "disc drive"; break;
                    case DriveType.Network: r.Kind = "network"; break;
                    case DriveType.Ram: r.Kind = "ram disk"; break;
                    default: r.Kind = "unknown"; break;
                }
                try
                {
                    r.Ready = d.IsReady;
                    if (r.Ready)
                    {
                        r.Label = d.VolumeLabel;
                        r.Format = d.DriveFormat;
                        r.Size = d.TotalSize;
                        r.Free = d.AvailableFreeSpace;
                    }
                    else
                    {
                        r.Label = "no media";
                    }
                }
                catch
                {
                    r.Ready = false;
                    r.Label = "unreadable";
                }
                rows.Add(r);
            }
            return rows;
        }

        public static string Gb(long bytes)
        {
            if (bytes <= 0) return "-";
            double gb = bytes / 1073741824.0;
            if (gb < 1.0) return (bytes / 1048576.0).ToString("0", CultureInfo.InvariantCulture) + " MB";
            return gb.ToString("0.0", CultureInfo.InvariantCulture) + " GB";
        }
    }

    // =======================================================================
    //  MINDS
    //  An LLM she can ask. More than one, on purpose: two models given the
    //  same question rarely give the same answer, and seeing both is worth
    //  more than trusting either.
    //
    //  minds.cfg holds them:   name|kind|endpoint|model|enabled|key
    //    kind ollama  talks to a local Ollama at /api/generate
    //    kind openai  talks to anything with an OpenAI shaped
    //                 /v1/chat/completions - LM Studio, Jan, llama.cpp
    //                 server, or a hosted one if a key is put in the file
    //
    //  NOTHING IS SENT ANYWHERE UNLESS A MIND IS ENABLED AND POINTED AT A
    //  REAL ENDPOINT. Local ones stay on this machine.
    // =======================================================================
    internal sealed class Mind
    {
        public string Name = "";
        public string Kind = "ollama";
        public string Endpoint = "http://127.0.0.1:11434";
        public string Model = "";
        public bool Enabled = true;
        public string Key = "";

        public bool Online;
        public int LatencyMs = -1;
        public string LastError = "";
        public bool Local
        {
            get
            {
                string e = (Endpoint == null ? "" : Endpoint.ToLowerInvariant());
                return e.Contains("127.0.0.1") || e.Contains("localhost");
            }
        }
    }

    internal static class Minds
    {
        public static readonly List<Mind> All = new List<Mind>();
        public static string ConfigPath;

        public static void Load(string path)
        {
            ConfigPath = path;
            All.Clear();
            if (!File.Exists(path)) { WriteDefault(path); }
            string[] lines;
            try { lines = File.ReadAllLines(path); }
            catch { return; }
            for (int i = 0; i < lines.Length; i++)
            {
                string line = lines[i].Trim();
                if (line.Length == 0 || line[0] == '#') continue;
                string[] c = line.Split('|');
                if (c.Length < 5) continue;
                Mind m = new Mind();
                m.Name = c[0].Trim();
                m.Kind = c[1].Trim().ToLowerInvariant();
                m.Endpoint = c[2].Trim();
                m.Model = c[3].Trim();
                m.Enabled = c[4].Trim() == "1";
                m.Key = c.Length > 5 ? c[5].Trim() : "";
                All.Add(m);
            }
        }

        private static void WriteDefault(string path)
        {
            try
            {
                StringBuilder sb = new StringBuilder();
                sb.AppendLine("# =========================================================================");
                sb.AppendLine("#  minds.cfg  -  the models starpOS may ask");
                sb.AppendLine("# =========================================================================");
                sb.AppendLine("#  FORMAT:  name|kind|endpoint|model|enabled|key");
                sb.AppendLine("#");
                sb.AppendLine("#    kind ollama   a local Ollama. No key, nothing leaves the machine.");
                sb.AppendLine("#    kind openai   anything with an OpenAI shaped API at");
                sb.AppendLine("#                  /v1/chat/completions - LM Studio, Jan, llama.cpp");
                sb.AppendLine("#                  server, or a hosted one if you put a key in.");
                sb.AppendLine("#");
                sb.AppendLine("#    enabled  1 or 0. A 0 mind is never contacted at all.");
                sb.AppendLine("#    key      left empty for local models, which need none.");
                sb.AppendLine("#");
                sb.AppendLine("#  WHY MORE THAN ONE");
                sb.AppendLine("#  Two models given the same question rarely answer the same way. The");
                sb.AppendLine("#  council command asks every enabled mind at once and shows the answers");
                sb.AppendLine("#  side by side, so the disagreement is visible instead of hidden.");
                sb.AppendLine("#");
                sb.AppendLine("#  WHAT ACTUALLY LIMITS A LOCAL MODEL IS RAM, NOT DISK.");
                sb.AppendLine("#  A 2 GB model on a machine with 400 GB free disk and 1 GB free");
                sb.AppendLine("#  memory will page to disk and crawl. The doctor, on MD, measures");
                sb.AppendLine("#  both and says which one you are short of.");
                sb.AppendLine("#");
                sb.AppendLine("#  ADDING A SECOND LOCAL MODEL - free, offline, one command:");
                sb.AppendLine("#      ollama pull qwen2.5:3b");
                sb.AppendLine("#  then set enabled to 1 on the second line below.");
                sb.AppendLine("#");
                sb.AppendLine("#  NOTHING IS SENT ANYWHERE unless a mind is enabled AND its endpoint is");
                sb.AppendLine("#  not local. The two below are both on this machine.");
                sb.AppendLine("# =========================================================================");
                sb.AppendLine();
                sb.AppendLine("ollama|ollama|http://127.0.0.1:11434|llama3.2:3b|1|");
                sb.AppendLine("second|ollama|http://127.0.0.1:11434|qwen2.5:3b|0|");
                sb.AppendLine("studio|openai|http://127.0.0.1:1234|local-model|0|");
                File.WriteAllText(path, sb.ToString());
            }
            catch { }
        }

        public static void Save()
        {
            if (string.IsNullOrEmpty(ConfigPath)) return;
            try
            {
                List<string> keep = new List<string>();
                if (File.Exists(ConfigPath))
                {
                    string[] lines = File.ReadAllLines(ConfigPath);
                    for (int i = 0; i < lines.Length; i++)
                    {
                        string t = lines[i].Trim();
                        if (t.Length == 0 || t[0] == '#') keep.Add(lines[i]);
                    }
                }
                for (int i = 0; i < All.Count; i++)
                {
                    Mind m = All[i];
                    keep.Add(m.Name + "|" + m.Kind + "|" + m.Endpoint + "|" + m.Model +
                             "|" + (m.Enabled ? "1" : "0") + "|" + m.Key);
                }
                File.WriteAllLines(ConfigPath, keep.ToArray());
            }
            catch { }
        }

        public static Mind ByName(string name)
        {
            if (name == null) return null;
            for (int i = 0; i < All.Count; i++)
                if (string.Equals(All[i].Name, name.Trim(), StringComparison.OrdinalIgnoreCase))
                    return All[i];
            return null;
        }

        public static Mind Default()
        {
            for (int i = 0; i < All.Count; i++)
                if (All[i].Enabled && All[i].Online) return All[i];
            for (int i = 0; i < All.Count; i++)
                if (All[i].Enabled) return All[i];
            return null;
        }

        // -------------------------------------------------------------------
        //  Is it there, and what does it have. Cheap, short timeout, safe to
        //  call on a timer.
        // -------------------------------------------------------------------
        public static void Probe(Mind m)
        {
            m.Online = false;
            m.LatencyMs = -1;
            m.LastError = "";
            if (!m.Enabled) { m.LastError = "switched off"; return; }
            DateTime t0 = DateTime.UtcNow;
            try
            {
                string url = m.Kind == "ollama"
                    ? m.Endpoint.TrimEnd('/') + "/api/tags"
                    : m.Endpoint.TrimEnd('/') + "/v1/models";
                string body = Http(url, null, m.Key, 3500);
                m.LatencyMs = (int)(DateTime.UtcNow - t0).TotalMilliseconds;
                m.Online = body != null;
                if (body == null) m.LastError = "no answer";
            }
            catch (Exception ex)
            {
                m.LastError = Short(ex.Message);
            }
        }

        public static List<string> Models(Mind m)
        {
            try
            {
                string url = m.Kind == "ollama"
                    ? m.Endpoint.TrimEnd('/') + "/api/tags"
                    : m.Endpoint.TrimEnd('/') + "/v1/models";
                string body = Http(url, null, m.Key, 4000);
                if (body == null) return new List<string>();
                List<string> names = Json.GetStrings(body, m.Kind == "ollama" ? "name" : "id");
                return names;
            }
            catch { return new List<string>(); }
        }

        // -------------------------------------------------------------------
        //  Ask it something. Blocking - always call this off the UI thread.
        // -------------------------------------------------------------------
        // Ollama reports a byte size per model in /api/tags. Worth knowing,
        // because a model that does not fit in free memory does not run
        // slowly - it fails to load at all, after a long wait that looks
        // exactly like a hang.
        public static long ModelSize(Mind m)
        {
            try
            {
                if (m.Kind != "ollama") return -1;
                string body = Http(m.Endpoint.TrimEnd('/') + "/api/tags", null, m.Key, 4000);
                if (body == null) return -1;
                int at = body.IndexOf("\"" + m.Model + "\"", StringComparison.Ordinal);
                if (at < 0) return -1;
                return Json.GetLong(body, "size", at);
            }
            catch { return -1; }
        }

        public static string Ask(Mind m, string prompt, int timeoutMs)
        {
            if (m == null) return null;
            try
            {
                string url, body;
                if (m.Kind == "ollama")
                {
                    url = m.Endpoint.TrimEnd('/') + "/api/generate";
                    // keep_alive holds the model in memory after the first
                    // answer, so only the first question pays the load cost.
                    body = "{\"model\":\"" + Json.Escape(m.Model) +
                           "\",\"prompt\":\"" + Json.Escape(prompt) +
                           "\",\"stream\":false,\"keep_alive\":\"30m\"}";
                }
                else
                {
                    url = m.Endpoint.TrimEnd('/') + "/v1/chat/completions";
                    body = "{\"model\":\"" + Json.Escape(m.Model) +
                           "\",\"messages\":[{\"role\":\"user\",\"content\":\"" +
                           Json.Escape(prompt) + "\"}],\"stream\":false}";
                }
                string reply = Http(url, body, m.Key, timeoutMs);
                if (reply == null) return null;
                string text = m.Kind == "ollama"
                    ? Json.GetString(reply, "response")
                    : Json.GetString(reply, "content");
                if (string.IsNullOrEmpty(text)) text = Json.GetString(reply, "error");
                return text;
            }
            catch (Exception ex)
            {
                m.LastError = Short(ex.Message);
                return null;
            }
        }

        private static string Http(string url, string jsonBody, string key, int timeoutMs)
        {
            HttpWebRequest req = (HttpWebRequest)WebRequest.Create(url);
            req.Timeout = timeoutMs;
            req.ReadWriteTimeout = timeoutMs;
            req.Method = jsonBody == null ? "GET" : "POST";
            req.ContentType = "application/json";
            req.Proxy = null;
            if (!string.IsNullOrEmpty(key))
                req.Headers.Add("Authorization", "Bearer " + key);
            if (jsonBody != null)
            {
                byte[] data = Encoding.UTF8.GetBytes(jsonBody);
                req.ContentLength = data.Length;
                using (Stream s = req.GetRequestStream()) s.Write(data, 0, data.Length);
            }
            using (HttpWebResponse res = (HttpWebResponse)req.GetResponse())
            using (StreamReader sr = new StreamReader(res.GetResponseStream(), Encoding.UTF8))
                return sr.ReadToEnd();
        }

        private static string Short(string s)
        {
            if (s == null) return "";
            if (s.Length > 60) s = s.Substring(0, 59) + "-";
            return s.Replace("\r", " ").Replace("\n", " ");
        }
    }

    // =======================================================================
    //  THE DOCTOR
    //  One pass over everything that can be broken, with a verdict and a
    //  reading for each. Every check answers three things: what it looked
    //  at, whether it is well, and how long it took to find out.
    // =======================================================================
    internal enum Health { Good, Warn, Bad }

    internal sealed class Check
    {
        public string Group = "";
        public string Name = "";
        public Health State = Health.Good;
        public string Detail = "";
        public int Ms;
    }

    internal static class Doctor
    {
        public static DateTime LastRun = DateTime.MinValue;
        public static readonly List<Check> Results = new List<Check>();

        public static int Count(Health h)
        {
            int n = 0;
            for (int i = 0; i < Results.Count; i++) if (Results[i].State == h) n++;
            return n;
        }

        public static void RunAll()
        {
            Results.Clear();
            LastRun = DateTime.Now;

            // ---- the files she is made of -------------------------------
            FileCheck("FILES", "places.cfg", Paths.Places, true);
            FileCheck("FILES", "ai.bat", Path.Combine(Paths.Sys, "ai.bat"), false);
            FileCheck("FILES", "ai.cs", Path.Combine(Paths.Sys, "ai.cs"), false);
            FileCheck("FILES", "speak.vbs", Path.Combine(Paths.Sys, "speak.vbs"), false);
            FileCheck("FILES", "starpos.cfg", Paths.Config, false);
            FileCheck("FILES", "apps.reg", Path.Combine(Paths.Sys, "apps.reg"), false);
            FileCheck("FILES", "users.db", Path.Combine(Paths.Sys, "users.db"), false);
            FileCheck("FILES", "minds.cfg", Path.Combine(Paths.Sys, "minds.cfg"), false);

            // ---- can she actually write anything down -------------------
            Time("STORAGE", "data folder writable", delegate(Check c)
            {
                try
                {
                    Paths.EnsureData();
                    string probe = Path.Combine(Paths.Data, "kh_doctor.tmp");
                    File.WriteAllText(probe, "probe");
                    string back = File.ReadAllText(probe);
                    File.Delete(probe);
                    if (back != "probe") { c.State = Health.Bad; c.Detail = "wrote, read back wrong"; }
                    else c.Detail = "write, read and delete all fine";
                }
                catch (Exception ex)
                {
                    c.State = Health.Bad;
                    c.Detail = "STARP-0202  " + ex.GetType().Name;
                }
            });

            // ---- drives --------------------------------------------------
            Time("STORAGE", "drives", delegate(Check c)
            {
                List<DriveRow> rows = Drives.All();
                int ready = 0, tight = 0;
                for (int i = 0; i < rows.Count; i++)
                {
                    if (!rows[i].Ready) continue;
                    ready++;
                    if (rows[i].Size > 0 && rows[i].UsedPercent >= 90) tight++;
                }
                c.Detail = rows.Count.ToString(CultureInfo.InvariantCulture) + " attached, " +
                           ready.ToString(CultureInfo.InvariantCulture) + " ready";
                if (tight > 0)
                {
                    c.State = Health.Warn;
                    c.Detail += ", " + tight.ToString(CultureInfo.InvariantCulture) + " nearly full";
                }
            });

            Time("STORAGE", "room on the starpOS drive", delegate(Check c)
            {
                try
                {
                    DriveInfo d = new DriveInfo(Path.GetPathRoot(Paths.Sys));
                    double freeGb = d.AvailableFreeSpace / 1073741824.0;
                    c.Detail = freeGb.ToString("0.0", CultureInfo.InvariantCulture) + " GB free";
                    if (freeGb < 1.0) c.State = Health.Bad;
                    else if (freeGb < 5.0) c.State = Health.Warn;
                }
                catch { c.State = Health.Warn; c.Detail = "could not read"; }
            });

            // ---- memory --------------------------------------------------
            Time("MACHINE", "memory", delegate(Check c)
            {
                ulong total, avail;
                if (!Native.MemoryStatus(out total, out avail))
                {
                    c.State = Health.Warn;
                    c.Detail = "not reported";
                    return;
                }
                int used = (int)(100 - (avail * 100 / total));
                c.Detail = used.ToString(CultureInfo.InvariantCulture) + " percent in use, " +
                           (avail / 1048576).ToString(CultureInfo.InvariantCulture) + " MB free";
                if (used >= 92) c.State = Health.Bad;
                else if (used >= 80) c.State = Health.Warn;
            });

            // ---- the voice ----------------------------------------------
            Time("SERVICES", "speech engine", delegate(Check c)
            {
                try
                {
                    System.Speech.Synthesis.SpeechSynthesizer s =
                        new System.Speech.Synthesis.SpeechSynthesizer();
                    int voices = s.GetInstalledVoices().Count;
                    s.Dispose();
                    c.Detail = voices.ToString(CultureInfo.InvariantCulture) + " voice(s) installed";
                    if (voices == 0) { c.State = Health.Warn; c.Detail = "no voices  STARP-0501"; }
                }
                catch (Exception ex)
                {
                    c.State = Health.Warn;
                    c.Detail = "STARP-0501  " + ex.GetType().Name;
                }
            });

            // ---- what she has learned -----------------------------------
            Time("LEARNING", "lessons", delegate(Check c)
            {
                int n = Brain.Load().Count;
                c.Detail = n.ToString(CultureInfo.InvariantCulture) + " taught";
                if (n == 0) { c.State = Health.Warn; c.Detail = "nothing taught yet - open TH"; }
            });

            Time("LEARNING", "unanswered backlog", delegate(Check c)
            {
                int n = 0;
                try { if (File.Exists(Paths.Unknown)) n = File.ReadAllLines(Paths.Unknown).Length; }
                catch { }
                c.Detail = n.ToString(CultureInfo.InvariantCulture) + " waiting to be taught";
                if (n > 25) c.State = Health.Warn;
            });

            // ---- the minds ----------------------------------------------
            for (int i = 0; i < Minds.All.Count; i++)
            {
                Mind m = Minds.All[i];
                Check c = new Check();
                c.Group = "MINDS";
                c.Name = m.Name + "  " + m.Model;
                DateTime t0 = DateTime.UtcNow;
                if (!m.Enabled)
                {
                    c.State = Health.Warn;
                    c.Detail = "switched off in minds.cfg";
                }
                else
                {
                    Minds.Probe(m);
                    if (m.Online)
                    {
                        List<string> models = Minds.Models(m);
                        bool has = models.Contains(m.Model);
                        c.Detail = m.LatencyMs.ToString(CultureInfo.InvariantCulture) + " ms, " +
                                   models.Count.ToString(CultureInfo.InvariantCulture) + " model(s)";
                        if (!has)
                        {
                            c.State = Health.Warn;
                            c.Detail += ", but " + m.Model + " is not one of them";
                        }
                    }
                    else
                    {
                        c.State = Health.Bad;
                        c.Detail = "not answering on " + m.Endpoint +
                                   (string.IsNullOrEmpty(m.LastError) ? "" : "  -  " + m.LastError);
                    }
                }
                c.Ms = (int)(DateTime.UtcNow - t0).TotalMilliseconds;
                Results.Add(c);
            }

            // ---- can this machine actually RUN what it is pointed at ----
            // MEMORY, not disk. Worth being explicit about, because a machine
            // with hundreds of free gigabytes and no free RAM looks fine from
            // every other angle and this is the one thing that catches it.
            Time("MINDS", "model against free RAM", delegate(Check c)
            {
                ulong total, avail, commitTotal, commitAvail;
                if (!Native.MemoryStatus(out total, out avail, out commitTotal, out commitAvail))
                {
                    c.State = Health.Warn;
                    c.Detail = "memory not reported";
                    return;
                }
                long biggest = -1;
                string worst = "";
                for (int i = 0; i < Minds.All.Count; i++)
                {
                    Mind m = Minds.All[i];
                    if (!m.Enabled || !m.Online) continue;
                    long sz = Minds.ModelSize(m);
                    if (sz > biggest) { biggest = sz; worst = m.Model; }
                }
                if (biggest <= 0)
                {
                    c.Detail = "no local model to weigh";
                    return;
                }
                double needGb = biggest / 1073741824.0;
                double freeGb = avail / 1073741824.0;
                double totalGb = total / 1073741824.0;
                double commitGb = commitAvail / 1073741824.0;
                string need = needGb.ToString("0.0", CultureInfo.InvariantCulture);
                string free = freeGb.ToString("0.0", CultureInfo.InvariantCulture);

                if (needGb > commitGb)
                {
                    c.State = Health.Bad;
                    c.Detail = worst + " needs " + need + " GB, only " +
                               commitGb.ToString("0.0", CultureInfo.InvariantCulture) +
                               " GB can be committed. It cannot run here.";
                }
                else if (needGb > freeGb)
                {
                    c.State = Health.Warn;
                    c.Detail = worst + " needs " + need + " GB RAM, " + free +
                               " GB free of " +
                               totalGb.ToString("0.0", CultureInfo.InvariantCulture) +
                               " GB. Windows will page it, so the first answer is slow.";
                }
                else if (needGb > freeGb * 0.75)
                {
                    c.State = Health.Warn;
                    c.Detail = worst + " needs " + need + " GB RAM, " + free +
                               " GB free. Tight. Expect a long first answer.";
                }
                else
                {
                    c.Detail = worst + " needs " + need + " GB RAM, " + free + " GB free. Room to run.";
                }
            });

            // ---- the other face -----------------------------------------
            Time("SERVICES", "log streams", delegate(Check c)
            {
                int alive = 0;
                string[] names = new string[] { "1.log", "2.log", "3.log" };
                for (int i = 0; i < names.Length; i++)
                    if (File.Exists(Path.Combine(Paths.Data, names[i]))) alive++;
                c.Detail = alive.ToString(CultureInfo.InvariantCulture) + " of 3 streams present";
                if (alive == 0) { c.State = Health.Warn; c.Detail = "no streams  STARP-0202"; }
            });
        }

        private static void FileCheck(string group, string name, string path, bool fatal)
        {
            Check c = new Check();
            c.Group = group;
            c.Name = name;
            DateTime t0 = DateTime.UtcNow;
            if (File.Exists(path))
            {
                try
                {
                    FileInfo fi = new FileInfo(path);
                    c.Detail = fi.Length.ToString("#,0", CultureInfo.InvariantCulture) + " bytes, " +
                               fi.LastWriteTime.ToString("dd MMM HH:mm", CultureInfo.InvariantCulture);
                }
                catch { c.Detail = "present"; }
            }
            else
            {
                c.State = fatal ? Health.Bad : Health.Warn;
                c.Detail = "missing";
            }
            c.Ms = (int)(DateTime.UtcNow - t0).TotalMilliseconds;
            Results.Add(c);
        }

        private delegate void CheckBody(Check c);

        private static void Time(string group, string name, CheckBody body)
        {
            Check c = new Check();
            c.Group = group;
            c.Name = name;
            DateTime t0 = DateTime.UtcNow;
            try { body(c); }
            catch (Exception ex)
            {
                c.State = Health.Bad;
                c.Detail = ex.GetType().Name;
            }
            c.Ms = (int)(DateTime.UtcNow - t0).TotalMilliseconds;
            Results.Add(c);
        }
    }

    // =======================================================================
    //  RULES
    //  The part that lets her act without being asked. A rule is a plain
    //  sentence: WHEN something is true, DO one thing. They are listed on
    //  screen with what they last did, because an automation you cannot see
    //  is one you cannot trust.
    //
    //  rules.cfg:   enabled|when|threshold|then|note
    // =======================================================================
    internal sealed class Rule
    {
        public bool Enabled = true;
        public string When = "";
        public int Threshold;
        public string Then = "";
        public string Note = "";
        public string LastFired = "never";
    }

    internal static class Rules
    {
        public static readonly List<Rule> All = new List<Rule>();
        public static string ConfigPath;

        public static readonly string[] Whens = new string[]
        {
            "unanswered_over", "quests_over", "disk_below_gb", "memory_over", "mind_offline"
        };
        public static readonly string[] Thens = new string[]
        {
            "tell_me", "ask_a_mind", "write_a_note", "flag_it"
        };

        public static void Load(string path)
        {
            ConfigPath = path;
            All.Clear();
            if (!File.Exists(path)) WriteDefault(path);
            try
            {
                string[] lines = File.ReadAllLines(path);
                for (int i = 0; i < lines.Length; i++)
                {
                    string line = lines[i].Trim();
                    if (line.Length == 0 || line[0] == '#') continue;
                    string[] c = line.Split('|');
                    if (c.Length < 5) continue;
                    Rule r = new Rule();
                    r.Enabled = c[0].Trim() == "1";
                    r.When = c[1].Trim();
                    int.TryParse(c[2].Trim(), out r.Threshold);
                    r.Then = c[3].Trim();
                    r.Note = c[4].Trim();
                    All.Add(r);
                }
            }
            catch { }
        }

        private static void WriteDefault(string path)
        {
            try
            {
                StringBuilder sb = new StringBuilder();
                sb.AppendLine("# =========================================================================");
                sb.AppendLine("#  rules.cfg  -  when she is allowed to act on her own");
                sb.AppendLine("# =========================================================================");
                sb.AppendLine("#  FORMAT:  enabled|when|threshold|then|note");
                sb.AppendLine("#");
                sb.AppendLine("#  WHEN one of:");
                sb.AppendLine("#     unanswered_over   more than N questions she could not answer");
                sb.AppendLine("#     quests_over       more than N quests still open");
                sb.AppendLine("#     disk_below_gb     less than N GB free on the starpOS drive");
                sb.AppendLine("#     memory_over       more than N percent of memory in use");
                sb.AppendLine("#     mind_offline      any enabled model has stopped answering");
                sb.AppendLine("#");
                sb.AppendLine("#  THEN one of:");
                sb.AppendLine("#     tell_me           say it in the bar, next time you look");
                sb.AppendLine("#     ask_a_mind        ask a model about it and show the answer");
                sb.AppendLine("#     write_a_note      put it on the NT list so it is not lost");
                sb.AppendLine("#     flag_it           write it to the flag stream and nothing else");
                sb.AppendLine("#");
                sb.AppendLine("#  Every rule is listed on the AU panel with what it last did. An");
                sb.AppendLine("#  automation you cannot see is one you cannot trust, so none of these");
                sb.AppendLine("#  ever act silently.");
                sb.AppendLine("# =========================================================================");
                sb.AppendLine();
                sb.AppendLine("1|unanswered_over|5|tell_me|Nudge me when the teaching pile builds up");
                sb.AppendLine("1|disk_below_gb|5|tell_me|Warn me before the drive fills");
                sb.AppendLine("1|memory_over|90|tell_me|Warn me when the machine is struggling");
                sb.AppendLine("1|mind_offline|0|tell_me|Say so when a model stops answering");
                sb.AppendLine("0|quests_over|10|write_a_note|Note it when the checklist gets long");
                File.WriteAllText(path, sb.ToString());
            }
            catch { }
        }

        public static void Save()
        {
            if (string.IsNullOrEmpty(ConfigPath)) return;
            try
            {
                List<string> keep = new List<string>();
                if (File.Exists(ConfigPath))
                {
                    string[] lines = File.ReadAllLines(ConfigPath);
                    for (int i = 0; i < lines.Length; i++)
                    {
                        string t = lines[i].Trim();
                        if (t.Length == 0 || t[0] == '#') keep.Add(lines[i]);
                    }
                }
                for (int i = 0; i < All.Count; i++)
                {
                    Rule r = All[i];
                    keep.Add((r.Enabled ? "1" : "0") + "|" + r.When + "|" +
                             r.Threshold.ToString(CultureInfo.InvariantCulture) + "|" +
                             r.Then + "|" + r.Note);
                }
                File.WriteAllLines(ConfigPath, keep.ToArray());
            }
            catch { }
        }

        // Returns the sentences that fired, so the screen can show them.
        public static List<string> Evaluate()
        {
            List<string> fired = new List<string>();
            for (int i = 0; i < All.Count; i++)
            {
                Rule r = All[i];
                if (!r.Enabled) continue;
                int reading = 0;
                bool hit = false;
                switch (r.When)
                {
                    case "unanswered_over":
                        try { if (File.Exists(Paths.Unknown)) reading = File.ReadAllLines(Paths.Unknown).Length; }
                        catch { }
                        hit = reading > r.Threshold;
                        break;
                    case "quests_over":
                        reading = Store.OpenCount("QS");
                        hit = reading > r.Threshold;
                        break;
                    case "disk_below_gb":
                        try
                        {
                            DriveInfo d = new DriveInfo(Path.GetPathRoot(Paths.Sys));
                            reading = (int)(d.AvailableFreeSpace / 1073741824L);
                            hit = reading < r.Threshold;
                        }
                        catch { }
                        break;
                    case "memory_over":
                        ulong total, avail;
                        if (Native.MemoryStatus(out total, out avail) && total > 0)
                        {
                            reading = (int)(100 - (avail * 100 / total));
                            hit = reading > r.Threshold;
                        }
                        break;
                    case "mind_offline":
                        for (int k = 0; k < Minds.All.Count; k++)
                            if (Minds.All[k].Enabled && !Minds.All[k].Online) { hit = true; reading++; }
                        break;
                }
                if (!hit) continue;
                r.LastFired = DateTime.Now.ToString("HH:mm", CultureInfo.InvariantCulture);
                string sentence = Sentence(r, reading);
                fired.Add(sentence);
                Act(r, sentence);
            }
            return fired;
        }

        private static string Sentence(Rule r, int reading)
        {
            string n = reading.ToString(CultureInfo.InvariantCulture);
            switch (r.When)
            {
                case "unanswered_over": return n + " questions are waiting to be taught. Open TH.";
                case "quests_over": return n + " quests are still open.";
                case "disk_below_gb": return "Only " + n + " GB left on the starpOS drive.";
                case "memory_over": return "Memory is " + n + " percent used.";
                case "mind_offline": return n + " model(s) stopped answering. Open MD.";
            }
            return r.Note;
        }

        private static void Act(Rule r, string sentence)
        {
            switch (r.Then)
            {
                case "write_a_note":
                    Store.Add("NT", sentence);
                    break;
                case "flag_it":
                    Streams.Write("flag", sentence);
                    break;
                default:
                    Streams.Write("flag", sentence);
                    break;
            }
        }
    }
}
