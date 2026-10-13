using System;
using System.Threading;
using System.Windows;
using AleClip.Services;

namespace AleClip;

public partial class App : Application
{
    private static Mutex? _mutex;
    private TrayIconManager? _trayIconManager;
    private MainWindow? _mainWindow;
    private ClipboardMonitor? _clipboardMonitor;
    private HotkeyManager? _hotkeyManager;

    protected override void OnStartup(StartupEventArgs e)
    {
        const string appName = "AleClip_SingleInstance_Mutex";
        _mutex = new Mutex(true, appName, out bool createdNew);

        if (!createdNew)
        {
            Current.Shutdown();
            return;
        }

        base.OnStartup(e);

        _mainWindow = new MainWindow();
        _mainWindow.Show();
        _mainWindow.Hide(); // Ensure HWND is initialized

        // Setup System Tray
        _trayIconManager = new TrayIconManager();
        _trayIconManager.OnToggle = () => _mainWindow.TogglePanel();
        _trayIconManager.OnClearUnpinned = () => StorageService.Instance.ClearUnpinned();
        _trayIconManager.OnSettings = () =>
        {
            var win = new SettingsWindow();
            win.ShowDialog();
        };
        _trayIconManager.OnAbout = () =>
        {
            var win = new AboutWindow();
            win.ShowDialog();
        };
        _trayIconManager.OnExit = () => Shutdown();
        _trayIconManager.Setup(_mainWindow);

        // Clipboard listener
        _clipboardMonitor = new ClipboardMonitor();
        _clipboardMonitor.Start(_mainWindow);

        // Global Hotkey (Alt + V)
        _hotkeyManager = new HotkeyManager();
        _hotkeyManager.HotkeyPressed = () => _mainWindow.TogglePanel();
        _hotkeyManager.Register(_mainWindow);
    }

    protected override void OnExit(ExitEventArgs e)
    {
        _clipboardMonitor?.Stop();
        _hotkeyManager?.Unregister();
        _trayIconManager?.Remove();
        _mutex?.ReleaseMutex();
        base.OnExit(e);
    }
}
