@echo off
git add -A
git commit -m "VPSForge v1.0.0 — Initial stable release: Lightweight Incus-based VPS manager with BTRFS optimization"
git tag -a v1.0.0 -m "VPSForge v1.0.0 — Initial stable release"
git push origin main v1.0.0

