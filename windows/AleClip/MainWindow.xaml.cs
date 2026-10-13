using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media;
using AleClip.Models;
using AleClip.Services;
using KeyEventArgs = System.Windows.Input.KeyEventArgs;

namespace AleClip;

public partial class MainWindow : Window
{
    private const int GWL_EXSTYLE = -20;
    private const int WS_EX_NOACTIVATE = 0x08000000;
    private const int WS_EX_TOOLWINDOW = 0x00000080;

    [DllImport("user32.dll")]
    private static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll", SetLastError = true)]
    private static extern int GetWindowLong(IntPtr hWnd, int nIndex);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);

    private IntPtr _previousForegroundHwnd = IntPtr.Zero;
    private List<ClipItem> _filteredClips = new();
    private int _selectedIndex = 0;
    private string _activeFilter = "all";

    public MainWindow()
    {
        InitializeComponent();
        StorageService.Instance.ClipsUpdated += OnClipsUpdated;
        LocalizationService.Instance.LanguageChanged += UpdateLocalization;
        UpdateLocalization();
    }

    protected override void OnSourceInitialized(EventArgs e)
    {
        base.OnSourceInitialized(e);
        var helper = new WindowInteropHelper(this);
        int exStyle = GetWindowLong(helper.Handle, GWL_EXSTYLE);
        SetWindowLong(helper.Handle, GWL_EXSTYLE, exStyle | WS_EX_NOACTIVATE | WS_EX_TOOLWINDOW);
    }

    public void TogglePanel()
    {
        if (Visibility == Visibility.Visible)
        {
            HidePanel();
        }
        else
        {
            ShowPanel();
        }
    }

    public void ShowPanel()
    {
        _previousForegroundHwnd = GetForegroundWindow();

        // Position bottom-center of the primary working area
        var workArea = SystemParameters.WorkArea;
        Left = (workArea.Width - Width) / 2 + workArea.Left;
        Top = workArea.Bottom - Height - 20;

        SearchTextBox.Text = string.Empty;
        _selectedIndex = 0;
        RefreshClips();

        Visibility = Visibility.Visible;
        SearchTextBox.Focus();
    }

    public void HidePanel()
    {
        Visibility = Visibility.Collapsed;
    }

    private void UpdateLocalization()
    {
        var l10n = LocalizationService.Instance;
        SearchPlaceholder.Text = l10n.Loc("panel.searchPlaceholder");
        ChipAll.Content = l10n.Loc("filter.all");
        ChipPinned.Content = l10n.Loc("filter.pinned");
        ChipText.Content = l10n.Loc("filter.text");
        ChipLinks.Content = l10n.Loc("filter.links");
        ChipImages.Content = l10n.Loc("filter.images");
        ChipFiles.Content = l10n.Loc("filter.files");
        ChipColors.Content = l10n.Loc("filter.colors");

        FooterNavigate.Text = l10n.Loc("footer.navigate");
        FooterPaste.Text = l10n.Loc("footer.paste");
        FooterPlainText.Text = l10n.Loc("footer.plainText");
        FooterPreview.Text = l10n.Loc("footer.preview");
        FooterDelete.Text = l10n.Loc("footer.delete");
        FooterClose.Text = l10n.Loc("footer.close");

        RefreshClips();
    }

    private void OnClipsUpdated()
    {
        Dispatcher.Invoke(RefreshClips);
    }

    private void RefreshClips()
    {
        var query = SearchTextBox.Text.Trim();
        var all = StorageService.Instance.Clips;

        _filteredClips = all.Where(c =>
        {
            if (!c.Matches(query)) return false;

            return _activeFilter switch
            {
                "pinned" => c.IsPinned,
                "text" => c.Type == ClipType.Text || c.Type == ClipType.RichText || c.Type == ClipType.Html,
                "links" => c.Type == ClipType.Link,
                "images" => c.Type == ClipType.Image,
                "files" => c.Type == ClipType.File,
                "colors" => c.Type == ClipType.Color,
                _ => true
            };
        }).ToList();

        if (_selectedIndex >= _filteredClips.Count)
            _selectedIndex = Math.Max(0, _filteredClips.Count - 1);

        RenderCards();

        var l10n = LocalizationService.Instance;
        var countWord = _filteredClips.Count == 1 ? l10n.Loc("footer.clip") : l10n.Loc("footer.clips");
        FooterCount.Text = $"{_filteredClips.Count} {countWord}";

        if (_filteredClips.Count == 0)
        {
            EmptyStateText.Text = string.IsNullOrEmpty(query) 
                ? l10n.Loc("empty.noClips") 
                : l10n.Loc("empty.noMatch");
            EmptyStateText.Visibility = Visibility.Visible;
        }
        else
        {
            EmptyStateText.Visibility = Visibility.Collapsed;
        }
    }

    private void RenderCards()
    {
        CardsPanel.Children.Clear();

        for (int i = 0; i < _filteredClips.Count; i++)
        {
            var clip = _filteredClips[i];
            bool isSelected = (i == _selectedIndex);
            var card = CreateCardElement(clip, isSelected, i);
            CardsPanel.Children.Add(card);
        }
    }

    private Border CreateCardElement(ClipItem clip, bool isSelected, int index)
    {
        var border = new Border
        {
            Width = 175,
            Height = 170,
            CornerRadius = new CornerRadius(12),
            Background = new SolidColorBrush(isSelected ? Color.FromRgb(39, 39, 42) : Color.FromRgb(28, 28, 30)),
            BorderBrush = new SolidColorBrush(isSelected ? Color.FromRgb(59, 130, 246) : (clip.IsPinned ? Color.FromRgb(245, 158, 11) : Color.FromRgb(45, 45, 48))),
            BorderThickness = new Thickness(isSelected ? 2 : 1),
            Margin = new Thickness(0, 0, 10, 0),
            Padding = new Thickness(10),
            Cursor = Cursors.Hand
        };

        var grid = new Grid();
        grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        grid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
        grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

        // Header: Title / Pin
        var header = new DockPanel();
        if (clip.IsPinned)
        {
            var pinBadge = new Border
            {
                Background = new SolidColorBrush(Color.FromRgb(245, 158, 11)),
                CornerRadius = new CornerRadius(4),
                Padding = new Thickness(4, 1, 4, 1),
                Margin = new Thickness(0, 0, 4, 0)
            };
            pinBadge.Child = new TextBlock
            {
                Text = "PIN",
                FontSize = 9,
                FontWeight = FontWeights.Bold,
                Foreground = Brushes.Black
            };
            DockPanel.SetDock(pinBadge, Dock.Right);
            header.Children.Add(pinBadge);
        }

        var titleText = new TextBlock
        {
            Text = clip.DisplayTitle,
            FontWeight = FontWeights.SemiBold,
            FontSize = 12,
            Foreground = Brushes.White,
            TextTrimming = TextTrimming.CharacterEllipsis
        };
        header.Children.Add(titleText);
        Grid.SetRow(header, 0);
        grid.Children.Add(header);

        // Body: Content snippet
        var bodyText = new TextBlock
        {
            Text = clip.PlainText,
            Foreground = new SolidColorBrush(Color.FromRgb(161, 161, 170)),
            FontSize = 11,
            TextWrapping = TextWrapping.Wrap,
            TextTrimming = TextTrimming.CharacterEllipsis,
            Margin = new Thickness(0, 6, 0, 6)
        };
        Grid.SetRow(bodyText, 1);
        grid.Children.Add(bodyText);

        // Footer: Source App / Time
        var cardFooter = new DockPanel();
        var timeText = new TextBlock
        {
            Text = clip.RelativeTimeString,
            FontSize = 10,
            Foreground = new SolidColorBrush(Color.FromRgb(113, 113, 122))
        };
        DockPanel.SetDock(timeText, Dock.Right);
        cardFooter.Children.Add(timeText);

        if (!string.IsNullOrEmpty(clip.SourceAppName))
        {
            var appText = new TextBlock
            {
                Text = clip.SourceAppName,
                FontSize = 10,
                Foreground = new SolidColorBrush(Color.FromRgb(113, 113, 122)),
                TextTrimming = TextTrimming.CharacterEllipsis
            };
            cardFooter.Children.Add(appText);
        }
        Grid.SetRow(cardFooter, 2);
        grid.Children.Add(cardFooter);

        border.Child = grid;

        border.MouseDown += (s, e) =>
        {
            _selectedIndex = index;
            if (e.ClickCount == 2)
            {
                PasteSelectedClip();
            }
            else
            {
                RenderCards();
            }
        };

        return border;
    }

    private void SearchTextBox_TextChanged(object sender, TextChangedEventArgs e)
    {
        SearchPlaceholder.Visibility = string.IsNullOrEmpty(SearchTextBox.Text) 
            ? Visibility.Visible 
            : Visibility.Collapsed;
        RefreshClips();
    }

    private void Filter_Checked(object sender, RoutedEventArgs e)
    {
        if (sender is RadioButton rb)
        {
            _activeFilter = rb.Name switch
            {
                "ChipPinned" => "pinned",
                "ChipText" => "text",
                "ChipLinks" => "links",
                "ChipImages" => "images",
                "ChipFiles" => "files",
                "ChipColors" => "colors",
                _ => "all"
            };
            RefreshClips();
        }
    }

    private void Window_KeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.Escape)
        {
            HidePanel();
            e.Handled = true;
        }
        else if (e.Key == Key.Left)
        {
            if (_selectedIndex > 0)
            {
                _selectedIndex--;
                RenderCards();
            }
            e.Handled = true;
        }
        else if (e.Key == Key.Right)
        {
            if (_selectedIndex < _filteredClips.Count - 1)
            {
                _selectedIndex++;
                RenderCards();
            }
            e.Handled = true;
        }
        else if (e.Key == Key.Enter)
        {
            bool forcePlain = Keyboard.IsKeyDown(Key.LeftShift) || Keyboard.IsKeyDown(Key.RightShift);
            PasteSelectedClip(forcePlain);
            e.Handled = true;
        }
        else if (e.Key == Key.Space)
        {
            OpenQuickLook();
            e.Handled = true;
        }
        else if (e.Key == Key.Delete)
        {
            DeleteSelectedClip();
            e.Handled = true;
        }
    }

    private void PasteSelectedClip(bool forcePlainText = false)
    {
        if (_selectedIndex >= 0 && _selectedIndex < _filteredClips.Count)
        {
            var clip = _filteredClips[_selectedIndex];
            HidePanel();
            PasteService.Instance.PasteClip(clip, _previousForegroundHwnd, forcePlainText);
        }
    }

    private void DeleteSelectedClip()
    {
        if (_selectedIndex >= 0 && _selectedIndex < _filteredClips.Count)
        {
            var clip = _filteredClips[_selectedIndex];
            StorageService.Instance.DeleteClip(clip.Id);
        }
    }

    private void OpenQuickLook()
    {
        if (_selectedIndex >= 0 && _selectedIndex < _filteredClips.Count)
        {
            var clip = _filteredClips[_selectedIndex];
            var ql = new QuickLookWindow(clip, () => PasteSelectedClip());
            ql.Owner = this;
            ql.ShowDialog();
        }
    }

    private void Window_Deactivated(object sender, EventArgs e)
    {
        HidePanel();
    }
}
