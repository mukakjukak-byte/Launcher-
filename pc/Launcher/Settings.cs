using System;
using System.IO;
using System.Text;

namespace CrmpLauncher
{
    /// <summary>Ник и путь к игре: %AppData%\CrmpLauncher\settings.ini</summary>
    internal sealed class Settings
    {
        public string Nickname = "";
        public string GamePath = "";
        public bool CloseAfterLaunch = true;

        private static string FilePath =>
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
                "CrmpLauncher", "settings.ini");

        public static Settings Load()
        {
            var s = new Settings();
            try
            {
                if (!File.Exists(FilePath)) return s;
                foreach (var line in File.ReadAllLines(FilePath, Encoding.UTF8))
                {
                    int eq = line.IndexOf('=');
                    if (eq <= 0) continue;
                    string key = line.Substring(0, eq).Trim();
                    string val = line.Substring(eq + 1).Trim();
                    switch (key)
                    {
                        case "Nickname": s.Nickname = val; break;
                        case "GamePath": s.GamePath = val; break;
                        case "CloseAfterLaunch": s.CloseAfterLaunch = val != "0"; break;
                    }
                }
            }
            catch { }
            return s;
        }

        public void Save()
        {
            try
            {
                Directory.CreateDirectory(Path.GetDirectoryName(FilePath));
                File.WriteAllText(FilePath,
                    "Nickname=" + Nickname + "\r\n" +
                    "GamePath=" + GamePath + "\r\n" +
                    "CloseAfterLaunch=" + (CloseAfterLaunch ? "1" : "0") + "\r\n",
                    Encoding.UTF8);
            }
            catch { }
        }
    }
}
