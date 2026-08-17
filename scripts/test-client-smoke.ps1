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
    public struct MouseInput
    {
        public int Dx;
        public int Dy;
        public uint MouseData;
        public uint Flags;
        public uint Time;
        public UIntPtr ExtraInfo;
    }

    [StructLayout(LayoutKind.Explicit)]
    public struct InputValue
    {
        [FieldOffset(0)]
        public MouseInput Mouse;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct Input
    {
        public uint Type;
        public InputValue Value;
    }

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
    public static extern bool BringWindowToTop(IntPtr window);

    [DllImport("user32.dll")]
    public static extern IntPtr SetFocus(IntPtr window);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr window, IntPtr processId);

    [DllImport("kernel32.dll")]
    public static extern uint GetCurrentThreadId();

    [DllImport("user32.dll")]
    public static extern bool AttachThreadInput(uint first, uint second, bool attach);

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern IntPtr GetAncestor(IntPtr window, uint flags);

    [DllImport("user32.dll")]
    public static extern bool SetProcessDPIAware();

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr window, int command);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern uint SendInput(uint inputCount, Input[] inputs, int inputSize);

    [DllImport("user32.dll")]
    public static extern int GetSystemMetrics(int index);

    [DllImport("user32.dll")]
    public static extern void keybd_event(byte key, byte scan, uint flags, UIntPtr extraInfo);

    public static void ClickAt(int x, int y)
    {
        const uint mouseInput = 0;
        const uint move = 0x0001;
        const uint leftDown = 0x0002;
        const uint leftUp = 0x0004;
        const uint virtualDesk = 0x4000;
        const uint absolute = 0x8000;
        int left = GetSystemMetrics(76);
        int top = GetSystemMetrics(77);
        int width = GetSystemMetrics(78);
        int height = GetSystemMetrics(79);
        int normalizedX = (int)Math.Round((x - left) * 65535.0 / (width - 1));
        int normalizedY = (int)Math.Round((y - top) * 65535.0 / (height - 1));
        Input[] movement = new Input[1];
        movement[0].Type = mouseInput;
        movement[0].Value.Mouse.Dx = normalizedX;
        movement[0].Value.Mouse.Dy = normalizedY;
        movement[0].Value.Mouse.Flags = move | virtualDesk | absolute;
        int inputSize = Marshal.SizeOf(typeof(Input));
        if (SendInput(1, movement, inputSize) != 1)
        {
            throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
        }
        System.Threading.Thread.Sleep(750);
        Input[] click = new Input[2];
        click[0].Type = mouseInput;
        click[0].Value.Mouse.Flags = leftDown;
        click[1].Type = mouseInput;
        click[1].Value.Mouse.Flags = leftUp;
        if (SendInput((uint)click.Length, click, inputSize) != click.Length)
        {
            throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
        }
    }
}
'@

$null = [SunriseSmokeInput]::SetProcessDPIAware()

$uiTargets = @{
  CharacterList = [pscustomobject]@{ X = 1810 / 2560; FirstY = 610; RowHeight = 148 }
  CharacterAction = [pscustomobject]@{ X = 2205 / 2560; Y = 610 / 1440 }
  Earth = [pscustomobject]@{ X = 1265 / 2560; Y = 820 / 1440 }
  TrostlandMarker = [pscustomobject]@{ X = 1890 / 2560; Y = 1220 / 1440 }
  Launch = [pscustomobject]@{ X = 2180 / 2560; Y = 1200 / 1440 }
}

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
    [string]$Stage,
    [scriptblock]$Pulse,
    [int]$PulseIntervalSeconds = 5
  )

  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  $nextPulse = [datetime]::MinValue
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
    if ($null -ne $Pulse -and (Get-Date) -ge $nextPulse) {
      & $Pulse
      $nextPulse = (Get-Date).AddSeconds($PulseIntervalSeconds)
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

function Get-GameViewport {
  param([System.Diagnostics.Process]$Process)

  $area = Get-ClientArea -Process $Process
  $knownSizes = @(
    [pscustomobject]@{ Width = 1280; Height = 720 },
    [pscustomobject]@{ Width = 1920; Height = 1080 },
    [pscustomobject]@{ Width = 2560; Height = 1440 },
    [pscustomobject]@{ Width = 3840; Height = 2160 }
  )
  $size = $knownSizes | Where-Object {
    [math]::Abs($area.Width - $_.Width) -le 32 `
      -and [math]::Abs($area.Height - $_.Height) -le 64
  } | Select-Object -First 1
  if ($null -eq $size) {
    throw "The smoke route requires a known 16:9 game size. Current size: $($area.Width)x$($area.Height)."
  }

  return [pscustomobject]@{
    Window = $area.Window
    Left = $area.Left
    Top = $area.Top
    Width = $area.Width
    Height = $area.Height
  }
}

function Set-GameForeground {
  param([System.Diagnostics.Process]$Process)

  $area = Get-ClientArea -Process $Process
  $currentThread = [SunriseSmokeInput]::GetCurrentThreadId()
  $windowThread = [SunriseSmokeInput]::GetWindowThreadProcessId($area.Window, [IntPtr]::Zero)
  $attached = $currentThread -ne $windowThread `
    -and [SunriseSmokeInput]::AttachThreadInput($currentThread, $windowThread, $true)
  try {
    $null = [SunriseSmokeInput]::ShowWindow($area.Window, 3)
    $null = [SunriseSmokeInput]::BringWindowToTop($area.Window)
    [SunriseSmokeInput]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero)
    [SunriseSmokeInput]::keybd_event(0x12, 0, 0x0002, [UIntPtr]::Zero)
    $null = [SunriseSmokeInput]::SetForegroundWindow($area.Window)
    $null = [SunriseSmokeInput]::SetFocus($area.Window)
  }
  finally {
    if ($attached) {
      $null = [SunriseSmokeInput]::AttachThreadInput($currentThread, $windowThread, $false)
    }
  }
  Start-Sleep -Milliseconds 500
  $foregroundRoot = [SunriseSmokeInput]::GetAncestor(
    [SunriseSmokeInput]::GetForegroundWindow(), 2
  )
  if ($foregroundRoot -ne $area.Window) {
    $shell = New-Object -ComObject WScript.Shell
    try {
      $null = $shell.AppActivate($Process.Id)
    }
    finally {
      $null = [System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell)
    }
    Start-Sleep -Milliseconds 500
  }
  $foregroundRoot = [SunriseSmokeInput]::GetAncestor(
    [SunriseSmokeInput]::GetForegroundWindow(), 2
  )
  if ($foregroundRoot -ne $area.Window) {
    throw 'Could not give input focus to Destiny 2 after two focus requests.'
  }
}

function Invoke-GameClick {
  param(
    [System.Diagnostics.Process]$Process,
    [double]$XRatio,
    [double]$YRatio
  )

  Set-GameForeground -Process $Process
  $area = Get-GameViewport -Process $Process
  if ($area.Width -lt 1280 -or $area.Height -lt 720) {
    throw "The game client area is too small: $($area.Width)x$($area.Height)."
  }

  $x = $area.Left + [math]::Round($area.Width * $XRatio)
  $y = $area.Top + [math]::Round($area.Height * $YRatio)
  [SunriseSmokeInput]::ClickAt($x, $y)
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

function Invoke-HeldGameKey {
  param(
    [System.Diagnostics.Process]$Process,
    [byte]$VirtualKey
  )

  Set-GameForeground -Process $Process
  [SunriseSmokeInput]::keybd_event($VirtualKey, 0, 0, [UIntPtr]::Zero)
  try {
    Start-Sleep -Milliseconds 250
  }
  finally {
    [SunriseSmokeInput]::keybd_event($VirtualKey, 0, 0x0002, [UIntPtr]::Zero)
  }
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
$approvedGameRoot = [System.IO.Path]::GetFullPath((Join-Path $repoRoot 'ProjectSunrise'))
if (-not $gameRoot.Equals($approvedGameRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
  throw "The client smoke test can use only the approved isolated client: $approvedGameRoot"
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
$shutdownFailure = $null
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
    -TimeoutSeconds $StartTimeoutSeconds -Stage 'character select' `
    -Pulse { Invoke-GameKey -Process $gameProcess -VirtualKey 0x0D }

  $orbitCursor = Get-LogCursor -Path $logPath
  $characterY = ($uiTargets.CharacterList.FirstY `
    + ($uiTargets.CharacterList.RowHeight * $CharacterIndex)) / 1440
  Invoke-GameClick -Process $gameProcess -XRatio $uiTargets.CharacterList.X -YRatio $characterY
  Invoke-GameClick -Process $gameProcess `
    -XRatio $uiTargets.CharacterAction.X -YRatio $uiTargets.CharacterAction.Y
  Start-Sleep -Milliseconds 1500
  Invoke-GameKey -Process $gameProcess -VirtualKey 0x1B
  Invoke-GameClick -Process $gameProcess -XRatio $uiTargets.CharacterList.X -YRatio $characterY
  Wait-LogPattern -Process $gameProcess -LogPath $logPath -Cursor $orbitCursor `
    -Pattern 'world_controller: successfully changed world to: orbit_d2' `
    -TimeoutSeconds $WorldTimeoutSeconds -Stage 'orbit'

  Start-Sleep -Seconds 8
  Invoke-HeldGameKey -Process $gameProcess -VirtualKey 0x4D
  Start-Sleep -Seconds 5
  Invoke-GameClick -Process $gameProcess -XRatio $uiTargets.Earth.X -YRatio $uiTargets.Earth.Y
  Start-Sleep -Seconds 5
  Invoke-GameClick -Process $gameProcess `
    -XRatio $uiTargets.TrostlandMarker.X -YRatio $uiTargets.TrostlandMarker.Y
  Start-Sleep -Seconds 3

  $destinationCursor = Get-LogCursor -Path $logPath
  Invoke-GameClick -Process $gameProcess -XRatio $uiTargets.Launch.X -YRatio $uiTargets.Launch.Y
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
    try {
      Stop-Process -Id $gameProcess.Id -ErrorAction Stop
      if (-not $gameProcess.WaitForExit(15000) -or -not $gameProcess.HasExited) {
        $shutdownFailure =
          "Destiny 2 did not stop within 15 seconds. Backups remain in $artifactDirectory."
      }
    }
    catch {
      $shutdownFailure =
        "Could not confirm that Destiny 2 stopped. Backups remain in $artifactDirectory. $($_.Exception.Message)"
    }
  }
  if ($null -eq $shutdownFailure) {
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
  }
  else {
    $passed = $false
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
  if ($null -ne $shutdownFailure) {
    throw $shutdownFailure
  }
}
