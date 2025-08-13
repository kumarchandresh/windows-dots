Import-Module "$PSScriptRoot\..\Utils"

# https://github.com/microsoft/winget-cli/issues/1653
# Currently, result of winget list and winget search is truncated for adjusting display size or
# 120 chars if output is redirected. Avoid using this command for package that has very long ID.
function Get-InstalledWinGetPackages {
  return (
    winget list --accept-source-agreements
  ) -match "^\p{L}" | ConvertFrom-FixedColumnTable
}

function Test-IsWinGetPackageInstalled {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string]$Id
  )
  return [bool](Get-InstalledWinGetPackages | Where-Object -Property Id -eq $Id)
}

function Install-WinGetPackage {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string]$Id,
    [Parameter()]
    [string]$Source = 'winget',
    [Parameter()]
    [ValidateSet('exe', 'zip', 'inno', 'nullsoft', 'msi', 'wix', 'appx', 'msix', 'burn', 'portable')]
    [string]$InstallerType,
    [Parameter()]
    [string]$Config,
    [Parameter()]
    [switch]$Global,
    [Parameter()]
    [switch]$Record
  )
  $Scope = if ($Global) { 'machine' } else { 'user' }
  $wingetCmd = if (Test-IsWinGetPackageInstalled $Id) { 'upgrade' } else { 'install' }
  $wingetArgs = @($wingetCmd)
  $wingetArgs += @('--exact', '--id', $Id)
  $wingetArgs += @('--scope', $Scope)
  $wingetArgs += @('--source', $Source)
  $wingetArgs += @('--accept-source-agreements', '--accept-package-agreements')
  if ($PSBoundParameters.ContainsKey('InstallerType')) {
    $wingetArgs += @('--installer-type', $InstallerType)
  }
  $type = $null
  $showArgs = @('--exact', '--id', $Id)
  $showArgs += @('--scope', $Scope)
  if ($PSBoundParameters.ContainsKey('InstallerType')) {
    $showArgs += @('--installer-type', $InstallerType)
  }
  $info = & winget show $showArgs | Out-String
  if ($info -match 'Installer\s*Type:\s+(.*)') {
    $type = $matches[1].Trim().ToLower()
  }
  $Config = if ($PSBoundParameters.ContainsKey('Config')) {
    "$PSScriptRoot\Configs\$Config"
  }
  else {
    $null
  }
  $logsDir = "${env:TEMP}\Logs"
  if ($Config) {
    switch ($type) {
      'inno' {
        if ($Record) {
          $wingetArgs += @('--interactive', "--custom '/SAVEINF=`"$Config`"'")
        }
        elseif (Test-Path $Config) {
          $wingetArgs += @("--custom '/LOADINF=`"$Config`"'")
        }
        else {
          Write-Host "Config file not found: $Config" -ForegroundColor Red
        }
      }
      { $_ -in @('wix', 'burn') } {
        if ($Record) {
          $wingetArgs += @('--interactive', "--custom '/log `"$logsDir\$Id.log`"'")
        }
        elseif (Test-Path $Config) {
          $fileContent = (Get-Content $Config | Expand-EnvVars) `
            -join ' ' `
            -replace '`', '``' `
            -replace '"', '`"'
          $wingetArgs += @("--custom `"$fileContent`"")
        }
        else {
          Write-Host "Config file not found: $Config" -ForegroundColor Red
        }
      }
      default {
        if (Test-Path $Config) {
          Write-Host "Config file is not supported for $type installer type" -ForegroundColor Red
        }
      }
    }
  }
  $command = "winget $($wingetArgs -join ' ')"
  Write-Host $command -ForegroundColor DarkGray
  Invoke-Expression $command
}
