#!/usr/bin/env bash
# Diagnose the local password stack and set a password through a privileged,
# interactive passwd process. Password data is never accepted as an argument,
# read by this script, written to a file, or sent to the journal.

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=00-common.sh
source "$SCRIPT_DIR/00-common.sh"

ACCOUNT="$TARGET_USER"
DIAGNOSE_ONLY=0
REPAIR_PAM=0
REPORT_FILE=""
FAILURES=0
WARNINGS=0
readonly JOURNAL_TAG="ubuntuRicePack-password"
readonly LEGACY_POLICY_FILE="/etc/security/pwquality.conf.d/99-ubuntu-rice-pack-short-passwords.conf"

usage() {
    cat <<'USAGE'
Usage: 09-set-local-password.sh [options]

Options:
  --user NAME       Change this local account (default: current target user)
  --diagnose-only   Write diagnostics without opening a password prompt
  --repair-pam      Back up and regenerate Ubuntu's packaged common-* PAM
                    stack before diagnosing and changing the password
  --help            Show this help

The password prompt is owned directly by `sudo passwd NAME`. This lets root
bypass the existing-password check and Ubuntu's ordinary weak-password
rejection without weakening password policy for every user.

Use --repair-pam only when ordinary passwd produces duplicate current-password
prompts or "Authentication token manipulation error". It runs the Ubuntu
administrator tool `pam-auth-update --force` after making a separate backup.
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --user)
            ACCOUNT="${2:?Missing value for --user}"
            shift 2
            ;;
        --diagnose-only)
            DIAGNOSE_ONLY=1
            shift
            ;;
        --repair-pam)
            REPAIR_PAM=1
            shift
            ;;
        --help | -h)
            usage
            exit 0
            ;;
        *)
            fail "Unknown argument: $1"
            ;;
    esac
done

report_line() {
    local check="$1"
    local expected="$2"
    local actual="$3"
    local result="$4"

    printf '%s\t%s\t%s\t%s\n' \
        "$check" "$expected" "$actual" "$result" >>"$REPORT_FILE"
}

record_failure() {
    local check="$1"
    local expected="$2"
    local actual="$3"

    report_line "$check" "$expected" "$actual" FAIL
    warn "$check: expected $expected; got $actual"
    FAILURES=$((FAILURES + 1))
}

record_warning() {
    local check="$1"
    local expected="$2"
    local actual="$3"

    report_line "$check" "$expected" "$actual" WARN
    warn "$check: expected $expected; got $actual"
    WARNINGS=$((WARNINGS + 1))
}

journal_note() {
    local message="$1"

    if command -v logger >/dev/null 2>&1; then
        logger --tag "$JOURNAL_TAG" -- "$message" || true
    fi
}

repair_packaged_pam_stack() {
    local backup_dir="$STATE_DIR/backups/pam-$RUN_ID"
    local pam_files=(
        passwd
        common-auth
        common-account
        common-password
        common-session
        common-session-noninteractive
    )
    local available_files=()
    local name=""

    [[ "$REPAIR_PAM" == "1" ]] || return 0

    require_command pam-auth-update
    require_command tar

    for name in "${pam_files[@]}"; do
        if run_root test -f "/etc/pam.d/$name"; then
            available_files+=("$name")
        fi
    done

    ((${#available_files[@]} > 0)) ||
        fail "No packaged PAM files were available to back up."

    mkdir -p -- "$backup_dir"
    log "Backing up the current PAM stack to $backup_dir."
    run_root tar \
        -C /etc/pam.d \
        -cpf - \
        "${available_files[@]}" |
        tar -C "$backup_dir" -xpf -

    journal_note "regenerating packaged PAM stack after backup to $backup_dir"
    log "Regenerating Ubuntu's packaged PAM stack with pam-auth-update."
    if ! run_root env DEBIAN_FRONTEND=noninteractive pam-auth-update --force; then
        journal_note "pam-auth-update failed; original files remain in $backup_dir"
        fail "pam-auth-update failed. Original files are preserved in $backup_dir."
    fi

    printf '%s\n' \
        "PAM stack regenerated with: pam-auth-update --force" \
        "Original files copied from: /etc/pam.d" \
        "Created: $(date --iso-8601=seconds)" \
        >"$backup_dir/README.txt"

    log "PAM regeneration completed; the pre-repair copy remains at $backup_dir."
}

check_account() {
    local entry=""
    local status=""

    entry="$(getent passwd "$ACCOUNT" || true)"
    if [[ -z "$entry" ]]; then
        record_failure "local account" "present" "missing: $ACCOUNT"
        return
    fi
    report_line "local account" "present" "$ACCOUNT" PASS

    status="$(run_root passwd -S "$ACCOUNT" 2>/dev/null || true)"
    if [[ -n "$status" ]]; then
        report_line "password status" "readable" "$status" PASS
    else
        record_failure "password status" "readable" "unavailable"
    fi
}

check_root_filesystem() {
    local options=""

    options="$(findmnt -no OPTIONS / 2>/dev/null || true)"
    if [[ ",$options," == *,ro,* ]]; then
        record_failure "root filesystem" "writable" "$options"
    elif [[ -n "$options" ]]; then
        report_line "root filesystem" "writable" "$options" PASS
    else
        record_warning "root filesystem" "mount options readable" "unavailable"
    fi
}

check_account_database_file() {
    local path="$1"
    local file_class="$2"
    local actual_owner=""
    local actual_group=""
    local actual_mode=""

    if ! run_root test -f "$path"; then
        record_failure "$path" "regular file" "missing"
        return
    fi

    actual_owner="$(run_root stat -Lc '%U' "$path")"
    actual_group="$(run_root stat -Lc '%G' "$path")"
    actual_mode="$(run_root stat -Lc '%a' "$path")"

    if [[ "$actual_owner" != "root" ]]; then
        record_failure \
            "$path owner" \
            "root" \
            "$actual_owner:$actual_group"
        return
    fi

    if [[ "$file_class" == "public" ]]; then
        if [[ "$actual_group" == "root" && "$actual_mode" == "644" ]]; then
            report_line \
                "$path owner/mode" \
                "root:root 644" \
                "$actual_owner:$actual_group $actual_mode" \
                PASS
        else
            record_failure \
                "$path owner/mode" \
                "root:root 644" \
                "$actual_owner:$actual_group $actual_mode"
        fi
        return
    fi

    if [[ "$actual_mode" != "600" && "$actual_mode" != "640" ]]; then
        record_failure \
            "$path mode" \
            "600 or 640" \
            "$actual_mode"
        return
    fi

    if [[ "$actual_group" == "root" ||
        "$actual_group" == "shadow" ||
        "$actual_group" == "nogroup" ]]
    then
        report_line \
            "$path owner/mode" \
            "root:(root|shadow|nogroup) 600|640" \
            "$actual_owner:$actual_group $actual_mode" \
            PASS
    else
        record_warning \
            "$path group" \
            "root, shadow, or nogroup" \
            "$actual_group"
    fi
}

check_password_lock() {
    local owner=""
    local mode=""

    if ! run_root test -e /etc/.pwd.lock; then
        report_line \
            "/etc/.pwd.lock" \
            "absent or root-owned lock file" \
            "absent" \
            PASS
        return
    fi

    # shadow-utils normally keeps this file permanently and locks it while
    # updating the account databases. Presence is not evidence of a stale lock.
    owner="$(run_root stat -Lc '%U:%G' /etc/.pwd.lock)"
    mode="$(run_root stat -Lc '%a' /etc/.pwd.lock)"
    if [[ "$owner" == "root:root" &&
        ("$mode" == "600" || "$mode" == "640") ]]
    then
        report_line \
            "/etc/.pwd.lock" \
            "root:root mode 600|640" \
            "$owner $mode (normal persistent lock file)" \
            PASS
    else
        record_warning \
            "/etc/.pwd.lock owner/mode" \
            "root:root mode 600|640" \
            "$owner $mode"
    fi
}

check_passwd_binary() {
    local binary=""
    local owner=""
    local mode=""
    local mode_number=0
    local package=""

    binary="$(command -v passwd)"
    binary="$(readlink -f -- "$binary")"
    owner="$(stat -Lc '%U:%G' "$binary")"
    mode="$(stat -Lc '%a' "$binary")"
    mode_number=$((8#$mode))

    if [[ "$owner" == "root:root" &&
        $((mode_number & 04000)) -ne 0 &&
        -x "$binary" ]]
    then
        report_line \
            "passwd executable" \
            "root:root, executable, setuid" \
            "$binary $owner $mode" \
            PASS
    else
        # The helper below still invokes the program through sudo, but a
        # missing setuid bit explains why an ordinary `passwd` can authenticate
        # and then fail to update /etc/shadow.
        record_warning \
            "passwd executable" \
            "root:root, executable, setuid" \
            "$binary $owner $mode"
    fi

    if command -v dpkg-query >/dev/null 2>&1; then
        package="$(dpkg-query -S "$binary" 2>/dev/null | head -n 1 || true)"
        report_line \
            "passwd package owner" \
            "Ubuntu package" \
            "${package:-not found}" \
            "$([[ -n "$package" ]] && printf PASS || printf WARN)"
    fi
}

check_account_databases() {
    if command -v pwck >/dev/null 2>&1; then
        if run_root pwck -r -q >/dev/null 2>&1; then
            report_line "passwd/shadow consistency" "valid" "valid" PASS
        else
            record_failure "passwd/shadow consistency" "valid" "pwck failed"
        fi
    else
        record_warning "passwd/shadow consistency" "pwck available" "missing"
    fi

    if command -v grpck >/dev/null 2>&1; then
        if run_root grpck -r >/dev/null 2>&1; then
            report_line "group/gshadow consistency" "valid" "valid" PASS
        else
            record_failure "group/gshadow consistency" "valid" "grpck failed"
        fi
    else
        record_warning "group/gshadow consistency" "grpck available" "missing"
    fi
}

check_pam_stack() {
    local unix_count=0
    local unix_line=""
    local quality_root_enforced=""

    if [[ ! -r /etc/pam.d/passwd ]]; then
        record_failure "/etc/pam.d/passwd" "readable" "missing/unreadable"
    elif grep -Eq \
        '^[[:space:]]*@include[[:space:]]+common-password([[:space:]]|$)' \
        /etc/pam.d/passwd
    then
        report_line \
            "/etc/pam.d/passwd" \
            "includes common-password" \
            "yes" \
            PASS
    else
        record_failure \
            "/etc/pam.d/passwd" \
            "includes common-password" \
            "no"
    fi

    if [[ ! -r /etc/pam.d/common-password ]]; then
        record_failure "/etc/pam.d/common-password" "readable" "missing/unreadable"
        return
    fi

    unix_count="$(
        grep -Ec \
            '^[[:space:]]*password[[:space:]].*pam_unix\.so([[:space:]]|$)' \
            /etc/pam.d/common-password || true
    )"
    if [[ "$unix_count" -eq 1 ]]; then
        report_line "pam_unix password entries" "1" "$unix_count" PASS
    else
        record_failure "pam_unix password entries" "1" "$unix_count"
    fi

    unix_line="$(
        grep -E \
            '^[[:space:]]*password[[:space:]].*pam_unix\.so([[:space:]]|$)' \
            /etc/pam.d/common-password |
            head -n 1 || true
    )"
    report_line \
        "pam_unix configuration" \
        "single active entry" \
        "${unix_line:-missing}" \
        "$([[ -n "$unix_line" ]] && printf PASS || printf FAIL)"

    quality_root_enforced="$(
        {
            grep -Eh \
                '^[[:space:]]*enforce_for_root([[:space:]]|=|$)' \
                /etc/security/pwquality.conf \
                /etc/security/pwquality.conf.d/*.conf 2>/dev/null || true
            grep -E \
                '^[[:space:]]*password[[:space:]].*pam_pwquality\.so.*enforce_for_root' \
                /etc/pam.d/common-password 2>/dev/null || true
        } |
            head -n 1
    )"
    if [[ -n "$quality_root_enforced" ]]; then
        record_warning \
            "root password-quality enforcement" \
            "disabled for privileged reset" \
            "$quality_root_enforced"
    else
        report_line \
            "root password-quality enforcement" \
            "disabled for privileged reset" \
            "not configured" \
            PASS
    fi
}

remove_legacy_global_override() {
    if ! run_root test -e "$LEGACY_POLICY_FILE"; then
        report_line "legacy global pwquality override" "absent" "absent" PASS
        return
    fi

    # This exact file was created by an older ubuntuRicePack revision. It
    # weakened policy for every non-root user and is no longer needed.
    run_root rm -f -- "$LEGACY_POLICY_FILE"
    report_line \
        "legacy global pwquality override" \
        "absent" \
        "removed managed file" \
        PASS
    log "Removed the obsolete global pwquality override."
}

write_journal_excerpt() {
    local since="$1"
    local journal_file="${REPORT_FILE%.tsv}-journal.txt"

    if ! command -v journalctl >/dev/null 2>&1; then
        printf 'journalctl is unavailable\n' >"$journal_file"
        return
    fi

    {
        run_root journalctl \
            -b \
            --since "$since" \
            --no-pager \
            -o short-iso \
            _COMM=passwd 2>/dev/null || true
        run_root journalctl \
            -b \
            --since "$since" \
            --no-pager \
            -o short-iso \
            "SYSLOG_IDENTIFIER=$JOURNAL_TAG" 2>/dev/null || true
    } >"$journal_file"

    log "Password journal excerpt: $journal_file"
}

main() {
    local report_dir="$STATE_DIR/reports"
    local started_at=""
    local post_status=""

    require_normal_user
    require_ubuntu
    require_command getent
    require_command findmnt
    require_command passwd
    require_command readlink
    require_command stat
    sudo_validate

    mkdir -p -- "$report_dir"
    REPORT_FILE="$report_dir/password-$RUN_ID.tsv"
    printf 'check\texpected\tactual\tresult\n' >"$REPORT_FILE"
    started_at="$(date --iso-8601=seconds)"

    journal_note "starting local password diagnostics for account $ACCOUNT"
    check_account
    check_root_filesystem
    check_passwd_binary
    check_account_database_file /etc/passwd public
    check_account_database_file /etc/group public
    check_account_database_file /etc/shadow sensitive
    check_account_database_file /etc/gshadow sensitive
    check_password_lock
    check_account_databases
    repair_packaged_pam_stack
    check_pam_stack
    remove_legacy_global_override

    log "Password diagnostic report: $REPORT_FILE"

    if ((FAILURES > 0)); then
        journal_note "password diagnostics failed for $ACCOUNT ($FAILURES failures)"
        write_journal_excerpt "$started_at"
        fail "Password diagnostics found $FAILURES blocking problem(s); review $REPORT_FILE."
    fi

    if [[ "$DIAGNOSE_ONLY" == "1" ]]; then
        journal_note "password diagnostics passed for $ACCOUNT"
        log "Password diagnostics passed with $WARNINGS warning(s)."
        write_journal_excerpt "$started_at"
        return 0
    fi

    log "Opening root's interactive passwd prompt for $ACCOUNT."
    log "Enter the new password twice; no current-password prompt is expected."
    journal_note "opening privileged passwd prompt for account $ACCOUNT"

    if ! run_root passwd "$ACCOUNT"; then
        journal_note "privileged passwd failed for account $ACCOUNT"
        write_journal_excerpt "$started_at"
        fail "passwd failed. Review $REPORT_FILE and its journal excerpt."
    fi

    post_status="$(run_root passwd -S "$ACCOUNT" 2>/dev/null || true)"
    if [[ "$post_status" =~ ^[^[:space:]]+[[:space:]]+P([[:space:]]|$) ]]; then
        report_line "post-change password status" "P (usable)" "$post_status" PASS
    else
        journal_note "password status check failed after passwd for account $ACCOUNT"
        write_journal_excerpt "$started_at"
        fail "passwd returned success, but the account status is not usable: $post_status"
    fi
    journal_note "privileged passwd completed for account $ACCOUNT"
    write_journal_excerpt "$started_at"
    log "Password changed successfully for $ACCOUNT."
}

if [[ "${RICE_SOURCE_ONLY:-0}" != "1" ]]; then
    main "$@"
fi
