#!/bin/bash
# VPSForge v1.0.0 — Edit VPS menu.

# Prompts for VPS selection and opens the VPS editing menu.
edit_vps_menu() {
  ask_vps_selection || return
  edit_selected_vps
}
