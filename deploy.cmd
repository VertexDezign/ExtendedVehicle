:: Mod to FS25 Mods Folder deployer
:: Author: Junie (based on John Deere 6930)

@echo off
echo Deploying Mod to FS25 ...

:: getting 7zip dir
set dir7Zip=%LOCALAPPDATA%\Microsoft\WindowsApps\NanaZipC.exe

:: getting name from current folder
for %%I in ("%~dp0.") do set modName=%%~nxI

:: setting packing directory (current directory)
set packDir=%~dp0
:: remove trailing backslash
if "%packDir:~-1%"=="\" set packDir=%packDir:~0,-1%

:: setting destination directory
set destDir=%USERPROFILE%\Documents\My Games\FarmingSimulator2025\mods

:: setting filename
set filename=%destDir%\%modName%.zip

:: setting FS25 executable path
set fs25Exe=G:\SteamLibrary\steamapps\common\Farming Simulator 25\FarmingSimulator2025.exe

:: check if 7zip is in default installation directory
IF not exist "%dir7Zip%" (
    echo.
    echo 7Zip/NanaZip not found in default installation directory! 
    echo Default: %dir7Zip%
    echo Please install NanaZip in default installation directory.
    echo %modName% deployment canceled!
    echo.
    
) ELSE (
    :: check if modDesc is available
    IF exist "%packDir%\modDesc.xml" (
    
        :: check if old modZip exists in destination
        if exist "%filename%" (
            echo.
            del "%filename%"
            echo Note: Old %modName%.zip in mods folder deleted!
        )

        :: packing mod directly to destination
        "%dir7Zip%" a "%filename%" "%packDir%\*" ^
            -xr!*.cmd -xr!*.zip -xr!*.yml -xr!$data ^
            -xr!*.blend ^
            -xr!.svn ^
            -xr!.editorconfig ^
            -xr!.git -xr!.gitattributes -xr!.gitignore ^
            -xr!.mayaSwatches -xr!*.mel -xr!*.mb -xr!*.ma ^
            -xr!substance ^
            -xr!*.obj -xr!*.fbx -xr!*.txt -xr!*.md ^
            -xr!*.png -xr!*.psd -xr!*.tga !*.png -xr!*.gim -xr!*.pdn ^
            -xr!.idea -xr!.vscode ^
            -xr!LICENSE 

        echo.
        echo Mod '%modName%' deployed successfully to %destDir%!
        echo.

        :: check if launch parameter is provided
        if /i "%1"=="launch" (
            if exist "%fs25Exe%" (
                echo Launching Farming Simulator 25...
                echo.
                start "" "%fs25Exe%"
            ) else (
                echo.
                echo FS25 executable not found at: %fs25Exe%
                echo Please check the path and try again.
                echo.
            )
        )
    ) ELSE (
        echo.
        echo %modName% has no modDesc.xml!
        echo %modName% deployment canceled!
        echo.
    )
)
