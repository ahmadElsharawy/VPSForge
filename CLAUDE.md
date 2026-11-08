# VPSForge — contributor rules

VPSForge turns one VPS (Oracle, Google, any cloud) into many VPSs using Incus
containers. It is a Bash project that runs as root on Ubuntu; it cannot run on
Windows, so verify with the offline scripts below and test real behavior on a VPS.

## Code rules
- **One function per file.** The file is named after the function
  (`lib/core/vps/create_vps.sh` holds `create_vps`). Global variables go in a
  `<name>_globals.sh` file. `scripts/check.sh` rejects any `lib/` file with 2+ functions.
- Keep code easy for a stranger to read: short functions, a one-line comment above
  each function saying what it does, no clever one-liners.
- Never interpolate user input into `sh -c "..."` strings or `python3 -c "..."` code:
  pass values through `--env`, stdin, or `sys.argv`.
- Use POSIX awk only (Ubuntu's default awk is mawk: no 3-argument `match()`).
- Must work on the weakest hosts: avoid heavy loops over `incus` calls, prefer one
  `incus list --format json` over per-container queries, cache anything slow.
- The default root password stays `root` (owner's decision); users change it themselves.

## Checks (run before every commit)
```bash
bash scripts/check.sh          # bash -n on every script + one-function-per-file rule
bash scripts/check.sh --lint   # also shellcheck, if installed
bash scripts/test.sh           # offline unit tests for the pure-logic functions
```

## Layout (folders by topic, every function in its own file named after it)
- `vpsforge.sh` - entry point; `lib/load_vpsforge_lib.sh` (`load_vpsforge_lib`) sources every file under `lib/`, any depth.
- `lib/core/` - logic, one folder per topic:
  `common` (constants, helpers) | `vps/{create,guest,image,network,user,ssh_port,state,preserve,profile,reinstall,repair}` |
  `network/{host,ip,guest,ssh}` | `firewall/{rules,persistence,bulk,display,isolation,metadata}` |
  `resources/{cpu,ram,disk,network,traffic,host,allocation,device}` | `selection/` | `setup/{install,storage,compat,kernel,update,preinstall}` |
  `proxy/caddy` | `backups/` | `incus/` (pin, health check, selftest) | `uninstall/`
- `lib/dashboard/` - numbered menus matching the main-menu options (each topic has `menu/`, actions in subfolders).
- `scripts/` - `check.sh`, `test.sh` (offline), `e2e.sh` and `space-test.sh` (run on a real VPS as root).

## Rules that every feature must follow
- Long operations run through `run_guarded "<cleanup command>" <steps>`: failure or interruption cleans up everything and shows the reason.
- Every prompt offers the last answer as its default (`pref_get` / `pref_set`); `0` goes back one step (`run_wizard`, `WIZARD_BACK`).
- Test with `scripts/test.sh` (offline) and, on a server, `scripts/e2e.sh` and `scripts/ui-test.py` (use `UI_TEST_SAFE=1` where real VPSs exist).

## Clean-host promise
Deleting a VPS removes its snapshots, offers to delete its backups, and returns freed space to the real disk
(`reclaim_pool_space`, also weekly via cron). `vpsforge uninstall` puts the server back as it was
(uses the record in `/opt/vpsforge/.pre_install`). New features must keep this promise.
