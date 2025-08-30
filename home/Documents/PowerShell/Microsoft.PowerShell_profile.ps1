Import-Module -Force 'posh-git'
Import-Module -Force 'Terminal-Icons'
Import-Module -Force 'Utils'

Restore-EnvPath # Change "Path" precedence

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

Invoke-Expression (& { (oh-my-posh init pwsh --config "$HOME\.config\oh-my-posh\pure.omp.yaml" | Out-String) })
