[CmdletBinding()]
param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$Ref,

  [ValidateSet('Debug', 'Release')]
  [string]$Configuration = 'Release',

  [switch]$Deploy,

  [string]$GameDirectory = 'D:\Games\Sunrise\ProjectSunrise'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Find-MSBuild {
  $command = Get-Command MSBuild.exe -ErrorAction SilentlyContinue
  if ($null -ne $command) {
    return $command.Source
  }

  $vswhere = 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe'
  if (Test-Path -LiteralPath $vswhere) {
    $installPath = & $vswhere -latest -products * -requires Microsoft.Component.MSBuild `
      -property installationPath
    if ($LASTEXITCODE -eq 0 -and $installPath) {
      $candidate = Join-Path $installPath 'MSBuild\Current\Bin\MSBuild.exe'
      if (Test-Path -LiteralPath $candidate) {
        return $candidate
      }
    }
  }

  throw 'MSBuild was not found. Install Visual Studio C++ build tools for this solution.'
}

function Invoke-Git {
  param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)

  & git @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "Git failed: git $($Arguments -join ' ')"
  }
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = [System.IO.Path]::GetFullPath($repoRoot)
$worktreeRoot = [System.IO.Path]::GetFullPath((Join-Path $repoRoot '.worktrees'))
$msbuild = Find-MSBuild

Push-Location $repoRoot
try {
  $commit = (& git rev-parse --verify "$Ref`^{commit}").Trim()
  if ($LASTEXITCODE -ne 0 -or $commit -notmatch '^[0-9a-f]{40}$') {
    throw "Git ref does not name a commit: $Ref"
  }

  $worktreePath = [System.IO.Path]::GetFullPath((Join-Path $worktreeRoot $commit))
  $worktreePrefix = $worktreeRoot.TrimEnd('\') + '\'
  if (-not $worktreePath.StartsWith($worktreePrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'The worktree path is outside the allowed worktree directory.'
  }

  New-Item -ItemType Directory -Path $worktreeRoot -Force | Out-Null
  Invoke-Git worktree add --detach $worktreePath $commit

  try {
    $solution = Join-Path $worktreePath 'Sunrise.sln'
    & $msbuild $solution /m /t:Build "/p:Configuration=$Configuration" /p:Platform=x64
    if ($LASTEXITCODE -ne 0) {
      throw "The $Configuration x64 build failed."
    }

    $builtDll = Join-Path $worktreePath "build\x64\$Configuration\steam_api64.dll"
    if (-not (Test-Path -LiteralPath $builtDll -PathType Leaf)) {
      throw "The build did not create the expected DLL: $builtDll"
    }

    $artifactDirectory = Join-Path $repoRoot "build\refs\$commit\$Configuration"
    New-Item -ItemType Directory -Path $artifactDirectory -Force | Out-Null
    $artifactDll = Join-Path $artifactDirectory 'steam_api64.dll'
    Copy-Item -LiteralPath $builtDll -Destination $artifactDll -Force

    Write-Host "Built $Ref at commit $commit"
    Write-Host "Artifact: $artifactDll"

    if ($Deploy) {
      $gameRoot = [System.IO.Path]::GetFullPath($GameDirectory)
      $liveGameRoot = [System.IO.Path]::GetFullPath(
        'C:\Program Files (x86)\Steam\steamapps\common\Destiny 2'
      )
      if ($gameRoot.Equals($liveGameRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'Deployment to the live Destiny 2 directory is not allowed.'
      }

      $gameExe = Join-Path $gameRoot 'destiny2.exe'
      if (-not (Test-Path -LiteralPath $gameExe -PathType Leaf)) {
        throw "The test game was not found: $gameExe"
      }
      if (Get-Process destiny2 -ErrorAction SilentlyContinue) {
        throw 'Close destiny2.exe before DLL deployment.'
      }

      $targetDll = Join-Path $gameRoot 'bin\x64\steam_api64.dll'
      $backupDirectory = Join-Path $gameRoot 'bin\x64\Sunrise\backups'
      New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null

      if (Test-Path -LiteralPath $targetDll -PathType Leaf) {
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $backupDll = Join-Path $backupDirectory "steam_api64-$stamp.dll"
        Copy-Item -LiteralPath $targetDll -Destination $backupDll
        Write-Host "Backup: $backupDll"
      }

      Copy-Item -LiteralPath $artifactDll -Destination $targetDll -Force
      Write-Host "Deployed: $targetDll"
    }
  }
  finally {
    if (Test-Path -LiteralPath $worktreePath) {
      Invoke-Git worktree remove --force $worktreePath
    }
  }
}
finally {
  Pop-Location
}
