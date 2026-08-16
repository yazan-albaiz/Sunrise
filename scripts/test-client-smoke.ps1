[CmdletBinding()]
param(
  [string]$Ref = 'HEAD',

  [ValidateSet('Debug', 'Release')]
  [string]$Configuration = 'Release',

  [string]$GameDirectory = 'D:\Games\Sunrise\ProjectSunrise',

  [ValidateRange(0, 2)]
  [int]$CharacterIndex = 0,

  [ValidateRange(30, 600)]
  [int]$StartTimeoutSeconds = 240,

  [ValidateRange(30, 600)]
  [int]$WorldTimeoutSeconds = 180,

  [switch]$PlanOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class SunriseSmokeInput
{
    [StructLayout(LayoutKind.Sequential)]
    public struct Point
    {
        public int X;
        public int Y;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct Rect
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    [DllImport("user32.dll")]
    public static extern bool ClientToScreen(IntPtr window, ref Point point);

    [DllImport("user32.dll")]
    public static extern bool GetClientRect(IntPtr window, out Rect rect);

    [DllImport("user32.dll")]
    public static extern bool SetCursorPos(int x, int y);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr window);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr window, int command);

    [DllImport("user32.dll")]
    public static extern void mouse_event(uint flags, uint x, uint y, uint data, UIntPtr extraInfo);

    [DllImport("user32.dll")]
    public static extern void keybd_event(byte key, byte scan, uint flags, UIntPtr extraInfo);
}
'@

function Resolve-Commit {
  param([string]$GitRef)

  $commit = (& git rev-parse --verify "$GitRef`^{commit}").Trim()
  if ($LASTEXITCODE -ne 0 -or $commit -notmatch '^[0-9a-f]{40}$') {
    throw "Git ref does not name a commit: $GitRef"
  }
  return $commit
}

function Get-LogCursor {
  param([string]$Path)

  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    return [pscustomobject]@{ CreationUtc = [datetime]::MinValue; Length = 0L }
  }

  $file = Get-Item -LiteralPath $Path
  return [pscustomobject]@{ CreationUtc = $file.CreationTimeUtc; Length = $file.Length }
}

function Get-NewLogText {
  param(
    [string]$Path,
    [pscustomobject]$Cursor
  )

  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    return ''
  }

  $file = Get-Item -LiteralPath $Path
  $offset = $Cursor.Length
  if ($file.CreationTimeUtc -ne $Cursor.CreationUtc -or $file.Length -lt $offset) {
    $offset = 0
  }
  if ($file.Length -le $offset) {
    return ''
  }

  $stream = [System.IO.File]::Open(
    $Path,
    [System.IO.FileMode]::Open,
    [System.IO.FileAccess]::Read,
    [System.IO.FileShare]::ReadWrite
  )
  try {
    $null = $stream.Seek($offset, [System.IO.SeekOrigin]::Begin)
    $reader = [System.IO.StreamReader]::new($stream)
    try {
      return $reader.ReadToEnd()
    }
    finally {
      $reader.Dispose()
    }
  }
  finally {
    $stream.Dispose()
  }
}

function Wait-LogPattern {
  param(
    [System.Diagnostics.Process]$Process,
    [string]$LogPath,
    [pscustomobject]$Cursor,
    [string]$Pattern,
    [int]$TimeoutSeconds,
    [string]$Stage
  )

  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  while ((Get-Date) -lt $deadline) {
    $Process.Refresh()
    if ($Process.HasExited) {
      throw "destiny2.exe exited during the $Stage stage with code $($Process.ExitCode)."
    }

    $text = Get-NewLogText -Path $LogPath -Cursor $Cursor
    if ($text -match 'ev=hook .*result=fail') {
      throw "A required Client hook failed during the $Stage stage."
    }
    if ($text -match $Pattern) {
      return
    }
    Start-Sleep -Seconds 1
  }

  throw "The $Stage stage did not finish in $TimeoutSeconds seconds."
}

function Get-ClientArea {
  param([System.Diagnostics.Process]$Process)

  $Process.Refresh()
  $window = $Process.MainWindowHandle
  if ($window -eq [IntPtr]::Zero) {
    throw 'destiny2.exe does not have a main window.'
  }

  $rect = [SunriseSmokeInput+Rect]::new()
  $origin = [SunriseSmokeInput+Point]::new()
  if (-not [SunriseSmokeInput]::GetClientRect($window, [ref]$rect)) {
    throw 'Could not read the Destiny 2 client area.'
  }
  if (-not [SunriseSmokeInput]::ClientToScreen($window, [ref]$origin)) {
    throw 'Could not find the Destiny 2 client position.'
  }

  return [pscustomobject]@{
    Window = $window
    Left = $origin.X
    Top = $origin.Y
    Width = $rect.Right - $rect.Left
    Height = $rect.Bottom - $rect.Top
  }
}

function Set-GameForeground {
  param([System.Diagnostics.Process]$Process)

  $area = Get-ClientArea -Process $Process
  $null = [SunriseSmokeInput]::ShowWindow($area.Window, 9)
  $null = [SunriseSmokeInput]::SetForegroundWindow($area.Window)
  Start-Sleep -Milliseconds 500
}

function Invoke-GameClick {
  param(
    [System.Diagnostics.Process]$Process,
    [double]$XRatio,
    [double]$YRatio
  )

  Set-GameForeground -Process $Process
  $area = Get-ClientArea -Process $Process
  if ($area.Width -lt 1280 -or $area.Height -lt 720) {
    throw "The game client area is too small: $($area.Width)x$($area.Height)."
  }

  $x = $area.Left + [math]::Round($area.Width * $XRatio)
  $y = $area.Top + [math]::Round($area.Height * $YRatio)
  if (-not [SunriseSmokeInput]::SetCursorPos($x, $y)) {
    throw 'Could not move the mouse pointer into the Destiny 2 window.'
  }
  [SunriseSmokeInput]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
  [SunriseSmokeInput]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
}

function Invoke-GameKey {
  param(
    [System.Diagnostics.Process]$Process,
    [byte]$VirtualKey
  )

  Set-GameForeground -Process $Process
  [SunriseSmokeInput]::keybd_event($VirtualKey, 0, 0, [UIntPtr]::Zero)
  [SunriseSmokeInput]::keybd_event($VirtualKey, 0, 0x0002, [UIntPtr]::Zero)
}

function Save-FailureScreenshot {
  param(
    [System.Diagnostics.Process]$Process,
    [string]$Path
  )

  try {
    Add-Type -AssemblyName System.Drawing
    $area = Get-ClientArea -Process $Process
    $bitmap = [System.Drawing.Bitmap]::new($area.Width, $area.Height)
    try {
      $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
      try {
        $graphics.CopyFromScreen($area.Left, $area.Top, 0, 0, $bitmap.Size)
      }
      finally {
        $graphics.Dispose()
      }
      $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
      $bitmap.Dispose()
    }
  }
  catch {
    Write-Warning "Could not save the failure screenshot: $($_.Exception.Message)"
  }
}

$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$gameRoot = [System.IO.Path]::GetFullPath($GameDirectory)
$liveGameRoot = [System.IO.Path]::GetFullPath(
  'C:\Program Files (x86)\Steam\steamapps\common\Destiny 2'
)
if ($gameRoot.Equals($liveGameRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
  throw 'The client smoke test cannot use the live Destiny 2 directory.'
}

$gameExe = Join-Path $gameRoot 'destiny2.exe'
$targetDll = Join-Path $gameRoot 'bin\x64\steam_api64.dll'
$settingsPath = Join-Path $gameRoot 'bin\x64\Sunrise\settings.json'
$logPath = Join-Path $gameRoot 'bin\x64\Sunrise\logs\sunrise.log'
if (-not (Test-Path -LiteralPath $gameExe -PathType Leaf)) {
  throw "The isolated game executable was not found: $gameExe"
}
if (Get-Process destiny2 -ErrorAction SilentlyContinue) {
  throw 'Close destiny2.exe before the client smoke test.'
}

Push-Location $repoRoot
try {
  $commit = Resolve-Commit -GitRef $Ref
}
finally {
  Pop-Location
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$artifactDirectory = Join-Path $repoRoot "build\smoke\$stamp-$($commit.Substring(0, 12))"
$backupDll = Join-Path $artifactDirectory 'before-steam_api64.dll'
$backupSettings = Join-Path $artifactDirectory 'before-settings.json'
$failureScreenshot = Join-Path $artifactDirectory 'failure.png'
$capturedLog = Join-Path $artifactDirectory 'sunrise.log'

if ($PlanOnly) {
  [pscustomobject]@{
    Commit = $commit
    Configuration = $Configuration
    GameDirectory = $gameRoot
    CharacterIndex = $CharacterIndex
    Destination = 'EDZ Trostland'
  }
  return
}

New-Item -ItemType Directory -Path $artifactDirectory -Force | Out-Null
$hadDll = Test-Path -LiteralPath $targetDll -PathType Leaf
$hadSettings = Test-Path -LiteralPath $settingsPath -PathType Leaf
if ($hadDll) {
  Copy-Item -LiteralPath $targetDll -Destination $backupDll
}
if ($hadSettings) {
  Copy-Item -LiteralPath $settingsPath -Destination $backupSettings
}

$gameProcess = $null
$passed = $false
try {
  & (Join-Path $PSScriptRoot 'build-ref.ps1') $commit `
    -Configuration $Configuration -Deploy -GameDirectory $gameRoot

  $startCursor = Get-LogCursor -Path $logPath
  $gameProcess = Start-Process -FilePath $gameExe -WorkingDirectory $gameRoot -PassThru

  $windowDeadline = (Get-Date).AddSeconds($StartTimeoutSeconds)
  while ((Get-Date) -lt $windowDeadline) {
    $gameProcess.Refresh()
    if ($gameProcess.HasExited) {
      throw "destiny2.exe exited during startup with code $($gameProcess.ExitCode)."
    }
    if ($gameProcess.MainWindowHandle -ne [IntPtr]::Zero) {
      break
    }
    Start-Sleep -Seconds 1
  }
  if ($gameProcess.MainWindowHandle -eq [IntPtr]::Zero) {
    throw "destiny2.exe did not create a window in $StartTimeoutSeconds seconds."
  }

  Wait-LogPattern -Process $gameProcess -LogPath $logPath -Cursor $startCursor `
    -Pattern 'ev=bootflow stage=character_select result=held' `
    -TimeoutSeconds $StartTimeoutSeconds -Stage 'character select'

  $orbitCursor = Get-LogCursor -Path $logPath
  $characterY = (610 + (148 * $CharacterIndex)) / 1440
  Invoke-GameClick -Process $gameProcess -XRatio (1810 / 2560) -YRatio $characterY
  Wait-LogPattern -Process $gameProcess -LogPath $logPath -Cursor $orbitCursor `
    -Pattern 'world_controller: successfully changed world to: orbit_d2' `
    -TimeoutSeconds $WorldTimeoutSeconds -Stage 'orbit'

  Start-Sleep -Seconds 8
  Invoke-GameKey -Process $gameProcess -VirtualKey 0x4D
  Start-Sleep -Seconds 4
  Invoke-GameClick -Process $gameProcess -XRatio (1265 / 2560) -YRatio (820 / 1440)
  Start-Sleep -Seconds 4
  Invoke-GameClick -Process $gameProcess -XRatio (1880 / 2560) -YRatio (1350 / 1440)
  Start-Sleep -Seconds 2

  $destinationCursor = Get-LogCursor -Path $logPath
  Invoke-GameClick -Process $gameProcess -XRatio (2180 / 2560) -YRatio (1200 / 1440)
  Wait-LogPattern -Process $gameProcess -LogPath $logPath -Cursor $destinationCursor `
    -Pattern 'world_controller: successfully changed world to: edz_freeroam' `
    -TimeoutSeconds $WorldTimeoutSeconds -Stage 'EDZ Trostland'

  $passed = $true
  Write-Host "Client smoke test passed for commit $commit."
  Write-Host 'The isolated client reached EDZ Trostland.'
}
catch {
  if ($null -ne $gameProcess -and -not $gameProcess.HasExited) {
    Save-FailureScreenshot -Process $gameProcess -Path $failureScreenshot
  }
  throw
}
finally {
  if (Test-Path -LiteralPath $logPath -PathType Leaf) {
    Copy-Item -LiteralPath $logPath -Destination $capturedLog -Force
  }
  if ($null -ne $gameProcess -and -not $gameProcess.HasExited) {
    Stop-Process -Id $gameProcess.Id
    $gameProcess.WaitForExit(15000) | Out-Null
  }
  if ($hadDll) {
    Copy-Item -LiteralPath $backupDll -Destination $targetDll -Force
  }
  elseif (Test-Path -LiteralPath $targetDll -PathType Leaf) {
    Remove-Item -LiteralPath $targetDll
  }
  if ($hadSettings) {
    Copy-Item -LiteralPath $backupSettings -Destination $settingsPath -Force
  }
  elseif (Test-Path -LiteralPath $settingsPath -PathType Leaf) {
    Remove-Item -LiteralPath $settingsPath
  }

  $result = [pscustomobject]@{
    Commit = $commit
    Configuration = $Configuration
    Passed = $passed
    Destination = 'EDZ Trostland'
    FinishedAt = (Get-Date).ToString('o')
  }
  $result | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $artifactDirectory 'result.json')
  Write-Host "Smoke artifacts: $artifactDirectory"
}
