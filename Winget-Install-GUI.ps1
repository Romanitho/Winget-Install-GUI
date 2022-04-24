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
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $AppSelect = New-Object System.Windows.Forms.Form

    $Cancel = New-Object System.Windows.Forms.Button
    $OK = New-Object System.Windows.Forms.Button
    $Search = New-Object System.Windows.Forms.Button
    $SearchText = New-Object System.Windows.Forms.TextBox
    $SearchLabel = New-Object System.Windows.Forms.Label
    $SearchResult = New-Object System.Windows.Forms.ComboBox
    $Submit = New-Object System.Windows.Forms.Button
    $SubmitLabel = New-Object System.Windows.Forms.Label
    $AppList = New-Object System.Windows.Forms.ListBox
    $AppListLabel = New-Object System.Windows.Forms.Label
    #
    # Cancel
    #
    $Cancel.Location = New-Object System.Drawing.Point(397, 526)
    $Cancel.Name = "Cancel"
    $Cancel.Size = New-Object System.Drawing.Size(75, 23)
    $Cancel.TabIndex = 0
    $Cancel.Text = "Cancel"
    $Cancel.UseVisualStyleBackColor = $true
    #
    # OK
    #
    $OK.Location = New-Object System.Drawing.Point(316, 526)
    $OK.Name = "OK"
    $OK.Size = New-Object System.Drawing.Size(75, 23)
    $OK.TabIndex = 1
    $OK.Text = "OK"
    $OK.UseVisualStyleBackColor = $true
    #
    # Search
    #
    $Search.Location = New-Object System.Drawing.Point(397, 34)
    $Search.Name = "Search"
    $Search.Size = New-Object System.Drawing.Size(75, 23)
    $Search.TabIndex = 2
    $Search.Text = "Search"
    $Search.UseVisualStyleBackColor = $true
    #
    # SearchText
    #
    $SearchText.Location = New-Object System.Drawing.Point(12, 36)
    $SearchText.Name = "SearchText"
    $SearchText.Size = New-Object System.Drawing.Size(379, 20)
    $SearchText.TabIndex = 3
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
    # SearchResult
    #
    $SearchResult.FormattingEnabled = $true
    $SearchResult.Location = New-Object System.Drawing.Point(13, 91)
    $SearchResult.Name = "SearchResult"
    $SearchResult.Size = New-Object System.Drawing.Size(378, 21)
    $SearchResult.TabIndex = 5
    #
    # Submit
    #
    $Submit.Location = New-Object System.Drawing.Point(397, 90)
    $Submit.Name = "Submit"
    $Submit.Size = New-Object System.Drawing.Size(75, 23)
    $Submit.TabIndex = 6
    $Submit.Text = "Submit"
    $Submit.UseVisualStyleBackColor = $true
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
    # AppList
    #
    $AppList.Location = New-Object System.Drawing.Point(12, 152)
    $AppList.Name = "AppList"
    $AppList.Size = New-Object System.Drawing.Size(460, 368)
    $AppList.TabIndex = 8
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
    # AppSelect
    #
    $AppSelect.ClientSize = New-Object System.Drawing.Size(484, 561)
    $AppSelect.Controls.Add($AppListLabel)
    $AppSelect.Controls.Add($AppList)
    $AppSelect.Controls.Add($SubmitLabel)
    $AppSelect.Controls.Add($Submit)
    $AppSelect.Controls.Add($SearchResult)
    $AppSelect.Controls.Add($SearchLabel)
    $AppSelect.Controls.Add($SearchText)
    $AppSelect.Controls.Add($Search)
    $AppSelect.Controls.Add($OK)
    $AppSelect.Controls.Add($Cancel)
    $AppSelect.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
    $AppSelect.Name = "AppSelect"
    $AppSelect.Text = "Winget-Install"


    # On clicks
    $Search.add_click({
        $SearchResult.Items.Clear()
        $List = Get-WingetAppInfo $SearchText.Text
        foreach ($L in $List){
                $SearchResult.Items.Add($L.ID)
        }
        $SearchResult.SelectedIndex = 0
    })

    $Submit.add_click({
        $AddAppToList = $SearchResult.Text
        $AppList.Items
        if ($AddAppToList -ne "" -and $AppList.Items -notcontains $AddAppToList){
            $AppList.Items.Add($AddAppToList)
        }  
    })

    $Cancel.add_click({
        $AppSelect.Close()
    })

    $OK.add_click({
        $Script:AppToInstall = $AppList.Items
        $AppSelect.Close()
    })

    $AppSelect.ShowDialog() | Out-Null
}


## Main ##

Get-InstallGUI

Write-Host "Selected Apps to install : $AppToInstall"

foreach ($App in $AppToInstall){
    & $Winget install -e --id $App -h --accept-package-agreements --accept-source-agreements
}

Timeout 10
