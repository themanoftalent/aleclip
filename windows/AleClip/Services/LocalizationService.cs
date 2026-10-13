using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Reflection;
using System.Text.Json;

namespace AleClip.Services;

public class LocalizationService
{
    private static readonly Lazy<LocalizationService> _instance = new(() => new LocalizationService());
    public static LocalizationService Instance => _instance.Value;

    private Dictionary<string, string> _enStrings = new();
    private Dictionary<string, string> _trStrings = new();
    public string CurrentLanguage { get; private set; } = "en";

    public event Action? LanguageChanged;

    private LocalizationService()
    {
        LoadEmbeddedStrings();
        DetectLanguage();
    }

    private void LoadEmbeddedStrings()
    {
        var assembly = Assembly.GetExecutingAssembly();

        try
        {
            using var streamEn = assembly.GetManifestResourceStream("AleClip.Resources.Strings.en.json");
            if (streamEn != null)
            {
                using var reader = new StreamReader(streamEn);
                _enStrings = JsonSerializer.Deserialize<Dictionary<string, string>>(reader.ReadToEnd()) ?? new();
            }
        }
        catch { }

        try
        {
            using var streamTr = assembly.GetManifestResourceStream("AleClip.Resources.Strings.tr.json");
            if (streamTr != null)
            {
                using var reader = new StreamReader(streamTr);
                _trStrings = JsonSerializer.Deserialize<Dictionary<string, string>>(reader.ReadToEnd()) ?? new();
            }
        }
        catch { }
    }

    private void DetectLanguage()
    {
        var preferred = StorageService.Instance.Settings.Language;
        if (preferred == "tr")
        {
            CurrentLanguage = "tr";
        }
        else if (preferred == "en")
        {
            CurrentLanguage = "en";
        }
        else
        {
            var systemLang = CultureInfo.CurrentUICulture.TwoLetterISOLanguageName;
            CurrentLanguage = systemLang.Equals("tr", StringComparison.OrdinalIgnoreCase) ? "tr" : "en";
        }
    }

    public void SetLanguage(string lang)
    {
        CurrentLanguage = lang == "tr" ? "tr" : "en";
        StorageService.Instance.Settings.Language = lang;
        StorageService.Instance.SaveSettings();
        LanguageChanged?.Invoke();
    }

    public string Loc(string key)
    {
        var dict = CurrentLanguage == "tr" ? _trStrings : _enStrings;
        if (dict.TryGetValue(key, out var val))
            return val;

        // Fallback to English
        if (_enStrings.TryGetValue(key, out var fallback))
            return fallback;

        return key;
    }

    public string LocF(string key, params object[] args)
    {
        var format = Loc(key);
        try
        {
            return string.Format(format, args);
        }
        catch
        {
            return format;
        }
    }
}
