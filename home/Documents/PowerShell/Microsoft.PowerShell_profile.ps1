Import-Module -Force 'posh-git'
Import-Module -Force 'Utils'

Restore-EnvPath # Change "Path" precedence

function which {
  if ($args.Length -ne 0) {
    return (
      Get-Command -Name $args[0] -CommandType Application, ExternalScript -ErrorAction SilentlyContinue |
      Select-Object -First 1 -ExpandProperty Source
    ) -replace [regex]::Escape($HOME), '~'
  }
}
