using System;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows;
using AleClip.Models;

namespace AleClip.Services;

public class PasteService
{
    private static readonly Lazy<PasteService> _instance = new(() => new PasteService());
    public static PasteService Instance => _instance.Value;

    private const int KEYEVENTF_KEYUP = 0x0002;
    private const byte VK_CONTROL = 0x11;
    private const byte VK_V = 0x56;

    [DllImport("user32.dll")]
    private static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);

    [DllImport("user32.dll")]
    private static extern bool SetForegroundWindow(IntPtr hWnd);

    private PasteService() { }

    public void CopyToClipboard(ClipItem clip)
    {
        try
        {
            var dataObj = new DataObject();
            dataObj.SetText(clip.PlainText, TextDataFormat.UnicodeText);

            if (!string.IsNullOrEmpty(clip.HtmlContent))
                dataObj.SetText(clip.HtmlContent, TextDataFormat.Html);
            if (!string.IsNullOrEmpty(clip.RtfData))
                dataObj.SetText(clip.RtfData, TextDataFormat.Rtf);

            System.Windows.Clipboard.SetDataObject(dataObj, true);
        }
        catch { }
    }

    public void PasteClip(ClipItem clip, IntPtr previousForegroundHwnd, bool forcePlainText = false)
    {
        try
        {
            if (forcePlainText)
            {
                System.Windows.Clipboard.SetText(clip.PlainText, TextDataFormat.UnicodeText);
            }
            else
            {
                CopyToClipboard(clip);
            }

            if (StorageService.Instance.Settings.PasteDirectly && previousForegroundHwnd != IntPtr.Zero)
            {
                SetForegroundWindow(previousForegroundHwnd);
                Thread.Sleep(60);

                // Synthesize Ctrl + V
                keybd_event(VK_CONTROL, 0, 0, UIntPtr.Zero);
                keybd_event(VK_V, 0, 0, UIntPtr.Zero);
                keybd_event(VK_V, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);
                keybd_event(VK_CONTROL, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);
            }
        }
        catch { }
    }
}
