<### Install ps2exe ###>

Install-Module ps2exe

<### Run ps2exe ###>

Invoke-ps2exe -inputFile ".\Winget-Install-GUI.ps1" -outputFile ".\WiGui.exe" -noConsole -requireAdmin -title "WiGui" -version 1.1.0 -copyright "Romanitho" -product "WiGui"