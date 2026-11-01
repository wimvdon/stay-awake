@echo off
"%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe" /nologo /target:winexe /optimize+ /out:"%~dp0Stay Awake.exe" /win32icon:"%~dp0icon.ico" /resource:"%~dp0icon.ico",icon.ico /resource:"%~dp0icon-idle.ico",icon-idle.ico /r:System.Windows.Forms.dll /r:System.Drawing.dll "%~dp0Stay Awake.cs"
