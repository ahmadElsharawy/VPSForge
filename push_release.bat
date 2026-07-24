@echo off
git add -A
git commit -m "Initial Release v1.0.0"
git tag -f -a v1.0.0 -m "Release v1.0.0"
git push origin main v1.0.0
