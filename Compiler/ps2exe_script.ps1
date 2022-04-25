<### Install ps2exe ###>

Install-Module ps2exe

<### Run ps2exe ###>
$InputFile = ".\Sources\Winget-Install-GUI.ps1"
$OutputFile = ".\Sources\WiGui.exe"
$Icon = ".\Sources\WiGui.ico"
$Title = "WiGui"
$AppVersion = "1.2.0"
Invoke-ps2exe -inputFile $InputFile -outputFile $OutputFile -noConsole -requireAdmin -title $Title -version $AppVersion -copyright "Romanitho" -product $Title -icon $Icon
