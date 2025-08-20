param (
  [switch]$SelfExecuted
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

if (Test-IsProcessElevated) {
  throw 'Cannot be executed from an elevated PowerShell session.'
}

if ($PSEdition -eq 'Core' -and (-not $SelfExecuted)) {
  throw 'Must be executed from Windows PowerShell (not PowerShell Core).'
}

# Bootstrap in PowerShell (Core)
if ($PSEdition -ne 'Core') {

  # https://github.com/ScoopInstaller/Scoop/wiki
  Write-Title '(+) Install scoop'
  if (-not (Test-IsCommandAvailable 'scoop')) {
    Invoke-RestMethod -Uri 'https://get.scoop.sh' | Invoke-Expression; Restore-EnvPath

    if (-not (Test-IsCommandAvailable 'scoop')) {
      throw 'scoop is not available; visit https://github.com/ScoopInstaller/Scoop'
    }
  }
  else {
    scoop update
  }

  # https://aria2.github.io
  Write-Title '(+) Install aria2'
  Install-ScoopPackage 'main/aria2'
  scoop config aria2-warning-enabled false

  # https://www.7-zip.org
  Write-Title '(+) Install 7zip'
  Install-ScoopPackage 'main/7zip'
  # Add 7-Zip as a context menu option by running: "$HOME\scoop\apps\7zip\current\install-context.reg"

  # https://github.com/ScoopInstaller/Shim
  Write-Title '(+) Install ScoopInstaller/Shim'
  Install-ScoopPackage 'main/scoop-shim'

  # https://gitforwindows.org
  Write-Title '(+) Install git'
  Install-ScoopPackage 'main/git'
  # Set Git Credential Manager Core by running: "git config --global credential.helper manager"
  # To add context menu entries, run '$HOME\scoop\apps\git\current\install-context.reg'
  # To create file-associations for .git* and .sh files, run '$HOME\scoop\apps\git\current\install-file-associations.reg'

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

  # https://github.com/PowerShell/PowerShell/issues/19845
  # Notes: If winget had user-level installation of PowerShell and Git, then we could bootstrap with
  # winget, install Git and PowerShell first, and then install scoop so that the scoop buckets are
  # initialized with git. But this is not possible as of now.
  # Workaround: Install PowerShell (Core) from Microsoft Store, and GitHub Desktop (for git) from WinGet.
  # https://microsoft.com/PowerShell
  Write-Title '(+) Install PowerShell (Core)'
  Install-ScoopPackage 'main/pwsh'
  # Add PowerShell Core as a explorer context menu by running: '$HOME\scoop\apps\pwsh\current\install-explorer-context.reg'
  # For file context menu, run '$HOME\scoop\apps\pwsh\current\install-file-context.reg'

  # Re-launching in PowerShell (Core)
  & pwsh -NoProfile -ExecutionPolicy (Get-ExecutionPolicy) -File $PSCommandPath -SelfExecuted
  exit 0
}

# https://learn.microsoft.com/en-us/windows/package-manager/winget
Write-Title '(+) Install winget'
if (-not (Test-IsCommandAvailable 'winget')) {
  Install-ScoopPackage 'main/winget'

  if (-not (Test-IsCommandAvailable 'winget')) {
    throw 'winget is not available; visit https://github.com/microsoft/winget-cli'
  }
}
else {
  winget source update
  winget upgrade winget
}

# https://github.com/dahlbyk/posh-git
Write-Title '(+) Install posh-git'
Install-ScoopPackage 'extras/posh-git'

# https://github.com/devblackops/Terminal-Icons
Write-Title '(+) Install Terminal-Icons'
Install-ScoopPackage 'extras/terminal-icons'

# https://github.com/fastfetch-cli/fastfetch
Write-Title '(+) Install fastfetch'
Install-ScoopPackage 'main/fastfetch'

# https://github.com/lukesampson/psutils
Write-Title '(+) Install psutils'
Install-ScoopPackage 'main/psutils'

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
Install-WinGetPackage 'Microsoft.VisualStudioCode' -Config 'vscode.inf'

# https://github.com/0xType/0xProto
Write-Title '(+) Install font: 0xProto'
Install-ScoopPackage 'fonts/0xProto'
Install-ScoopPackage 'fonts/0xProtoNerdFont'

# https://github.com/bitwarden/clients
Write-Title '(+) Install Bitwarden CLI'
Install-ScoopPackage 'main/bitwarden-cli'
Unlock-Bitwarden

# https://www.chezmoi.io
Write-Title '(+) Install chezmoi'
Install-ScoopPackage 'main/chezmoi'

try {
  chezmoi git status 2>&1 | Out-Null
}
finally {
  Write-Host 'Applying chezmoi changes...' -ForegroundColor Yellow
  if ($LASTEXITCODE -ne 0) {
    chezmoi init --apply 'github.com/kumarchandresh' --force
  }
  else {
    chezmoi apply --force
  }
  if ($LASTEXITCODE -eq 0) {
    Write-Host 'Done.' -ForegroundColor Green
  }
}
