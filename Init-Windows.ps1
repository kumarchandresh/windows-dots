[CmdletBinding()]
param (
  [switch]$SelfExecuted,
  [ValidateSet('personal', 'work')]
  [string]$MachineType
)

# Get-ChildItem -Recurse -File | Where-Object { $_.Name -match '.ps(d|m)?1$' } | Unblock-File

# https://stackoverflow.com/a/49481797
# Display Unicode in PowerShell
# Required for properly formatting result of `winget list` command.
$PSDefaultParameterValues['*:Encoding'] = 'utf8'
$OutputEncoding = [Console]::OutputEncoding = [Console]::InputEncoding = [Text.Encoding]::UTF8

Import-Module -Force "$PSScriptRoot\home\Documents\PowerShell\Modules\Scoop"
Import-Module -Force "$PSScriptRoot\home\Documents\PowerShell\Modules\Utils"
Import-Module -Force "$PSScriptRoot\home\Documents\PowerShell\Modules\WinGet"

function Write-Title {
  Write-Host ''
  Write-Host @args -ForegroundColor Blue
}

Write-Host ''
Write-Host "Running as admin? $(if (Test-IsProcessElevated) { 'Yes' } else { 'No' })" -ForegroundColor Magenta
Write-Host "Executed itself? $(if($SelfExecuted) { 'Yes' } else { 'No' })" -ForegroundColor Magenta

if (Test-WindowsTerminal) {
  throw 'Cannot be executed from Windows Terminal.'
}

if ((Test-IsProcessElevated) -and (-not $SelfExecuted)) {
  throw 'Cannot be executed from an elevated PowerShell session.'
}

if ($PSEdition -eq 'Core' -and (-not $SelfExecuted)) {
  throw 'Must be executed from Windows PowerShell (not PowerShell Core).'
}

if (-not $PSBoundParameters.ContainsKey('MachineType')) {
  $validMachineTypes = @('personal', 'work')
  $MachineType = Read-Host "Enter machine type (`"$($validMachineTypes -join '`" or `"')`")"
  if ($MachineType -notin $validMachineTypes) {
    throw "Invalid machine type: $MachineType. Please enter 'personal' or 'work'."
  }
}

# Bootstrap in PowerShell (Core)
if ($PSEdition -ne 'Core') {

  # https://learn.microsoft.com/en-us/windows/package-manager/winget
  Write-Title '(+) Install winget'
  if (-not (Test-IsCommandAvailable 'winget')) {
    throw 'winget is not available; visit https://github.com/microsoft/winget-cli'
  }
  else {
    winget source update
    winget upgrade winget
  }

  # TODO: Figure out how to register Windows Terminal Preview as the default terminal (in Win+X menu) and keep both
  if (Test-IsWinGetPackageInstalled 'Microsoft.WindowsTerminal') {
    Write-Title '(-) Uninstall Windows Terminal'
    winget uninstall 'Microsoft.WindowsTerminal'
  }

  # https://github.com/microsoft/terminal
  Write-Title '(+) Install Windows Terminal (Preview)'
  Install-WinGetPackage 'Microsoft.WindowsTerminal.Preview'

  # https://github.com/ScoopInstaller/Scoop/wiki
  Write-Title '(+) Install scoop'
  if (-not (Test-IsCommandAvailable 'scoop')) {
    Write-Host '(=) Set scoop branch (develop)'
    $env:SCOOP_BRANCH = 'develop'
    Invoke-RestMethod -Uri 'https://get.scoop.sh' | Invoke-Expression; Restore-EnvPath

    if (-not (Test-IsCommandAvailable 'scoop')) {
      throw 'scoop is not available; visit https://github.com/ScoopInstaller/Scoop'
    }
  }
  else {
    if ((scoop config scoop_branch) -ne 'develop') {
      Write-Host '(=) Set scoop branch (develop)'
      scoop config scoop_branch develop
    }
    scoop update
  }

  # https://aria2.github.io
  Write-Title '(+) Install aria2'
  Install-ScoopPackage 'main/aria2'
  scoop config aria2-warning-enabled false

  # https://wixtoolset.org
  Write-Title '(+) Install dark (WiX Toolset Decompiler)'
  Install-ScoopPackage 'main/dark'

  # https://www.7-zip.org
  Write-Title '(+) Install 7zip'
  Install-ScoopPackage 'main/7zip'
  reg import "$HOME\scoop\apps\7zip\current\install-context.reg"

  # https://gitforwindows.org
  Write-Title '(+) Install git'
  Install-ScoopPackage 'main/git'

  # Add scoop buckets.
  $buckets = @(Get-ChildItem -Path "$HOME\scoop\buckets" -Directory | Select-Object -ExpandProperty Name)
  $moreBuckets = @{
    'fonts' = 'https://github.com/kumarchandresh/scoop-fonts'
  }
  $buckets += @('extras', 'versions', 'java') + $moreBuckets.Keys
  $buckets = $buckets | Select-Object -Unique

  foreach ($bucket in $buckets) {
    $bucketPath = "$HOME\scoop\buckets\$bucket"
    if (-not (Test-Path $bucketPath)) {
      Write-Title "(+) Add scoop bucket: $bucket"
      if ($moreBuckets.ContainsKey($bucket)) {
        & scoop bucket add $bucket $moreBuckets[$bucket]
      }
      else {
        & scoop bucket add $bucket
      }
    }
    elseif (-not (Test-Path "$bucketPath\.git")) {
      Write-Title "(+) Re-add scoop bucket: $bucket"
      & scoop bucket rm $bucket
      if ($moreBuckets.ContainsKey($bucket)) {
        & scoop bucket add $bucket $moreBuckets[$bucket]
      }
      else {
        & scoop bucket add $bucket
      } 
    }
  }

  # https://microsoft.com/PowerShell
  Write-Title '(+) Install PowerShell (Core)'
  Install-ScoopPackage 'main/pwsh'

  # Re-launch in PowerShell (Core)
  & pwsh -NoProfile -ExecutionPolicy (Get-ExecutionPolicy) -File $PSCommandPath -SelfExecuted -MachineType $MachineType
  exit 0
}

if (Test-IsProcessElevated) {
  # https://learn.microsoft.com/en-us/visualstudio/install/workload-component-id-vs-build-tools?view=vs-2022
  # https://learn.microsoft.com/en-us/visualstudio/install/use-command-line-parameters-to-install-visual-studio?view=vs-2022#use-winget-to-install-or-modify-visual-studio
  # https://visualstudio.microsoft.com/visual-cpp-build-tools/
  # TODO: Find out how to update the workloads; it may have something to do with winget's configure command
  Write-Title '(+) Install Visual Studio Build Tools for C++'
  Install-WinGetPackage -Global 'Microsoft.VisualStudio.2022.BuildTools' -Config 'VisualStudio.BuildTools.txt' -Override

  # https://learn.microsoft.com/en-us/windows/wsl/install-manual
  
  if (-not (Test-IsWslAvailable)) {
    @(
      'Microsoft-Windows-Subsystem-Linux',
      'VirtualMachinePlatform'
    ) | ForEach-Object {
      $featureName = $_
      $feature = Get-WindowsOptionalFeature -Online | Where-Object { $_.FeatureName -eq $featureName }
      if ($feature.State -ne 'Enabled' -or $feature.State -ne 'EnablePending') {
        Write-Title "(+) Enable Windows optional feature: $_"
        Enable-WindowsOptionalFeature -Online -FeatureName $_ -All -NoRestart
      }
    }
    Write-Title "(+) Install WSL Linux kernel update package"
    wsl --update
  }
  exit 0
}
else {
  # https://github.com/gerardog/gsudo
  Write-Title '(+) Install gsudo'
  Install-ScoopPackage 'main/gsudo'

  Write-Host "`nRunning as admin; expect a UAC prompt." -ForegroundColor Yellow
  & gsudo --integrity High pwsh -NoProfile -ExecutionPolicy (Get-ExecutionPolicy) -File $PSCommandPath -SelfExecuted -MachineType $MachineType
}

if (Test-PendingReboot) {
  # TODO: How to restart automatically and execute this script again?
  Write-Host "A reboot is pending. You should restart and run this script again." -ForegroundColor Yellow
  $continue = Read-Host 'Continue? (y/n) '
  if ($continue -ne 'y') {
    exit 0
  }
}

if (Test-IsWslAvailable) {
  $wslList = (wsl --list --verbose 2>&1 | Out-String) -replace "`0", ''
  if ($wslList -notmatch "Ubuntu") {
    Write-Title "(+) Install WSL Distro: Ubuntu"
    wsl --install Ubuntu --no-launch
  }
}

# https://go.dev
Write-Title '(+) Install Go'
Install-ScoopPackage 'main/go'

# https://www.rust-lang.org
Write-Title '(+) Install Rust'
if (Test-IsCommandAvailable rustup) { 
  rustup update
}
else {
  Install-ScoopPackage 'main/rustup'
}

# https://www.microsoft.com/openjdk
Write-Title '(+) Install Microsoft Build of OpenJDK™ (LTS)'
Install-ScoopPackage 'java/microsoft-lts-jdk'

# https://groovy-lang.org
Write-Title '(+) Install Groovy'
Install-ScoopPackage 'main/groovy'

# https://www.python.org
Write-Title '(+) Install Python (3.x)'
Install-ScoopPackage 'main/python'
reg import "$HOME\scoop\apps\python\current\install-pep-514.reg"

# https://nodejs.org
Write-Title '(+) Install Node.js (LTS)'
Install-ScoopPackage 'main/nodejs-lts'

# https://pnpm.io
Write-Title '(+) Install pnpm'
Install-ScoopPackage 'main/pnpm'
if (-not $env:PNPM_HOME) {
  & pnpm setup
  $env:PNPM_HOME = [Environment]::GetEnvironmentVariable('PNPM_HOME', 'User')
  Restore-EnvPath
}

Write-Title '(+) Add Turborepo CLI'
& pnpm add turbo --global

# https://github.com/lukesampson/psutils
Write-Title '(+) Install psutils'
Install-ScoopPackage 'main/psutils'

# https://github.com/fastfetch-cli/fastfetch
Write-Title '(+) Install fastfetch'
Install-ScoopPackage 'main/fastfetch'

# https://github.com/junegunn/fzf
Write-Title '(+) Install fzf'
Install-ScoopPackage 'main/fzf'

# https://github.com/ajeetdsouza/zoxide
Write-Title '(+) Install zoxide'
Install-ScoopPackage 'main/zoxide'

# https://github.com/sharkdp/fd
Write-Title '(+) Install fd'
Install-ScoopPackage 'main/fd'

# https://github.com/BurntSushi/ripgrep
Write-Title '(+) Install ripgrep'
Install-ScoopPackage 'main/ripgrep'

# https://github.com/sharkdp/bat
Write-Title '(+) Install bat'
Install-ScoopPackage 'main/bat'

# https://github.com/dandavison/delta
Write-Title '(+) Install delta'
Install-ScoopPackage 'main/delta'

# https://www.gnu.org/software/grep
Write-Title '(+) Install grep'
Install-ScoopPackage 'main/grep'

# https://www.gnu.org/software/sed
Write-Title '(+) Install sed'
Install-ScoopPackage 'main/sed'

# https://github.com/tldr-pages/tlrc
Write-Title '(+) Install tldr'
Install-ScoopPackage 'main/tlrc'

# https://code.visualstudio.com
Write-Title '(+) Install Visual Studio Code'
Install-WinGetPackage 'Microsoft.VisualStudioCode' -Config 'Microsoft.VSCode.inf'

# https://obsidian.md
Write-Title '(+) Install Obsidian'
Install-WinGetPackage 'Obsidian.Obsidian'

if ($MachineType -eq 'personal') {
  # https://store.steampowered.com/
  Write-Title '[+] Install Steam'
  Install-WinGetPackage -Global 'Valve.Steam' -Location $(Join-Path (Get-WmiObject Win32_OperatingSystem).SystemDrive Steam)


  # https://discord.com
  Write-Title '(+) Install Discord'
  Install-WinGetPackage 'Discord.Discord'
}

# https://github.com/dahlbyk/posh-git
Write-Title '(+) Install posh-git'
Install-ScoopPackage 'extras/posh-git'

# https://github.com/devblackops/Terminal-Icons
Write-Title '(+) Install Terminal-Icons'
Install-ScoopPackage 'extras/terminal-icons'

# https://ohmyposh.dev
Write-Title '(+) Install Oh My Posh'
Install-WinGetPackage 'JanDeDobbeleer.OhMyPosh'

# https://github.com/bitwarden/clients
Write-Title '(+) Install Bitwarden CLI'
Install-ScoopPackage 'main/bitwarden-cli'
Unlock-Bitwarden

# https://www.chezmoi.io
Write-Title '(+) Install chezmoi'
Install-ScoopPackage 'main/chezmoi'

chezmoi git status *> $null
$isInitialized = $LASTEXITCODE -eq 0

Write-Host 'Applying chezmoi changes...' -ForegroundColor Yellow
$env:CHEZMOI_MACHINE_TYPE = $MachineType

if (-not $isInitialized) {
  chezmoi init --apply 'github.com/kumarchandresh' --force
}
else {
  chezmoi update --force
}

if ($LASTEXITCODE -eq 0) {
  Write-Host 'Done.' -ForegroundColor Green
}

$sshGitHub = & ssh -T git@github.com 2>&1 | Out-String
if ($sshGitHub -match 'kumarchandresh') {
  if (-not (Test-Path "$HOME\scoop\buckets\private")) {
    Write-Title "(+) Add scoop bucket: private"
    scoop bucket add 'private' 'git@github.com:kumarchandresh/scoop-private.git'
  }

  # https://www.monolisa.dev
  Write-Title '(+) Install font: MonoLisa'
  Install-ScoopPackage 'private/MonoLisa'
}

# https://www.nerdfonts.com
Write-Title '(+) Install Nerd Font Symbols'
Install-ScoopPackage 'fonts/SymbolsNerdFont'

# TODO: Can we handle this better via chezmoi?
Write-Title '(+) Install Windows Terminal themes'
$wtColorSchemes = @(
  @{ name = 'Catppuccin Frappe'    ; url = 'https://raw.githubusercontent.com/catppuccin/windows-terminal/refs/heads/main/frappe.json' },
  @{ name = 'Catppuccin Latte'     ; url = 'https://raw.githubusercontent.com/catppuccin/windows-terminal/refs/heads/main/latte.json' },
  @{ name = 'Catppuccin Macchiato' ; url = 'https://raw.githubusercontent.com/catppuccin/windows-terminal/refs/heads/main/macchiato.json' },
  @{ name = 'Catppuccin Mocha'     ; url = 'https://raw.githubusercontent.com/catppuccin/windows-terminal/refs/heads/main/mocha.json' },
  @{ name = 'rose-pine'            ; url = 'https://raw.githubusercontent.com/rose-pine/windows-terminal/refs/heads/main/rose-pine.scheme.json' },
  @{ name = 'rose-pine-dawn'       ; url = 'https://raw.githubusercontent.com/rose-pine/windows-terminal/refs/heads/main/rose-pine-dawn.scheme.json' },
  @{ name = 'rose-pine-moon'       ; url = 'https://raw.githubusercontent.com/rose-pine/windows-terminal/refs/heads/main/rose-pine-moon.scheme.json' }
)

$wtThemes = @(
  @{ name = 'Catppuccin Frappe'    ; url = 'https://raw.githubusercontent.com/catppuccin/windows-terminal/refs/heads/main/frappeTheme.json' },
  @{ name = 'Catppuccin Latte'     ; url = 'https://raw.githubusercontent.com/catppuccin/windows-terminal/refs/heads/main/latteTheme.json' },
  @{ name = 'Catppuccin Macchiato' ; url = 'https://raw.githubusercontent.com/catppuccin/windows-terminal/refs/heads/main/macchiatoTheme.json' },
  @{ name = 'Catppuccin Mocha'     ; url = 'https://raw.githubusercontent.com/catppuccin/windows-terminal/refs/heads/main/mochaTheme.json' },
  @{ name = 'rose-pine'            ; url = 'https://raw.githubusercontent.com/rose-pine/windows-terminal/refs/heads/main/rose-pine.theme.json' },
  @{ name = 'rose-pine-dawn'       ; url = 'https://raw.githubusercontent.com/rose-pine/windows-terminal/refs/heads/main/rose-pine-dawn.theme.json' },
  @{ name = 'rose-pine-moon'       ; url = 'https://raw.githubusercontent.com/rose-pine/windows-terminal/refs/heads/main/rose-pine-moon.theme.json' }
)

try {
  $TerminalDir = Get-ChildItem "$env:LOCALAPPDATA\Packages" -Filter Microsoft.WindowsTerminal* | Select-Object -First 1 -ExpandProperty FullName
  if ($null -ne $TerminalDir) {
    $TerminalSettingsPath = Join-Path $TerminalDir 'LocalState\settings.json'
    $TerminalSettings = Get-Content $TerminalSettingsPath -Raw | ConvertFrom-Json -Depth 99
    Write-Host 'Downloading color schemes...'
    $TerminalSettings.schemes = $wtColorSchemes | ForEach-Object {
      Write-Host $_.name -ForegroundColor DarkGray
      (Invoke-WebRequest -Uri $_.url).Content | ConvertFrom-Json -Depth 99
    }
    Write-Host 'Downloading themes...'
    $TerminalSettings.themes = $wtThemes | ForEach-Object {
      Write-Host $_.name -ForegroundColor DarkGray
      (Invoke-WebRequest -Uri $_.url).Content | ConvertFrom-Json -Depth 99
    }
  }
  if ($null -eq $TerminalSettings.theme) {
    $TerminalSettings | Add-Member -Type NoteProperty -Name 'theme' -Value ''
  }
  if ($null -eq $TerminalSettings.profiles) {
    $TerminalSettings | Add-Member -Type NoteProperty -Name 'profiles' -Value ([PSCustomObject]@{})
  }
  if ($null -eq $TerminalSettings.profiles.defaults) {
    $TerminalSettings.profiles | Add-Member -Type NoteProperty -Name 'defaults' -Value ([PSCustomObject]@{})
  }
  if ($null -eq $TerminalSettings.profiles.defaults.colorScheme) {
    $TerminalSettings.profiles.defaults | Add-Member -Type NoteProperty -Name 'colorScheme' -Value ''
  }
  $TerminalSettings.theme = 'rose-pine'
  $TerminalSettings.profiles.defaults.colorScheme = 'rose-pine'
  $TerminalSettings | ConvertTo-Json -Depth 99 | Out-File $TerminalSettingsPath -Encoding UTF8
}
catch {
  Write-Error $_
}
