<#
.SYNOPSIS
Install apps with Winget-Install and configure Winget-AutoUpdate

.DESCRIPTION
This script will:
 - Install Winget if not present
 - Install apps with Winget from a custom list file (apps.txt) or directly from popped up default list.
 - Install Winget-AutoUpdate to get apps daily updated
https://github.com/Romanitho/Winget-AllinOne
#>


<# FUNCTIONS #>

function Get-GithubRepository ($Url) {
     
    # Force to create a zip file 
    $ZipFile = "$Location\temp.zip"
    New-Item $ZipFile -ItemType File -Force | Out-Null

    # Download the zip 
    Invoke-RestMethod -Uri $Url -OutFile $ZipFile

    # Extract Zip File
    Expand-Archive -Path $ZipFile -DestinationPath $Location -Force
    Get-ChildItem -Path $Location -Recurse | Unblock-File
     
    # remove the zip file
    Remove-Item -Path $ZipFile -Force
}

function Get-WingetStatus{
    
    $hasAppInstaller = Get-AppXPackage -Name 'Microsoft.DesktopAppInstaller'
    [Version]$AppInstallerVers = $hasAppInstaller.version
    
    if (!($AppInstallerVers -gt "1.18.0.0")){

        #installing dependencies
        $ProgressPreference = 'SilentlyContinue'
        
        if (!(Get-AppxPackage -Name 'Microsoft.UI.Xaml.2.7')){
            $UiXamlUrl = "https://www.nuget.org/api/v2/package/Microsoft.UI.Xaml/2.7.0"
            Invoke-RestMethod -Uri $UiXamlUrl -OutFile ".\Microsoft.UI.XAML.2.7.zip"
            Expand-Archive -Path "$Location\Microsoft.UI.XAML.2.7.zip" -DestinationPath "$Location\extracted" -Force
            Add-AppxPackage -Path "$Location\extracted\tools\AppX\x64\Release\Microsoft.UI.Xaml.2.7.appx"
            Remove-Item -Path "$Location\Microsoft.UI.XAML.2.7.zip" -Force
            Remove-Item -Path "$Location\extracted" -Force -Recurse
        }

        if (!(Get-AppxPackage -Name 'Microsoft.VCLibs.140.00')){
            Add-AppxPackage -Path https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx
        }

        #installin Winget
        Add-AppxPackage -Path https://github.com/microsoft/winget-cli/releases/download/v1.3.431/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle
    
    }

}

function Get-WingetAppInfo ($SearchApp){
    class Software {
        [string]$Name
        [string]$Id
    }

    #Config console output encoding
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

    #Get WinGet Path (if admin context)
    $ResolveWingetPath = Resolve-Path "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe"
    if ($ResolveWingetPath){
        #If multiple version, pick last one
        $WingetPath = $ResolveWingetPath[-1].Path
    }
    #Get Winget Location in User context
    $WingetCmd = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($WingetCmd){
        $Script:Winget = $WingetCmd.Source
    }
    #Get Winget Location in System context (WinGet < 1.17)
    elseif (Test-Path "$WingetPath\AppInstallerCLI.exe"){
        $Script:Winget = "$WingetPath\AppInstallerCLI.exe"
    }
    #Get Winget Location in System context (WinGet > 1.17)
    elseif (Test-Path "$WingetPath\winget.exe"){
        $Script:Winget = "$WingetPath\winget.exe"
    }
    else{
        Write-Host "WinGet is not installed. It is mandatory to run WiGui"
        break
    }

    #Get list of available upgrades on winget format
    $AppResult = & $Winget search $SearchApp --accept-source-agreements --source winget | Out-String

    #Start Convertion of winget format to an array. Check if "-----" exists
    if (!($AppResult -match "-----")){
        Write-Host "No application found."
        return
    }

    #Split winget output to lines
    $lines = $AppResult.replace("¦ ","").Split([Environment]::NewLine) | Where-Object {$_}

    # Find the line that starts with "------"
    $fl = 0
    while (-not $lines[$fl].StartsWith("-----")){
        $fl++
    }

    $fl = $fl - 1

    #Get header titles
    $index = $lines[$fl] -split '\s+'

    # Line $fl has the header, we can find char where we find ID and Version
    $idStart = $lines[$fl].IndexOf($index[1])
    $versionStart = $lines[$fl].IndexOf($index[2])

    # Now cycle in real package and split accordingly
    $upgradeList = @()
    For ($i = $fl + 2; $i -le $lines.Length; $i++){
        $line = $lines[$i]
        if ($line.Length -gt ($sourceStart+5)){
            $software = [Software]::new()
            $software.Name = $line.Substring(0, $idStart).TrimEnd()
            $software.Id = $line.Substring($idStart, $versionStart - $idStart).TrimEnd()
            #add formated soft to list
            $upgradeList += $software
        }
    }
    return $upgradeList
}

function Get-InstallGUI {
    
    ## VARIABLES ##

    $Script:AppToInstall = $null
    $Script:InstallWAU = $null


    ## FORM ##

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    $WiguiForm = New-Object System.Windows.Forms.Form

    $CloseButton = New-Object System.Windows.Forms.Button
    $InstallButton = New-Object System.Windows.Forms.Button
    $SearchButton = New-Object System.Windows.Forms.Button
    $SearchTextBox = New-Object System.Windows.Forms.TextBox
    $SearchLabel = New-Object System.Windows.Forms.Label
    $SubmitComboBox = New-Object System.Windows.Forms.ComboBox
    $SubmitButton = New-Object System.Windows.Forms.Button
    $SubmitLabel = New-Object System.Windows.Forms.Label
    $AppListLabel = New-Object System.Windows.Forms.Label
    $AppListBox = New-Object System.Windows.Forms.ListBox
    $RemoveButton = New-Object System.Windows.Forms.Button
    $SaveListButton = New-Object System.Windows.Forms.Button
    $MoreInfoLabel = New-Object System.Windows.Forms.LinkLabel
    $WAUCheckBox = New-Object System.Windows.Forms.CheckBox
    #
    # CloseButton
    #
    $CloseButton.Location = New-Object System.Drawing.Point(397, 526)
    $CloseButton.Name = "CloseButton"
    $CloseButton.Size = New-Object System.Drawing.Size(75, 24)
    $CloseButton.TabIndex = 0
    $CloseButton.Text = "Close"
    $CloseButton.UseVisualStyleBackColor = $true
    #
    # InstallButton
    #
    $InstallButton.Location = New-Object System.Drawing.Point(316, 526)
    $InstallButton.Name = "InstallButton"
    $InstallButton.Size = New-Object System.Drawing.Size(75, 24)
    $InstallButton.TabIndex = 1
    $InstallButton.Text = "Install"
    $InstallButton.UseVisualStyleBackColor = $true
    #
    # SearchButton
    #
    $SearchButton.Location = New-Object System.Drawing.Point(397, 34)
    $SearchButton.Name = "SearchButton"
    $SearchButton.Size = New-Object System.Drawing.Size(75, 23)
    $SearchButton.TabIndex = 2
    $SearchButton.Text = "Search"
    $SearchButton.UseVisualStyleBackColor = $true
    #
    # SearchTextBox
    #
    $SearchTextBox.Location = New-Object System.Drawing.Point(12, 36)
    $SearchTextBox.Name = "SearchTextBox"
    $SearchTextBox.Size = New-Object System.Drawing.Size(379, 20)
    $SearchTextBox.TabIndex = 3
    #
    # SearchLabel
    #
    $SearchLabel.AutoSize = $true
    $SearchLabel.Location = New-Object System.Drawing.Point(12, 19)
    $SearchLabel.Name = "SearchLabel"
    $SearchLabel.Size = New-Object System.Drawing.Size(80, 13)
    $SearchLabel.TabIndex = 4
    $SearchLabel.Text = "Search for an app:"
    #
    # SubmitComboBox
    #
    $SubmitComboBox.FormattingEnabled = $true
    $SubmitComboBox.Location = New-Object System.Drawing.Point(13, 91)
    $SubmitComboBox.Name = "SubmitComboBox"
    $SubmitComboBox.Size = New-Object System.Drawing.Size(378, 21)
    $SubmitComboBox.TabIndex = 5
    $SubmitComboBox.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    #
    # SubmitButton
    #
    $SubmitButton.Location = New-Object System.Drawing.Point(397, 90)
    $SubmitButton.Name = "SubmitButton"
    $SubmitButton.Size = New-Object System.Drawing.Size(75, 23)
    $SubmitButton.TabIndex = 6
    $SubmitButton.Text = "Submit"
    $SubmitButton.UseVisualStyleBackColor = $true
    #
    # SubmitLabel
    #
    $SubmitLabel.AutoSize = $true
    $SubmitLabel.Location = New-Object System.Drawing.Point(13, 74)
    $SubmitLabel.Name = "SubmitLabel"
    $SubmitLabel.Size = New-Object System.Drawing.Size(174, 13)
    $SubmitLabel.TabIndex = 7
    $SubmitLabel.Text = "Select the matching Winget AppID:"
    #
    # AppListLabel
    #
    $AppListLabel.AutoSize = $true
    $AppListLabel.Location = New-Object System.Drawing.Point(13, 135)
    $AppListLabel.Name = "AppListLabel"
    $AppListLabel.Size = New-Object System.Drawing.Size(114, 13)
    $AppListLabel.TabIndex = 9
    $AppListLabel.Text = "Current Application list:"
    #
    # AppListBox
    #
    $AppListBox.FormattingEnabled = $true
    $AppListBox.Location = New-Object System.Drawing.Point(12, 152)
    $AppListBox.Name = "AppListBox"
    $AppListBox.Size = New-Object System.Drawing.Size(379, 355)
    $AppListBox.TabIndex = 11
    $AppListBox.SelectionMode = 'MultiExtended'
    #
    # RemoveButton
    #
    $RemoveButton.Location = New-Object System.Drawing.Point(397, 151)
    $RemoveButton.Name = "RemoveButton"
    $RemoveButton.Size = New-Object System.Drawing.Size(75, 23)
    $RemoveButton.TabIndex = 12
    $RemoveButton.Text = "Remove"
    $RemoveButton.UseVisualStyleBackColor = $true
    #
    # SaveListButton
    #
    $SaveListButton.Location = New-Object System.Drawing.Point(200, 526)
    $SaveListButton.Name = "SaveListButton"
    $SaveListButton.Size = New-Object System.Drawing.Size(110, 24)
    $SaveListButton.TabIndex = 13
    $SaveListButton.Text = "Save list to File"
    $SaveListButton.UseVisualStyleBackColor = $true
    #
    # MoreInfoLabel
    #
    $MoreInfoLabel.AutoSize = $true
    $MoreInfoLabel.Location = New-Object System.Drawing.Point(92, 532)
    $MoreInfoLabel.Name = "MoreInfoLabel"
    $MoreInfoLabel.Size = New-Object System.Drawing.Size(52, 13)
    $MoreInfoLabel.TabIndex = 15
    $MoreInfoLabel.TabStop = $true
    $MoreInfoLabel.Text = "More Info"
    #
    # WAUCheckBox
    #
    $WAUCheckBox.AutoSize = $true
    $WAUCheckBox.Location = New-Object System.Drawing.Point(15, 530)
    $WAUCheckBox.Name = "WAUCheckBox"
    $WAUCheckBox.Size = New-Object System.Drawing.Size(82, 17)
    $WAUCheckBox.TabIndex = 16
    $WAUCheckBox.Text = "Install WAU"
    $WAUCheckBox.UseVisualStyleBackColor = $true
    $WAUCheckBox.Checked = $false
    #
    # WiguiForm
    #
    $WiguiForm.ClientSize = New-Object System.Drawing.Size(484, 561)
    $WiguiForm.Controls.Add($MoreInfoLabel)
    $WiguiForm.Controls.Add($WAUCheckBox)
    $WiguiForm.Controls.Add($SaveListButton)
    $WiguiForm.Controls.Add($RemoveButton)
    $WiguiForm.Controls.Add($AppListBox)
    $WiguiForm.Controls.Add($AppListLabel)
    $WiguiForm.Controls.Add($SubmitLabel)
    $WiguiForm.Controls.Add($SubmitButton)
    $WiguiForm.Controls.Add($SubmitComboBox)
    $WiguiForm.Controls.Add($SearchLabel)
    $WiguiForm.Controls.Add($SearchTextBox)
    $WiguiForm.Controls.Add($SearchButton)
    $WiguiForm.Controls.Add($InstallButton)
    $WiguiForm.Controls.Add($CloseButton)
    $WiguiForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
    $WiguiForm.Name = "WiguiForm"
    $WiguiForm.ShowIcon = $false
    $WiguiForm.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $WiguiForm.AcceptButton = $SearchButton
    $WiguiForm.Text = "WiGui (Winget-Install-GUI) 1.2.0"


    ## ACTIONS ##

    $MoreInfoLabel.add_click({
        [System.Diagnostics.Process]::Start("https://github.com/Romanitho/Winget-AutoUpdate")
    })

    $SearchButton.add_click({
        $SubmitComboBox.Items.Clear()
        if ($SearchTextBox.Text){
            $List = Get-WingetAppInfo $SearchTextBox.Text
            foreach ($L in $List){
                $SubmitComboBox.Items.Add($L.ID)
            }
            $SubmitComboBox.SelectedIndex = 0
        }
    })

    $SubmitButton.add_click({
        $AddAppToList = $SubmitComboBox.Text
        if ($AddAppToList -ne "" -and $AppListBox.Items -notcontains $AddAppToList){
            $AppListBox.Items.Add($AddAppToList)
        }  
    })

    $RemoveButton.add_click({
        while($AppListBox.SelectedItems) {
            $AppListBox.Items.Remove($AppListBox.SelectedItems[0])
        }
    })

    $SaveListButton.add_click({
        Add-Type -AssemblyName System.Windows.Forms
        $SaveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
        $SaveFileDialog.Filter = "txt files (*.txt)|*.txt|All files (*.*)|*.*"
        $response = $SaveFileDialog.ShowDialog( ) # $response can return OK or Cancel
        if ( $response -eq 'OK' ) {
            $AppListBox.Items | Out-File $SaveFileDialog.FileName -Append
            Write-Host 'File saved:' $SaveFileDialog.FileName
        }
    })

    $CloseButton.add_click({
        $WiguiForm.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        $WiguiForm.Close()
    })

    $InstallButton.add_click({
        if ($AppListBox.Items -or $WAUCheckBox.Checked){
            $Script:AppToInstall = $AppListBox.Items -join ","
            $Script:InstallWAU = $WAUCheckBox.Checked
            Start-Installations
            #$WiguiForm.DialogResult = [System.Windows.Forms.DialogResult]::OK
        }
    })


    ## RETURNS ##

    $Script:FormReturn = $WiguiForm.ShowDialog()

}

function Start-Installations {
    
    ## WAU PART ##

    #Download and install Winget-AutoUpdate if box is checked
    if ($InstallWAU){
        
        #Check if WAU already downloaded
        $TestPath = "$Location\*Winget-AutoUpdate*\Winget-AutoUpdate-Install.ps1"
        if (!(Test-Path $TestPath)){
            #If not, download
            Get-GithubRepository "https://github.com/Romanitho/Winget-AutoUpdate/archive/refs/tags/v1.8.0.zip"
        }

        #Install Winget-Autoupdate
        $WAUInstallFile = (Resolve-Path $TestPath)[0].Path
        Start-Process "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Maximized -Command `"$WAUInstallFile -Silent -DoNotUpdate`"" -Wait -Verb RunAs
    }

    ## WINGET INSTALL PART ##

    if ($AppToInstall){
        #Check if Winget-Install already downloaded
        $TestPath = "$Location\*Winget-Install*\winget-install.ps1"
        if (!(Test-Path $TestPath)){
            #If not, download
            Get-GithubRepository "https://github.com/Romanitho/Winget-Install/archive/refs/tags/v1.5.0.zip"
        }

        #Run Winget-Install
        $WIInstallFile = (Resolve-Path $TestPath)[0].Path
        Start-Process "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Maximized -Command `"$WIInstallFile -AppIDs $AppToInstall`"" -Wait -Verb RunAs
    }

}




<# MAIN #>

#Temp folder
$Script:Location = "$env:ProgramData\WiGui_Temp"

#Check if Winget is installed, and install if not
Get-WingetStatus

#Run WiGui
Get-InstallGUI

#Remove temp items
Remove-Item -Path $Location -Force -Recurse -ErrorAction SilentlyContinue
