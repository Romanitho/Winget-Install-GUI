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

<# APP INFO #>
$WiGuiVersion = "1.4.1"

<# FUNCTIONS #>

function Install-Prerequisites{
    #Check if Visual C++ 2019 or 2022 installed
    $Visual2019 = "Microsoft Visual C++ 2015-2019 Redistributable*"
    $Visual2022 = "Microsoft Visual C++ 2015-2022 Redistributable*"
    $path = Get-Item HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*, HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object {$_.GetValue("DisplayName") -like $Visual2019 -or $_.GetValue("DisplayName") -like $Visual2022}
    
    #If not installed, install
    if (!($path)){
        try{
            if((Get-CimInStance Win32_OperatingSystem).OSArchitecture -like "*64*"){
                $OSArch = "x64"
            }
            else{
                $OSArch = "x86"
            }
            $SourceURL = "https://aka.ms/vs/17/release/VC_redist.$OSArch.exe"
            $Installer = $Location + "\VC_redist.$OSArch.exe"
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest $SourceURL -OutFile (New-Item -Path $Installer -Force)
            Start-Process -FilePath $Installer -Args "/quiet /norestart" -Wait
            Remove-Item $Installer -ErrorAction Ignore
        }
        catch{
            Write-host "MS Visual C++ 2015-2022 installation failed." -ForegroundColor Red
            Start-Sleep 3
        }
    }
    else{
        Write-Host "Prerequisites checked. OK" -ForegroundColor Green
    }
}
function Get-Tools ($Url, $Path) {
     
    # Force to create a zip file 
    $ZipFile = "$Location\temp.zip"
    New-Item $ZipFile -ItemType File -Force | Out-Null

    # Download the zip 
    Invoke-RestMethod -Uri $Url -OutFile $ZipFile

    # Extract Zip File
    if ($Path){
        Expand-Archive -Path $ZipFile -DestinationPath "$Path" -Force
        Get-ChildItem -Path $Path -Recurse | Unblock-File
    }
    else{
        Expand-Archive -Path $ZipFile -DestinationPath $Location -Force
        Get-ChildItem -Path $Location -Recurse | Unblock-File
    }
     
    # remove the zip file
    Remove-Item -Path $ZipFile -Force
}

function Get-WingetStatus{
    
    $hasAppInstaller = Get-AppXPackage -Name 'Microsoft.DesktopAppInstaller'
    [Version]$AppInstallerVers = $hasAppInstaller.version
    
    if (!($AppInstallerVers -gt "1.18.0.0")){

        if ($UserName -eq "WDAGUtilityAccount") {

            #Show Wait form
            Add-Type -AssemblyName System.Windows.Forms 
            $Form = New-Object system.Windows.Forms.Form
            $Label = New-Object System.Windows.Forms.Label
            $Form.Controls.Add($Label)
            $Label.Multiline = $True
            $Label.Text = "`r`n Windows Sandbox detected:`r`n NirSoft AdvancedRun and UninstallView`r`n have been installed...`r`n`r`n Installing prerequisites:`r`n Visual C++ 2015-2022..."
            $Label.AutoSize = $True
            $Form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
            $Form.MaximizeBox = $false
            $Form.MinimizeBox = $false
            $Form.Size = New-Object System.Drawing.Size(230,150)
            $Form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
            $Form.Text = "WiGui $WiGuiVersion"
            $Form.Icon = [System.Drawing.Icon]::FromHandle(([System.Drawing.Bitmap]::new($stream).GetHIcon()))
            $Form.Visible = $True
            $Form.Update()
            #Start-Sleep -Seconds 10

            #Check Prereqs
            Install-Prerequisites

            #installing dependencies
            $ProgressPreference = 'SilentlyContinue'
            
            if (!(Get-AppxPackage -Name 'Microsoft.UI.Xaml.2.7')){
                $Label.Text = "`r`n Windows Sandbox detected:`r`n NirSoft AdvancedRun and UninstallView`r`n have been installed...`r`n`r`n Installing prerequisites:`r`n Microsoft.UI.Xaml.2.7..."
                $Form.Update()
                $UiXamlUrl = "https://www.nuget.org/api/v2/package/Microsoft.UI.Xaml/2.7.0"
                Invoke-RestMethod -Uri $UiXamlUrl -OutFile "$Location\Microsoft.UI.XAML.2.7.zip"
                Expand-Archive -Path "$Location\Microsoft.UI.XAML.2.7.zip" -DestinationPath "$Location\extracted" -Force
                Add-AppxPackage -Path "$Location\extracted\tools\AppX\x64\Release\Microsoft.UI.Xaml.2.7.appx"
                Remove-Item -Path "$Location\Microsoft.UI.XAML.2.7.zip" -Force
                Remove-Item -Path "$Location\extracted" -Force -Recurse
            }

            if (!(Get-AppxPackage -Name 'Microsoft.VCLibs.140.00')){
                $Label.Text = "`r`n Windows Sandbox detected:`r`n NirSoft AdvancedRun and UninstallView`r`n have been installed...`r`n`r`n Installing prerequisites:`r`n Microsoft.VCLibs.140.00..."
                $Form.Update()
                Add-AppxPackage -Path https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx
            }

            $Label.Text = "`r`n Windows Sandbox detected:`r`n NirSoft AdvancedRun and UninstallView`r`n have been installed...`r`n`r`n Installing prerequisites:`r`n MSIXBundle for App Installer..."
            $Form.Update()
            #Download WinGet MSIXBundle
            $WinGetURL = "https://github.com/microsoft/winget-cli/releases/download/v1.3.431/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
            $WebClient=New-Object System.Net.WebClient
            $WebClient.DownloadFile($WinGetURL, "$Location\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle")

            #Install WinGet MSIXBundle
            try{
                Add-AppxProvisionedPackage -Online -PackagePath "$Location\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle" -SkipLicense | Out-Null
            }
            catch{
                Write-Host "Failed to intall MSIXBundle for App Installer..." -ForegroundColor Red
            }
        
            #Remove WinGet MSIXBundle
            Remove-Item -Path "$Location\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle" -Force -ErrorAction Continue | Out-Null
        
            #Hide popup
            $Form.Close()
        }
        else {

            #installing dependencies
            $ProgressPreference = 'SilentlyContinue'
            
            if (!(Get-AppxPackage -Name 'Microsoft.UI.Xaml.2.7')){
                $UiXamlUrl = "https://www.nuget.org/api/v2/package/Microsoft.UI.Xaml/2.7.0"
                Invoke-RestMethod -Uri $UiXamlUrl -OutFile "$Location\Microsoft.UI.XAML.2.7.zip"
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
}

function Get-WingetAppInfo ($SearchApp){
    class Software {
        [string]$Name
        [string]$Id
    }

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
    $AppResult = & $Winget search $SearchApp --accept-source-agreements --source winget

    #Start Convertion of winget format to an array. Check if "-----" exists
    if (!($AppResult -match "-----")){
        Write-Host "No application found."
        return
    }

    #Split winget output to lines
    $lines = $AppResult.Split([Environment]::NewLine) | Where-Object {$_}

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

    ## FORM ##
    #
    # Begin
    #
    $WiGuiForm = New-Object System.Windows.Forms.Form
    $WiGuiTabControl = New-Object System.Windows.Forms.TabControl
    $AppsTabPage = New-Object System.Windows.Forms.TabPage
    $WAUTabPage = New-Object System.Windows.Forms.TabPage
    $SaveListButton = New-Object System.Windows.Forms.Button
    $InstallButton = New-Object System.Windows.Forms.Button
    $CloseButton = New-Object System.Windows.Forms.Button
    $WiGuiLinkLabel = New-Object System.Windows.Forms.LinkLabel
    $OpenListButton = New-Object System.Windows.Forms.Button
    $RemoveButton = New-Object System.Windows.Forms.Button
    $AppListBox = New-Object System.Windows.Forms.ListBox
    $AppListLabel = New-Object System.Windows.Forms.Label
    $SubmitLabel = New-Object System.Windows.Forms.Label
    $SubmitButton = New-Object System.Windows.Forms.Button
    $SubmitComboBox = New-Object System.Windows.Forms.ComboBox
    $SearchLabel = New-Object System.Windows.Forms.Label
    $SearchTextBox = New-Object System.Windows.Forms.TextBox
    $SearchButton = New-Object System.Windows.Forms.Button
    $WAUMoreInfoLabel = New-Object System.Windows.Forms.LinkLabel
    $WAUCheckBox = New-Object System.Windows.Forms.CheckBox
    $WAUDoNotUpdateCheckBox = New-Object System.Windows.Forms.CheckBox
    $WAUgroupBox = New-Object System.Windows.Forms.GroupBox
    $WAUDisableAUCheckBox = New-Object System.Windows.Forms.CheckBox
    $SaveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    #
    # WiGuiTabControl
    #
    $WiGuiTabControl.Controls.Add($AppsTabPage)
    $WiGuiTabControl.Controls.Add($WAUTabPage)
    $WiGuiTabControl.Location = New-Object System.Drawing.Point(12, 12)
    $WiGuiTabControl.Name = "WiGuiTabControl"
    $WiGuiTabControl.SelectedIndex = 0
    $WiGuiTabControl.Size = New-Object System.Drawing.Size(512, 500)
    $WiGuiTabControl.TabIndex = 0
    #
    # AppsTabPage
    #
    $AppsTabPage.BackColor = [System.Drawing.Color]::Transparent
    $AppsTabPage.Controls.Add($OpenListButton)
    $AppsTabPage.Controls.Add($SaveListButton)
    $AppsTabPage.Controls.Add($RemoveButton)
    $AppsTabPage.Controls.Add($AppListBox)
    $AppsTabPage.Controls.Add($AppListLabel)
    $AppsTabPage.Controls.Add($SubmitLabel)
    $AppsTabPage.Controls.Add($SubmitButton)
    $AppsTabPage.Controls.Add($SubmitComboBox)
    $AppsTabPage.Controls.Add($SearchLabel)
    $AppsTabPage.Controls.Add($SearchTextBox)
    $AppsTabPage.Controls.Add($SearchButton)
    $AppsTabPage.Location = New-Object System.Drawing.Point(4, 22)
    $AppsTabPage.Name = "AppsTabPage"
    $AppsTabPage.Padding = New-Object System.Windows.Forms.Padding(3)
    $AppsTabPage.Size = New-Object System.Drawing.Size(504, 474)
    $AppsTabPage.TabIndex = 0
    $AppsTabPage.Text = "Select Apps"
    #
    # WAUTabPage
    #
    $WAUTabPage.BackColor = [System.Drawing.Color]::Transparent
    $WAUTabPage.Controls.Add($WAUgroupBox)
    $WAUTabPage.Controls.Add($WAUMoreInfoLabel)
    $WAUTabPage.Controls.Add($WAUCheckBox)
    $WAUTabPage.Location = New-Object System.Drawing.Point(4, 22)
    $WAUTabPage.Name = "WAUTabPage"
    $WAUTabPage.Padding = New-Object System.Windows.Forms.Padding(3)
    $WAUTabPage.Size = New-Object System.Drawing.Size(504, 474)
    $WAUTabPage.TabIndex = 1
    $WAUTabPage.Text = "Configure WAU"
    #
    # SaveListButton
    #
    $SaveListButton.Location = New-Object System.Drawing.Point(394, 120)
    $SaveListButton.Name = "SaveListButton"
    $SaveListButton.Size = New-Object System.Drawing.Size(100, 23)
    $SaveListButton.TabIndex = 16
    $SaveListButton.Text = "Save list to File"
    $SaveListButton.UseVisualStyleBackColor = $true
    #
    # InstallButton
    #
    $InstallButton.Location = New-Object System.Drawing.Point(368, 525)
    $InstallButton.Name = "InstallButton"
    $InstallButton.Size = New-Object System.Drawing.Size(75, 24)
    $InstallButton.TabIndex = 15
    $InstallButton.Text = "Install"
    $InstallButton.UseVisualStyleBackColor = $true
    #
    # CloseButton
    #
    $CloseButton.Location = New-Object System.Drawing.Point(449, 525)
    $CloseButton.Name = "CloseButton"
    $CloseButton.Size = New-Object System.Drawing.Size(75, 24)
    $CloseButton.TabIndex = 14
    $CloseButton.Text = "Close"
    $CloseButton.UseVisualStyleBackColor = $true
    #
    # WiGuiLinkLabel
    #
    $WiGuiLinkLabel.AutoSize = $true
    $WiGuiLinkLabel.Location = New-Object System.Drawing.Point(13, 531)
    $WiGuiLinkLabel.Name = "WiGuiLinkLabel"
    $WiGuiLinkLabel.Size = New-Object System.Drawing.Size(97, 13)
    $WiGuiLinkLabel.TabIndex = 17
    $WiGuiLinkLabel.TabStop = $true
    $WiGuiLinkLabel.Text = "WiGui is on GitHub"
    #
    # OpenListButton
    #
    $OpenListButton.Location = New-Object System.Drawing.Point(394, 149)
    $OpenListButton.Name = "OpenListButton"
    $OpenListButton.Size = New-Object System.Drawing.Size(100, 23)
    $OpenListButton.TabIndex = 27
    $OpenListButton.Text = "Import from File"
    $OpenListButton.UseVisualStyleBackColor = $true
    #
    # RemoveButton
    #
    $RemoveButton.Location = New-Object System.Drawing.Point(394, 178)
    $RemoveButton.Name = "RemoveButton"
    $RemoveButton.Size = New-Object System.Drawing.Size(100, 23)
    $RemoveButton.TabIndex = 26
    $RemoveButton.Text = "Remove"
    $RemoveButton.UseVisualStyleBackColor = $true
    #
    # AppListBox
    #
    $AppListBox.FormattingEnabled = $true
    $AppListBox.Location = New-Object System.Drawing.Point(9, 120)
    $AppListBox.Name = "AppListBox"
    $AppListBox.Size = New-Object System.Drawing.Size(379, 342)
    $AppListBox.TabIndex = 25
    $AppListBox.SelectionMode = "MultiExtended"
    #
    # AppListLabel
    #
    $AppListLabel.AutoSize = $true
    $AppListLabel.Location = New-Object System.Drawing.Point(10, 103)
    $AppListLabel.Name = "AppListLabel"
    $AppListLabel.Size = New-Object System.Drawing.Size(114, 13)
    $AppListLabel.TabIndex = 24
    $AppListLabel.Text = "Current Application list:"
    #
    # SubmitLabel
    #
    $SubmitLabel.AutoSize = $true
    $SubmitLabel.Location = New-Object System.Drawing.Point(10, 53)
    $SubmitLabel.Name = "SubmitLabel"
    $SubmitLabel.Size = New-Object System.Drawing.Size(174, 13)
    $SubmitLabel.TabIndex = 23
    $SubmitLabel.Text = "Select the matching Winget AppID:"
    #
    # SubmitButton
    #
    $SubmitButton.Location = New-Object System.Drawing.Point(394, 69)
    $SubmitButton.Name = "SubmitButton"
    $SubmitButton.Size = New-Object System.Drawing.Size(100, 23)
    $SubmitButton.TabIndex = 22
    $SubmitButton.Text = "Add to List"
    $SubmitButton.UseVisualStyleBackColor = $true
    #
    # SubmitComboBox
    #
    $SubmitComboBox.FormattingEnabled = $true
    $SubmitComboBox.Location = New-Object System.Drawing.Point(10, 70)
    $SubmitComboBox.Name = "SubmitComboBox"
    $SubmitComboBox.Size = New-Object System.Drawing.Size(378, 21)
    $SubmitComboBox.TabIndex = 21
    #
    # SearchLabel
    #
    $SearchLabel.AutoSize = $true
    $SearchLabel.Location = New-Object System.Drawing.Point(9, 9)
    $SearchLabel.Name = "SearchLabel"
    $SearchLabel.Size = New-Object System.Drawing.Size(80, 13)
    $SearchLabel.TabIndex = 20
    $SearchLabel.Text = "Search an app:"
    #
    # SearchTextBox
    #
    $SearchTextBox.Location = New-Object System.Drawing.Point(9, 26)
    $SearchTextBox.Name = "SearchTextBox"
    $SearchTextBox.Size = New-Object System.Drawing.Size(379, 20)
    $SearchTextBox.TabIndex = 19
    #
    # SearchButton
    #
    $SearchButton.Location = New-Object System.Drawing.Point(394, 24)
    $SearchButton.Name = "SearchButton"
    $SearchButton.Size = New-Object System.Drawing.Size(100, 23)
    $SearchButton.TabIndex = 18
    $SearchButton.Text = "Search"
    $SearchButton.UseVisualStyleBackColor = $true
    #
    # WAUMoreInfoLabel
    #
    $WAUMoreInfoLabel.AutoSize = $true
    $WAUMoreInfoLabel.Location = New-Object System.Drawing.Point(374, 446)
    $WAUMoreInfoLabel.Name = "WAUMoreInfoLabel"
    $WAUMoreInfoLabel.Size = New-Object System.Drawing.Size(111, 13)
    $WAUMoreInfoLabel.TabIndex = 17
    $WAUMoreInfoLabel.TabStop = $true
    $WAUMoreInfoLabel.Text = "More Info about WAU"
    #
    # WAUCheckBox
    #
    $WAUCheckBox.AutoSize = $true
    $WAUCheckBox.Location = New-Object System.Drawing.Point(12, 16)
    $WAUCheckBox.Name = "WAUCheckBox"
    $WAUCheckBox.Size = New-Object System.Drawing.Size(82, 17)
    $WAUCheckBox.TabIndex = 18
    $WAUCheckBox.Text = "Install WAU (Winget-AutoUpdate)"
    $WAUCheckBox.UseVisualStyleBackColor = $true
    #
    # WAUDoNotUpdateCheckBox
    #
    $WAUDoNotUpdateCheckBox.AutoSize = $true
    $WAUDoNotUpdateCheckBox.Location = New-Object System.Drawing.Point(6, 19)
    $WAUDoNotUpdateCheckBox.Name = "WAUDoNotUpdateCheckBox"
    $WAUDoNotUpdateCheckBox.Size = New-Object System.Drawing.Size(177, 17)
    $WAUDoNotUpdateCheckBox.TabIndex = 19
    $WAUDoNotUpdateCheckBox.Text = "Do not run WAU just after install"
    $WAUDoNotUpdateCheckBox.UseVisualStyleBackColor = $true
    #
    # WAUgroupBox
    #
    $WAUgroupBox.Controls.Add($WAUDisableAUCheckBox)
    $WAUgroupBox.Controls.Add($WAUDoNotUpdateCheckBox)
    $WAUgroupBox.Location = New-Object System.Drawing.Point(12, 48)
    $WAUgroupBox.Name = "WAUgroupBox"
    $WAUgroupBox.Size = New-Object System.Drawing.Size(192, 68)
    $WAUgroupBox.TabIndex = 20
    $WAUgroupBox.TabStop = $false
    $WAUgroupBox.Text = "WAU Configurations"
    $WAUgroupBox.Enabled = $false
    #
    # WAUDisableAUCheckBox
    #
    $WAUDisableAUCheckBox.AutoSize = $true
    $WAUDisableAUCheckBox.Location = New-Object System.Drawing.Point(6, 42)
    $WAUDisableAUCheckBox.Name = "WAUDisableAUCheckBox"
    $WAUDisableAUCheckBox.Size = New-Object System.Drawing.Size(151, 17)
    $WAUDisableAUCheckBox.TabIndex = 20
    $WAUDisableAUCheckBox.Text = "Disable WAU Auto-update"
    $WAUDisableAUCheckBox.UseVisualStyleBackColor = $true
    #
    # SaveFileDialog
    #
    $SaveFileDialog.Filter = "Text files (*.txt)|*.txt|All files (*.*)|*.*"
    #
    # OpenFileDialog
    #
    $OpenFileDialog.Filter = "Text files (*.txt)|*.txt|All files (*.*)|*.*"
    #
    # WiGuiForm
    #
    $WiGuiForm.AcceptButton = $SearchButton
    $WiGuiForm.ClientSize = New-Object System.Drawing.Size(536, 561)
    $WiGuiForm.Controls.Add($WiGuiLinkLabel)
    $WiGuiForm.Controls.Add($InstallButton)
    $WiGuiForm.Controls.Add($CloseButton)
    $WiGuiForm.Controls.Add($WiGuiTabControl)
    $WiGuiForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
    $WiGuiForm.MaximizeBox = $false
    $WiGuiForm.Name = "WiGuiForm"
    $WiGuiForm.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    #
    # Custom
    #
    $WiGuiForm.Text = "WiGui $WiGuiVersion"
    $WiGuiForm.Icon = [System.Drawing.Icon]::FromHandle(([System.Drawing.Bitmap]::new($stream).GetHIcon()))


    ## ACTIONS ##

    $WAUCheckBox.add_click({
        if ($WAUCheckBox.Checked -eq $true)
        {
            $WAUgroupBox.Enabled = $true  
        }
        elseif ($WAUCheckBox.Checked -eq $false)
        {
            $WAUgroupBox.Enabled = $false
        } 
    })

    $WiGuiLinkLabel.add_click({
        [System.Diagnostics.Process]::Start("https://github.com/Romanitho/Winget-Install-GUI")
    })

    $WAUMoreInfoLabel.add_click({
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
        $response = $SaveFileDialog.ShowDialog() # $response can return OK or Cancel
        if ( $response -eq 'OK' ) {
            $AppListBox.Items | Out-File $SaveFileDialog.FileName -Append
            Write-Host "File saved to:`n$($SaveFileDialog.FileName)"
        }
    })

    $OpenListButton.add_click({
        $response = $OpenFileDialog.ShowDialog() # $response can return OK or Cancel
        if ( $response -eq 'OK' ) {
            $FileContent = Get-Content $OpenFileDialog.FileName
            foreach($App in $FileContent){
                if ($App -ne "" -and $AppListBox.Items -notcontains $App){
                    $AppListBox.Items.Add($App)
                } 
            }
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
            $Script:WAUDoNotUpdate = $WAUDoNotUpdateCheckBox.Checked
            $Script:WAUDisableAU = $WAUDisableAUCheckBox.Checked
            Start-Installations
            $WAUCheckBox.Checked = $false
            $WAUgroupBox.Enabled = $false
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
            Get-Tools "https://github.com/Romanitho/Winget-AutoUpdate/archive/refs/tags/v1.8.0.zip" ""
        }

        #Configure parameters
        $WAUParameters = "-Silent "
        if ($WAUDoNotUpdate) {$WAUParameters += "-DoNotUpdate "}
        if ($WAUDisableAU) {$WAUParameters += "-DisableWAUAutoUpdate "}

        #Install Winget-Autoupdate
        $WAUInstallFile = (Resolve-Path $TestPath)[0].Path
        Start-Process "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Maximized -Command `"$WAUInstallFile $WAUParameters`"" -Wait -Verb RunAs
    }

    ## WINGET INSTALL PART ##

    if ($AppToInstall){
        #Check if Winget-Install already downloaded
        $TestPath = "$Location\*Winget-Install*\winget-install.ps1"
        if (!(Test-Path $TestPath)){
            #If not, download
            Get-Tools "https://github.com/Romanitho/Winget-Install/archive/refs/tags/v1.5.0.zip" ""
        }

        #Run Winget-Install
        $WIInstallFile = (Resolve-Path $TestPath)[0].Path
        Start-Process "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Maximized -Command `"$WIInstallFile -AppIDs $AppToInstall`"" -Wait -Verb RunAs
    }

}

function Get-WiGuiLatestVersion {
    
    #Get latest stable info
    $WiGuiURL = 'https://api.github.com/repos/Romanitho/Winget-Install-GUI/releases/latest'
    $WiGuiLatestVersion = ((Invoke-WebRequest $WiGuiURL -UseBasicParsing | ConvertFrom-Json)[0].tag_name).Replace("v","")
    
    if ([version]$WiGuiVersion -lt [version]$WiGuiLatestVersion){

        ## FORM ##
        #
        # Begin
        #
        $WiGuiUpdate = New-Object System.Windows.Forms.Form
        $SkipButton = New-Object System.Windows.Forms.Button
        $DownloadButton = New-Object System.Windows.Forms.Button
        $GithubButton = New-Object System.Windows.Forms.Button
        $TextLabel = New-Object System.Windows.Forms.Label
        $WiGuiSaveFile = New-Object System.Windows.Forms.SaveFileDialog
        #
        # SkipButton
        #
        $SkipButton.Location = New-Object System.Drawing.Point(224, 64)
        $SkipButton.Name = "SkipButton"
        $SkipButton.Size = New-Object System.Drawing.Size(100, 23)
        $SkipButton.TabIndex = 0
        $SkipButton.Text = "Skip"
        $SkipButton.UseVisualStyleBackColor = $true
        #
        # DownloadButton
        #
        $DownloadButton.Location = New-Object System.Drawing.Point(118, 64)
        $DownloadButton.Name = "DownloadButton"
        $DownloadButton.Size = New-Object System.Drawing.Size(100, 23)
        $DownloadButton.TabIndex = 1
        $DownloadButton.Text = "Download"
        $DownloadButton.UseVisualStyleBackColor = $true
        #
        # GithubButton
        #
        $GithubButton.Location = New-Object System.Drawing.Point(12, 64)
        $GithubButton.Name = "GithubButton"
        $GithubButton.Size = New-Object System.Drawing.Size(100, 23)
        $GithubButton.TabIndex = 2
        $GithubButton.Text = "See on GitHub"
        $GithubButton.UseVisualStyleBackColor = $true
        #
        # TextLabel
        #
        $TextLabel.Location = New-Object System.Drawing.Point(12, 9)
        $TextLabel.Name = "TextLabel"
        $TextLabel.RightToLeft = [System.Windows.Forms.RightToLeft]::No
        $TextLabel.Size = New-Object System.Drawing.Size(312, 52)
        $TextLabel.TabIndex = 3
        $TextLabel.Text = "A New WiGui version is available. Version $WiGuiLatestVersion"
        $TextLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
        #
        # WiGuiSaveFile
        #
        $WiGuiSaveFile.Filter = "Exe file (*.exe)|*.exe"
        $WiGuiSaveFile.FileName = "WiGui_$WiGuiLatestVersion.exe"
        #
        # WiGuiUpdate
        #
        $WiGuiUpdate.ClientSize = New-Object System.Drawing.Size(338, 99)
        $WiGuiUpdate.Controls.Add($TextLabel)
        $WiGuiUpdate.Controls.Add($GithubButton)
        $WiGuiUpdate.Controls.Add($DownloadButton)
        $WiGuiUpdate.Controls.Add($SkipButton)
        $WiGuiUpdate.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
        $WiGuiUpdate.MaximizeBox = $false
        $WiGuiUpdate.MinimizeBox = $false
        $WiGuiUpdate.Name = "WiGuiUpdate"
        $WiGuiUpdate.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
        $WiGuiUpdate.Text = "WiGui $WiGuiVersion - Update available"
        $WiGuiUpdate.Icon = [System.Drawing.Icon]::FromHandle(([System.Drawing.Bitmap]::new($stream).GetHIcon()))


        ## ACTIONS ##

        $GithubButton.add_click({
            [System.Diagnostics.Process]::Start("https://github.com/Romanitho/Winget-Install-GUI/releases")
        })

        $DownloadButton.add_click({
            $response = $WiGuiSaveFile.ShowDialog() # $response can return OK or Cancel
            if ( $response -eq 'OK' ) {
                $WiGuiDlLink = "https://github.com/Romanitho/Winget-Install-GUI/releases/download/v$WiGuiLatestVersion/WiGui.exe"
                Invoke-WebRequest -Uri $WiGuiDlLink -OutFile $WiGuiSaveFile.FileName
                $WiGuiUpdate.Close()
                $WiGuiUpdate.DialogResult = [System.Windows.Forms.DialogResult]::OK
            }
        })

        $SkipButton.add_click({
            $WiGuiUpdate.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
            $WiGuiUpdate.Close()
        })


        ## RETURNS ##
        $WiGuiUpdRespond = $WiGuiUpdate.ShowDialog()

        if ($WiGuiUpdRespond -eq "OK"){
            Break
        }

    }

}

function Add-Shortcut ($Source, $Target) {

    #Creates shortcut
    $SourceFilePath = "$Source"
    $ShortcutPath = "$Target"
    $WScriptObj = New-Object -ComObject ("WScript.Shell")
    $shortcut = $WscriptObj.CreateShortcut($ShortcutPath)
    $shortcut.TargetPath = $SourceFilePath
    $shortcut.Save()
}
<# MAIN #>

#Temp folder
$Script:Location = "$env:ProgramData\WiGui_Temp"
#Create Temp folder
if (!(Test-Path $Location)){
    New-Item -ItemType Directory -Force -Path $Location | Out-Null
}

#Load assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

#Set some variables
$ProgressPreference = "SilentlyContinue"
$Script:AppToInstall = $null
$Script:InstallWAU = $null
$IconBase64 = [Convert]::FromBase64String("AAABAAEAEBAAAAAAAABoBAAAFgAAACgAAAAQAAAAIAAAAAEAIAAAAAAAQAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAUKEUwPHjCLECAzkRAgM5EQIDORECAzkRAgM5EQIDORECAzkRAgM5EPHjCOBQoRXwAAABQAAAAAAAAAABUoPpAyYZv9NWaj/zVmpP81ZqT/NWak/zVmpP81ZqT/NWak/zVmpP81ZqT/NWaj/zJgmv0TJDmtAAAAFAkQGC01ZZ/9MGWh/yFfl/8oY5z/IV+X/y5loP81aKT/W4S1/8XKz/+5vcL/ub3C/7m9wv99lLH/KU56/QYKD1wgOVZcOGyn/zFpov8eX5X/Lmeg/x5flf8vaKH/OGyn/2GKuf+2trb/n5+f/5+fn/+Tk5P/Z3uS/ypTf/8QHi2LJURjXzpxqv85cKn/Kmie/zlxqv8raJ//OHCo/zpxqv9Tg7X/obbM/5uxxv+QobP/d4eX/1Z0kv8sVoL/EiEwjCdHZl88daz/PHWs/zx1rP88daz/PHWs/zx1rP88daz/PHWs/zx1rP82apv/LlqE/y5ZhP8uWYT/LlmE/xMjMosrTGpfPnqv/z56r/8+eq//Pnqv/z56r/8+eq//Pnqv/z56r/84bp7/L12G/y9dhv8vXYb/L12G/y9dhv8VJTSKL1FtX0B/sv9Af7L/QH+y/0B/sv9Af7L/QH+y/0B/sv86cqD/MWGI/zFhiP8xYYj/MWGI/zFhiP8xYYj/Fyc1iTNWcF9DhLX/Q4S1/0OEtf9DhLX/Q4S1/0OEtf88dqL/M2SK/zNkiv8zZIr/M2SK/zNkiv8zZIr/M2SK/xkqN4g4WnJfRYi3/0WIt/9FiLf/RYi3/0WIt/9Girj/U5i3/1edu/83a4//NWiM/zVojP81aIz/NWiM/zdulP8fNUSHPF91X0eNuv9Hjbr/R426/0eNuv9Hjbr/SI67/1igvv9cpsP/OW+R/zZsjv82bI7/NmyO/zlylv9Girb/IzpIhUBjd19Jkb3/SZG9/0mRvf9Jkb3/SZG9/0uTvf9Yob7/XafD/zpyk/84b5D/OG+Q/zt1mP9Ij7n/SZG9/yU8SoRHaHpbS5a//0uWv/9Llr//S5a//0uWv/9Nl8D/WaO//12oxP88dpX/OXOS/z15mv9Kk7v/S5a//0uWv/8oPUl9QFRfIVuixvtOm8L/TpvC/06bwv9Om8L/T5zC/1mkwP9eqcX/PXmX/z58nP9Ml77/TpvC/06bwv9ZoMT8ExkdPwAAAAB4obZsY6jK+0+dw/9OnMP/TpzD/1Cdw/9apMD/XqnF/0GBn/9Nmb//TpzD/0+dw/9hpcf8OlFchQAAAAIAAAAAAAAAAEpdZyFhfIlbYXyKX2F8il9ifYpfZX+JX2eBil9he4hfYnyKX2J8il9bc39cHiYqKQAAAAAAAAAAgAEAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAAAAAwAMAAA==")
$Script:stream = [System.IO.MemoryStream]::new($IconBase64, 0, $IconBase64.Length)

#Check if WiGui is uptodate
Get-WiGuiLatestVersion

#Check if Winget is installed, and install if not (and download favourite apps/set ACL if in WSB)
$Script:UserName = "$env:UserName"
if ($UserName -eq "WDAGUtilityAccount") {

    #set user start menu
    $Script:UserStartMenu = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs"
    #set NirSoft install path (x64)
    $Script:NirSoftInstallPathx64 = "$env:ProgramFiles\NirSoft"

    #Check if AdvancedRun already installed
     if (!(Test-Path "$NirSoftInstallPathx64\AdvancedRun")){
        #If not, download and create shortcut in user start menu
        Get-Tools "https://www.nirsoft.net/utils/advancedrun-x64.zip" "$NirSoftInstallPathx64\AdvancedRun"
        New-Item -ItemType Directory -Force -Path "$UserStartMenu\NirSoft AdvancedRun" | Out-Null
        Add-Shortcut "$NirSoftInstallPathx64\AdvancedRun\AdvancedRun.exe" "$UserStartMenu\NirSoft AdvancedRun\AdvancedRun.lnk"
        Add-Shortcut "$NirSoftInstallPathx64\AdvancedRun\AdvancedRun.chm" "$UserStartMenu\NirSoft AdvancedRun\AdvancedRun Help.lnk"
    }
    #Check if UninstallView already installed
    if (!(Test-Path "$NirSoftInstallPathx64\UninstallView")){
        #If not, download and create shortcut in user start menu
        Get-Tools "https://www.nirsoft.net/utils/uninstallview-x64.zip" "$NirSoftInstallPathx64\UninstallView"
        New-Item -ItemType Directory -Force -Path "$UserStartMenu\NirSoft UninstallView" | Out-Null
        Add-Shortcut "$NirSoftInstallPathx64\UninstallView\UninstallView.exe" "$UserStartMenu\NirSoft UninstallView\UninstallView.lnk"
        Add-Shortcut "$NirSoftInstallPathx64\UninstallView\UninstallView.chm" "$UserStartMenu\NirSoft UninstallView\UninstallView Help.lnk"
    }
    #WindowsApps folder
    $Script:AppsLocation = "$env:ProgramFiles\WindowsApps"
    if (!(Test-Path "$AppsLocation\WSB.fix")) {
        # Take ownership
        & C:\Windows\System32\takeown.exe /F $AppsLocation /R /A /D Y | Out-Null

        # Set PS variables for each of the icacls options
        $icaclsPath = $AppsLocation   #The path must be the first thing passed to icacls
        $replaceInherit = "/inheritance:r"
        $Grant = "/grant:r"
        $userAccount = "Administrators"
        $Permissions = ":(OI)(CI)F"
        $traverseContinue = "/T /C"
        # Run icacls using invoke Expression
        Invoke-Expression -Command ('icacls $icaclsPath $replaceInherit $Grant $userAccount$Permissions "${$traverseContinue}"') | Out-Null

        New-Item -ItemType File -Force -Path "$AppsLocation\WSB.fix" | Out-Null
    }
    Get-WingetStatus
}
else {
    Get-WingetStatus
}

#Run WiGui
Get-InstallGUI

#Remove temp items
Remove-Item -Path $Location -Force -Recurse -ErrorAction SilentlyContinue
