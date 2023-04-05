This script automates the process of detecting where OneDrive is installed (per-user or per-machine), finds the OneDriveSetup.exe file in the version specific folder, and then runs the correct uninstall command for the type of install. The "/allusers" command line parameter is used when doing a per-machine uninstall.

To do the same steps manually, you would identify where the OneDriveSetup.exe file exists and then run one of these commands (where ##.###.####.#### is the version number):
Per-User: 
%localappdata%\Microsoft\OneDrive\##.###.####.####\OneDriveSetup.exe /uninstall

Example:
%localappdata%\Microsoft\OneDrive\20.084.0426.0004\OneDriveSetup.exe /uninstall


Per-Machine:
C:\Program Files (x86)\Microsoft OneDrive\##.###.####.####\OneDriveSetup.exe /allusers /uninstall

Example:
C:\Program Files (x86)\Microsoft OneDrive\20.084.0426.0004\OneDriveSetup.exe /allusers /uninstall

