#!/bin/bash
# Edit VPS: pick ONE, SEVERAL or ALL VPSs (same selection prompt everywhere),
# then use the same menu whatever the selection.
edit_vps_menu() {
  ask_vps_selection || return
  edit_selected_vps
}
