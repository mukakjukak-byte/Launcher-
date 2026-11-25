using System;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using Microsoft.Win32;

namespace CrmpLauncher
{
    internal static class GameLauncher
    {
        /// <summary>Ищем папку GTA SA: реестр SA-MP, потом стандартные пути.</summary>
        public static string DetectGamePath()
        {
            try
            {
                using (var key = Registry.CurrentUser.OpenSubKey(@"Software\SAMP"))
                {
                    var exe = key?.GetValue("gta_sa_exe") as string;
                    if (!string.IsNullOrEmpty(exe) && File.Exists(exe))
                        return Path.GetDirectoryName(exe);
                }
            }
            catch { }

            string pf86 = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86);
            string pf = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);
            string[] candidates =
            {
                Path.Combine(pf86, @"Rockstar Games\GTA San Andreas"),
                Path.Combine(pf, @"Rockstar Games\GTA San Andreas"),
                @"C:\Games\GTA San Andreas",
                @"D:\Games\GTA San Andreas",
                @"C:\GTA San Andreas",
                @"D:\GTA San Andreas",
            };
            foreach (var c in candidates)
                if (File.Exists(Path.Combine(c, Config.GtaExe))) return c;
            return "";
        }

        public static bool IsGameDir(string dir) =>
            !string.IsNullOrEmpty(dir) && File.Exists(Path.Combine(dir, Config.GtaExe));

        public static bool HasSamp(string dir) =>
            File.Exists(Path.Combine(dir, Config.SampExe)) || File.Exists(Path.Combine(dir, Config.SampDll));

        /// <summary>Запуск: samp.exe ip:port, а если его нет — gta_sa.exe + загрузка samp.dll.</summary>
        public static void Launch(string gameDir, string nick)
        {
            string gta = Path.Combine(gameDir, Config.GtaExe);

            // samp.exe и сам клиент берут ник отсюда
            using (var key = Registry.CurrentUser.CreateSubKey(@"Software\SAMP"))
            {
                key.SetValue("PlayerName", nick);
                key.SetValue("gta_sa_exe", gta);
            }

            string sampExe = Path.Combine(gameDir, Config.SampExe);
            if (File.Exists(sampExe))
            {
                Process.Start(new ProcessStartInfo(sampExe, Config.ServerAddress)
                {
                    WorkingDirectory = gameDir,
                    UseShellExecute = false
                });
                return;
            }

            string dll = Path.Combine(gameDir, Config.SampDll);
            if (!File.Exists(dll))
                throw new FileNotFoundException("Не найден SA-MP клиент (samp.exe / samp.dll).");

            string args = $"\"{gta}\" -c -n {nick} -h {Config.ServerIp} -p {Config.ServerPort}";
            StartWithDll(gta, args, gameDir, dll);
        }

        // ---------- запуск gta_sa.exe с samp.dll (так же делает samp.exe) ----------

        private static void StartWithDll(string exe, string cmdLine, string workDir, string dllPath)
        {
            var si = new STARTUPINFO { cb = Marshal.SizeOf(typeof(STARTUPINFO)) };
            if (!CreateProcess(exe, new StringBuilder(cmdLine), IntPtr.Zero, IntPtr.Zero, false,
                    CREATE_SUSPENDED, IntPtr.Zero, workDir, ref si, out var pi))
                throw new Win32Exception(Marshal.GetLastWin32Error(), "Не удалось запустить gta_sa.exe");

            try
            {
                byte[] path = Encoding.Default.GetBytes(dllPath + "\0");
                IntPtr mem = VirtualAllocEx(pi.hProcess, IntPtr.Zero, (uint)path.Length,
                    MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
                if (mem == IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error());

                if (!WriteProcessMemory(pi.hProcess, mem, path, (uint)path.Length, out _))
                    throw new Win32Exception(Marshal.GetLastWin32Error());

                IntPtr loadLib = GetProcAddress(GetModuleHandle("kernel32.dll"), "LoadLibraryA");
                IntPtr thread = CreateRemoteThread(pi.hProcess, IntPtr.Zero, 0, loadLib, mem, 0, out _);
                if (thread == IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error());

                WaitForSingleObject(thread, 10000);
                CloseHandle(thread);
                VirtualFreeEx(pi.hProcess, mem, 0, MEM_RELEASE);
                ResumeThread(pi.hThread);
            }
            catch
            {
                TerminateProcess(pi.hProcess, 1);
                throw;
            }
            finally
            {
                CloseHandle(pi.hThread);
                CloseHandle(pi.hProcess);
            }
        }

        private const uint CREATE_SUSPENDED = 0x4;
        private const uint MEM_COMMIT = 0x1000, MEM_RESERVE = 0x2000, MEM_RELEASE = 0x8000;
        private const uint PAGE_READWRITE = 0x04;

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        private struct STARTUPINFO
        {
            public int cb;
            public string lpReserved, lpDesktop, lpTitle;
            public int dwX, dwY, dwXSize, dwYSize, dwXCountChars, dwYCountChars, dwFillAttribute, dwFlags;
            public short wShowWindow, cbReserved2;
            public IntPtr lpReserved2, hStdInput, hStdOutput, hStdError;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct PROCESS_INFORMATION
        {
            public IntPtr hProcess, hThread;
            public int dwProcessId, dwThreadId;
        }

        [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        private static extern bool CreateProcess(string app, StringBuilder cmd, IntPtr pa, IntPtr ta, bool inherit,
            uint flags, IntPtr env, string dir, ref STARTUPINFO si, out PROCESS_INFORMATION pi);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern IntPtr VirtualAllocEx(IntPtr h, IntPtr addr, uint size, uint type, uint protect);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool VirtualFreeEx(IntPtr h, IntPtr addr, uint size, uint type);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool WriteProcessMemory(IntPtr h, IntPtr addr, byte[] buf, uint size, out IntPtr written);

        [DllImport("kernel32.dll", CharSet = CharSet.Ansi)]
        private static extern IntPtr GetProcAddress(IntPtr module, string name);

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
        private static extern IntPtr GetModuleHandle(string name);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern IntPtr CreateRemoteThread(IntPtr h, IntPtr attr, uint stack, IntPtr start,
            IntPtr param, uint flags, out IntPtr id);

        [DllImport("kernel32.dll")] private static extern uint WaitForSingleObject(IntPtr h, uint ms);
        [DllImport("kernel32.dll")] private static extern uint ResumeThread(IntPtr h);
        [DllImport("kernel32.dll")] private static extern bool TerminateProcess(IntPtr h, uint code);
        [DllImport("kernel32.dll")] private static extern bool CloseHandle(IntPtr h);
    }
}
