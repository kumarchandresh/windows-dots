# https://stackoverflow.com/a/49481797
$PSDefaultParameterValues['*:Encoding'] = 'utf8'
$OutputEncoding = [Console]::OutputEncoding = [Console]::InputEncoding = [Text.Encoding]::UTF8

Import-Module -Force 'gsudoModule'
Import-Module -Force 'posh-git'
Import-Module -Force 'Terminal-Icons'
Import-Module -Force 'Utils'

Restore-EnvPath # Change "Path" precedence

$GitPromptSettings.EnableStashStatus = $true

zoxide init powershell --no-cmd | Invoke-Expression

oh-my-posh init pwsh --config "$HOME\.config\oh-my-posh\pure.omp.yaml" | Invoke-Expression

function Set-FzfLocation {
  [CmdletBinding(DefaultParameterSetName = 'Path')]
  param (
    [Parameter(Position = 0, ParameterSetName = 'Path', ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [string]$Path,
    [Parameter(Position = 0, ParameterSetName = 'LiteralPath', ValueFromPipelineByPropertyName)]
    [string]$LiteralPath
  )
  process {
    if ((-not $Path) -and (-not $LiteralPath)) {
      $Path = fd --type=directory --follow | fzf `
        --height=40% `
        --layout=reverse `
        --border
      if (($LASTEXITCODE -eq 0) -and (Test-Path -PathType Container -Path $path)) {
        Set-Location $path
      }
    }
    elseif (($PSCmdlet.ParameterSetName -eq 'LiteralPath') -and $LiteralPath) {
      Set-Location -LiteralPath $LiteralPath
    }
    elseif ($Path) {
      Set-Location -Path $Path
    }
  }
}

function Set-ZLocation {
  if ($args.Length -eq 0) {
    $path = zoxide query --list | fzf `
      --height=40% `
      --layout=reverse `
      --border
    if (($LASTEXITCODE -eq 0) -and (Test-Path -PathType Container -Path $path)) {
      Set-Location $path
    }
  }
  elseif ($args.Length -eq 1 -and ($args[0] -eq '-' -or $args[0] -eq '+' -or $args[0] -eq '~')) {
    Set-Location -Path $args[0]
  }
  elseif ($args.Length -eq 1 -and (Test-Path -PathType Container -LiteralPath $args[0])) {
    Set-Location -LiteralPath $args[0]
  }
  elseif ($args.Length -eq 1 -and (Test-Path -PathType Container -Path $args[0])) {
    Set-Location -Path $args[0]
  }
  else {
    $path = ''
    if ($PWD.Provider.Name -eq 'FileSystem') {
      $path = $PWD.ProviderPath
    }
    $path = zoxide query --list --exclude $path | fzf --filter ($args -join ' ') | Select-Object -First 1
    if (($LASTEXITCODE -eq 0) -and (Test-Path -PathType Container -Path $path)) {
      Set-Location $path
    }
  }
}

function which ($name) {
  $path = (
    Get-Command $name -CommandType Application, ExternalScript -ErrorAction SilentlyContinue |
    Select-Object -First 1 -ExpandProperty Source
  ) -replace [regex]::Escape($HOME), '~'
  if ($path -match '\\scoop\\shims') {
    $path = & scoop which $name
  }
  $path
}

function glog($n = 10) {
  git log `
    --max-count=$n `
    --color=always `
    --date=short `
    --format='%C(yellow)%h %C(red)%ad %C(blue)%an%C(green)%d %C(reset)%s'
}

Set-Alias -Force -Name z -Value Set-ZLocation -Option AllScope -Scope Global
Set-Alias -Force -Name cd -Value Set-FzfLocation -Option AllScope -Scope Global
