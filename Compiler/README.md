### Tool used to compile EXE

We use PS2EXE to create the EXE
https://github.com/MScholtes/PS2EXE

To install module, open Powershell then  
`Install-Module ps2exe`

### Command used to compile

 To compile, run command :  
`Invoke-ps2exe -inputFile "C:\Tools\Winget-Install-GUI.ps1" -outputFile "C:\Tools\WiGui.exe" -noConsole -requireAdmin -title "WiGui" -version 1.1.0.0`
