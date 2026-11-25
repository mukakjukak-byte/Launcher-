using System;
using System.Diagnostics;
using System.Linq;
using System.Drawing;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace CrmpLauncher
{
    internal sealed class MainForm : Form
    {
        private static readonly Color Bg = Color.FromArgb(0x34, 0x36, 0x5A);
        private static readonly Color Card = Color.FromArgb(0x23, 0x25, 0x2F);
        private static readonly Color TextMain = Color.FromArgb(0xEC, 0xEF, 0xF4);
        private static readonly Color TextDim = Color.FromArgb(0x9A, 0xA3, 0xA8);
        private static readonly Color Accent = Color.FromArgb(0x5B, 0x8D, 0xEF);
        private static readonly Color Online = Color.FromArgb(0x4C, 0xD0, 0x7D);
        private static readonly Color Offline = Color.FromArgb(0xE5, 0x53, 0x4B);
        private static readonly Regex NickRegex = new Regex(@"^[A-Za-z0-9_\[\]().$@=]{3,20}$");

        private readonly Settings _settings = Settings.Load();

        private readonly Label _lblHost = new Label();
        private readonly Label _lblOnline = new Label();
        private readonly Label _lblMode = new Label();
        private readonly TextBox _txtNick = new TextBox();
        private readonly TextBox _txtPath = new TextBox();
        private readonly Label _lblStatus = new Label();
        private readonly ProgressBar _progress = new ProgressBar();
        private readonly CheckBox _chkClose = new CheckBox();
        private readonly Button _btnPlay = new Button();
        private readonly Button _btnCache = new Button();
        private readonly Timer _timer = new Timer { Interval = 15000 };
        private bool _busy;

        private enum CacheState { Unknown, NoGame, NeedInstall, NeedUpdate, Ready }
        private CacheState _cache = CacheState.Unknown;
        private string _remoteVersion;

        public MainForm()
        {
            Text = Config.LauncherTitle;
            ClientSize = new Size(480, 560);
            FormBorderStyle = FormBorderStyle.FixedSingle;
            MaximizeBox = false;
            StartPosition = FormStartPosition.CenterScreen;
            BackColor = Bg;
            ForeColor = TextMain;
            Font = new Font("Segoe UI", 10f);

            BuildUi();

            _txtNick.Text = _settings.Nickname;
            _txtPath.Text = GameLauncher.IsGameDir(_settings.GamePath)
                ? _settings.GamePath
                : GameLauncher.DetectGamePath();
            _chkClose.Checked = _settings.CloseAfterLaunch;

            _timer.Tick += (s, e) => RefreshOnline();
            Shown += async (s, e) => { RefreshOnline(); _timer.Start(); await CheckCacheAsync(); };
            FormClosing += (s, e) => SaveSettings();
        }

        // ---------------- UI ----------------

        private void BuildUi()
        {
            var title = new Label
            {
                Text = Config.LauncherTitle,
                Font = new Font("Segoe UI", 20f, FontStyle.Bold),
                ForeColor = TextMain,
                TextAlign = ContentAlignment.MiddleCenter,
                Bounds = new Rectangle(0, 12, 480, 44)
            };
            Controls.Add(title);

            // адрес
            var addr = MakeCard(16, 66, 448, 50);
            addr.Controls.Add(new Label
            {
                Text = "Адрес: " + Config.ServerAddress,
                Font = new Font("Segoe UI", 12f),
                ForeColor = TextMain,
                Bounds = new Rectangle(12, 12, 300, 26)
            });
            var copy = MakeButton("Копировать", Card, new Rectangle(330, 9, 106, 32));
            copy.FlatAppearance.BorderColor = Accent;
            copy.Click += (s, e) =>
            {
                Clipboard.SetText(Config.ServerAddress);
                _lblStatus.Text = "Адрес скопирован";
            };
            addr.Controls.Add(copy);

            // онлайн
            var online = MakeCard(16, 126, 448, 86);
            Setup(_lblHost, "Сервер", new Font("Segoe UI", 11f, FontStyle.Bold), TextMain, new Rectangle(12, 8, 424, 24));
            Setup(_lblOnline, "Проверка…", Font, TextDim, new Rectangle(12, 34, 424, 22));
            Setup(_lblMode, "", new Font("Segoe UI", 9f), TextDim, new Rectangle(12, 58, 424, 20));
            online.Controls.AddRange(new Control[] { _lblHost, _lblOnline, _lblMode });

            // ник
            var nick = MakeCard(16, 222, 448, 70);
            nick.Controls.Add(MakeCaption("Никнейм (Имя_Фамилия)"));
            SetupBox(_txtNick, new Rectangle(12, 32, 424, 26));
            _txtNick.MaxLength = 20;
            nick.Controls.Add(_txtNick);

            // путь к игре
            var path = MakeCard(16, 302, 448, 70);
            path.Controls.Add(MakeCaption("Папка GTA San Andreas"));
            SetupBox(_txtPath, new Rectangle(12, 32, 380, 26));
            path.Controls.Add(_txtPath);
            var browse = MakeButton("…", Card, new Rectangle(398, 31, 38, 28));
            browse.FlatAppearance.BorderColor = Accent;
            browse.Click += (s, e) => BrowseGame();
            path.Controls.Add(browse);

            // статус + прогресс
            var status = MakeCard(16, 382, 448, 62);
            Setup(_lblStatus, "Проверка кэша…", new Font("Segoe UI", 9.5f), TextDim, new Rectangle(12, 8, 424, 20));
            _progress.Bounds = new Rectangle(12, 34, 424, 16);
            _progress.Maximum = 100;
            status.Controls.AddRange(new Control[] { _lblStatus, _progress });

            _chkClose.Text = "Закрыть лаунчер после запуска (экономит ОЗУ)";
            _chkClose.ForeColor = TextDim;
            _chkClose.Bounds = new Rectangle(18, 452, 440, 24);
            Controls.Add(_chkClose);

            _btnPlay.Text = "ИГРАТЬ";
            _btnPlay.Font = new Font("Segoe UI", 15f, FontStyle.Bold);
            _btnPlay.Bounds = new Rectangle(16, 482, 300, 60);
            StyleButton(_btnPlay, Accent);
            _btnPlay.FlatAppearance.BorderSize = 0;
            _btnPlay.Click += async (s, e) => await MainButtonAsync();
            Controls.Add(_btnPlay);

            _btnCache.Text = "Переустановить\nкэш";
            _btnCache.Font = new Font("Segoe UI", 9f);
            _btnCache.Bounds = new Rectangle(326, 482, 138, 60);
            StyleButton(_btnCache, Card);
            _btnCache.FlatAppearance.BorderColor = Accent;
            _btnCache.Click += async (s, e) => await CacheOnlyAsync();
            Controls.Add(_btnCache);

            AcceptButton = _btnPlay;
        }

        private Panel MakeCard(int x, int y, int w, int h)
        {
            var p = new Panel { Bounds = new Rectangle(x, y, w, h), BackColor = Card };
            Controls.Add(p);
            return p;
        }

        private Label MakeCaption(string text) => new Label
        {
            Text = text,
            Font = new Font("Segoe UI", 9f),
            ForeColor = TextDim,
            Bounds = new Rectangle(12, 8, 424, 20)
        };

        private static void Setup(Label l, string text, Font f, Color c, Rectangle b)
        {
            l.Text = text; l.Font = f; l.ForeColor = c; l.Bounds = b; l.AutoEllipsis = true;
        }

        private void SetupBox(TextBox t, Rectangle b)
        {
            t.Bounds = b;
            t.BackColor = Color.FromArgb(0x2E, 0x31, 0x3D);
            t.ForeColor = TextMain;
            t.BorderStyle = BorderStyle.FixedSingle;
            t.Font = new Font("Segoe UI", 11f);
        }

        private Button MakeButton(string text, Color bg, Rectangle b)
        {
            var btn = new Button { Text = text, Bounds = b, Font = new Font("Segoe UI", 9f) };
            StyleButton(btn, bg);
            return btn;
        }

        private void StyleButton(Button b, Color bg)
        {
            b.FlatStyle = FlatStyle.Flat;
            b.BackColor = bg;
            b.ForeColor = Color.White;
            b.Cursor = Cursors.Hand;
            b.UseVisualStyleBackColor = false;
        }

        // ---------------- логика ----------------

        private void RefreshOnline()
        {
            Task.Run(() => SampQuery.Query(Config.ServerIp, Config.ServerPort)).ContinueWith(t =>
            {
                var info = t.Result;
                if (info == null)
                {
                    _lblHost.Text = "Сервер";
                    _lblOnline.ForeColor = Offline;
                    _lblOnline.Text = "● Оффлайн / нет ответа";
                    _lblMode.Text = "";
                }
                else
                {
                    _lblHost.Text = string.IsNullOrEmpty(info.Hostname) ? "Сервер" : info.Hostname;
                    _lblOnline.ForeColor = Online;
                    _lblOnline.Text = $"● Онлайн: {info.Players} / {info.MaxPlayers}    Пинг: {info.PingMs} мс";
                    _lblMode.Text = string.Join(" • ", new[] { info.Gamemode, info.Language }
                        .Where(x => !string.IsNullOrEmpty(x)));
                }
            }, TaskScheduler.FromCurrentSynchronizationContext());
        }

        private void BrowseGame()
        {
            using (var dlg = new FolderBrowserDialog { Description = "Выбери папку с gta_sa.exe" })
            {
                if (GameLauncher.IsGameDir(_txtPath.Text)) dlg.SelectedPath = _txtPath.Text;
                if (dlg.ShowDialog(this) != DialogResult.OK) return;
                if (!GameLauncher.IsGameDir(dlg.SelectedPath))
                {
                    Error("В этой папке нет gta_sa.exe.");
                    return;
                }
                _txtPath.Text = dlg.SelectedPath;
                SaveSettings();
                _ = CheckCacheAsync();
            }
        }

        /// <summary>Проверяем, установлен ли кэш, и меняем большую кнопку.</summary>
        private async Task CheckCacheAsync()
        {
            string dir = _txtPath.Text.Trim();
            if (!GameLauncher.IsGameDir(dir))
            {
                SetCacheState(CacheState.NoGame, "Укажи папку GTA San Andreas, чтобы установить кэш");
                return;
            }

            _lblStatus.Text = "Проверка кэша…";
            try
            {
                _remoteVersion = await CacheManager.FetchRemoteVersionAsync();
            }
            catch
            {
                // нет интернета: если кэш уже стоит — пускаем играть
                if (CacheManager.GetInstalledVersion(dir) != null)
                    SetCacheState(CacheState.Ready, "Не удалось проверить обновления кэша (нет интернета)");
                else
                    SetCacheState(CacheState.NeedInstall, "Нет интернета — кэш не установить");
                return;
            }

            string installed = CacheManager.GetInstalledVersion(dir);
            if (_remoteVersion == null)
                SetCacheState(CacheState.Ready, "Кэш не требуется");
            else if (installed == null)
                SetCacheState(CacheState.NeedInstall, "Кэш не установлен — нажми «Установить кэш»");
            else if (installed != _remoteVersion)
                SetCacheState(CacheState.NeedUpdate, $"Доступно обновление кэша: {installed} → {_remoteVersion}");
            else
                SetCacheState(CacheState.Ready, "Кэш установлен (версия " + installed + ")");
        }

        private void SetCacheState(CacheState state, string text)
        {
            _cache = state;
            _lblStatus.Text = text;
            _progress.Value = state == CacheState.Ready ? 100 : 0;
            UpdateMainButton();
        }

        private void UpdateMainButton()
        {
            if (_busy) { _btnPlay.Text = "ЗАГРУЗКА…"; return; }
            switch (_cache)
            {
                case CacheState.NeedInstall: _btnPlay.Text = "УСТАНОВИТЬ КЭШ"; break;
                case CacheState.NeedUpdate: _btnPlay.Text = "ОБНОВИТЬ КЭШ"; break;
                default: _btnPlay.Text = "ИГРАТЬ"; break;
            }
        }

        private async Task MainButtonAsync()
        {
            if (_busy) return;
            if (_cache == CacheState.NeedInstall || _cache == CacheState.NeedUpdate)
            {
                string dir = _txtPath.Text.Trim();
                if (await RunCacheAsync(dir, false))
                    await CheckCacheAsync();
                return;
            }
            await PlayAsync();
        }

        private async Task PlayAsync()
        {
            if (_busy) return;
            string nick = _txtNick.Text.Trim();
            if (!NickRegex.IsMatch(nick))
            {
                Error("Ник: 3–20 символов, латиница, цифры и _ [ ] ( ) . $ @ =\nНапример: Ivan_Ivanov");
                _txtNick.Focus();
                return;
            }
            string dir = _txtPath.Text.Trim();
            if (!GameLauncher.IsGameDir(dir))
            {
                Error("Укажи папку GTA San Andreas (где лежит gta_sa.exe).");
                return;
            }
            if (!GameLauncher.HasSamp(dir))
            {
                if (MessageBox.Show(this,
                        "В папке игры не найден SA-MP 0.3.7.\nОткрыть страницу загрузки SA-MP?",
                        Config.LauncherTitle, MessageBoxButtons.YesNo, MessageBoxIcon.Question) == DialogResult.Yes)
                    Process.Start(Config.SampDownloadUrl);
                return;
            }
            SaveSettings();

            // кэш обязателен: перепроверяем перед запуском
            await CheckCacheAsync();
            if (_cache == CacheState.NeedInstall || _cache == CacheState.NeedUpdate)
            {
                Error("Сначала установи кэш — нажми «" + _btnPlay.Text + "».");
                return;
            }

            try
            {
                _lblStatus.Text = "Запуск игры…";
                GameLauncher.Launch(dir, nick);
                if (_chkClose.Checked) Close();
            }
            catch (Exception ex)
            {
                Error("Не удалось запустить игру:\n" + ex.Message);
            }
        }

        private async Task CacheOnlyAsync()
        {
            string dir = _txtPath.Text.Trim();
            if (!GameLauncher.IsGameDir(dir))
            {
                Error("Сначала укажи папку GTA San Andreas.");
                return;
            }
            if (await RunCacheAsync(dir, true))
                await CheckCacheAsync();
        }

        /// <returns>false — если была ошибка и запускать игру не надо.</returns>
        private async Task<bool> RunCacheAsync(string dir, bool force)
        {
            SetBusy(true);
            try
            {
                var cm = new CacheManager(dir,
                    s => BeginInvoke((Action)(() => _lblStatus.Text = s)),
                    p => BeginInvoke((Action)(() => _progress.Value = Math.Max(0, Math.Min(100, p)))));
                var result = await cm.UpdateAsync(force);
                return true;
            }
            catch (UnauthorizedAccessException)
            {
                Error("Нет прав на запись в папку игры.\nЗапусти лаунчер от имени администратора.");
                return false;
            }
            catch (Exception ex)
            {
                _lblStatus.Text = "Ошибка кэша";
                Error("Не удалось обновить кэш:\n" + ex.Message + "\n\nПроверь интернет.");
                return false;
            }
            finally
            {
                SetBusy(false);
            }
        }

        private void SetBusy(bool busy)
        {
            _busy = busy;
            _btnPlay.Enabled = !busy;
            _btnCache.Enabled = !busy;
            UpdateMainButton();
        }

        private void SaveSettings()
        {
            _settings.Nickname = _txtNick.Text.Trim();
            _settings.GamePath = _txtPath.Text.Trim();
            _settings.CloseAfterLaunch = _chkClose.Checked;
            _settings.Save();
        }

        private void Error(string msg) =>
            MessageBox.Show(this, msg, Config.LauncherTitle, MessageBoxButtons.OK, MessageBoxIcon.Warning);
    }
}
