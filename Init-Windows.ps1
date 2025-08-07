param (
  [switch]$SelfExecuted
)

# https://stackoverflow.com/a/49481797
# Display Unicode in PowerShell
# Required for properly formatting result of `winget list` command.
$PSDefaultParameterValues['*:Encoding'] = 'utf8'
$OutputEncoding = [Console]::OutputEncoding = [Console]::InputEncoding = [Text.Encoding]::UTF8

Import-Module -Force "$PSScriptRoot\Modules\Util"
Import-Module -Force "$PSScriptRoot\Modules\Scoop"
Import-Module -Force "$PSScriptRoot\Modules\WinGet"

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
  Write-Title '(*) Install scoop'
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
  Write-Title '(*) Install 7zip'
  Install-ScoopPackage 'main/7zip'
  # Add 7-Zip as a context menu option by running: "$HOME\scoop\apps\7zip\current\install-context.reg"

  # https://github.com/ScoopInstaller/Shim
  Write-Title '(*) Install ScoopInstaller/Shim'
  Install-ScoopPackage 'main/scoop-shim'

  # https://gitforwindows.org
  Write-Title '(*) Install git'
  Install-ScoopPackage 'main/git'
  # Set Git Credential Manager Core by running: "git config --global credential.helper manager"
  # To add context menu entries, run '$HOME\scoop\apps\git\current\install-context.reg'
  # To create file-associations for .git* and .sh files, run '$HOME\scoop\apps\git\current\install-file-associations.reg'

  # Add scoop buckets.
  $buckets = @(Get-ChildItem -Path "$HOME\scoop\buckets" -Directory | Select-Object -ExpandProperty Name)
  $buckets += @('extras', 'versions', 'java')
  $buckets = $buckets | Select-Object -Unique
  foreach ($bucket in $buckets) {
    if (-not (Test-Path "$HOME\scoop\buckets\$bucket")) {
      Write-Title "(*) Add scoop bucket: $bucket"
      & scoop bucket add $bucket
    }
    elseif (-not (Test-Path "$HOME\scoop\buckets\$bucket\.git")) {
      Write-Title "(*) Re-add scoop bucket: $bucket"
      & scoop bucket rm $bucket
      & scoop bucket add $bucket
    }
  }

  # https://github.com/PowerShell/PowerShell/issues/19845
  # Notes: If winget had user-level installation of PowerShell and Git, then we could bootstrap with
  # winget, install Git and PowerShell first, and then install scoop so that the scoop buckets are
  # initialized with git. But this is not possible as of now.
  # Workaround: Install PowerShell (Core) from Microsoft Store, and GitHub Desktop (for git) from WinGet.
  # https://microsoft.com/PowerShell
  Write-Title '(*) Install PowerShell (Core)'
  Install-ScoopPackage 'main/pwsh'
  # Add PowerShell Core as a explorer context menu by running: '$HOME\scoop\apps\pwsh\current\install-explorer-context.reg'
  # For file context menu, run '$HOME\scoop\apps\pwsh\current\install-file-context.reg'

  # Re-launching in PowerShell (Core)
  & pwsh -NoProfile -ExecutionPolicy (Get-ExecutionPolicy) -File $PSCommandPath -SelfExecuted
  exit 0
}

# https://learn.microsoft.com/en-us/windows/package-manager/winget
Write-Title '(*) Install winget'
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
Write-Title '(*) Install posh-git'
Install-ScoopPackage 'extras/posh-git'

# https://code.visualstudio.com
Write-Title '(*) Install Visual Studio Code'
Install-WinGetPackage 'Microsoft.VisualStudioCode' -Config 'vscode.inf'

# https://code.visualstudio.com/insiders
Write-Title '(*) Install Visual Studio Code (Insiders)'
Install-WinGetPackage 'Microsoft.VisualStudioCode.Insiders' -Config 'vscode.inf'

# https://cursor.com
Write-Title '(*) Install Cursor'
Install-WinGetPackage 'Anysphere.Cursor' -Config 'vscode.inf'
