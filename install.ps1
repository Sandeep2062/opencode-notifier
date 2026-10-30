<#
.SYNOPSIS
    Installs OpenCode Audio & Visual Notification Plugin on Windows.
.DESCRIPTION
    Automates plugin setup, registers OpenCode AppUserModelID for Windows 10/11 Toast
    Notifications, copies notification scripts, runs a quick self-test,
    without restarting the OpenCode background service.
#>

[CmdletBinding()]
param(
    [switch]$SkipTest,
    [string]$ConfigDir = ''
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  OpenCode Audio & Visual Notification Plugin Installer   " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$customConfig = [bool]$ConfigDir
if (-not $ConfigDir) {
    $root = if ($env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME } else { Join-Path $HOME '.config' }
    $ConfigDir = Join-Path $root 'opencode'
}
$PluginDir = Join-Path $ConfigDir 'plugins\opencode-notifier'
$BackupDir = Join-Path $ConfigDir ("notifier-backups\" + [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss-fffffff'))
$knownFiles = @('plugins\opencode-notifier\notify.js', 'plugins\opencode-notifier\notification-core.js', 'plugins\opencode-notifier\delivery-claim.js', 'plugins\opencode-notifier\package.json', 'opencode-notify.ps1', 'opencode-notify.sh', 'notifier-sounds\attention.wav', 'notifier-sounds\complete.wav', 'notifier-sounds\error.wav')
$legacyFiles = @('plugin\notify.js', 'plugins\notify.js')
foreach ($relative in ($knownFiles + $legacyFiles)) {
    $existing = Join-Path $ConfigDir $relative
    if (-not (Test-Path -LiteralPath $existing -PathType Leaf)) { continue }
    if ($relative -in $legacyFiles -and -not ((Get-Content -LiteralPath $existing -Raw) -match 'audio-visual-notifications')) {
        Write-Warning "Preserving unrecognized plugin: $existing"
        continue
    }
    $backup = Join-Path $BackupDir $relative
    New-Item -ItemType Directory -Path (Split-Path -Parent $backup) -Force | Out-Null
    Copy-Item -LiteralPath $existing -Destination $backup -Force
}
if (Test-Path -LiteralPath $BackupDir) { Write-Host "Backup: $BackupDir" -ForegroundColor Green }

# 1. Ensure target directories exist
Write-Host "[1/6] Creating configuration directories..." -ForegroundColor Yellow
if (-not (Test-Path $PluginDir)) {
    New-Item -ItemType Directory -Path $PluginDir -Force | Out-Null
}
Write-Host "  -> Target: $PluginDir" -ForegroundColor Green

# 2. Register OpenCode AppUserModelId for Windows 10/11 Toast Notifications
Write-Host "[2/6] Registering OpenCode Application ID for Windows Action Center..." -ForegroundColor Yellow
if (-not $customConfig) { try {
    $StartMenuPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs"
    $ShortcutPath = Join-Path $StartMenuPath 'OpenCode Notifier.lnk'
    $AppId = 'OpenCode.Notifier'
    if (Test-Path -LiteralPath $ShortcutPath) { Write-Host '  -> Existing notifier shortcut preserved.'; throw 'Shortcut already exists; registration left unchanged' }
    $ExePath = if (Get-Command opencode -ErrorAction SilentlyContinue) { (Get-Command opencode).Source } else { "$PSHome\powershell.exe" }

    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;

public class ShellLinkHelper {
    [ComImport, Guid("00021401-0000-0000-C000-000000000046")]
    public class ShellLink {}

    [ComImport, Guid("000214F9-0000-0000-C000-000000000046"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IShellLink {
        void GetPath([Out, MarshalAs(UnmanagedType.LPWStr)] System.Text.StringBuilder pszFile, int cchMaxPath, out IntPtr pfd, int fFlags);
        void GetIDList(out IntPtr ppidl);
        void SetIDList(IntPtr pidl);
        void GetDescription([Out, MarshalAs(UnmanagedType.LPWStr)] System.Text.StringBuilder pszName, int cchMaxName);
        void SetDescription([MarshalAs(UnmanagedType.LPWStr)] string pszName);
        void GetWorkingDirectory([Out, MarshalAs(UnmanagedType.LPWStr)] System.Text.StringBuilder pszDir, int cchMaxPath);
        void SetWorkingDirectory([MarshalAs(UnmanagedType.LPWStr)] string pszDir);
        void GetArguments([Out, MarshalAs(UnmanagedType.LPWStr)] System.Text.StringBuilder pszArgs, int cchMaxPath);
        void SetArguments([MarshalAs(UnmanagedType.LPWStr)] string pszArgs);
        void GetHotkey(out short pwHotkey);
        void SetHotkey(short wHotkey);
        void GetShowCmd(out int piShowCmd);
        void SetShowCmd(int piShowCmd);
        void GetLocation([Out, MarshalAs(UnmanagedType.LPWStr)] System.Text.StringBuilder pszIconPath, int cchIconPath, out int piIcon);
        void SetIconLocation([MarshalAs(UnmanagedType.LPWStr)] string pszIconPath, int iIcon);
        void SetRelativePath([MarshalAs(UnmanagedType.LPWStr)] string pszPathRel, int dwReserved);
        void Resolve(IntPtr hwnd, int fFlags);
        void SetPath([MarshalAs(UnmanagedType.LPWStr)] string pszFile);
    }

    [StructLayout(LayoutKind.Sequential, Pack = 4)]
    public struct PROPERTYKEY {
        public Guid fmtid;
        public uint pid;
        public PROPERTYKEY(Guid guid, uint id) {
            fmtid = guid;
            pid = id;
        }
    }

    [ComImport, Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IPropertyStore {
        void GetCount(out uint cProps);
        void GetAt(uint iProp, out PROPERTYKEY pkey);
        void GetValue(ref PROPERTYKEY pkey, out object pv);
        void SetValue(ref PROPERTYKEY pkey, [In] ref PROPVARIANT pv);
        void Commit();
    }

    [StructLayout(LayoutKind.Explicit)]
    public struct PROPVARIANT {
        [FieldOffset(0)] public ushort vt;
        [FieldOffset(8)] public IntPtr pwszVal;
        
        public PROPVARIANT(string str) {
            vt = 31;
            pwszVal = Marshal.StringToCoTaskMemUni(str);
        }
    }

    public static void CreateShortcutWithAUMID(string lnkPath, string target, string args, string icon, string aumid) {
        ShellLink link = new ShellLink();
        IShellLink shellLink = (IShellLink)link;

        shellLink.SetPath(target);
        if (!string.IsNullOrEmpty(args)) shellLink.SetArguments(args);
        if (!string.IsNullOrEmpty(icon)) shellLink.SetIconLocation(icon, 0);

        IPropertyStore propStore = (IPropertyStore)link;
        PROPERTYKEY pkey = new PROPERTYKEY(new Guid("9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3"), 5);
        PROPVARIANT propVar = new PROPVARIANT(aumid);

        try {
            propStore.SetValue(ref pkey, ref propVar);
            propStore.Commit();
            IPersistFile persistFile = (IPersistFile)link;
            persistFile.Save(lnkPath, true);
        } finally {
            Marshal.FreeCoTaskMem(propVar.pwszVal);
            Marshal.FinalReleaseComObject(link);
        }
    }
}
"@ -ErrorAction SilentlyContinue

    [ShellLinkHelper]::CreateShortcutWithAUMID($ShortcutPath, $ExePath, "", "", $AppId)
    Write-Host "  -> Registered OpenCode Start Menu shortcut with AppId '$AppId'" -ForegroundColor Green
} catch {
    Write-Host "  -> Note: AppId shortcut registration skipped (will use fallback AppId)" -ForegroundColor DarkYellow
} }

# Install dependencies first and publish the entrypoint last.
Write-Host '[3/6] Installing notification engines and original chimes...' -ForegroundColor Yellow
$SourcePs = Join-Path $ScriptDir "scripts\opencode-notify.ps1"
$SourceSh = Join-Path $ScriptDir "scripts\opencode-notify.sh"

Copy-Item -Path $SourcePs -Destination (Join-Path $ConfigDir "opencode-notify.ps1") -Force
Copy-Item -Path $SourceSh -Destination (Join-Path $ConfigDir 'opencode-notify.sh') -Force
$SoundDir = Join-Path $ConfigDir 'notifier-sounds'
New-Item -ItemType Directory -Path $SoundDir -Force | Out-Null
foreach ($sound in @('attention.wav', 'complete.wav', 'error.wav')) {
    Copy-Item -LiteralPath (Join-Path $ScriptDir "sounds\$sound") -Destination (Join-Path $SoundDir $sound) -Force
}
Write-Host '[4/6] Installing V2 plugin package...' -ForegroundColor Yellow
foreach ($name in @('notification-core.js', 'delivery-claim.js', 'package.json', 'notify.js')) {
    Copy-Item -LiteralPath (Join-Path $ScriptDir "plugin\$name") -Destination (Join-Path $PluginDir $name) -Force
}
foreach ($relative in $legacyFiles) {
    $existing = Join-Path $ConfigDir $relative
    if ((Test-Path -LiteralPath (Join-Path $BackupDir $relative)) -and (Test-Path -LiteralPath $existing)) {
        Remove-Item -LiteralPath $existing -Force
    }
}
Write-Host "  -> Installed opencode-notify.ps1 and opencode-notify.sh" -ForegroundColor Green

Write-Host '[5/6] Files installed. OpenCode reloads watched plugins; use /reload if needed. No service restart.' -ForegroundColor Green

# 6. Self-Test
Write-Host "[6/6] Testing notifications..." -ForegroundColor Yellow
if (-not $SkipTest) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $ConfigDir 'opencode-notify.ps1') -Type 'question' -Title 'OpenCode Setup Test' -Message 'Question notifications are ready. Did you see a banner and hear a chime?' -LogPath (Join-Path $ConfigDir 'notify.log')
    if ($LASTEXITCODE -ne 0) { Write-Warning 'Notification test failed; inspect notify.log.' }
    else { Write-Host '  -> Notification APIs attempted. Confirm banner/sound and check Windows notification settings if absent.' -ForegroundColor Green }
} else {
    Write-Host "  -> Test skipped." -ForegroundColor Gray
}

Write-Host "`nInstallation Completed Successfully!" -ForegroundColor Cyan
Write-Host "Supported Events:" -ForegroundColor White
Write-Host '  Questions/options and permissions -> soft attention chime + banner' -ForegroundColor Gray
Write-Host '  Completion and errors -> distinct original chimes + banner' -ForegroundColor Gray
