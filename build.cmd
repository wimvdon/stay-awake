@echo off
"%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe" /nologo /target:winexe /optimize+ /out:"%~dp0Stay awake.exe" /r:System.Windows.Forms.dll /r:System.Drawing.dll "%~dp0Stay awake.cs"
