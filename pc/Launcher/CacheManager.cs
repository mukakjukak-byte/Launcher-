using System;
using System.IO;
using System.IO.Compression;
using System.Net;
using System.Net.Http;
using System.Threading.Tasks;

namespace CrmpLauncher
{
    /// <summary>
    /// Свой кэш: cache.zip + version.txt в GitHub Release "cache-pc".
    /// Качаем только если версия на GitHub отличается от установленной.
    /// </summary>
    internal sealed class CacheManager
    {
        public enum Result { UpToDate, Updated, NotPublished }

        private readonly string _gameDir;
        private readonly Action<string> _status;
        private readonly Action<int> _progress;

        private static readonly HttpClient Http = CreateClient();

        private static HttpClient CreateClient()
        {
            ServicePointManager.SecurityProtocol |= SecurityProtocolType.Tls12;
            var c = new HttpClient { Timeout = TimeSpan.FromMinutes(60) };
            c.DefaultRequestHeaders.UserAgent.ParseAdd("CrmpLauncher/1.0");
            return c;
        }

        public CacheManager(string gameDir, Action<string> status, Action<int> progress)
        {
            _gameDir = gameDir;
            _status = status;
            _progress = progress;
        }

        private string VersionFile => Path.Combine(_gameDir, Config.LocalCacheVersionFile);

        public string InstalledVersion =>
            File.Exists(VersionFile) ? File.ReadAllText(VersionFile).Trim() : null;

        /// <summary>Версия кэша на GitHub; null — кэш не опубликован.</summary>
        public static async Task<string> FetchRemoteVersionAsync()
        {
            using (var resp = await Http.GetAsync(Config.CacheVersionUrl))
            {
                if (resp.StatusCode == HttpStatusCode.NotFound) return null;
                resp.EnsureSuccessStatusCode();
                string v = (await resp.Content.ReadAsStringAsync()).Trim();
                return v.Length == 0 ? null : v;
            }
        }

        public static string GetInstalledVersion(string gameDir)
        {
            try
            {
                string f = Path.Combine(gameDir, Config.LocalCacheVersionFile);
                return File.Exists(f) ? File.ReadAllText(f).Trim() : null;
            }
            catch { return null; }
        }

        public async Task<Result> UpdateAsync(bool force)
        {
            _status("Проверка кэша…");
            string remote = await FetchRemoteVersionAsync();
            if (remote == null) return Result.NotPublished;

            if (!force && remote == InstalledVersion)
            {
                _status("Кэш актуален (версия " + remote + ")");
                _progress(100);
                return Result.UpToDate;
            }

            string tmp = Path.Combine(Path.GetTempPath(), "crmp_cache.zip");
            await DownloadAsync(Config.CacheZipUrl, tmp);

            _status("Распаковка…");
            await Task.Run(() => Extract(tmp, _gameDir));
            try { File.Delete(tmp); } catch { }

            File.WriteAllText(VersionFile, remote);
            _status("Кэш установлен (версия " + remote + ")");
            _progress(100);
            return Result.Updated;
        }

        private async Task DownloadAsync(string url, string target)
        {
            using (var resp = await Http.GetAsync(url, HttpCompletionOption.ResponseHeadersRead))
            {
                resp.EnsureSuccessStatusCode();
                long total = resp.Content.Headers.ContentLength ?? -1;
                using (var input = await resp.Content.ReadAsStreamAsync())
                using (var output = File.Create(target))
                {
                    var buf = new byte[81920];
                    long done = 0;
                    int last = -1, n;
                    while ((n = await input.ReadAsync(buf, 0, buf.Length)) > 0)
                    {
                        await output.WriteAsync(buf, 0, n);
                        done += n;
                        if (total > 0)
                        {
                            int p = (int)(done * 100 / total);
                            if (p != last)
                            {
                                last = p;
                                _progress(p);
                                _status($"Загрузка кэша: {done / 1048576.0:0.0} / {total / 1048576.0:0.0} МБ");
                            }
                        }
                    }
                }
            }
        }

        private const string UserPrefix = "UserFiles/";

        private void Extract(string zipPath, string dest)
        {
            string root = Path.GetFullPath(dest).TrimEnd('\\') + "\\";
            // Файлы из UserFiles/ идут в "Документы\GTA San Andreas User Files" (там sa-mp.cfg и настройки игры)
            string userRoot = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments), "GTA San Andreas User Files");
            string userRootFull = Path.GetFullPath(userRoot).TrimEnd('\\') + "\\";
            using (var zip = ZipFile.OpenRead(zipPath))
            {
                int i = 0, count = Math.Max(zip.Entries.Count, 1), last = -1;
                foreach (var entry in zip.Entries)
                {
                    i++;
                    string name = entry.FullName.Replace('\\', '/');
                    string baseDir = dest, baseFull = root;
                    if (name.StartsWith(UserPrefix, StringComparison.OrdinalIgnoreCase))
                    {
                        name = name.Substring(UserPrefix.Length);
                        baseDir = userRoot;
                        baseFull = userRootFull;
                    }
                    if (name.Length == 0) continue;

                    string full = Path.GetFullPath(Path.Combine(baseDir, name));
                    if (!full.StartsWith(baseFull, StringComparison.OrdinalIgnoreCase))
                        throw new IOException("Плохой путь в архиве: " + entry.FullName);

                    if (name.EndsWith("/"))
                    {
                        Directory.CreateDirectory(full);
                    }
                    else
                    {
                        Directory.CreateDirectory(Path.GetDirectoryName(full));
                        entry.ExtractToFile(full, true);
                    }

                    int p = i * 100 / count;
                    if (p != last) { last = p; _progress(p); _status("Распаковка: " + p + "%"); }
                }
            }
        }
    }
}
