using System.Windows;
using AleClip.Services;

namespace AleClip;

public partial class AboutWindow : Window
{
    public AboutWindow()
    {
        InitializeComponent();
        UpdateLocalization();
    }

    private void UpdateLocalization()
    {
        var l10n = LocalizationService.Instance;
        Title = l10n.Loc("about.title");
        TaglineText.Text = l10n.Loc("about.tagline");
        DevelopedByText.Text = l10n.Loc("about.developedBy");
        CloseButton.Content = l10n.Loc("footer.close");
    }

    private void CloseButton_Click(object sender, RoutedEventArgs e)
    {
        Close();
    }
}
