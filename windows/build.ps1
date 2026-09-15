# ProxyPin Windows 打包脚本
# 用法: 在 Windows 机器上, 项目根目录执行  powershell -ExecutionPolicy Bypass -File windows/build.ps1
# 产物输出到 dist/

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path (Split-Path $MyInvocation.MyCommand.Path -Parent) -Parent
Set-Location $ProjectRoot

$Version = "1.3.1"
$DistDir = Join-Path $ProjectRoot "dist"
$ReleaseDir = Join-Path $ProjectRoot "build\windows\x64\runner\Release"

# 1. 构建 Windows release
Write-Host "==> flutter build windows --release" -ForegroundColor Cyan
flutter build windows --release
if ($LASTEXITCODE -ne 0) { throw "flutter build failed" }

if (-not (Test-Path $ReleaseDir)) { throw "Release dir not found: $ReleaseDir" }
New-Item -ItemType Directory -Force -Path $DistDir | Out-Null

# 2. 生成 zip
Write-Host "==> Packing zip" -ForegroundColor Cyan
$ZipPath = Join-Path $DistDir "ProxyPin-$Version-windows.zip"
if (Test-Path $ZipPath) { Remove-Item $ZipPath }
Compress-Archive -Path "$ReleaseDir\*" -DestinationPath $ZipPath -CompressionLevel Optimal
Write-Host "    $ZipPath" -ForegroundColor Green

# 3. 生成 exe (Inno Setup, 需要安装 https://jrsoftware.org/isinfo.php)
$ISCC = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
if (Test-Path $ISCC) {
    Write-Host "==> Building Inno Setup installer" -ForegroundColor Cyan
    $IssPath = Join-Path $DistDir "ProxyPin-$Version.iss"
    $SetupIcon = Join-Path $ProjectRoot "windows\runner\resources\app_icon.ico"
    $Iss = @"
[Setup]
AppId={{502CBca5-A7F1-4F8F-894D-9820BAC2E36F}
AppName=ProxyPin
AppVersion=$Version
AppPublisher=ProxyPin
DefaultDirName={autopf64}\ProxyPin
DisableProgramGroupPage=yes
OutputDir=$DistDir
OutputBaseFilename=ProxyPin-$Version-windows-setup
Compression=lzma
SolidCompression=yes
SetupIconFile=$SetupIcon
WizardStyle=modern
CloseApplications=force

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: checkablealone

[Files]
Source: "$ReleaseDir\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\ProxyPin"; Filename: "{app}\proxypin.exe"
Name: "{autodesktop}\ProxyPin"; Filename: "{app}\proxypin.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\proxypin.exe"; Description: "{cm:LaunchProgram,ProxyPin}"; Flags: nowait postinstall skipifsilent
"@
    Set-Content -Path $IssPath -Value $Iss -Encoding ASCII
    & $ISCC $IssPath | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Host "    Inno Setup failed (exit $LASTEXITCODE)" -ForegroundColor Yellow } else { Write-Host "    Setup installer generated" -ForegroundColor Green }
} else {
    Write-Host "    Inno Setup not found at $ISCC, skip exe installer" -ForegroundColor Yellow
    Write-Host "    可安装 Inno Setup 6 后重试: https://jrsoftware.org/isinfo.php" -ForegroundColor Yellow
}

# 4. 生成 msix (需要 msix 工具: dart pub global activate msix)
$MsixTool = Get-Command msix -ErrorAction SilentlyContinue
if ($MsixTool) {
    Write-Host "==> Building msix" -ForegroundColor Cyan
    msix --install-certificate false
    if ($LASTEXITCODE -ne 0) { Write-Host "    msix build failed (exit $LASTEXITCODE)" -ForegroundColor Yellow }
} else {
    Write-Host "    msix tool not found, skip (安装: dart pub global activate msix)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "===== 打包完成, 产物在 dist/ =====" -ForegroundColor Green
Get-ChildItem $DistDir | Select-Object Name, @{N="Size(MB)";E={[math]::Round($_.Length/1MB,1)}}
