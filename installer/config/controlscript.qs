// 写日志到 C:\Temp\datasafe_install.log，方便排查问题
var LOG_FILE = "C:\\Temp\\datasafe_install.log";

function log(msg) {
    try {
        var ps = "Add-Content -Path '" + LOG_FILE + "' -Value (\"[\" + (Get-Date -Format 'HH:mm:ss') + \"] " + msg.replace(/'/g, "") + "\")";
        installer.execute("powershell.exe", ["-NoProfile", "-Command", ps]);
    } catch(e) {}
}

function Controller() {
    try {
        // 确保日志目录存在
        installer.execute("powershell.exe", ["-NoProfile", "-Command",
            "if (!(Test-Path 'C:\\Temp')) { New-Item -ItemType Directory -Path 'C:\\Temp' | Out-Null }; " +
            "Add-Content -Path '" + LOG_FILE + "' -Value '=== installer started ===';"
        ]);
    } catch(e) {}
}

// 对指定目录执行重命名（仅在确认是旧安装目录时才操作）
// 返回实际被重命名的目录路径（空字符串表示未操作）
function renameIfOverwrite(targetDir) {
    if (!targetDir) return "";

    var markerExe = targetDir + "/safebox.exe";
    var hasMarker = installer.fileExists(markerExe);
    log("renameIfOverwrite targetDir=" + targetDir + " markerExists=" + hasMarker);
    if (!hasMarker) return "";

    var filenames = ["components.xml", "maintenancetool.exe", "maintenancetool.dat", "maintenancetool.ini"];
    var cmdChain = "";
    for (var i = 0; i < filenames.length; ++i) {
        var fullPath = targetDir + "/" + filenames[i];
        var exists = installer.fileExists(fullPath);
        log("  file: " + fullPath + " exists=" + exists);
        if (exists) {
            var src = fullPath.replace(/\//g, "\\");
            if (cmdChain !== "") cmdChain += " & ";
            cmdChain += "move /y \"" + src + "\" \"" + src + ".bak\"";
        }
    }

    if (cmdChain === "") {
        log("  nothing to rename");
        return "";
    }

    log("  executing rename: " + cmdChain);
    var psCmd = "Start-Process cmd -ArgumentList '/c " + cmdChain + "' -Verb RunAs -Wait -WindowStyle Hidden";
    installer.execute("powershell.exe", ["-NoProfile", "-Command", psCmd]);
    log("  rename done");
    return targetDir;
}

// 还原指定目录下被重命名为 .bak 的安装文件
function restoreRenamedFiles(targetDir) {
    if (!targetDir) return;

    var filenames = ["components.xml", "maintenancetool.exe", "maintenancetool.dat", "maintenancetool.ini"];
    var cmdChain = "";
    for (var i = 0; i < filenames.length; ++i) {
        var bakPath = targetDir + "/" + filenames[i] + ".bak";
        if (installer.fileExists(bakPath)) {
            var src = bakPath.replace(/\//g, "\\");
            var dst = src.replace(".bak", "");
            if (cmdChain !== "") cmdChain += " & ";
            cmdChain += "move /y \"" + src + "\" \"" + dst + "\"";
        }
    }

    if (cmdChain === "") return;

    log("restoreRenamedFiles: " + targetDir + " cmd=" + cmdChain);
    var psCmd = "Start-Process cmd -ArgumentList '/c " + cmdChain + "' -Verb RunAs -Wait -WindowStyle Hidden";
    installer.execute("powershell.exe", ["-NoProfile", "-Command", psCmd]);
    log("restoreRenamedFiles done");
}

// TargetDirectoryPageCallback：
// 1. 页面显示时对当前路径做重命名（记录哪个目录被操作过）
// 2. 用户修改路径时：先还原上一次操作的目录，再对新路径做重命名
// 3. 这样始终只有用户最终选定的路径被重命名，切换路径不会留下残留
Controller.prototype.TargetDirectoryPageCallback = function() {
    try {
        log("TargetDirectoryPageCallback entered");

        if (!(installer.isInstaller() && installer.value("os") === "win")) {
            log("skip: not installer or not win");
            return;
        }

        var page = gui.pageWidgetByObjectName("TargetDirectoryPage");
        log("page found: " + (page ? "yes" : "no"));
        if (!page) return;

        var dirEdit = gui.findChild(page, "TargetDirectoryLineEdit");
        log("dirEdit found: " + (dirEdit ? "yes" : "no"));
        if (!dirEdit) return;

        // 记录当前已被重命名的目录，用于用户切换路径时还原
        var lastRenamedDir = "";

        // 页面显示时，对默认路径执行一次
        var initialDir = dirEdit.text.replace(/\\/g, "/").trim();
        log("initialDir: " + initialDir);
        lastRenamedDir = renameIfOverwrite(initialDir);

        // 用户修改路径时触发：先还原上一次操作的目录，再处理新路径
        dirEdit.textChanged.connect(function(newText) {
            var newDir = newText.replace(/\\/g, "/").trim();
            log("textChanged newDir=" + newDir + " lastRenamedDir=" + lastRenamedDir);

            // 路径没有变化，不需要做任何事
            if (newDir === lastRenamedDir) return;

            // 还原上一次重命名的目录（如果有的话）
            if (lastRenamedDir !== "") {
                restoreRenamedFiles(lastRenamedDir);
                lastRenamedDir = "";
            }

            // 对新路径判断是否需要重命名
            lastRenamedDir = renameIfOverwrite(newDir);
        });

    } catch (e) {
        log("TargetDirectoryPageCallback failed: " + e);
    }
};
