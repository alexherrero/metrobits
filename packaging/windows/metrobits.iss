; The Windows installer, built with Inno Setup by package.sh, which passes:
;   Version  the export presets' application/short_version
;   Source   the exported game, with its content beside it
;   License  EA's notice, then the GPL
;   Icon     the installer's icon, the app icon
;   Output   where Metrobits-<Version>-setup.exe goes
; It installs into Program Files, adds Metrobits to the Start menu and an
; uninstaller to Windows' list of installed apps, and opens on the same
; welcome and licence as the Mac installer. Saved cities and settings live in
; %APPDATA%\Metrobits, which uninstalling leaves alone.

[Setup]
AppId={{6F1C8E4A-5B2D-4E8F-9A3C-2D7B1E0F4C59}
AppName=Metrobits
AppVersion={#Version}
AppVerName=Metrobits {#Version}
AppPublisher=Metrobits
AppPublisherURL=https://github.com/alexherrero/metrobits
AppSupportURL=https://github.com/alexherrero/metrobits
AppCopyright=Built on Micropolis, Copyright (C) 1989 - 2007 Electronic Arts Inc.: a modified version, GPLv3 with additional terms.
VersionInfoVersion={#Version}
DefaultDirName={autopf}\Metrobits
DefaultGroupName=Metrobits
DisableProgramGroupPage=yes
DisableWelcomePage=no
LicenseFile={#License}
OutputDir={#Output}
OutputBaseFilename=Metrobits-{#Version}-setup
SetupIconFile={#Icon}
UninstallDisplayIcon={app}\Metrobits.exe
UninstallDisplayName=Metrobits
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern

[Messages]
WelcomeLabel1=Metrobits (built on Micropolis)
WelcomeLabel2=Metrobits is Micropolis, the city simulator first released in 1989, rebuilt to run on a modern PC with its original look and feel.%n%nThis installer puts Metrobits in your Program Files folder. Your saved cities and settings will live in your AppData folder, in a folder called Metrobits.%n%nMetrobits is a modified version of Micropolis. Electronic Arts and Micropolis GmbH don't make, endorse or support it.%n%nMicropolis is a registered trademark of Micropolis Corporation (Micropolis GmbH) and is licensed here as a courtesy of the owner under the Micropolis Public Name License.

[Files]
Source: "{#Source}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Metrobits"; Filename: "{app}\Metrobits.exe"

[Run]
Filename: "{app}\Metrobits.exe"; Description: "Play Metrobits"; Flags: nowait postinstall skipifsilent
