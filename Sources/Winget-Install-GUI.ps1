## Funtions ##

function Get-WingetAppInfo ($SearchApp){
    class Software {
        [string]$Name
        [string]$Id
    }

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
        break
    }

    #Get list of available upgrades on winget format
    $AppResult = & $Winget search $SearchApp --accept-source-agreements --source winget

    #Start Convertion of winget format to an array. Check if "-----" exists
    if (!($AppResult -match "-----")){
        Write-Host "Nothing to display"
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
        if ($line.Length -gt ($sourceStart+5) -and -not $line.Contains("--include-unknown")){
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
    
    ## FORM ##

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $WiguiForm = New-Object System.Windows.Forms.Form

    $CancelButton = New-Object System.Windows.Forms.Button
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
    #
    # CancelButton
    #
    $CancelButton.Location = New-Object System.Drawing.Point(397, 526)
    $CancelButton.Name = "CancelButton"
    $CancelButton.Size = New-Object System.Drawing.Size(75, 23)
    $CancelButton.TabIndex = 0
    $CancelButton.Text = "Cancel"
    $CancelButton.UseVisualStyleBackColor = $true
    #
    # InstallButton
    #
    $InstallButton.Location = New-Object System.Drawing.Point(316, 526)
    $InstallButton.Name = "InstallButton"
    $InstallButton.Size = New-Object System.Drawing.Size(75, 23)
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
    $SearchLabel.Text = "Search an app:"
    #
    # SubmitComboBox
    #
    $SubmitComboBox.FormattingEnabled = $true
    $SubmitComboBox.Location = New-Object System.Drawing.Point(13, 91)
    $SubmitComboBox.Name = "SubmitComboBox"
    $SubmitComboBox.Size = New-Object System.Drawing.Size(378, 21)
    $SubmitComboBox.TabIndex = 5
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
    $SaveListButton.Location = New-Object System.Drawing.Point(12, 526)
    $SaveListButton.Name = "SaveListButton"
    $SaveListButton.Size = New-Object System.Drawing.Size(130, 23)
    $SaveListButton.TabIndex = 13
    $SaveListButton.Text = "Save list to File"
    $SaveListButton.UseVisualStyleBackColor = $true
    #
    # WiguiForm
    #
    $WiguiForm.ClientSize = New-Object System.Drawing.Size(484, 561)
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
    $WiguiForm.Controls.Add($CancelButton)
    $WiguiForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
    $WiguiForm.Name = "WiguiForm"
    $WiguiForm.ShowIcon = $false
    $WiguiForm.Text = "Winget-Install-GUI (WiGui v1.1.0)"



    ## ACTIONS ##

    # On clicks

    $SearchButton.add_click({
        $SubmitComboBox.Items.Clear()
        $List = Get-WingetAppInfo $SearchTextBox.Text
        foreach ($L in $List){
                $SubmitComboBox.Items.Add($L.ID)
        }
        $SubmitComboBox.SelectedIndex = 0
    })

    $SubmitButton.add_click({
        $AddAppToList = $SubmitComboBox.Text
        if ($AddAppToList -ne "" -and $AppListBox.Items -notcontains $AddAppToList){
            $AppListBox.Items.Add($AddAppToList)
        }  
    })

    $RemoveButton.add_click({
        $RemoveAppFromList = $AppListBox.SelectedItem
        $AppListBox.Items.Remove($RemoveAppFromList)
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

    $CancelButton.add_click({
        $WiguiForm.Close()
    })

    $InstallButton.add_click({
        if ($AppListBox.Items){
            $Script:AppToInstall = $AppListBox.Items
            $WiguiForm.Close()
        }
    })

    $WiguiForm.ShowDialog() | Out-Null
}


## Main ##
$Script:AppToInstall = $null

Get-InstallGUI

if ($AppToInstall){

    Write-Host "Selected Apps to install : $AppToInstall"

    foreach ($App in $AppToInstall){
        & $Winget install -e --id $App -h --accept-package-agreements --accept-source-agreements
    }

}