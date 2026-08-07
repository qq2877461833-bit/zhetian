@echo off
title Zhetian - Deploy to GitHub Pages
echo ==========================================
echo   ZheTian - Deploy to GitHub Pages
echo   Repo: https://github.com/qq2877461833-bit/zhetian
echo ==========================================
cd /d "%~dp0"

set "GIT=C:\Users\yanglimei\.workbuddy\vendor\PortableGit\cmd\git.exe"
set "GODOT=C:\Users\yanglimei\Desktop\Godot_v4.4-stable_win64.exe"

echo.
echo [0/4] Configuring remote...
"%GIT%" remote remove origin 2>nul
"%GIT%" remote add origin https://github.com/qq2877461833-bit/zhetian.git
echo.

echo [1/5] Switching to master branch (FIX)...
"%GIT%" checkout master 2>nul
"%GIT%" checkout -f master
"%GIT%" branch -D gh-pages 2>nul
"%GIT%" branch -D gh-pages-tmp 2>nul
echo   current branch: 
"%GIT%" branch --show-current
echo.

echo [2/5] Exporting Web build via Godot...
"%GODOT%" --headless --path "." --export-release "Web" "build\web\index.html"
if errorlevel 1 ( echo EXPORT FAILED & pause & exit /b 1 )
echo.

echo [3/5] Committing main branch...
"%GIT%" add -A
"%GIT%" -c user.name="Yoan Summit" -c user.email="studio@zhetian.local" commit -m "update build"
"%GIT%" push -u origin master
echo.

echo [4/5] Publishing build/web to gh-pages...
"%GIT%" subtree split --prefix build/web -b gh-pages-tmp
"%GIT%" push -f origin gh-pages-tmp:gh-pages
"%GIT%" branch -D gh-pages-tmp
echo.

echo ==========================================
echo   DEPLOY DONE! Wait 1-2 min for GitHub Pages build
echo   URL: https://qq2877461833-bit.github.io/zhetian/index.html
echo   If blank: Repo Settings - Pages - Branch: gh-pages
echo ==========================================
pause
