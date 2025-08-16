function Test-IsProcessElevated {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = [Security.Principal.WindowsPrincipal]$identity
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-IsCommandAvailable {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string]$Command
  )
  return [bool](Get-Command -Name $Command -ErrorAction SilentlyContinue)
}

# https://stackoverflow.com/a/74297741
function ConvertFrom-FixedColumnTable {
  [CmdletBinding()]
  param (
    [Parameter(ValueFromPipeline)]
    [string]$InputObject
  )
  begin {
    Set-StrictMode -Version 1
    $lineIdx = 0
  }
  process {
    $lines = $InputObject -split '\r?\n'
    $oht = [ordered]@{}
    foreach ($line in $lines) {
      ++$lineIdx
      if ($lineIdx -eq 1) {
        $fieldStartIndices = [regex]::Matches($line, '\b\S').Index
        $fieldLengths = foreach ($i in 1..($fieldStartIndices.Length - 1)) {
          ($fieldStartIndices[$i] - $fieldStartIndices[$i - 1])
        }
        $columnNames = foreach ($i in 0..($fieldStartIndices.Length - 1)) {
          if ($i -eq ($fieldStartIndices.Length - 1)) {
            $line.Substring($fieldStartIndices[$i]).Trim()
          }
          else {
            $line.Substring($fieldStartIndices[$i], $fieldLengths[$i]).Trim()
          }
        }
      }
      else {
        $i = 0
        foreach ($column in $columnNames) {
          $oht[$column] = if ($fieldStartIndices[$i] -lt $line.Length) {
            if ($fieldLengths[$i]) {
              $line.Substring($fieldStartIndices[$i], $fieldLengths[$i]).Trim()
            }
            else {
              $line.Substring($fieldStartIndices[$i]).Trim()
            }
          }
          else {
            $null
          }
          ++$i
        }
      }
    }
    return [PSCustomObject]$oht
  }
}

function Expand-EnvVars {
  [CmdletBinding()]
  param (
    [Parameter(ValueFromPipeline)]
    [string]$InputObject
  )
  process {
    return [regex]::Replace($InputObject, '%(\w+)%', { param($match)
      $envVar = [Environment]::GetEnvironmentVariable($match.Groups[1].Value)
      if ($envVar) {
        $envVar
      }
      else {
        $match.Value
      }
    })
  }
}

function Set-PersistentEnvVar {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string]$Name,
    [Parameter(Mandatory)]
    [string]$Value,
    [Parameter()]
    [ValidateSet('Machine', 'User')]
    [string]$Scope = 'User'
  )
  [Environment]::SetEnvironmentVariable($Name, $Value, $Scope)
  Set-Item -Path "env:$Name" -Value $Value
}

function Restore-EnvPath {
  # https://superuser.com/q/867728/1042970
  # Windows is crazy; it prepends system path to user path; which results in
  # system applications taking precedence over user applications.
  ${env:Path} = @(
    [Environment]::GetEnvironmentVariable('Path', 'User')
    [Environment]::GetEnvironmentVariable('Path', 'Machine')
  ) -join ';'
}

function Test-IsSymbolicLink {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string]$Path
  )
  return [bool]((Test-Path $Path) -and ((Get-Item $Path).LinkType -eq 'SymbolicLink'))
}

function Unlock-Bitwarden {
  do {
    if (-not (Test-IsCommandAvailable 'bw')) {
      throw 'Bitwarden CLI not available'
    }
    $bwStatus = & bw status | ConvertFrom-Json
    if ($bwStatus.status -eq 'unauthenticated') {
      Write-Host 'Login to Bitwarden:' -ForegroundColor Yellow
      $env:BW_SESSION = & bw login --raw
    }
    elseif ($bwStatus.status -eq 'locked') {
      Write-Host 'Unlock your Bitwarden vault:' -ForegroundColor Yellow
      $env:BW_SESSION = & bw unlock --raw
    }
    elseif ($bwStatus.status -eq 'unlocked') {
      Write-Host 'Bitwarden vault is already unlocked' -ForegroundColor Green
    }
    $retry = 'n'
    if (($LASTEXITCODE -eq 0) -and ($bwStatus.status -ne 'unlocked')) {
      Write-Host 'Bitwarden vault unlocked successfully' -ForegroundColor Green
    } else {
      Write-Host 'Failed to unlock Bitwarden vault' -ForegroundColor Red
      $retry = Read-Host 'Try again? (y/n)'
    }
  } while ($retry -eq 'y')
}
