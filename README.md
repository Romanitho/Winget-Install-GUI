<div align="center">

# Winget-Install-GUI (aka WiGui)
[![GitHub release (latest by date including pre-releases)](https://img.shields.io/github/v/release/Romanitho/Winget-Install-GUI?label=Latest%20version&style=flat-square)](https://github.com/Romanitho/Winget-Install-GUI/releases)
[![GitHub release (latest by date including pre-releases)](https://img.shields.io/github/downloads-pre/Romanitho/Winget-Install-GUI/latest/total?label=Downloads&style=flat-square)](https://github.com/Romanitho/Winget-Install-GUI/releases)

</div>

## Intro

GUI to search, select and install Apps at once with Winget package manager behind

<img src="https://user-images.githubusercontent.com/96626929/167912661-86014091-1d7c-478b-a836-421ec9f307a8.png" width="400"> <img src="https://user-images.githubusercontent.com/96626929/167912772-de5a55fe-68a8-44ed-91fb-fcf5b34d891f.png" width="400">

1. Download [latest](https://github.com/Romanitho/Winget-Install-GUI/releases/) `WiGui.exe` and run (Or run `Winget-Install-GUI.ps1` from sources directly, as WiGui.exe is not signed and can be untrusted from antivirus. Exe is built to simplify execution)
3. Search for an app, select your app in the droplist and submit it to the list. You can remove an app if wrong one submited.
4. Once the list is complete, click "Install" to launch the installations or "Save list to File" if you want to create app list that can be used with WAU for example
5. Optionally, you can install WAU in the same time.

## Functionalities

- Install Apps at Once
  - Search, add and install apps
  - Export/Import app list
- Install [WAU](https://github.com/Romanitho/Winget-AutoUpdate)
  - Install and configure WAU
  - Select Update frequency

![animation](https://user-images.githubusercontent.com/96626929/168034491-4dfe7ccd-55d7-4082-8bd7-e8b3d56d34f8.gif)


All In One GUI :)

## Install via Winget

WiGui is also on Winget:
`winget install Romanitho.WiGUI` (to default Winget portable location path)
or something like this:
`winget install wigui --location desktop`

<div align="center">

[![GitHub all releases](https://img.shields.io/github/downloads/Romanitho/Winget-Install-GUI/total?label=Total%20WiGui%20downloads&style=flat-square)](https://tooomm.github.io/github-release-stats/?username=Romanitho&repository=Winget-Install-GUI)

</div>
