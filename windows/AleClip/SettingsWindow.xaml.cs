using System;
using System.Windows;
using System.Windows.Controls;
using AleClip.Services;
using Microsoft.Win32;

namespace AleClip;

public partial class SettingsWindow : Window
{
    private bool _initializing = true;

    public SettingsWindow()
    {
        InitializeComponent();
        LoadSettings();
        UpdateLocalization();
        _initializing = false;
    }

    private void LoadSettings()
    {
        var settings = StorageService.Instance.Settings;
        HistorySlider.Value = settings.HistoryLimit;
        PasteDirectlyCheck.IsChecked = settings.PasteDirectly;

        if (settings.Language == "tr")
            LanguageCombo.SelectedIndex = 2;
        else if (settings.Language == "en")
            LanguageCombo.SelectedIndex = 1;
        else
            LanguageCombo.SelectedIndex = 0;
    }

    private void UpdateLocalization()
    {
        var l10n = LocalizationService.Instance;
        Title = l10n.Loc("settings.title");
        TabGeneral.Header = l10n.Loc("settings.tab.general");
        TabShortcuts.Header = l10n.Loc("settings.tab.shortcuts");
        TabBackup.Header = l10n.Loc("settings.tab.backup");

        LangHeader.Text = l10n.Loc("settings.general.language");
        HistoryHeader.Text = l10n.Loc("settings.general.historyLimits");
        HistoryLimitLabel.Text = $"{l10n.Loc("settings.general.maxItems")} {(int)HistorySlider.Value}";
        PasteBehaviorHeader.Text = l10n.Loc("settings.general.pasteBehavior");
        PasteDirectlyCheck.Content = l10n.Loc("settings.general.pasteDirectly");

        ExportBtn.Content = l10n.Loc("settings.backup.exportBtn");
        ImportBtn.Content = l10n.Loc("settings.backup.importBtn");
        ClearUnpinnedBtn.Content = l10n.Loc("settings.backup.clearUnpinnedBtn");
    }

    private void LanguageCombo_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_initializing) return;

        if (LanguageCombo.SelectedItem is ComboBoxItem item && item.Tag is string langTag)
        {
            LocalizationService.Instance.SetLanguage(langTag);
            UpdateLocalization();
        }
    }

    private void HistorySlider_ValueChanged(object sender, RoutedPropertyChangedEventArgs<double> e)
    {
        if (_initializing) return;

        int limit = (int)e.NewValue;
        StorageService.Instance.Settings.HistoryLimit = limit;
        StorageService.Instance.SaveSettings();

        var l10n = LocalizationService.Instance;
        HistoryLimitLabel.Text = $"{l10n.Loc("settings.general.maxItems")} {limit}";
    }

    private void PasteDirectlyCheck_Changed(object sender, RoutedEventArgs e)
    {
        if (_initializing) return;

        StorageService.Instance.Settings.PasteDirectly = (PasteDirectlyCheck.IsChecked == true);
        StorageService.Instance.SaveSettings();
    }

    private void ExportBtn_Click(object sender, RoutedEventArgs e)
    {
        var sfd = new SaveFileDialog
        {
            Filter = "JSON Files (*.json)|*.json",
            FileName = "aleclip-backup.json"
        };

        if (sfd.ShowDialog() == true)
        {
            try
            {
                StorageService.Instance.ExportJson(sfd.FileName);
                MessageBox.Show(LocalizationService.Instance.Loc("settings.backup.exportSuccess"), "AleClip", MessageBoxButton.OK, MessageBoxImage.Information);
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, "Export Error", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }
    }

    private void ImportBtn_Click(object sender, RoutedEventArgs e)
    {
        var ofd = new OpenFileDialog
        {
            Filter = "JSON Files (*.json)|*.json"
        };

        if (ofd.ShowDialog() == true)
        {
            try
            {
                int count = StorageService.Instance.ImportJson(ofd.FileName);
                MessageBox.Show(LocalizationService.Instance.LocF("settings.backup.importSuccess", count), "AleClip", MessageBoxButton.OK, MessageBoxImage.Information);
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, "Import Error", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }
    }

    private void ClearUnpinnedBtn_Click(object sender, RoutedEventArgs e)
    {
        StorageService.Instance.ClearUnpinned();
        MessageBox.Show(LocalizationService.Instance.Loc("settings.backup.clearSuccess"), "AleClip", MessageBoxButton.OK, MessageBoxImage.Information);
    }
}
