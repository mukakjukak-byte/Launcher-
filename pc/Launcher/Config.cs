namespace CrmpLauncher
{
    /// <summary>Все настройки лаунчера. Поменял -> запушил -> GitHub Actions собрал новый exe.</summary>
    internal static class Config
    {
        public const string LauncherTitle = "CRMP Launcher";

        // Твой сервер
        public const string ServerIp = "188.127.241.74";
        public const int ServerPort = 2626;
        public static string ServerAddress => ServerIp + ":" + ServerPort;

        // Кэш для ПК лежит в GitHub Release с тегом "cache-pc" (cache.zip + version.txt)
        public const string GitHubRepo = "mukakjukak-byte/Launcher-";
        public const string CacheTag = "cache-pc";
        public static string CacheVersionUrl => $"https://github.com/{GitHubRepo}/releases/download/{CacheTag}/version.txt";
        public static string CacheZipUrl => $"https://github.com/{GitHubRepo}/releases/download/{CacheTag}/cache.zip";

        // Файлы игры
        public const string GtaExe = "gta_sa.exe";
        public const string SampExe = "samp.exe";
        public const string SampDll = "samp.dll";
        public const string LocalCacheVersionFile = "launcher_cache_version.txt";

        // Где скачать SA-MP клиент, если он не установлен
        public const string SampDownloadUrl = "https://www.sa-mp.mp/downloads/";
    }
}
