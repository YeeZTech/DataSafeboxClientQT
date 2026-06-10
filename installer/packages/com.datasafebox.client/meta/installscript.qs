function Component() {
    try {
        installer.setMessageBoxAutomaticAnswer("OverwriteTargetDirectory", QMessageBox.Yes);
    } catch (e) {
        console.log("Overwrite target directory setup failed: " + e);
    }
}

function toWindowsPath(path) {
    if (!path) {
        return "";
    }
    return String(path).replace(/\//g, "\\");
}

function psLiteral(value) {
    if (!value) {
        return "''";
    }
    return "'" + String(value).replace(/'/g, "''") + "'";
}

Component.prototype.createOperations = function() {
    var isWindows = installer.value("os") === "win";
    var targetDirRaw = installer.value("TargetDir");
    var appDisplayName = "\u6570\u636e\u5b89\u5168\u67dc\u63a7\u5236\u53f0";

    if (isWindows && targetDirRaw) {
        var regCleanScript =
            "$targetDir = " + psLiteral(toWindowsPath(targetDirRaw)) + "; " +
            "try { " +
            "  $normTarget = $targetDir.TrimEnd('\\').TrimEnd('/'); " +
            "  $regPaths = @('HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall', 'HKLM:\\SOFTWARE\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall', 'HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall'); " +
            "  foreach ($path in $regPaths) { " +
            "    if (Test-Path $path) { " +
            "      Get-ChildItem $path | ForEach-Object { " +
            "        try { " +
            "          $props = Get-ItemProperty $_.PSPath; " +
            "          $displayName = $props.DisplayName; " +
            "          if ($null -ne $displayName -and $displayName.Trim() -eq " + psLiteral(appDisplayName) + ") { " +
            "            $instLoc = if ($props.InstallLocation) { $props.InstallLocation.TrimEnd('\\').TrimEnd('/') } else { '' }; " +
            "            if ($instLoc -and $normTarget -and $instLoc.Equals($normTarget, [StringComparison]::OrdinalIgnoreCase)) { " +
            "              Remove-Item $_.PSPath -Force -Recurse -ErrorAction SilentlyContinue; " +
            "            } " +
            "          } " +
            "        } catch {} " +
            "      } " +
            "    } " +
            "  } " +
            "} catch {}";

        component.addOperation(
            "Execute",
            "powershell.exe",
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-Command", regCleanScript
        );
    }

    if (isWindows && targetDirRaw) {
        // Files of a previous install can be locked (a running app instance or
        // its QtWebEngineProcess helper keeps e.g. resources/icudtl.dat
        // memory-mapped) or carry a read-only attribute; either aborts
        // extraction with "Can't unlink already-existing object: Permission
        // denied". Stop processes running from the target dir and clear
        // attributes before the archives are extracted.
        var unlockScript =
            "$targetDir = " + psLiteral(toWindowsPath(targetDirRaw)) + "; " +
            "try { " +
            "  if (Test-Path $targetDir) { " +
            "    Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -and $_.Path.StartsWith(($targetDir.TrimEnd('\\') + '\\'), [StringComparison]::OrdinalIgnoreCase) } | Stop-Process -Force -ErrorAction SilentlyContinue; " +
            "    Start-Sleep -Milliseconds 800; " +
            "    attrib.exe -R ($targetDir.TrimEnd('\\') + '\\*') /S /D; " +
            "  } " +
            "} catch {}; exit 0";

        component.addOperation(
            "Execute",
            "powershell.exe",
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-Command", unlockScript
        );
    }

    component.createOperations();

    if (!isWindows) {
        return;
    }

    var targetDir = installer.value("TargetDir");
    if (!targetDir || targetDir === "") {
        return;
    }

    var target = "@TargetDir@/DataSafebox.exe";
    var iconPath = "@TargetDir@/icons/SafeLogo_256.ico";
    component.addOperation("CreateShortcut", target, "@StartMenuDir@/" + appDisplayName + ".lnk", "workingDirectory=@TargetDir@", "iconPath=" + iconPath);
    component.addOperation("CreateShortcut", target, "@DesktopDir@/" + appDisplayName + ".lnk", "workingDirectory=@TargetDir@", "iconPath=" + iconPath);

    // Refresh the Windows shell icon cache so the freshly written shortcut/exe
    // icons replace any icon Explorer cached from a previously installed version
    // (same install path + filename, so Windows otherwise keeps showing the old
    // icon). Non-destructive: notifies the shell instead of restarting Explorer.
    // try/catch keeps PowerShell's exit code at 0 so the IFW Execute op succeeds.
    var iconCacheRefreshScript =
        "try { Start-Process -FilePath 'ie4uinit.exe' -ArgumentList '-show' -WindowStyle Hidden -ErrorAction SilentlyContinue } catch {}; " +
        "try { " +
        "  Add-Type -Namespace Shell -Name Cache -MemberDefinition '[DllImport(\"shell32.dll\")] public static extern void SHChangeNotify(int eventId, uint flags, IntPtr item1, IntPtr item2);'; " +
        "  [Shell.Cache]::SHChangeNotify(0x08000000, 0, [IntPtr]::Zero, [IntPtr]::Zero); " +
        "} catch {}";

    component.addOperation(
        "Execute",
        "powershell.exe",
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-Command", iconCacheRefreshScript
    );

    var vcRedistPath = toWindowsPath(targetDir) + "\\vc_redist.x64.exe";
    var vcRedistScript =
        "$exe = " + psLiteral(vcRedistPath) + "; " +
        "if (Test-Path $exe) { " +
        "  try { " +
        "    $p = Start-Process -FilePath $exe -ArgumentList '/install','/quiet','/norestart' -Wait -PassThru -ErrorAction Stop; " +
        "    $code = $p.ExitCode; " +
        "    if ($code -eq 0 -or $code -eq 1638 -or $code -eq 3010) { Write-Host ('[VCRedist] OK exit=' + $code) } " +
        "    else { Write-Host ('[VCRedist] WARN exit=' + $code) } " +
        "  } catch { Write-Host ('[VCRedist] Error: ' + $_.ToString()) } " +
        "} else { Write-Host '[VCRedist] vc_redist.x64.exe not found, skipping' }";

    component.addOperation(
        "Execute",
        "powershell.exe",
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-Command", vcRedistScript
    );

    var protocolRegScript =
        "$targetDir = " + psLiteral(toWindowsPath(targetDir)) + "; " +
        "$exePath = Join-Path $targetDir 'DataSafebox.exe'; " +
        "New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT -ErrorAction SilentlyContinue | Out-Null; " +
        "if (-not (Test-Path 'HKCR:\\dianshu')) { New-Item -Path 'HKCR:\\dianshu' -Force | Out-Null }; " +
        "Set-ItemProperty -Path 'HKCR:\\dianshu' -Name '(default)' -Value 'URL:Dianshu Protocol'; " +
        "Set-ItemProperty -Path 'HKCR:\\dianshu' -Name 'URL Protocol' -Value ''; " +
        "if (-not (Test-Path 'HKCR:\\dianshu\\shell\\open\\command')) { New-Item -Path 'HKCR:\\dianshu\\shell\\open\\command' -Force | Out-Null }; " +
        "$command = '\"' + $exePath + '\" \"%1\"'; " +
        "Set-ItemProperty -Path 'HKCR:\\dianshu\\shell\\open\\command' -Name '(default)' -Value $command;";

    component.addOperation(
        "Execute",
        "powershell.exe",
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-Command", protocolRegScript
    );
};
