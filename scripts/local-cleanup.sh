#!/bin/bash
# Keep the gitignored .local/ workspace inside a size budget.
#
# .local/artifacts/<task-id>/ accumulates one .xcresult bundle per UI test run.
# Each bundle embeds a ~98MB simulator log archive, so a heavy verification
# round can add several GB per day. This script enforces a retention policy and
# reports what is reclaimable. It never touches .local/postgres-hub, .local/logs
# or any non-.xcresult evidence (screenshots, motion clips, logs).
#
# Usage:
#   local-cleanup.sh                 # dry-run: show what would be removed
#   local-cleanup.sh --apply         # delete old bundles, hardlink duplicate images
#   local-cleanup.sh --derived       # also remove .local/DerivedData build caches
#   local-cleanup.sh --check         # exit 1 when artifacts exceed the budget
#   local-cleanup.sh --no-dedupe     # skip the duplicate-image hardlinking pass
#
# Options:
#   --keep N         newest .xcresult kept per task directory (default 2)
#   --budget-mb N    target ceiling for .local/artifacts in MB (default 3072)
#
# Verification rounds often copy the same screenshot set into several sibling
# directories. Byte-identical images are replaced with hardlinks so every path
# keeps working while the duplicate blocks are released; content is never
# changed and nothing is deleted by this pass.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCAL="$ROOT/.local"
ARTIFACTS="$LOCAL/artifacts"
DERIVED="$LOCAL/DerivedData"

APPLY=0
CHECK=0
DERIVED_CLEAN=0
DEDUPE=1
KEEP=2
BUDGET_MB=3072
BACKUPS_DAYS=7

while [ $# -gt 0 ]; do
  case "$1" in
    --apply) APPLY=1 ;;
    --check) CHECK=1 ;;
    --derived) DERIVED_CLEAN=1 ;;
    --no-dedupe) DEDUPE=0 ;;
    --keep) KEEP="${2:?--keep needs a number}"; shift ;;
    --budget-mb) BUDGET_MB="${2:?--budget-mb needs a number}"; shift ;;
    -h|--help) sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

[ -d "$LOCAL" ] || { echo "no .local/ in $ROOT (nothing to clean)"; exit 0; }

# Refuse to operate if .local resolves outside the repository.
LOCAL_REAL="$(cd "$LOCAL" && pwd -P)"
ROOT_REAL="$(cd "$ROOT" && pwd -P)"
case "$LOCAL_REAL" in
  "$ROOT_REAL"/.local) ;;
  *) echo "refusing: $LOCAL_REAL is not $ROOT_REAL/.local" >&2; exit 2 ;;
esac

if [ "$APPLY" -eq 1 ]; then MODE="apply"; else MODE="dry-run"; fi
echo "Doki .local cleanup ($MODE)"
echo "  keep per task : $KEEP newest .xcresult"
echo "  budget        : ${BUDGET_MB} MB for .local/artifacts"
echo

removed_kb=0
removed_count=0
batch_rows=""

# Measure before deleting, otherwise the "after" figure double-counts the drop.
artifacts_start_kb=0
if [ -d "$ARTIFACTS" ]; then
  artifacts_start_kb=$(du -sk "$ARTIFACTS" 2>/dev/null | cut -f1)
  artifacts_start_kb=${artifacts_start_kb:-0}
fi

if [ -d "$ARTIFACTS" ]; then
  for dir in "$ARTIFACTS"/*/; do
    [ -d "$dir" ] || continue
    name="$(basename "$dir")"
    total=$(find "$dir" -maxdepth 1 -name '*.xcresult' -type d 2>/dev/null | wc -l | tr -d ' ')
    [ "$total" -eq 0 ] && continue
    [ "$total" -le "$KEEP" ] && continue

    # Oldest-first list, then everything after the keep window.
    drop="$(ls -1dt "$dir"*.xcresult 2>/dev/null | tail -n "+$((KEEP + 1))")"
    [ -z "$drop" ] && continue

    drop_count=0
    drop_kb=0
    while IFS= read -r bundle; do
      [ -n "$bundle" ] || continue
      [ -d "$bundle" ] || continue
      kb=$(du -sk "$bundle" 2>/dev/null | cut -f1)
      kb=${kb:-0}
      drop_count=$((drop_count + 1))
      drop_kb=$((drop_kb + kb))
      if [ "$APPLY" -eq 1 ]; then rm -rf -- "$bundle"; fi
    done <<EOF
$drop
EOF

    removed_kb=$((removed_kb + drop_kb))
    removed_count=$((removed_count + drop_count))
    batch_rows="${batch_rows}$(printf '  %-14s %4s bundles, drop %4s (%s MB)' \
      "$name" "$total" "$drop_count" "$((drop_kb / 1024))")
"
  done
fi

if [ -n "$batch_rows" ]; then
  echo "Per task directory:"
  printf '%s' "$batch_rows"
else
  echo "Per task directory: nothing over the keep window."
fi
echo

# ---------------------------------------------------------------- budget pass
if [ -d "$ARTIFACTS" ]; then
  artifacts_kb=$artifacts_start_kb
  budget_kb=$((BUDGET_MB * 1024))
  after_kb=$((artifacts_kb - removed_kb))

  echo "artifacts size: $((artifacts_kb / 1024)) MB now, $((after_kb / 1024)) MB after retention"

  if [ "$after_kb" -gt "$budget_kb" ]; then
    echo "  over budget by $(((after_kb - budget_kb) / 1024)) MB, evicting oldest bundles"
    oldest_first="$(ls -1dtr "$ARTIFACTS"/*/*.xcresult 2>/dev/null)"
    evicted=0
    while IFS= read -r bundle; do
      [ -n "$bundle" ] || continue
      [ "$after_kb" -le "$budget_kb" ] && break
      [ -d "$bundle" ] || continue
      kb=$(du -sk "$bundle" 2>/dev/null | cut -f1)
      kb=${kb:-0}
      if [ "$APPLY" -eq 1 ]; then rm -rf -- "$bundle"; fi
      after_kb=$((after_kb - kb))
      removed_kb=$((removed_kb + kb))
      removed_count=$((removed_count + 1))
      evicted=$((evicted + 1))
    done <<EOF
$oldest_first
EOF
    echo "  evicted $evicted more bundle(s); est. remaining $((after_kb / 1024)) MB"
    if [ "$APPLY" -eq 0 ]; then
      echo "  note: dry-run sizes are estimates; non-.xcresult evidence is never evicted"
    fi
  else
    echo "  within budget"
  fi
  echo
fi

# ------------------------------------------------------------------ dedupe
# Verification rounds re-copy the same screenshot set into several sibling
# directories (FIX7-screens, FIX7-attachments, evidence-screens-final, ...).
# Byte-identical images are replaced with hardlinks: every path still opens,
# the content is unchanged, and the duplicate blocks are released.
if [ "$DEDUPE" -eq 1 ] && [ -d "$ARTIFACTS" ]; then
  hash_file="$(mktemp "${TMPDIR:-/tmp}/doki-dedupe.XXXXXX")"
  trap 'rm -f "$hash_file"' EXIT
  find "$ARTIFACTS" -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' \) \
    ! -path '*.xcresult/*' -print0 2>/dev/null |
  while IFS= read -r -d '' img; do
    h=$(md5 -q "$img" 2>/dev/null) || continue
    printf '%s\t%s\n' "$h" "$img" >> "$hash_file"
  done

  dup_kb=0
  dup_count=0
  prev_hash=""
  keeper=""
  while IFS=$'\t' read -r h img; do
    [ -n "$h" ] || continue
    if [ "$h" = "$prev_hash" ]; then
      # Already the same inode from an earlier run: nothing to reclaim, so the
      # pass stays idempotent and reports zero the second time.
      same_inode=0
      if [ -n "$keeper" ]; then
        ki=$(stat -f%i "$keeper" 2>/dev/null)
        ii=$(stat -f%i "$img" 2>/dev/null)
        [ -n "$ki" ] && [ "$ki" = "$ii" ] && same_inode=1
      fi
      [ "$same_inode" -eq 1 ] && continue
      kb=$(du -sk "$img" 2>/dev/null | cut -f1)
      kb=${kb:-0}
      dup_kb=$((dup_kb + kb))
      dup_count=$((dup_count + 1))
      if [ "$APPLY" -eq 1 ] && [ -n "$keeper" ]; then
        ln -f -- "$keeper" "$img" 2>/dev/null || true
      fi
    else
      prev_hash="$h"
      keeper="$img"
    fi
  done <<EOF
$(sort "$hash_file" 2>/dev/null)
EOF

  rm -f "$hash_file"
  trap - EXIT

  if [ "$dup_count" -gt 0 ]; then
    if [ "$APPLY" -eq 1 ]; then
      echo "deduped: $dup_count byte-identical image(s) hardlinked, $((dup_kb / 1024)) MB released"
    else
      echo "dedupe: $dup_count byte-identical image(s) could be hardlinked, $((dup_kb / 1024)) MB"
      removed_kb=$((removed_kb + dup_kb))
    fi
    echo
  fi
fi

# ------------------------------------------------------------ derived data
if [ -d "$DERIVED" ]; then
  derived_kb=$(du -sk "$DERIVED" 2>/dev/null | cut -f1)
  derived_kb=${derived_kb:-0}
  if [ "$DERIVED_CLEAN" -eq 1 ]; then
    if [ "$APPLY" -eq 1 ]; then
      rm -rf -- "$DERIVED"
      echo "removed .local/DerivedData ($((derived_kb / 1024)) MB), it rebuilds on next xcodebuild"
    else
      echo "would remove .local/DerivedData ($((derived_kb / 1024)) MB)"
      removed_kb=$((removed_kb + derived_kb))
    fi
  else
    echo "kept .local/DerivedData ($((derived_kb / 1024)) MB); pass --derived to drop it"
  fi
  echo
fi

# ------------------------------------------------------------ stale backups
if [ -d "$LOCAL/backups" ]; then
  stale_kb=$(find "$LOCAL/backups" -type f -mtime "+$BACKUPS_DAYS" 2>/dev/null | tr '\n' '\0' | xargs -0 du -ck 2>/dev/null | tail -1 | cut -f1)
  stale_kb=${stale_kb:-0}
  if [ "$stale_kb" -gt 0 ]; then
    echo "note: $((stale_kb / 1024)) MB of .local/backups is older than ${BACKUPS_DAYS}d; review before deleting"
    echo
  fi
fi

if [ "$APPLY" -eq 1 ]; then
  echo "reclaimed: $((removed_kb / 1024)) MB across $removed_count .xcresult bundle(s)"
else
  echo "reclaimable: $((removed_kb / 1024)) MB across $removed_count .xcresult bundle(s)"
fi
if [ "$APPLY" -eq 1 ]; then
  echo "done. free space:"
  df -h /System/Volumes/Data 2>/dev/null | tail -1 | awk '{print "  used " $3 ", avail " $4 " (" $5 ")"}'
else
  echo "dry-run only; re-run with --apply to delete"
fi

if [ "$CHECK" -eq 1 ] && [ -d "$ARTIFACTS" ]; then
  final_kb=$(du -sk "$ARTIFACTS" 2>/dev/null | cut -f1)
  final_kb=${final_kb:-0}
  if [ "$final_kb" -gt $((BUDGET_MB * 1024)) ]; then
    echo "check failed: .local/artifacts is $((final_kb / 1024)) MB > ${BUDGET_MB} MB" >&2
    exit 1
  fi
fi
