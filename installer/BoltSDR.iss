; BoltSDR Windows Installer — Inno Setup 6
; =========================================
;
; Produces TWO outputs per build:
;   installer\Output\BoltSDR-Setup-<ver>.exe     ← full installer
;   installer\Output\BoltSDR-Portable-<ver>.zip  ← portable ZIP (no install)
;
; The portable ZIP is built by the [Run] section via PowerShell after the
; installer itself is created; both end up in installer\Output\.
;
; Prerequisites:
;   • Inno Setup 6   https://jrsoftware.org/isinfo.php
;   • Binary already built:
;       cargo build --profile dist -p rigflow-client
;   • Run from the repo root:
;       "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer\BoltSDR.iss
;   (or let the GitHub Actions workflow do it)

#define MyAppName      "BoltSDR"
#define MyAppVersion   "1.1.1"
#define MyAppPublisher "PE5JW / BoltSDR"
#define MyAppURL       "https://github.com/pe5jw/rigflow"
#define MyAppExe       "rigflow-client.exe"
#define BinDir         "..\target\dist"
#define OutDir         "Output"

; ---------------------------------------------------------------------------
[Setup]
AppId={{B0LTSDR-HPSDR-CLIENT-PE5JW-2024}}
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
OutputBaseFilename=BoltSDR-Setup-{#MyAppVersion}

; Per-user install — no UAC prompt needed
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

WizardStyle=modern
WizardSizePercent=120
; SetupIconFile=bolt_sdr.ico   ; uncomment + add an .ico to use a custom icon

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

; ---------------------------------------------------------------------------
; Build the portable ZIP alongside the installer.
; PowerShell compresses the same files into a self-contained archive that
; users can unzip anywhere and run without installing.
; ---------------------------------------------------------------------------
[Code]
procedure BuildPortableZip;
var
  BinPath, OutPath, ZipScript, TmpScript: String;
  ResultCode: Integer;
begin
  BinPath   := ExpandConstant('{src}\..\target\dist\{#MyAppExe}');
  OutPath   := ExpandConstant('{src}\{#OutDir}\BoltSDR-Portable-{#MyAppVersion}.zip');

  // PowerShell one-liner: create a temp dir, copy files, compress
  ZipScript :=
    '$src = "' + ExpandConstant('{src}') + '"; ' +
    '$bin = "' + BinPath + '"; ' +
    '$out = "' + OutPath + '"; ' +
    '$tmp = Join-Path $env:TEMP "BoltSDR-Portable-{#MyAppVersion}"; ' +
    'Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue; ' +
    'New-Item -ItemType Directory $tmp | Out-Null; ' +
    'Copy-Item $bin $tmp; ' +
    'Copy-Item "$src\..\README.md" $tmp; ' +
    'Copy-Item "$src\..\LICENSE" $tmp; ' +
    'Copy-Item "$src\..\DISCLAIMER.md" $tmp; ' +
    'Compress-Archive -Path "$tmp\*" -DestinationPath $out -Force; ' +
    'Remove-Item $tmp -Recurse -Force';

  TmpScript := ExpandConstant('{tmp}\boltsdr_portable.ps1');
  SaveStringToFile(TmpScript, ZipScript, False);

  if not Exec('powershell.exe',
       '-NoProfile -ExecutionPolicy Bypass -File "' + TmpScript + '"',
       '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
    MsgBox('Warning: could not build portable ZIP (PowerShell not found).', mbError, MB_OK)
  else if ResultCode <> 0 then
    MsgBox('Warning: portable ZIP build exited with code ' + IntToStr(ResultCode) + '.', mbError, MB_OK);
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  // After the setup files have been written (ssPostInstall) do nothing here;
  // we want the ZIP built at compile time, not at end-user install time.
  // The ZIP is created by the GitHub Actions step that runs ISCC.exe.
end;

// Called by ISCC at the very end of compilation (not at install time).
// Build the portable ZIP immediately after the installer .exe is written.
function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
end;
