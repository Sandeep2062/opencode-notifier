<#
.SYNOPSIS
    Installs OpenCode Audio & Visual Notification Plugin on Windows.
.DESCRIPTION
    Automates plugin setup, registers OpenCode AppUserModelID for Windows 10/11 Toast
    Notifications, copies notification scripts, runs a quick self-test,
    and restarts the OpenCode background service.
#>

[CmdletBinding()]
param(
    [switch]$SkipTest
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  OpenCode Audio & Visual Notification Plugin Installer   " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ConfigDir = Join-Path $HOME ".config\opencode"
$PluginDir = Join-Path $ConfigDir "plugin"

# 1. Ensure target directories exist
Write-Host "[1/6] Creating configuration directories..." -ForegroundColor Yellow
if (-not (Test-Path $PluginDir)) {
    New-Item -ItemType Directory -Path $PluginDir -Force | Out-Null
}
Write-Host "  -> Target: $PluginDir" -ForegroundColor Green

# 2. Register OpenCode AppUserModelId for Windows 10/11 Toast Notifications
Write-Host "[2/6] Registering OpenCode Application ID for Windows Action Center..." -ForegroundColor Yellow
try {
    $StartMenuPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs"
    $ShortcutPath = Join-Path $StartMenuPath "OpenCode.lnk"
    $AppId = "OpenCode"
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

        propStore.SetValue(ref pkey, ref propVar);
        propStore.Commit();

        IPersistFile persistFile = (IPersistFile)link;
        persistFile.Save(lnkPath, true);
    }
}
"@ -ErrorAction SilentlyContinue

    [ShellLinkHelper]::CreateShortcutWithAUMID($ShortcutPath, $ExePath, "", "", $AppId)
    Write-Host "  -> Registered OpenCode Start Menu shortcut with AppId '$AppId'" -ForegroundColor Green
} catch {
    Write-Host "  -> Note: AppId shortcut registration skipped (will use fallback AppId)" -ForegroundColor DarkYellow
}

# 3. Copy Plugin file
Write-Host "[3/6] Installing OpenCode plugin..." -ForegroundColor Yellow
$SourcePlugin = Join-Path $ScriptDir "plugin\notify.js"
$DestPlugin = Join-Path $PluginDir "notify.js"
Copy-Item -Path $SourcePlugin -Destination $DestPlugin -Force
Write-Host "  -> Installed notify.js" -ForegroundColor Green

# 4. Copy Notification Scripts
Write-Host "[4/6] Installing notification engines..." -ForegroundColor Yellow
$SourcePs = Join-Path $ScriptDir "scripts\opencode-notify.ps1"
$SourceSh = Join-Path $ScriptDir "scripts\opencode-notify.sh"

Copy-Item -Path $SourcePs -Destination (Join-Path $ConfigDir "opencode-notify.ps1") -Force
Copy-Item -Path $SourcePs -Destination (Join-Path $HOME "opencode-notify.ps1") -Force
Copy-Item -Path $SourceSh -Destination (Join-Path $HOME "opencode-notify.sh") -Force
Write-Host "  -> Installed opencode-notify.ps1 and opencode-notify.sh" -ForegroundColor Green

# 5. Restart OpenCode Service (if available)
Write-Host "[5/6] Checking OpenCode service status..." -ForegroundColor Yellow
if (Get-Command opencode -ErrorAction SilentlyContinue) {
    try {
        & opencode service restart | Out-Null
        Write-Host "  -> OpenCode background service restarted successfully!" -ForegroundColor Green
    } catch {
        Write-Host "  -> Note: OpenCode service could not be restarted automatically. Run 'opencode service restart' manually." -ForegroundColor DarkYellow
    }
} else {
    Write-Host "  -> Note: 'opencode' command not found in PATH. Install OpenCode CLI to use." -ForegroundColor DarkYellow
}

# 6. Self-Test
Write-Host "[6/6] Testing notifications..." -ForegroundColor Yellow
if (-not $SkipTest) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $ConfigDir "opencode-notify.ps1") -Type "permission" -Title "OpenCode Setup Test" -Message "OpenCode notifications installed successfully!"
    Write-Host "  -> Notification sound and desktop toast sent!" -ForegroundColor Green
} else {
    Write-Host "  -> Test skipped." -ForegroundColor Gray
}

Write-Host "`nInstallation Completed Successfully! 🎉" -ForegroundColor Cyan
Write-Host "Supported Events:" -ForegroundColor White
Write-Host "  1. permission.asked -> Exclamation alert sound + Windows Toast" -ForegroundColor Gray
Write-Host "  2. session.idle / succeeded -> Asterisk chime + Windows Toast" -ForegroundColor Gray
Write-Host "  3. session.error / failed   -> Hand warning sound + Windows Toast`n" -ForegroundColor Gray
