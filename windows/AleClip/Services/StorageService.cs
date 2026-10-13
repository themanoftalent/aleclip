using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using AleClip.Models;

namespace AleClip.Services;

public class AppSettings
{
    public int HistoryLimit { get; set; } = 200;
    public bool PasteDirectly { get; set; } = true;
    public bool PlaySounds { get; set; } = false;
    public string Language { get; set; } = "system";
    public string GlobalHotkey { get; set; } = "Alt+V";
    public List<string> ExcludedApps { get; set; } = new();
}

public class StorageService
{
    private static readonly Lazy<StorageService> _instance = new(() => new StorageService());
    public static StorageService Instance => _instance.Value;

    private readonly string _storageFolder;
    private readonly string _clipsFilePath;
    private readonly string _settingsFilePath;
    private readonly object _lock = new();

    public List<ClipItem> Clips { get; private set; } = new();
    public AppSettings Settings { get; private set; } = new();

    public event Action? ClipsUpdated;

    private StorageService()
    {
        var localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        _storageFolder = Path.Combine(localAppData, "AleClip");
        Directory.CreateDirectory(_storageFolder);

        _clipsFilePath = Path.Combine(_storageFolder, "clips.json");
        _settingsFilePath = Path.Combine(_storageFolder, "settings.json");

        LoadSettings();
        LoadClips();
    }

    public void LoadSettings()
    {
        lock (_lock)
        {
            if (File.Exists(_settingsFilePath))
            {
                try
                {
                    var json = File.ReadAllText(_settingsFilePath);
                    Settings = JsonSerializer.Deserialize<AppSettings>(json) ?? new();
                }
                catch { Settings = new(); }
            }
        }
    }

    public void SaveSettings()
    {
        lock (_lock)
        {
            try
            {
                var json = JsonSerializer.Serialize(Settings, new JsonSerializerOptions { WriteIndented = true });
                File.WriteAllText(_settingsFilePath, json);
            }
            catch { }
        }
    }

    public void LoadClips()
    {
        lock (_lock)
        {
            if (File.Exists(_clipsFilePath))
            {
                try
                {
                    var json = File.ReadAllText(_clipsFilePath);
                    Clips = JsonSerializer.Deserialize<List<ClipItem>>(json) ?? new();
                }
                catch { Clips = new(); }
            }
        }
    }

    public void SaveClips()
    {
        lock (_lock)
        {
            try
            {
                var json = JsonSerializer.Serialize(Clips, new JsonSerializerOptions { WriteIndented = true });
                File.WriteAllText(_clipsFilePath, json);
            }
            catch { }
        }
    }

    public void AddClip(ClipItem clip)
    {
        lock (_lock)
        {
            // If exists, bump to top
            var existingIndex = Clips.FindIndex(c => c.ContentHash == clip.ContentHash);
            if (existingIndex >= 0)
            {
                var existing = Clips[existingIndex];
                existing.LastUsedAt = DateTime.UtcNow;
                Clips.RemoveAt(existingIndex);
                Clips.Insert(0, existing);
            }
            else
            {
                Clips.Insert(0, clip);
            }

            PruneUnpinned();
            SaveClips();
        }

        ClipsUpdated?.Invoke();
    }

    public void TogglePin(Guid id)
    {
        lock (_lock)
        {
            var item = Clips.FirstOrDefault(c => c.Id == id);
            if (item != null)
            {
                item.IsPinned = !item.IsPinned;
                SaveClips();
            }
        }
        ClipsUpdated?.Invoke();
    }

    public void DeleteClip(Guid id)
    {
        lock (_lock)
        {
            Clips.RemoveAll(c => c.Id == id);
            SaveClips();
        }
        ClipsUpdated?.Invoke();
    }

    public void ClearUnpinned()
    {
        lock (_lock)
        {
            Clips.RemoveAll(c => !c.IsPinned);
            SaveClips();
        }
        ClipsUpdated?.Invoke();
    }

    private void PruneUnpinned()
    {
        if (Clips.Count <= Settings.HistoryLimit)
            return;

        int unpinnedToRemove = Clips.Count - Settings.HistoryLimit;
        for (int i = Clips.Count - 1; i >= 0 && unpinnedToRemove > 0; i--)
        {
            if (!Clips[i].IsPinned)
            {
                Clips.RemoveAt(i);
                unpinnedToRemove--;
            }
        }
    }

    public void ExportJson(string destinationPath)
    {
        lock (_lock)
        {
            var json = JsonSerializer.Serialize(Clips, new JsonSerializerOptions { WriteIndented = true });
            File.WriteAllText(destinationPath, json);
        }
    }

    public int ImportJson(string sourcePath)
    {
        lock (_lock)
        {
            var json = File.ReadAllText(sourcePath);
            var imported = JsonSerializer.Deserialize<List<ClipItem>>(json) ?? new();
            int count = 0;

            foreach (var item in imported)
            {
                if (!Clips.Any(c => c.ContentHash == item.ContentHash))
                {
                    Clips.Add(item);
                    count++;
                }
            }

            Clips = Clips.OrderByDescending(c => c.CreatedAt).ToList();
            PruneUnpinned();
            SaveClips();
            ClipsUpdated?.Invoke();
            return count;
        }
    }

    public static string ComputeHash(string content)
    {
        using var sha256 = SHA256.Create();
        var bytes = Encoding.UTF8.GetBytes(content);
        var hash = sha256.ComputeHash(bytes);
        return Convert.ToHexString(hash);
    }
}
