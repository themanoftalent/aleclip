using System;
using System.Globalization;
using System.IO;
using System.Text.Json.Serialization;
using AleClip.Services;

namespace AleClip.Models;

public class ClipItem
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public ClipType Type { get; set; } = ClipType.Text;
    public string PlainText { get; set; } = string.Empty;
    public string? HtmlContent { get; set; }
    public string? RtfData { get; set; }
    public string? ImageFileName { get; set; }
    public string? Url { get; set; }
    public string? ColorHex { get; set; }
    public string? Title { get; set; }
    public string? SourceAppName { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime LastUsedAt { get; set; } = DateTime.UtcNow;
    public bool IsPinned { get; set; }
    public string ContentHash { get; set; } = string.Empty;

    [JsonIgnore]
    public string DisplayTitle
    {
        get
        {
            if (!string.IsNullOrWhiteSpace(Title))
                return Title.Trim();

            switch (Type)
            {
                case ClipType.Color:
                    return ColorHex ?? "Color";
                case ClipType.File:
                    if (!string.IsNullOrEmpty(Url))
                    {
                        try { return Path.GetFileName(Url); } catch { }
                    }
                    return PlainText;
                case ClipType.Link:
                    return Url ?? PlainText;
                default:
                    var lines = PlainText.Split(new[] { "\r\n", "\r", "\n" }, StringSplitOptions.None);
                    var firstLine = lines.Length > 0 ? lines[0].Trim() : string.Empty;
                    return !string.IsNullOrEmpty(firstLine) ? firstLine : LocalizationService.Instance.Loc($"filter.{Type.ToString().ToLowerInvariant()}");
            }
        }
    }

    [JsonIgnore]
    public string RelativeTimeString
    {
        get
        {
            var span = DateTime.UtcNow - CreatedAt;
            var isTr = LocalizationService.Instance.CurrentLanguage == "tr";

            if (span.TotalSeconds < 60)
                return isTr ? "az önce" : "just now";
            if (span.TotalMinutes < 60)
                return isTr ? $"{(int)span.TotalMinutes} dk önce" : $"{(int)span.TotalMinutes}m ago";
            if (span.TotalHours < 24)
                return isTr ? $"{(int)span.TotalHours} sa önce" : $"{(int)span.TotalHours}h ago";
            return isTr ? $"{(int)span.TotalDays} gün önce" : $"{(int)span.TotalDays}d ago";
        }
    }

    public bool Matches(string query)
    {
        if (string.IsNullOrWhiteSpace(query))
            return true;

        var culture = LocalizationService.Instance.CurrentLanguage == "tr"
            ? new CultureInfo("tr-TR")
            : CultureInfo.CurrentCulture;

        var compareInfo = culture.CompareInfo;
        const CompareOptions options = CompareOptions.IgnoreCase | CompareOptions.IgnoreNonSpace;

        if (!string.IsNullOrEmpty(Title) && compareInfo.IndexOf(Title, query, options) >= 0)
            return true;
        if (!string.IsNullOrEmpty(PlainText) && compareInfo.IndexOf(PlainText, query, options) >= 0)
            return true;
        if (!string.IsNullOrEmpty(Url) && compareInfo.IndexOf(Url, query, options) >= 0)
            return true;
        if (!string.IsNullOrEmpty(ColorHex) && compareInfo.IndexOf(ColorHex, query, options) >= 0)
            return true;
        if (!string.IsNullOrEmpty(SourceAppName) && compareInfo.IndexOf(SourceAppName, query, options) >= 0)
            return true;

        return false;
    }
}
