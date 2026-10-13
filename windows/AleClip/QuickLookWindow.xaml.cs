using System;
using System.Windows;
using System.Windows.Input;
using AleClip.Models;
using AleClip.Services;
using KeyEventArgs = System.Windows.Input.KeyEventArgs;

namespace AleClip;

public partial class QuickLookWindow : Window
{
    private readonly ClipItem _clip;
    private readonly Action _onPaste;

    public QuickLookWindow(ClipItem clip, Action onPaste)
    {
        InitializeComponent();
        _clip = clip;
        _onPaste = onPaste;

        HeaderTitle.Text = clip.DisplayTitle;
        ContentTextBox.Text = clip.PlainText;

        var l10n = LocalizationService.Instance;
        Title = l10n.Loc("quicklook.title");
        CopyBtn.Content = l10n.Loc("quicklook.copy");
        PasteBtn.Content = l10n.Loc("quicklook.pasteIntoApp");

        int charCount = clip.PlainText.Length;
        int wordCount = clip.PlainText.Split(new[] { ' ', '\r', '\n', '\t' }, StringSplitOptions.RemoveEmptyEntries).Length;
        StatsText.Text = l10n.LocF("quicklook.stats", charCount, wordCount);
    }

    private void CopyBtn_Click(object sender, RoutedEventArgs e)
    {
        PasteService.Instance.CopyToClipboard(_clip);
        Close();
    }

    private void PasteBtn_Click(object sender, RoutedEventArgs e)
    {
        Close();
        _onPaste?.Invoke();
    }

    private void Window_KeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.Escape || e.Key == Key.Space)
        {
            Close();
            e.Handled = true;
        }
    }
}
