@setlocal enabledelayedexpansion
@echo off
cd /D "%~dp0"

set CURDIR=%~dp0
set DIRNAME=%~nx1
set PDFS=

for %%A in (%1\*.pdf) do (
	echo %%A
	call set PDFS=!PDFS! "%%A"
)

"C:\Program Files (x86)\PDFtk\bin\pdftk.exe" %PDFS% cat output "%CURDIR%\%DIRNAME%.pdf"
