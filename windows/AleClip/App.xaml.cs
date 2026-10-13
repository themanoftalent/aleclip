using System;
using System.Drawing;
using System.IO;
using System.Reflection;
using System.Threading;
using System.Windows;
using System.Windows.Forms;
using AleClip.Services;
using Application = System.Windows.Application;

namespace AleClip;

public partial class App : Application
{
    private static Mutex? _mutex;
    private NotifyIcon? _notifyIcon;
    private MainWindow? _mainWindow;
    private ClipboardMonitor? _clipboardMonitor;
    private HotkeyManager? _hotkeyManager;

    protected override void OnStartup(StartupEventArgs e)
    {
        const string appName = "AleClip_SingleInstance_Mutex";
        _mutex = new Mutex(true, appName, out bool createdNew);

        if (!createdNew)
        {
            // Another instance is already running
            Current.Shutdown();
            return;
        }

        base.OnStartup(e);

        _mainWindow = new MainWindow();
        _mainWindow.Show();
        _mainWindow.Hide(); // ensure handle created

        SetupTrayIcon();

        // Clipboard listener
        _clipboardMonitor = new ClipboardMonitor();
        _clipboardMonitor.Start(_mainWindow);

        // Global Hotkey (Alt + V)
        _hotkeyManager = new HotkeyManager();
        _hotkeyManager.HotkeyPressed = () => _mainWindow.TogglePanel();
        _hotkeyManager.Register(_mainWindow);
    }

    private void SetupTrayIcon()
    {
        _notifyIcon = new NotifyIcon();

        try
        {
            var assembly = Assembly.GetExecutingAssembly();
            using var iconStream = assembly.GetManifestResourceStream("AleClip.Resources.app.ico");
            if (iconStream != null)
                _notifyIcon.Icon = new Icon(iconStream);
            else
                _notifyIcon.Icon = SystemIcons.Application;
        }
        catch
        {
            _notifyIcon.Icon = SystemIcons.Application;
        }

        _notifyIcon.Text = "AleClip - Clipboard Manager (Alt+V)";
        _notifyIcon.Visible = true;
        _notifyIcon.DoubleClick += (s, e) => _mainWindow?.TogglePanel();

        UpdateTrayMenu();
        LocalizationService.Instance.LanguageChanged += UpdateTrayMenu;
    }

    private void UpdateTrayMenu()
    {
        if (_notifyIcon == null) return;

        var l10n = LocalizationService.Instance;
        var menu = new ContextMenuStrip();

        var openItem = new ToolStripMenuItem(l10n.Loc("menu.openPanel") + " (Alt+V)");
        openItem.Click += (s, e) => _mainWindow?.TogglePanel();
        menu.Items.Add(openItem);

        menu.Items.Add(new ToolStripSeparator());

        var clearItem = new ToolStripMenuItem(l10n.Loc("menu.clearUnpinned"));
        clearItem.Click += (s, e) => StorageService.Instance.ClearUnpinned();
        menu.Items.Add(clearItem);

        var settingsItem = new ToolStripMenuItem(l10n.Loc("menu.settings"));
        settingsItem.Click += (s, e) =>
        {
            var win = new SettingsWindow();
            win.ShowDialog();
        };
        menu.Items.Add(settingsItem);

        var aboutItem = new ToolStripMenuItem(l10n.Loc("menu.about"));
        aboutItem.Click += (s, e) =>
        {
            var win = new AboutWindow();
            win.ShowDialog();
        };
        menu.Items.Add(aboutItem);

        menu.Items.Add(new ToolStripSeparator());

        var exitItem = new ToolStripMenuItem(l10n.Loc("menu.quit"));
        exitItem.Click += (s, e) => Shutdown();
        menu.Items.Add(exitItem);

        _notifyIcon.ContextMenuStrip = menu;
    }

    protected override void OnExit(ExitEventArgs e)
    {
        _clipboardMonitor?.Stop();
        _hotkeyManager?.Unregister();

        if (_notifyIcon != null)
        {
            _notifyIcon.Visible = false;
            _notifyIcon.Dispose();
        }

        _mutex?.ReleaseMutex();
        base.OnExit(e);
    }
}
