﻿<### Install ps2exe ###>
#Install-Module ps2exe

<### Run ps2exe ###>
$Path = Split-Path $PSScriptRoot -Parent
$InputFile = "$Path\Sources\Winget-Install-GUI.ps1"
$OutputFile = "$Path\Sources\WiGui.exe"
$Icon = "$Path\Sources\WiGui.ico"
$Title = "WiGui"
$AppVersion = "1.4.0"
Invoke-ps2exe -inputFile $InputFile -outputFile $OutputFile -noConsole -requireAdmin -title $Title -version $AppVersion -copyright "Romanitho" -product $Title -icon $Icon -noerror
