<#
Deploy the Rain Harness green build to a stable folder and keep one desktop shortcut valid.

The app files are mirrored into -InstallDir on every run. Everything the app owns at runtime
lives outside the app folder (~/.raindsh and %APPDATA%\@rainroom\dsh-desktop), so replacing the
program files never touches sessions, credentials, workspaces or installed plugins.

Usage:
  powershell -ExecutionPolicy Bypass -File fork\install-green.ps1                 # build, then deploy
  powershell -ExecutionPolicy Bypass -File fork\install-green.ps1 -SkipBuild      # deploy existing build
#>
[CmdletBinding()]
param(
  [string]$Repo = 'D:\E\AI_DEV_PROJECT\dsh-use',
  [string]$InstallDir = 'D:\E\AI_DEV_PROJECT\dsh-use-app',
  [string]$ProductName = 'Rain Harness',
  [switch]$SkipBuild,
  [switch]$NoShortcut
)

$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
  Write-Host "install-green: $Message" -ForegroundColor Red
  exit 1
}

$desktop = Join-Path $Repo 'apps\desktop'
if (-not (Test-Path $desktop)) { Fail "missing $desktop" }

# A fresh clone has no apps/desktop/.env.windows because it is git-ignored. Unsigned builds only
# need the installer identity, so create the minimum instead of failing at the packaging step.
$envFile = Join-Path $desktop '.env.windows'
if (-not (Test-Path $envFile)) {
  $template = Join-Path $PSScriptRoot 'windows.env.template'
  $appIdLine = $null
  if (Test-Path $template) {
    $appIdLine = Get-Content $template |
      Where-Object { $_ -match '^\s*DSH_DESKTOP_APP_ID=' } |
      Select-Object -First 1
  }
  if (-not $appIdLine) { $appIdLine = 'DSH_DESKTOP_APP_ID=com.rainroom.harness' }
  Write-Host "install-green: creating $envFile ($($appIdLine.Trim()))"
  Set-Content -Path $envFile -Encoding ASCII -Value @(
    '# Rain Harness fork Windows packaging settings (local, git-ignored).',
    '# Written by fork/install-green.ps1; source template: fork/windows.env.template',
    $appIdLine.Trim()
  )
}

if (-not $SkipBuild) {
  Write-Host 'install-green: building (roughly 20 minutes)...'
  Push-Location $desktop
  try {
    & pnpm exec tsx scripts/package-target.ts win-x64 --unsigned --dir
    if ($LASTEXITCODE -ne 0) { Fail "build failed with exit code $LASTEXITCODE" }
  }
  finally { Pop-Location }
}

$source = Join-Path $desktop '.desktop-build\targets\win-x64\unsigned-artifacts\win-unpacked'
if (-not (Test-Path (Join-Path $source "$ProductName.exe"))) { Fail "no build output at $source" }

# Running instances hold file locks that would break the mirror.
$running = @(Get-Process -Name $ProductName -ErrorAction SilentlyContinue)
if ($running.Count -gt 0) {
  Write-Host "install-green: closing $($running.Count) running instance(s)"
  $running | ForEach-Object { [void]$_.CloseMainWindow() }
  Start-Sleep -Seconds 5
  Get-Process -Name $ProductName -ErrorAction SilentlyContinue |
    Stop-Process -Force -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 2
}

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
Write-Host "install-green: mirroring build into $InstallDir"
& robocopy $source $InstallDir /MIR /NFL /NDL /NJH /NJS /R:1 /W:1 | Out-Null
# robocopy reports 0-7 for success variants; 8 and above mean at least one file failed.
if ($LASTEXITCODE -ge 8) { Fail "robocopy failed with code $LASTEXITCODE" }

$exe = Join-Path $InstallDir "$ProductName.exe"
if (-not (Test-Path $exe)) { Fail "missing $exe after mirror" }

if (-not $NoShortcut) {
  $link = Join-Path ([Environment]::GetFolderPath('Desktop')) "$ProductName.lnk"
  $shell = New-Object -ComObject WScript.Shell
  $shortcut = $shell.CreateShortcut($link)
  $shortcut.TargetPath = $exe
  $shortcut.WorkingDirectory = $InstallDir
  $shortcut.IconLocation = $exe
  $shortcut.Description = "$ProductName (fork build)"
  $shortcut.Save()
  Write-Host "install-green: shortcut $link"
}

$harnessHome = Join-Path $env:USERPROFILE '.raindsh'
$userData = Join-Path $env:APPDATA '@rainroom\dsh-desktop'
Write-Host "install-green: deployed $((Get-Item $exe).LastWriteTime) to $exe"
Write-Host "install-green: runtime data stays in $harnessHome and $userData"
if (-not (Test-Path $harnessHome)) {
  Write-Host 'install-green: note: no harness home yet; the first launch creates it'
}
