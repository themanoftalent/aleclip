using System;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Interop;

namespace AleClip.Services;

public class TrayIconManager
{
    private const uint NIM_ADD = 0x00000000;
    private const uint NIM_DELETE = 0x00000002;
    private const uint NIF_MESSAGE = 0x00000001;
    private const uint NIF_ICON = 0x00000002;
    private const uint NIF_TIP = 0x00000004;

    private const int WM_USER = 0x0400;
    public const int WM_TRAYICON = WM_USER + 1;
    private const int WM_LBUTTONDBLCLK = 0x0203;
    private const int WM_RBUTTONUP = 0x0205;

    private const uint IMAGE_ICON = 1;
    private const uint LR_LOADFROMFILE = 0x00000010;

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    private struct NOTIFYICONDATA
    {
        public uint cbSize;
        public IntPtr hWnd;
        public uint uID;
        public uint uFlags;
        public uint uCallbackMessage;
        public IntPtr hIcon;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
        public string szTip;
    }

    [DllImport("shell32.dll", CharSet = CharSet.Auto)]
    private static extern bool Shell_NotifyIcon(uint dwMessage, ref NOTIFYICONDATA lpData);

    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    private static extern IntPtr LoadImage(IntPtr hinst, string lpszName, uint uType, int cxDesired, int cyDesired, uint fuLoad);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool DestroyIcon(IntPtr hIcon);

    [DllImport("user32.dll")]
    private static extern bool SetForegroundWindow(IntPtr hWnd);

    private NOTIFYICONDATA _nid;
    private IntPtr _hIcon = IntPtr.Zero;
    private HwndSource? _hwndSource;
    private ContextMenu? _contextMenu;

    public Action? OnToggle;
    public Action? OnExit;
    public Action? OnSettings;
    public Action? OnAbout;
    public Action? OnClearUnpinned;

    public void Setup(Window window)
    {
        var helper = new WindowInteropHelper(window);
        _hwndSource = HwndSource.FromHwnd(helper.EnsureHandle());
        if (_hwndSource == null) return;

        _hwndSource.AddHook(HwndHook);

        // Extract and load icon
        try
        {
            var tempIco = Path.Combine(Path.GetTempPath(), "aleclip_tray.ico");
            var assembly = Assembly.GetExecutingAssembly();
            using var stream = assembly.GetManifestResourceStream("AleClip.Resources.app.ico");
            if (stream != null)
            {
                using var fs = File.Create(tempIco);
                stream.CopyTo(fs);
                fs.Close();
                _hIcon = LoadImage(IntPtr.Zero, tempIco, IMAGE_ICON, 16, 16, LR_LOADFROMFILE);
            }
        }
        catch { }

        _nid = new NOTIFYICONDATA
        {
            cbSize = (uint)Marshal.SizeOf<NOTIFYICONDATA>(),
            hWnd = _hwndSource.Handle,
            uID = 1001,
            uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP,
            uCallbackMessage = WM_TRAYICON,
            hIcon = _hIcon,
            szTip = "AleClip - Clipboard Manager (Alt+V)"
        };

        Shell_NotifyIcon(NIM_ADD, ref _nid);
    }

    public void Remove()
    {
        Shell_NotifyIcon(NIM_DELETE, ref _nid);
        if (_hIcon != IntPtr.Zero)
        {
            DestroyIcon(_hIcon);
            _hIcon = IntPtr.Zero;
        }
    }

    private IntPtr HwndHook(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam, ref bool handled)
    {
        if (msg == WM_TRAYICON)
        {
            int mouseMsg = lParam.ToInt32();
            if (mouseMsg == WM_LBUTTONDBLCLK)
            {
                OnToggle?.Invoke();
                handled = true;
            }
            else if (mouseMsg == WM_RBUTTONUP)
            {
                ShowContextMenu();
                handled = true;
            }
        }
        return IntPtr.Zero;
    }

    private void ShowContextMenu()
    {
        var l10n = LocalizationService.Instance;
        _contextMenu = new ContextMenu();

        var openItem = new MenuItem { Header = l10n.Loc("menu.openPanel") + " (Alt+V)" };
        openItem.Click += (s, e) => OnToggle?.Invoke();
        _contextMenu.Items.Add(openItem);

        _contextMenu.Items.Add(new Separator());

        var clearItem = new MenuItem { Header = l10n.Loc("menu.clearUnpinned") };
        clearItem.Click += (s, e) => OnClearUnpinned?.Invoke();
        _contextMenu.Items.Add(clearItem);

        var settingsItem = new MenuItem { Header = l10n.Loc("menu.settings") };
        settingsItem.Click += (s, e) => OnSettings?.Invoke();
        _contextMenu.Items.Add(settingsItem);

        var aboutItem = new MenuItem { Header = l10n.Loc("menu.about") };
        aboutItem.Click += (s, e) => OnAbout?.Invoke();
        _contextMenu.Items.Add(aboutItem);

        _contextMenu.Items.Add(new Separator());

        var exitItem = new MenuItem { Header = l10n.Loc("menu.quit") };
        exitItem.Click += (s, e) => OnExit?.Invoke();
        _contextMenu.Items.Add(exitItem);

        if (_hwndSource != null)
            SetForegroundWindow(_hwndSource.Handle);

        _contextMenu.IsOpen = true;
    }
}
