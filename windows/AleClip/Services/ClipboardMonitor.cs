using System;
using System.Collections.Specialized;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Runtime.InteropServices;
using System.Text.RegularExpressions;
using System.Threading;
using System.Windows;
using System.Windows.Interop;
using AleClip.Models;

namespace AleClip.Services;

public class ClipboardMonitor
{
    private const int WM_CLIPBOARDUPDATE = 0x031D;

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool AddClipboardFormatListener(IntPtr hwnd);

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool RemoveClipboardFormatListener(IntPtr hwnd);

    [DllImport("user32.dll")]
    private static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    private HwndSource? _hwndSource;
    private string _lastCapturedHash = string.Empty;

    public void Start(Window window)
    {
        var helper = new WindowInteropHelper(window);
        _hwndSource = HwndSource.FromHwnd(helper.EnsureHandle());
        if (_hwndSource != null)
        {
            _hwndSource.AddHook(HwndHook);
            AddClipboardFormatListener(_hwndSource.Handle);
        }
    }

    public void Stop()
    {
        if (_hwndSource != null)
        {
            RemoveClipboardFormatListener(_hwndSource.Handle);
            _hwndSource.RemoveHook(HwndHook);
            _hwndSource = null;
        }
    }

    private IntPtr HwndHook(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam, ref bool handled)
    {
        if (msg == WM_CLIPBOARDUPDATE)
        {
            ProcessClipboardChange();
        }
        return IntPtr.Zero;
    }

    private void ProcessClipboardChange()
    {
        // Give clipboard time to stabilize
        Thread.Sleep(50);

        try
        {
            string? activeAppName = GetActiveApplicationName();
            if (!string.IsNullOrEmpty(activeAppName) && StorageService.Instance.Settings.ExcludedApps.Contains(activeAppName, StringComparer.OrdinalIgnoreCase))
            {
                return;
            }

            if (System.Windows.Clipboard.ContainsText())
            {
                var text = System.Windows.Clipboard.GetText();
                if (string.IsNullOrWhiteSpace(text)) return;

                var hash = StorageService.ComputeHash(text);
                if (hash == _lastCapturedHash) return;
                _lastCapturedHash = hash;

                var item = new ClipItem
                {
                    PlainText = text,
                    ContentHash = hash,
                    SourceAppName = activeAppName
                };

                // Check for URL
                if (Uri.TryCreate(text.Trim(), UriKind.Absolute, out var uriResult) &&
                    (uriResult.Scheme == Uri.UriSchemeHttp || uriResult.Scheme == Uri.UriSchemeHttps))
                {
                    item.Type = ClipType.Link;
                    item.Url = text.Trim();
                }
                // Check for Hex color (#RRGGBB or #RGB)
                else if (Regex.IsMatch(text.Trim(), @"^#(?:[0-9a-fA-F]{3}){1,2}$"))
                {
                    item.Type = ClipType.Color;
                    item.ColorHex = text.Trim().ToUpperInvariant();
                }
                else
                {
                    item.Type = ClipType.Text;
                }

                if (System.Windows.Clipboard.ContainsText(TextDataFormat.Html))
                    item.HtmlContent = System.Windows.Clipboard.GetText(TextDataFormat.Html);
                if (System.Windows.Clipboard.ContainsText(TextDataFormat.Rtf))
                    item.RtfData = System.Windows.Clipboard.GetText(TextDataFormat.Rtf);

                StorageService.Instance.AddClip(item);
            }
            else if (System.Windows.Clipboard.ContainsFileDropList())
            {
                var files = System.Windows.Clipboard.GetFileDropList();
                if (files.Count > 0)
                {
                    var firstFile = files[0];
                    var combined = string.Join(Environment.NewLine, files.Cast<string>());
                    var hash = StorageService.ComputeHash(combined);
                    if (hash == _lastCapturedHash) return;
                    _lastCapturedHash = hash;

                    var item = new ClipItem
                    {
                        Type = ClipType.File,
                        PlainText = combined,
                        Url = firstFile,
                        ContentHash = hash,
                        SourceAppName = activeAppName
                    };
                    StorageService.Instance.AddClip(item);
                }
            }
        }
        catch { }
    }

    private string? GetActiveApplicationName()
    {
        try
        {
            var hwnd = GetForegroundWindow();
            if (hwnd == IntPtr.Zero) return null;

            GetWindowThreadProcessId(hwnd, out uint pid);
            var process = Process.GetProcessById((int)pid);
            return process.ProcessName;
        }
        catch
        {
            return null;
        }
    }
}
