<#
.SYNOPSIS
Install apps with Winget-Install and configure Winget-AutoUpdate

.DESCRIPTION
This script will:
 - Install Winget if not present
 - Install apps with Winget from a custom list file (apps.txt) or directly from popped up default list.
 - Install Winget-AutoUpdate to get apps daily updated
https://github.com/Romanitho/Winget-Install-GUI
#>

<# APP INFO #>

# import Appx module if the powershell version is 7/core
if ( $psversionTable.PSEdition -eq "core" ) {
    import-Module -name Appx -UseWIndowsPowershell -WarningAction:SilentlyContinue
}

$Script:WiGuiVersion = "1.9.0"
$Script:WAUGithubLink = "https://github.com/Romanitho/Winget-AutoUpdate/releases/download/v1.17.5/WAU.zip"
$Script:WIGithubLink = "https://github.com/Romanitho/Winget-Install/archive/refs/tags/v1.10.1.zip"
$Script:WingetLink = "https://github.com/microsoft/winget-cli/releases/download/v1.4.10173/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"

<# FUNCTIONS #>

#Function to start or update popup
Function Start-PopUp ($Message) {

    if (!$PopUpWindow) {

        #Create window
        $inputXML = @"
<Window x:Class="WiGui_v3.PopUp"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
        xmlns:local="clr-namespace:WiGui_v3"
        mc:Ignorable="d"
        Title="WiGui {0}" ResizeMode="NoResize" WindowStartupLocation="CenterScreen" Topmost="True" Width="280" MinHeight="130" SizeToContent="Height">
    <Grid>
        <TextBlock x:Name="PopUpLabel" HorizontalAlignment="Center" VerticalAlignment="Center" TextWrapping="Wrap" Margin="20" TextAlignment="Center"/>
    </Grid>
</Window>
"@

        [xml]$XAML = ($inputXML -replace 'mc:Ignorable="d"', '' -replace "x:N", 'N' -replace '^<Win.*', '<Window') -f $WiGuiVersion

        #Read the form
        $Reader = (New-Object System.Xml.XmlNodeReader $XAML)
        $Script:PopUpWindow = [Windows.Markup.XamlReader]::Load($Reader)
        $PopUpWindow.Icon = $IconBase64

        #Store Form Objects In PowerShell
        $XAML.SelectNodes("//*[@Name]") | foreach {
            Set-Variable -Name "$($_.Name)" -Value $PopUpWindow.FindName($_.Name) -Scope Script
        }

        $PopUpWindow.Show()
    }
    #Message to display
    $PopUpLabel.Text = $Message
    #Update PopUp
    $PopUpWindow.Dispatcher.Invoke([action] {}, "Render")
}

#Function to close popup
Function Close-PopUp {
    $Script:PopUpWindow.Close()
    $Script:PopUpWindow = $null
}

function Get-GithubRepository ($Url, $SubFolder) {

    # Force to create a zip file
    $ZipFile = "$Location\temp.zip"
    New-Item $ZipFile -ItemType File -Force | Out-Null

    # Download the zip
    Invoke-RestMethod -Uri $Url -OutFile $ZipFile

    # Extract Zip File
    Expand-Archive -Path $ZipFile -DestinationPath "$Location\$SubFolder" -Force
    Get-ChildItem -Path "$Location\$SubFolder" -Recurse | Unblock-File

    # remove the zip file
    Remove-Item -Path $ZipFile -Force
}

function Get-WingetStatus {

    Start-PopUp "Starting..."

    #Check if Visual C++ 2019 or 2022 installed
    $Visual2019 = "Microsoft Visual C++ 2015-2019 Redistributable*"
    $Visual2022 = "Microsoft Visual C++ 2015-2022 Redistributable*"
    $path = Get-Item HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*, HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object { $_.GetValue("DisplayName") -like $Visual2019 -or $_.GetValue("DisplayName") -like $Visual2022 }

    #If not installed, install
    if (!($path)) {
        #Update Form
        Start-PopUp "Installing prerequisites:`nMicrosoft Visual C++ 2022"

        #Install
        try {
            if ((Get-CimInStance Win32_OperatingSystem).OSArchitecture -like "*64*") {
                $OSArch = "x64"
            }
            else {
                $OSArch = "x86"
            }
            $SourceURL = "https://aka.ms/vs/17/release/VC_redist.$OSArch.exe"
            $Installer = "$Location\VC_redist.$OSArch.exe"
            Invoke-WebRequest $SourceURL -OutFile (New-Item -Path $Installer -Force)
            Start-Process -FilePath $Installer -Args "/passive /norestart" -Wait
            Remove-Item $Installer -ErrorAction Ignore
        }
        catch {
            Write-host "MS Visual C++ 2015-2022 installation failed." -ForegroundColor Red
            Start-Sleep 3
        }
    }

    $hasAppInstaller = Get-AppXPackage -Name 'Microsoft.DesktopAppInstaller'
    [Version]$AppInstallerVers = $hasAppInstaller.version

    if (!($AppInstallerVers -ge "1.19.10173.0")) {

        #installing dependencies
        if (!(Get-AppxPackage -Name 'Microsoft.UI.Xaml.2.7')) {
            #Update Form
            Start-PopUp "Installing prerequisites:`nMicrosoft UI Xaml 2.7.0"

            #Install
            $UiXamlUrl = "https://www.nuget.org/api/v2/package/Microsoft.UI.Xaml/2.7.0"
            $UiXamlZip = "$Location\Microsoft.UI.XAML.2.7.zip"
            Invoke-RestMethod -Uri $UiXamlUrl -OutFile $UiXamlZip
            Expand-Archive -Path $UiXamlZip -DestinationPath "$Location\extracted" -Force
            Add-AppxPackage -Path "$Location\extracted\tools\AppX\x64\Release\Microsoft.UI.Xaml.2.7.appx"
            Remove-Item -Path $UiXamlZip -Force
            Remove-Item -Path "$Location\extracted" -Force -Recurse
        }

        if (!(Get-AppxPackage -Name 'Microsoft.VCLibs.140.00.UWPDesktop')) {
            #Update Form
            Start-PopUp "Installing prerequisites:`nMicrosoft VCLibs x64 14.00"

            #Install
            $VCLibsUrl = "https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx"
            $VCLibsFile = "$Location\Microsoft.VCLibs.x64.14.00.Desktop.appx"
            Invoke-RestMethod -Uri $VCLibsUrl -OutFile $VCLibsFile
            Add-AppxPackage -Path $VCLibsFile
            Remove-Item -Path $VCLibsFile -Force
        }

        #installing Winget
        #Update Form
        Start-PopUp "Installing prerequisites:`nWinget"

        #Install
        $WingetFile = "$Location\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
        Invoke-RestMethod -Uri $WingetLink -OutFile $WingetFile
        Add-AppxPackage -Path $WingetFile
        Remove-Item -Path $WingetFile

    }

    #Close Form
    Close-PopUp

}

function Get-WingetCmd {

    #WinGet Path (if User/Admin context)
    $UserWingetPath = Get-Command winget.exe -ErrorAction SilentlyContinue
    #WinGet Path (if system context)
    $SystemWingetPath = Resolve-Path "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe"

    #Get Winget Location in User/Admin context
    if ($UserWingetPath) {
        $Script:Winget = $UserWingetPath.Source
    }
    #Get Winget Location in System context
    elseif ($SystemWingetPath) {
        #If multiple version, pick last one
        $Script:Winget = $SystemWingetPath[-1].Path
    }
    else {
        Write-Host "WinGet is not installed. It is mandatory to run WiGui"
        break
    }

}

function Get-WingetAppInfo ($SearchApp) {
    class Software {
        [string]$Name
        [string]$Id
    }

    #Search for winget apps
    $AppResult = & $Winget search $SearchApp --accept-source-agreements --source winget

    #Start Convertion of winget format to an array. Check if "-----" exists
    if (!($AppResult -match "-----")) {
        Write-Host "No application found."
        return
    }

    #Split winget output to lines
    $lines = $AppResult.Split([Environment]::NewLine) | Where-Object { $_ }

    # Find the line that starts with "------"
    $fl = 0
    while (-not $lines[$fl].StartsWith("-----")) {
        $fl++
    }

    $fl = $fl - 1

    #Get header titles
    $index = $lines[$fl] -split '\s+'

    # Line $fl has the header, we can find char where we find ID and Version
    $idStart = $lines[$fl].IndexOf($index[1])
    $versionStart = $lines[$fl].IndexOf($index[2])

    # Now cycle in real package and split accordingly
    $searchList = @()
    For ($i = $fl + 2; $i -le $lines.Length; $i++) {
        $line = $lines[$i]
        if ($line.Length -gt ($sourceStart + 5)) {
            $software = [Software]::new()
            $software.Name = $line.Substring(0, $idStart).TrimEnd()
            $software.Id = $line.Substring($idStart, $versionStart - $idStart).TrimEnd()
            #add formated soft to list
            $searchList += $software
        }
    }
    return $searchList
}

function Get-WingetInstalledApps {

    #Json File where to export install apps
    $jsonFile = "$Location\Installed_Apps.json"

    #Get list of installed Winget apps to json file
    & $Winget export -o $jsonFile --accept-source-agreements | Out-Null

    #Convert from json file
    $InstalledApps = get-content $jsonFile | ConvertFrom-Json

    #Return app list
    return $InstalledApps.Sources.Packages.PackageIdentifier | Sort-Object | Get-Unique
}

function Start-Installations {

    ## WINGET-INSTALL PART ##

    #Download and run Winget-Install script if box is checked
    if ($AppToInstall) {

        Start-PopUp "Installing applications..."

        #Check if Winget-Install already downloaded
        $TestPath = "$Location\Winget-Install\Winget-Install*\winget-install.ps1"
        if (!(Test-Path $TestPath)) {
            #If not, download
            Get-GithubRepository $WIGithubLink "Winget-Install"
        }

        #Run Winget-Install
        $WIInstallFile = (Resolve-Path $TestPath)[0].Path
        Start-Process "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -Command `"$WIInstallFile -AppIDs $AppToInstall`"" -Wait -Verb RunAs
    }

    ## WAU PART ##

    #Download and install Winget-AutoUpdate if box is checked
    if ($InstallWAU) {

        Start-PopUp "Installing WAU..."

        #Check if WAU already downloaded
        $TestPath = "$Location\WAU\Winget-AutoUpdate-Install.ps1"
        if (!(Test-Path $TestPath)) {
            #If not, download
            Get-GithubRepository $WAUGithubLink "WAU"
        }

        #Get install file
        $WAUInstallFile = (Resolve-Path $TestPath)[0].Path

        #Get parent folder
        $WAUInstallFolder = Split-Path $WAUInstallFile

        #Configure parameters
        $WAUParameters = "-Silent "
        if ($WAUDoNotUpdate) {
            $WAUParameters += "-DoNotUpdate "
        }
        if ($WAUDisableAU) {
            $WAUParameters += "-DisableWAUAutoUpdate "
        }
        if ($WAUNotificationLevel) {
            $WAUParameters += "-NotificationLevel $WAUNotificationLevel "
        }
        if ($WAUFreqUpd) {
            $WAUParameters += "-UpdatesInterval $WAUFreqUpd "
        }
        if ($WAUAtUserLogon) {
            $WAUParameters += "-UpdatesAtLogon "
        }
        if ($WAUonMetered) {
            $WAUParameters += "-RunOnMetered "
        }
        if ($WAUUseWhiteList) {
            $WAUParameters += "-UseWhiteList "
            if ($WAUListPath) {
                Copy-Item $WAUListPath -Destination "$WAUInstallFolder\included_apps.txt" -Force -ErrorAction SilentlyContinue
            }
        }
        else {
            if ($WAUListPath) {
                Copy-Item $WAUListPath -Destination "$WAUInstallFolder\excluded_apps.txt" -Force -ErrorAction SilentlyContinue
            }
        }
        if ($WAUDesktopShortcut) {
            $WAUParameters += "-DesktopShortcut "
        }
        if ($WAUStartMenuShortcut) {
            $WAUParameters += "-StartMenuShortcut "
        }
        if ($WAUInstallUserContext) {
            $WAUParameters += "-InstallUserContext "
        }

        #Install Winget-Autoupdate
        Start-Process "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -Command `"$WAUInstallFile $WAUParameters`"" -Wait -Verb RunAs
    }

    ## ADMIN PART ##

    if ($CMTrace) {
        Start-PopUp "Installing CMTrace..."
        $CMToolkitLink = "https://github.com/Romanitho/Winget-Install-GUI/raw/main/Tools/cmtrace.exe"
        $CMToolkitPath = "C:\Tools\CMTrace.exe"
        Invoke-WebRequest $CMToolkitLink -OutFile (New-Item -Path $CMToolkitPath -Force)
        Start-Sleep 1
    }

    if ($AdvancedRun) {
        Start-PopUp "Installing AdvancedRun..."
        $AdvancedRunLink = "https://www.nirsoft.net/utils/advancedrun-x64.zip"
        $AdvancedRunPath = "C:\Tools\advancedrun-x64.zip"
        Invoke-WebRequest $AdvancedRunLink -OutFile (New-Item -Path $AdvancedRunPath -Force)
        Expand-Archive -Path $AdvancedRunPath -DestinationPath "C:\Tools\AdvancedRun" -Force
        Start-Sleep 1
        Remove-Item $AdvancedRunPath
    }

    if ($UninstallView) {
        Start-PopUp "Installing UninstallView..."
        $UninstallViewLink = "https://www.nirsoft.net/utils/uninstallview-x64.zip"
        $UninstallViewPath = "C:\Tools\uninstallview-x64.zip"
        Invoke-WebRequest $UninstallViewLink -OutFile (New-Item -Path $UninstallViewPath -Force)
        Expand-Archive -Path $UninstallViewPath -DestinationPath "C:\Tools\UninstallView" -Force
        Start-Sleep 1
        Remove-Item $UninstallViewPath
    }

    #If Popup Form is showing, close
    if ($PopUpWindow) {
        #Installs finished
        Start-PopUp "Done!"
        Start-Sleep 1
        #Close Popup
        Close-PopUp
    }

    if ($CMTrace -or $AdvancedRun -or $UninstallView) {
        Start-Process "C:\Tools"
    }
}

function Start-Uninstallations ($AppToUninstall) {
    #Download and run Winget-Install script if box is checked
    if ($AppToUninstall) {

        Start-PopUp "Uninstalling applications..."

        #Check if Winget-Install already downloaded
        $TestPath = "$Location\Winget-Install\Winget-Install*\winget-install.ps1"
        if (!(Test-Path $TestPath)) {
            #If not, download
            Get-GithubRepository $WIGithubLink "Winget-Install"
        }

        #Run Winget-Install -Uninstall
        $WIInstallFile = (Resolve-Path $TestPath)[0].Path
        $AppsToUninstall = "'$($AppToUninstall -join "','")'"
        Start-Process "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -Command `"$WIInstallFile -AppIDs $AppsToUninstall -Uninstall`"" -Wait -Verb RunAs

        Close-PopUp
    }
}

function Get-WAUInstallStatus {
    $WAUVersion = Get-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Winget-AutoUpdate\ -ErrorAction SilentlyContinue | Select-Object -ExpandProperty DisplayVersion -ErrorAction SilentlyContinue
    if ($WAUVersion) {
        $WAULabelText = "WAU is currently installed (v$WAUVersion)."
        $WAUStatus = "Green"
    }
    else {
        $WAULabelText = "WAU is not installed."
        $WAUStatus = "Red"
    }
    return $WAULabelText, $WAUStatus
}

function Get-WiGuiLatestVersion {

    ### FORM CREATION ###

    #Get latest stable info
    $WiGuiURL = 'https://api.github.com/repos/Romanitho/Winget-Install-GUI/releases/latest'
    $WiGuiLatestVersion = ((Invoke-WebRequest $WiGuiURL -UseBasicParsing | ConvertFrom-Json)[0].tag_name).Replace("v", "")

    if ([version]$WiGuiVersion -lt [version]$WiGuiLatestVersion) {

        #Create window
        $inputXML = @"
<Window x:Class="WiGui.Update"
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
    xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
    xmlns:local="clr-namespace:Winget_Intune_Packager"
    mc:Ignorable="d"
    Title="WiGui {0} - Update available" ResizeMode="NoResize" SizeToContent="WidthAndHeight" WindowStartupLocation="CenterScreen" Topmost="True">
    <Grid>
        <TextBlock x:Name="TextBlock" HorizontalAlignment="Center" TextWrapping="Wrap" VerticalAlignment="Center" Margin="26,26,26,60" MaxWidth="480" Text="A New WiGui version is available. Version $WiGuiLatestVersion"/>
        <StackPanel Height="32" Orientation="Horizontal" UseLayoutRounding="False" VerticalAlignment="Bottom" HorizontalAlignment="Center" Margin="6">
            <Button x:Name="GithubButton" Content="See on GitHub" Margin="4" Width="100"/>
            <Button x:Name="DownloadButton" Content="Download" Margin="4" Width="100"/>
            <Button x:Name="SkipButton" Content="Skip" Margin="4" Width="100" IsDefault="True"/>
        </StackPanel>
    </Grid>
</Window>
"@

        [xml]$XAML = ($inputXML -replace 'mc:Ignorable="d"', '' -replace "x:N", 'N' -replace '^<Win.*', '<Window') -f $WiGuiVersion

        #Read the form
        $Reader = (New-Object System.Xml.XmlNodeReader $xaml)
        $UpdateWindow = [Windows.Markup.XamlReader]::Load($Reader)
        $UpdateWindow.Icon = $IconBase64

        #Store Form Objects In PowerShell
        $FormObjects = $XAML.SelectNodes("//*[@Name]")
        $FormObjects | ForEach-Object {
            Set-Variable -Name "$($_.Name)" -Value $UpdateWindow.FindName($_.Name) -Scope Script
        }


        ## ACTIONS ##

        $GithubButton.add_click(
            {
                $UpdateWindow.Topmost = $false
                [System.Diagnostics.Process]::Start("https://github.com/Romanitho/Winget-Install-GUI/releases")
            }
        )

        $DownloadButton.add_click(
            {
                $WiGuiSaveFile = New-Object System.Windows.Forms.SaveFileDialog
                $WiGuiSaveFile.Filter = "Exe file (*.exe)|*.exe"
                $WiGuiSaveFile.FileName = "WiGui_$WiGuiLatestVersion.exe"
                $response = $WiGuiSaveFile.ShowDialog() # $response can return OK or Cancel
                if ( $response -eq 'OK' ) {
                    Start-PopUp "Downloading WiGui $WiGuiLatestVersion..."
                    $WiGuiDlLink = "https://github.com/Romanitho/Winget-Install-GUI/releases/download/v$WiGuiLatestVersion/WiGui.exe"
                    Invoke-WebRequest -Uri $WiGuiDlLink -OutFile $WiGuiSaveFile.FileName -UseBasicParsing
                    $UpdateWindow.DialogResult = [System.Windows.Forms.DialogResult]::OK
                    $UpdateWindow.Close()
                    Start-PopUp "Starting WiGui $WiGuiLatestVersion..."
                    Start-Process -FilePath $WiGuiSaveFile.FileName
                    Start-Sleep 4
                    Close-PopUp
                    Exit 0
                }
            }
        )

        $SkipButton.add_click(
            {
                $UpdateWindow.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
                $UpdateWindow.Close()
            }
        )


        ## RETURNS ##
        #Show Wait form
        $UpdateWindow.ShowDialog() | Out-Null
    }
}

function Start-InstallGUI {

    ### FORM CREATION ###

    # GUI XAML file
    $inputXML = @"
<Window x:Name="WiGuiForm" x:Class="WiGui_v3.MainWindow"
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
    xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
    xmlns:local="clr-namespace:WiGui_v3"
    mc:Ignorable="d"
    Title="WiGui {0}" Height="700" Width="540" ResizeMode="CanMinimize" WindowStartupLocation="CenterScreen">
<Grid>
    <Grid.Background>
        <SolidColorBrush Color="#FFF0F0F0"/>
    </Grid.Background>
    <TabControl x:Name="WiGuiTabControl" Margin="10,10,10,44">
        <TabItem x:Name="AppsTabPage" Header="Select Apps">
            <Grid>
                <Label x:Name="SearchLabel" Content="Search for an app:" VerticalAlignment="Top" HorizontalAlignment="Left" Margin="10,10,0,0"/>
                <TextBox x:Name="SearchTextBox" HorizontalAlignment="Left" VerticalAlignment="Top" Margin="10,36,0,0" Width="380" Height="24" VerticalContentAlignment="Center"/>
                <Button x:Name="SearchButton" Content="Search" HorizontalAlignment="Right" VerticalAlignment="Top" Width="90" Height="24" Margin="0,36,10,0" IsDefault="True"/>
                <Label x:Name="SubmitLabel" Content="Select the matching Winget AppID:" VerticalAlignment="Top" HorizontalAlignment="Left" Margin="10,70,0,0"/>
                <Button x:Name="SubmitButton" Content="Add to list" HorizontalAlignment="Right" VerticalAlignment="Top" Width="90" Height="24" Margin="0,96,10,0"/>
                <Label x:Name="AppListLabel" Content="Current Application list:" VerticalAlignment="Top" HorizontalAlignment="Left" Margin="10,130,0,0"/>
                <Button x:Name="SaveListButton" Content="Save list to file" HorizontalAlignment="Right" VerticalAlignment="Top" Width="90" Height="24" Margin="0,156,10,0"/>
                <Button x:Name="OpenListButton" Content="Import from file" HorizontalAlignment="Right" VerticalAlignment="Top" Width="90" Height="24" Margin="0,185,10,0"/>
                <Button x:Name="RemoveButton" Content="Remove" HorizontalAlignment="Right" VerticalAlignment="Top" Width="90" Height="24" Margin="0,214,10,0"/>
                <Button x:Name="UninstallButton" Content="Uninstall" HorizontalAlignment="Right" VerticalAlignment="Bottom" Width="90" Height="24" Margin="0,0,10,39"/>
                <Button x:Name="InstalledAppButton" Content="List installed" HorizontalAlignment="Right" VerticalAlignment="Bottom" Width="90" Height="24" Margin="0,0,10,10"/>
                <ListBox x:Name="AppListBox" HorizontalAlignment="Left" Margin="10,156,0,10" Width="380" SelectionMode="Extended"/>
                <ComboBox x:Name="SubmitComboBox" HorizontalAlignment="Left" Margin="10,96,0,0" VerticalAlignment="Top" Width="380" Height="24" IsEditable="True"/>
            </Grid>
        </TabItem>
        <TabItem x:Name="WAUTabPage" Header="Configure WAU">
            <Grid>
                <CheckBox x:Name="WAUCheckBox" Content="Install WAU (Winget-AutoUpdate)" Margin="10,20,0,0" VerticalAlignment="Top" HorizontalAlignment="Left" ToolTip="Install WAU with system and user context executions. Applications installed in system context will be ignored under user context."/>
                <GroupBox x:Name="WAUConfGroupBox" Header="Configurations" VerticalAlignment="Top" Margin="10,46,10,0" Height="134" IsEnabled="False">
                    <Grid>
                        <CheckBox x:Name="WAUDoNotUpdateCheckBox" Content="Do not run WAU just after install" Margin="10,10,0,0" HorizontalAlignment="Left" VerticalAlignment="Top" ToolTip="Do not run Winget-AutoUpdate after installation. By default, Winget-AutoUpdate is run just after installation."/>
                        <CheckBox x:Name="WAUDisableAUCheckBox" Content="Disable WAU Self-Update" Margin="10,34,0,0" HorizontalAlignment="Left" VerticalAlignment="Top" ToolTip="Disable WAU update checking. By default, WAU auto updates if new version is available on Github."/>
                        <CheckBox x:Name="WAUonMeteredCheckBox" Content="Run WAU on metered connexion" Margin="10,58,0,0" HorizontalAlignment="Left" VerticalAlignment="Top" ToolTip="Force WAU to run on metered connections. Not recommanded on connection sharing for instance as it might consume cellular data."/>
                        <TextBlock x:Name="NotifLevelLabel" HorizontalAlignment="Left" Margin="10,85,0,0" TextWrapping="Wrap" Text="Notification level" VerticalAlignment="Top" ToolTip="Specify the Notification level: Full (Default, displays all notification), SuccessOnly (Only displays notification for success) or None (Does not show any popup)."/>
                        <ComboBox x:Name="NotifLevelComboBox" HorizontalAlignment="Left" Margin="120,82,0,0" VerticalAlignment="Top" Width="110" ToolTip="Specify the Notification level: Full (Default, displays all notification), SuccessOnly (Only displays notification for success) or None (Does not show any popup).">
                            <ComboBoxItem Content="Full" IsSelected="True"/>
                            <ComboBoxItem Content="SuccessOnly"/>
                            <ComboBoxItem Content="None"/>
                        </ComboBox>
                        <CheckBox x:Name="WAUInstallUserContextCheckBox" Margin="250,10,0,0" HorizontalAlignment="Left" VerticalAlignment="Top" Content="Run WAU in user context too" ToolTip="Install WAU with system and user context executions (by default, only system for admin rights purpose). Applications installed in system context will be ignored under user context."/>
                    </Grid>
                </GroupBox>
                <GroupBox x:Name="WAUFreqGroupBox" Header="Update Frequency" VerticalAlignment="Top" Margin="10,185,10,0" Height="84" IsEnabled="False">
                    <Grid>
                        <StackPanel x:Name="WAUFreqLayoutPanel" VerticalAlignment="Top" Orientation="Horizontal">
                            <RadioButton Content="Daily" Margin="10"/>
                            <RadioButton Content="Weekly" Margin="10"/>
                            <RadioButton Content="Biweekly" Margin="10"/>
                            <RadioButton Content="Monthly" Margin="10"/>
                            <RadioButton Content="Never" Margin="10" IsChecked="True"/>
                        </StackPanel>
                        <CheckBox x:Name="UpdAtLogonCheckBox" Content="Run WAU at user logon" Margin="10,40,0,0" IsChecked="True"/>
                    </Grid>
                </GroupBox>
                <GroupBox x:Name="WAUWhiteBlackGroupBox" Header="White / Black List" VerticalAlignment="Top" Margin="10,274,10,0" Height="88" IsEnabled="False">
                    <Grid>
                        <StackPanel x:Name="WAUListLayoutPanel" VerticalAlignment="Top" Orientation="Horizontal">
                            <RadioButton x:Name="DefaultRadioBut" Content="Default" Margin="10" IsChecked="True"/>
                            <RadioButton x:Name="BlackRadioBut" Content="BlackList" Margin="10" ToolTip="Exclude apps from update job (for instance, apps to keep at a specific version or apps with built-in auto-update)"/>
                            <RadioButton x:Name="WhiteRadioBut" Content="WhiteList" Margin="10" ToolTip="Update only selected apps"/>
                        </StackPanel>
                        <TextBox x:Name="WAUListFileTextBox" VerticalAlignment="Top" Margin="10,36,106,0" Height="24" VerticalContentAlignment="Center" IsEnabled="False"/>
                        <Button x:Name="WAULoadListButton" Content="Load list" Width="90" Height="24" HorizontalAlignment="Right" VerticalAlignment="Top" Margin="0,36,10,0" IsEnabled="False"/>
                    </Grid>
                </GroupBox>
                <GroupBox x:Name="WAUShortcutsGroupBox" Header="Shortcuts" VerticalAlignment="Top" Margin="10,367,10,0" Height="80" IsEnabled="False">
                    <Grid>
                        <CheckBox x:Name="DesktopCheckBox" Content="Desktop" Margin="10,10,0,0" HorizontalAlignment="Left" VerticalAlignment="Top" IsChecked="True"/>
                        <CheckBox x:Name="StartMenuCheckBox" Content="Start Menu" Margin="10,34,0,0" HorizontalAlignment="Left" VerticalAlignment="Top" IsChecked="True"/>
                    </Grid>
                </GroupBox>
                <TextBlock x:Name="WAUStatusLabel" HorizontalAlignment="Left" VerticalAlignment="Bottom" Margin="10" Text="WAU installed status"/>
                <TextBlock x:Name="WAUMoreInfoLabel" HorizontalAlignment="Right" VerticalAlignment="Bottom" Margin="10">
                    <Hyperlink NavigateUri="https://github.com/Romanitho/Winget-AutoUpdate">More Info about WAU</Hyperlink>
                </TextBlock>
            </Grid>
        </TabItem>
        <TabItem x:Name="AdminTabPage" Header="Admin Tools" Visibility="Hidden">
            <Grid>
                <CheckBox x:Name="AdvancedRunCheckBox" Content="Install NirSoft AdvancedRun" Margin="10,20,0,0" HorizontalAlignment="Left" VerticalAlignment="Top"/>
                <CheckBox x:Name="UninstallViewCheckBox" Content="Install NirSoft UninstallView" Margin="10,44,0,0" HorizontalAlignment="Left" VerticalAlignment="Top"/>
                <CheckBox x:Name="CMTraceCheckBox" Content="Install CMTrace" Margin="10,68,0,0" HorizontalAlignment="Left" VerticalAlignment="Top"/>
                <Button x:Name="LogButton" Content="Open Log Folder" HorizontalAlignment="Right" VerticalAlignment="Bottom" Width="110" Height="24" Margin="0,0,10,10"/>
            </Grid>
        </TabItem>
    </TabControl>
    <Button x:Name="CloseButton" Content="Close" HorizontalAlignment="Right" VerticalAlignment="Bottom" Margin="0,0,10,10" Width="90" Height="24"/>
    <Button x:Name="InstallButton" Content="Install" HorizontalAlignment="Right" VerticalAlignment="Bottom" Margin="0,0,105,10" Width="90" Height="24"/>
    <TextBlock x:Name="WiGuiLinkLabel" HorizontalAlignment="Left" VerticalAlignment="Bottom" Margin="10,0,0,14">
        <Hyperlink NavigateUri="https://github.com/Romanitho/Winget-Install-GUI">WiGui is on GitHub</Hyperlink>
    </TextBlock>
</Grid>
</Window>
"@

    #Create window
    [xml]$XAML = ($inputXML -replace 'mc:Ignorable="d"', '' -replace "x:N", 'N' -replace '^<Win.*', '<Window') -f $WiGuiVersion

    #Read the form
    $Reader = (New-Object System.Xml.XmlNodeReader $xaml)
    $script:WiGuiForm = [Windows.Markup.XamlReader]::Load($reader)

    #Store Form Objects In PowerShell
    $FormObjects = $xaml.SelectNodes("//*[@Name]")
    $FormObjects | ForEach-Object {
        Set-Variable -Name "$($_.Name)" -Value $WiGuiForm.FindName($_.Name) -Scope Script
    }

    # Customization
    $SaveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
    $SaveFileDialog.Filter = "Text files (*.txt)|*.txt|All files (*.*)|*.*"
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.Filter = "Text files (*.txt)|*.txt|All files (*.*)|*.*"
    $WAUListOpenFile = New-Object System.Windows.Forms.OpenFileDialog
    $WAUListOpenFile.Filter = "Text files (*.txt)|*.txt|All files (*.*)|*.*"
    $WAUInstallStatus = Get-WAUInstallStatus
    $WAUStatusLabel.Text = $WAUInstallStatus[0]
    $WAUStatusLabel.Foreground = $WAUInstallStatus[1]
    $WiGuiForm.Icon = $IconBase64



    ### FORM ACTIONS ###

    ##
    # "Select Apps" Tab
    ##
    $SearchButton.add_click(
        {
            if ($SearchTextBox.Text) {
                Start-PopUp "Searching..."
                $SubmitComboBox.Items.Clear()
                $List = Get-WingetAppInfo $SearchTextBox.Text
                foreach ($L in $List) {
                    $SubmitComboBox.Items.Add($L.ID)
                }
                $SubmitComboBox.SelectedIndex = 0
                Close-PopUp
            }
        }
    )

    $SubmitButton.add_click(
        {
            $AddAppToList = $SubmitComboBox.Text
            if ($AddAppToList -ne "" -and $AppListBox.Items -notcontains $AddAppToList) {
                $AppListBox.Items.Add($AddAppToList)
            }
        }
    )

    $RemoveButton.add_click(
        {
            if (!$AppListBox.SelectedItems) {
                Start-PopUp "Please select apps to remove..."
                Start-Sleep 2
                Close-PopUp
            }
            while ($AppListBox.SelectedItems) {
                $AppListBox.Items.Remove($AppListBox.SelectedItems[0])
            }
        }
    )

    $SaveListButton.add_click(
        {
            $response = $SaveFileDialog.ShowDialog() # $response can return OK or Cancel
            if ( $response -eq 'OK' ) {
                $AppListBox.Items | Out-File $SaveFileDialog.FileName -Append
                Write-Host "File saved to:`n$($SaveFileDialog.FileName)"
            }
        }
    )

    $OpenListButton.add_click(
        {
            $response = $OpenFileDialog.ShowDialog() # $response can return OK or Cancel
            if ( $response -eq 'OK' ) {
                $FileContent = Get-Content $OpenFileDialog.FileName
                foreach ($App in $FileContent) {
                    if ($App -ne "" -and $AppListBox.Items -notcontains $App) {
                        $AppListBox.Items.Add($App)
                    }
                }
            }
        }
    )

    $InstalledAppButton.add_click(
        {
            Start-PopUp "Getting installed apps..."
            $AppListBox.Items.Clear()
            $List = Get-WingetInstalledApps
            foreach ($L in $List) {
                $AppListBox.Items.Add($L)
            }
            Close-PopUp
        }
    )

    $UninstallButton.add_click(
        {
            if ($AppListBox.SelectedItems) {
                Start-Uninstallations $AppListBox.SelectedItems
                $WAUInstallStatus = Get-WAUInstallStatus
                $WAUStatusLabel.Text = $WAUInstallStatus[0]
                $WAUStatusLabel.Foreground = $WAUInstallStatus[1]
                $AppListBox.Items.Clear()
            }
            else {
                Start-PopUp "Please select apps to uninstall..."
                Start-Sleep 1
                Close-PopUp
            }
        }
    )

    ##
    # "Configure WAU" Tab
    ##
    $WAUCheckBox.add_click(
        {
            if ($WAUCheckBox.IsChecked -eq $true) {
                $WAUConfGroupBox.IsEnabled = $true
                $WAUFreqGroupBox.IsEnabled = $true
                $WAUWhiteBlackGroupBox.IsEnabled = $true
                $WAUShortcutsGroupBox.IsEnabled = $true
            }
            elseif ($WAUCheckBox.IsChecked -eq $false) {
                $WAUConfGroupBox.IsEnabled = $false
                $WAUFreqGroupBox.IsEnabled = $false
                $WAUWhiteBlackGroupBox.IsEnabled = $false
                $WAUShortcutsGroupBox.IsEnabled = $false
            }
        }
    )

    $WAUMoreInfoLabel.Add_PreviewMouseDown(
        {
            [System.Diagnostics.Process]::Start("https://github.com/Romanitho/Winget-AutoUpdate")
        }
    )

    $BlackRadioBut.add_click(
        {
            $WAULoadListButton.IsEnabled = $true
        }
    )

    $WhiteRadioBut.add_click(
        {
            $WAULoadListButton.IsEnabled = $true
        }
    )

    $DefaultRadioBut.add_click(
        {
            $WAULoadListButton.IsEnabled = $false
            $WAUListFileTextBox.Clear()
        }
    )

    $WAULoadListButton.add_click(
        {
            $response = $WAUListOpenFile.ShowDialog() # $response can return OK or Cancel
            if ( $response -eq 'OK' ) {
                $WAUListFileTextBox.Text = $WAUListOpenFile.FileName
            }
        }
    )

    ##
    # "Admin Tool" Tab by hitting F9 Key (Replacing F10 used by default by Windows)
    ##
    $WiGuiForm.Add_KeyDown(
        {
            if ($_.Key -eq "F9") {
                $AdminTabPage.Visibility = "Visible"
            }
        }
    )

    $LogButton.add_click(
        {
            if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Winget-AutoUpdate\") {
                $LogPath = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Winget-AutoUpdate\" -Name InstallLocation
                Start-Process "$LogPath\Logs"
            }
            elseif (Test-Path "$env:programdata\Winget-AutoUpdate\Logs") {
                Start-Process "$env:programdata\Winget-AutoUpdate\Logs"
            }
            else {
                Write-Host "Log location not found."
            }
        }
    )

    ##
    # Global Form
    ##
    $WiGuiLinkLabel.Add_PreviewMouseDown(
        {
            [System.Diagnostics.Process]::Start("https://github.com/Romanitho/Winget-Install-GUI")
        }
    )

    $InstallButton.add_click(
        {
            if ($AppListBox.Items) {
                $Script:AppToInstall = "'$($AppListBox.Items -join "','")'"
            }
            else {
                $Script:AppToInstall = $null
            }
            $Script:InstallWAU = $WAUCheckBox.IsChecked
            $Script:WAUDoNotUpdate = $WAUDoNotUpdateCheckBox.IsChecked
            $Script:WAUDisableAU = $WAUDisableAUCheckBox.IsChecked
            $Script:WAUAtUserLogon = $UpdAtLogonCheckBox.IsChecked
            $Script:WAUNotificationLevel = $NotifLevelComboBox.Text
            $Script:WAUUseWhiteList = $WhiteRadioBut.IsChecked
            $Script:WAUListPath = $WAUListFileTextBox.Text
            $Script:WAUFreqUpd = $WAUFreqLayoutPanel.Children.Where({ $_.IsChecked -eq $true }).content
            $Script:AdvancedRun = $AdvancedRunCheckBox.IsChecked
            $Script:UninstallView = $UninstallViewCheckBox.IsChecked
            $Script:CMTrace = $CMTraceCheckBox.IsChecked
            $Script:WAUonMetered = $WAUonMeteredCheckBox.IsChecked
            $Script:WAUDesktopShortcut = $DesktopCheckBox.IsChecked
            $Script:WAUStartMenuShortcut = $StartMenuCheckBox.IsChecked
            $Script:WAUInstallUserContext = $WAUInstallUserContextCheckBox.IsChecked
            Start-Installations
            $WAUCheckBox.IsChecked = $false
            $WAUConfGroupBox.IsEnabled = $false
            $WAUFreqGroupBox.IsEnabled = $false
            $WAUShortcutsGroupBox.IsEnabled = $false
            $WAUWhiteBlackGroupBox.IsEnabled = $false
            $AdvancedRunCheckBox.IsChecked = $false
            $UninstallViewCheckBox.IsChecked = $false
            $CMTraceCheckBox.IsChecked = $false
            $WAUInstallStatus = Get-WAUInstallStatus
            $WAUStatusLabel.Text = $WAUInstallStatus[0]
            $WAUStatusLabel.Foreground = $WAUInstallStatus[1]
        }
    )

    $CloseButton.add_click(
        {
            $WiguiForm.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
            $WiguiForm.Close()
        }
    )

    # Shows the form
    $Script:FormReturn = $WiGuiForm.ShowDialog()
}


<# MAIN #>

Start-PopUp "Starting..."

#Temp folder
$Script:Location = "$Env:ProgramData\WiGui"
#Create Temp folder
if (!(Test-Path $Location)) {
    New-Item -ItemType Directory -Force -Path $Location | Out-Null
}

#Load assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName PresentationFramework

#Set some variables
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ProgressPreference = "SilentlyContinue"
$Script:AppToInstall = $null
$Script:InstallWAU = $null
$IconBase64 = [Convert]::FromBase64String("AAABAAEAEBAAAAAAAABoBAAAFgAAACgAAAAQAAAAIAAAAAEAIAAAAAAAQAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAUKEUwPHjCLECAzkRAgM5EQIDORECAzkRAgM5EQIDORECAzkRAgM5EPHjCOBQoRXwAAABQAAAAAAAAAABUoPpAyYZv9NWaj/zVmpP81ZqT/NWak/zVmpP81ZqT/NWak/zVmpP81ZqT/NWaj/zJgmv0TJDmtAAAAFAkQGC01ZZ/9MGWh/yFfl/8oY5z/IV+X/y5loP81aKT/W4S1/8XKz/+5vcL/ub3C/7m9wv99lLH/KU56/QYKD1wgOVZcOGyn/zFpov8eX5X/Lmeg/x5flf8vaKH/OGyn/2GKuf+2trb/n5+f/5+fn/+Tk5P/Z3uS/ypTf/8QHi2LJURjXzpxqv85cKn/Kmie/zlxqv8raJ//OHCo/zpxqv9Tg7X/obbM/5uxxv+QobP/d4eX/1Z0kv8sVoL/EiEwjCdHZl88daz/PHWs/zx1rP88daz/PHWs/zx1rP88daz/PHWs/zx1rP82apv/LlqE/y5ZhP8uWYT/LlmE/xMjMosrTGpfPnqv/z56r/8+eq//Pnqv/z56r/8+eq//Pnqv/z56r/84bp7/L12G/y9dhv8vXYb/L12G/y9dhv8VJTSKL1FtX0B/sv9Af7L/QH+y/0B/sv9Af7L/QH+y/0B/sv86cqD/MWGI/zFhiP8xYYj/MWGI/zFhiP8xYYj/Fyc1iTNWcF9DhLX/Q4S1/0OEtf9DhLX/Q4S1/0OEtf88dqL/M2SK/zNkiv8zZIr/M2SK/zNkiv8zZIr/M2SK/xkqN4g4WnJfRYi3/0WIt/9FiLf/RYi3/0WIt/9Girj/U5i3/1edu/83a4//NWiM/zVojP81aIz/NWiM/zdulP8fNUSHPF91X0eNuv9Hjbr/R426/0eNuv9Hjbr/SI67/1igvv9cpsP/OW+R/zZsjv82bI7/NmyO/zlylv9Girb/IzpIhUBjd19Jkb3/SZG9/0mRvf9Jkb3/SZG9/0uTvf9Yob7/XafD/zpyk/84b5D/OG+Q/zt1mP9Ij7n/SZG9/yU8SoRHaHpbS5a//0uWv/9Llr//S5a//0uWv/9Nl8D/WaO//12oxP88dpX/OXOS/z15mv9Kk7v/S5a//0uWv/8oPUl9QFRfIVuixvtOm8L/TpvC/06bwv9Om8L/T5zC/1mkwP9eqcX/PXmX/z58nP9Ml77/TpvC/06bwv9ZoMT8ExkdPwAAAAB4obZsY6jK+0+dw/9OnMP/TpzD/1Cdw/9apMD/XqnF/0GBn/9Nmb//TpzD/0+dw/9hpcf8OlFchQAAAAIAAAAAAAAAAEpdZyFhfIlbYXyKX2F8il9ifYpfZX+JX2eBil9he4hfYnyKX2J8il9bc39cHiYqKQAAAAAAAAAAgAEAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAAAAAwAMAAA==")
$Script:stream = [System.IO.MemoryStream]::new($IconBase64, 0, $IconBase64.Length)

#Check if WiGui is uptodate
Get-WiGuiLatestVersion

#Check if Winget is installed, and install if not
Get-WingetStatus

#Get WinGet cmd
Get-WingetCmd

#Run WiGui
Start-InstallGUI

#Remove temp items
Remove-Item -Path $Location -Force -Recurse -ErrorAction SilentlyContinue
