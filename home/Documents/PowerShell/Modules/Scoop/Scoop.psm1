function Test-IsScoopPackageInstalled {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string]$Name
  )
  return [bool](scoop list | Where-Object -Property Name -eq $Name)
}

function Install-ScoopPackage {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string]$Package,
    [Parameter()]
    [switch]$Global
  )

  switch -regex ($Package) {
    # URL format: https://example.com/app.json@version or https://example.com/app.json
    '^https?://.+/([^/@]+)\.json(@.*)?$' {
      $name = $matches[1]
      break
    }
    # Local path format: \path\to\app.json@version or \path\to\app.json
    '^.+[\\\/]([^\\/@]+)\.json(@.*)?$' {
      $name = $matches[1]
      break
    }
    # Bucket/app@version format: bucket/app@version
    '^[^/]+\/([^@]+)(@.*)?$' {
      $name = $matches[1]
      break
    }
    # Simple app@version format: app@version
    '^([^@]+)@.*$' {
      $name = $matches[1]
      break
    }
    # Use the name as-is (simple app name)
    default {
      $name = $Package
      break
    }
  }

  # Determine whether to install or update based on current installation status
  $scoopCmd = if (Test-IsScoopPackageInstalled $name) { 'update' } else { 'install' }
  $scoopArgs = @($scoopCmd)
  if ($Global) {
    $scoopArgs += '--global'
  }
  $scoopArgs += $Package

  $command = "scoop $($scoopArgs -join ' ')"
  Write-Host $command -ForegroundColor DarkGray
  & scoop @scoopArgs
}
