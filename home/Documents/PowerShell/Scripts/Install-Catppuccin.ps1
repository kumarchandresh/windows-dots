try {
  $TerminalDir = Get-ChildItem "$env:LOCALAPPDATA\Packages" -Filter Microsoft.WindowsTerminal_* | Select-Object -First 1 -ExpandProperty FullName
  if ($null -ne $TerminalDir) {
    $TerminalSettingsPath = Join-Path $TerminalDir 'LocalState\settings.json'
    $TerminalSettings = Get-Content $TerminalSettingsPath -Raw | ConvertFrom-Json -Depth 99
    Write-Host 'Downloading color schemes...'
    $Themes = @('frappe', 'latte', 'macchiato', 'mocha')
    $TerminalSettings.schemes = $Themes | ForEach-Object {
      $ColorScheme = $_
      Write-Host $ColorScheme -ForegroundColor DarkGray
      $ColorSchemeUrl = "https://raw.githubusercontent.com/catppuccin/windows-terminal/refs/heads/main/${ColorScheme}.json"
      (Invoke-WebRequest -Uri $ColorSchemeUrl).Content | ConvertFrom-Json -Depth 99
    }
    Write-Host 'Downloading themes...'
    $TerminalSettings.themes = $Themes | ForEach-Object {
      $Theme = $_
      Write-Host $Theme -ForegroundColor DarkGray
      $ThemeUrl = "https://raw.githubusercontent.com/catppuccin/windows-terminal/refs/heads/main/${Theme}Theme.json"
      (Invoke-WebRequest -Uri $ThemeUrl).Content | ConvertFrom-Json -Depth 99
    }
  }
  if ($null -eq $TerminalSettings.profiles) {
    $TerminalSettings | Add-Member -Type NoteProperty -Name 'profiles' -Value ([PSCustomObject]@{})
  }
  if ($null -eq $TerminalSettings.profiles.defaults) {
    $TerminalSettings.profiles | Add-Member -Type NoteProperty -Name 'defaults' -Value ([PSCustomObject]@{})
  }
  $TerminalSettings.profiles.defaults | Add-Member -Type NoteProperty -Name 'colorScheme' -Value 'Catppuccin Macchiato' -Force
  $TerminalSettings | ConvertTo-Json -Depth 99 | Out-File $TerminalSettingsPath -Encoding UTF8
}
catch {
  Write-Error $_
}
