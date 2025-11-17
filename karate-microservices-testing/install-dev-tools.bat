@echo off
setlocal enabledelayedexpansion

where winget >nul 2>&1
if %ERRORLEVEL% EQU 0 (
  winget install --id EclipseAdoptium.Temurin.21.JDK --source winget --silent --accept-source-agreements --accept-package-agreements
  winget install --id Git.Git --source winget --silent --accept-source-agreements --accept-package-agreements
  winget install --id Gradle.Gradle --source winget --silent --accept-source-agreements --accept-package-agreements
  winget install --id OpenJS.NodeJS.LTS --source winget --silent --accept-source-agreements --accept-package-agreements
  exit /b 0
)

where choco >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol=[System.Net.SecurityProtocolType]'Tls12'; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))"
)

where choco >nul 2>&1
if %ERRORLEVEL% EQU 0 (
  choco install temurin21 -y
  choco install git -y
  choco install gradle -y
  choco install nodejs-lts -y
  exit /b 0
)

exit /b 1