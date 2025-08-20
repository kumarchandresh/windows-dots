Import-Module -Force 'posh-git'
Import-Module -Force 'Terminal-Icons'
Import-Module -Force 'Utils'

Restore-EnvPath # Change "Path" precedence

function which {
  scoop which @args
}

Invoke-Expression (& { (oh-my-posh init pwsh --config "$HOME\.config\oh-my-posh\pure.omp.yaml" | Out-String) })
