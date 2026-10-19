; rigflow Windows Installer — Inno Setup 6
; ==========================================
;
; Produces TWO outputs per build:
;   installer\Output\rigflow-Setup-<ver>.exe     ← full installer
;   installer\Output\rigflow-Portable-<ver>.zip  ← portable ZIP (no install)
;
; The portable ZIP is built by the GitHub Actions workflow via a separate
; PowerShell step; both end up in installer\Output\.
;
; Prerequisites:
;   • Inno Setup 6   https://jrsoftware.org/isinfo.php
;   • Binary already built:
;       cargo build --profile dist -p rigflow-client
;   • Run from the repo root:
;       "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer\rigflow-windows.iss
;   (or let the GitHub Actions workflow do it)

#define MyAppName      "rigflow"
#define MyAppVersion   "1.1.1"
#define MyAppPublisher "PE5JW"
#define MyAppURL       "https://github.com/pe5jw/rigflow"
#define MyAppExe       "rigflow-client.exe"
#define BinDir         "..\target\dist"
#define OutDir         "Output"

; ---------------------------------------------------------------------------
[Setup]
AppId={{RIGFLOW-HPSDR-CLIENT-PE5JW-2024}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}/issues
AppUpdatesURL={#MyAppURL}/releases

DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes

OutputDir={#OutDir}
OutputBaseFilename=rigflow-Setup-{#MyAppVersion}

; Per-user install — no UAC prompt needed
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

WizardStyle=modern
WizardSizePercent=120
; SetupIconFile=rigflow.ico   ; uncomment + add an .ico to use a custom icon

Compression=lzma2/ultra64
SolidCompression=yes
LZMANumFastBytes=273

VersionInfoVersion={#MyAppVersion}
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription={#MyAppName} — HPSDR / HermesLite2 SDR client

; ---------------------------------------------------------------------------
[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "dutch";   MessagesFile: "compiler:Languages\Dutch.isl"

; ---------------------------------------------------------------------------
[Tasks]
Name: "desktopicon"; \
  Description: "{cm:CreateDesktopIcon}"; \
  GroupDescription: "{cm:AdditionalIcons}"; \
  Flags: unchecked

; ---------------------------------------------------------------------------
[Files]
; Main binary
Source: "{#BinDir}\{#MyAppExe}"; \
  DestDir: "{app}"; \
  Flags: ignoreversion

; Docs
Source: "..\README.md";     DestDir: "{app}"; Flags: ignoreversion isreadme
Source: "..\LICENSE";       DestDir: "{app}"; Flags: ignoreversion
Source: "..\DISCLAIMER.md"; DestDir: "{app}"; Flags: ignoreversion

; ---------------------------------------------------------------------------
[Icons]
Name: "{group}\{#MyAppName}";            Filename: "{app}\{#MyAppExe}"
Name: "{group}\Uninstall {#MyAppName}";  Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}";      Filename: "{app}\{#MyAppExe}"; \
  Tasks: desktopicon

; ---------------------------------------------------------------------------
[Run]
; Launch after install
Filename: "{app}\{#MyAppExe}"; \
  Description: "{cm:LaunchProgram,{#StringChange(MyAppName,'&','&&')}}"; \
  Flags: nowait postinstall skipifsilent
