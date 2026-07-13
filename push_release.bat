@echo off
cd /d g:\x\VPSForge

git add vpsforge.sh README.md package.json push_release.bat
if not errorlevel 1 (
git commit -m "Bump version to v1.0.0" >nul 2>&1
)

git tag -f -a v1.0.0 -m "Release v1.0.0"
git push origin main --follow-tags
