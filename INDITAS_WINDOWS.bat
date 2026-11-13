@echo off
cd /d "%~dp0"
dotnet run --project "Vaganymester\Vaganymester.csproj"
if errorlevel 1 (
  echo.
  echo Nem sikerult elinditani. Telepitsd a .NET 8 SDK-t es a WPF-t tamogato Visual Studiot.
  pause
)
