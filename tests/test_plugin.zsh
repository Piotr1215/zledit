#!/usr/bin/env zsh
# Test suite for zsh-jumper
# Run: zsh tests/test_plugin.zsh

emulate -L zsh

SCRIPT_DIR="${0:A:h}"
PLUGIN_DIR="${SCRIPT_DIR:h}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

typeset -gi TESTS_RUN=0
typeset -gi TESTS_PASSED=0
typeset -gi TESTS_SKIPPED=0

test_pass() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    print "${GREEN}✓${NC} $1"
}

test_fail() {
    print "${RED}✗${NC} $1"
    [[ -n "$2" ]] && print "  $2"
}

run_test() {
    TESTS_RUN=$((TESTS_RUN + 1))
    "$@"
}

skip_test() {
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
    print -- "- Skipping: $1"
}

# ------------------------------------------------------------------------------
# Tests
# ------------------------------------------------------------------------------

test_plugin_loads() {
    # Run in subshell, capture exit code
    zsh -c "source $PLUGIN_DIR/zsh-jumper.plugin.zsh" >/dev/null 2>&1
    if [[ $? -eq 0 ]]; then
        test_pass "Plugin loads without errors"
    else
        test_fail "Plugin fails to load" ""
    fi
}

test_functions_defined() {
    local result
    result=$(zsh -c "
        source $PLUGIN_DIR/zsh-jumper.plugin.zsh
        (( \$+functions[zsh-jumper-widget] )) || exit 1
        (( \$+functions[_zsh_jumper_detect_picker] )) || exit 1
        (( \$+functions[_zsh_jumper_get_picker_opts] )) || exit 1
        (( \$+functions[zsh-jumper-setup-bindings] )) || exit 1
        (( \$+functions[zsh-jumper-unload] )) || exit 1
    " 2>&1)
    if [[ $? -eq 0 ]]; then
        test_pass "All functions defined"
    else
        test_fail "Missing function definitions" "$result"
    fi
}

test_global_state() {
    local result
    result=$(zsh -c "
        source $PLUGIN_DIR/zsh-jumper.plugin.zsh
        [[ -n \"\${ZshJumper[dir]}\" ]] || exit 1
    " 2>&1)
    if [[ $? -eq 0 ]]; then
        test_pass "Global state initialized"
    else
        test_fail "Global state not set" "$result"
    fi
}

test_picker_detection_fzf() {
    if ! (( $+commands[fzf] )); then
        skip_test "fzf not installed"
        return 0
    fi

    local picker
    picker=$(zsh -c "
        source $PLUGIN_DIR/zsh-jumper.plugin.zsh
        _zsh_jumper_detect_picker
    " 2>&1)

    if [[ "$picker" == fzf* ]]; then
        test_pass "Detects fzf picker: $picker"
    else
        test_fail "Failed to detect fzf" "Got: $picker"
    fi
}

test_picker_detection_sk() {
    if ! (( $+commands[sk] )); then
        skip_test "sk not installed"
        return 0
    fi

    local picker
    picker=$(zsh -c "
        source $PLUGIN_DIR/zsh-jumper.plugin.zsh
        _zsh_jumper_detect_picker
    " 2>&1)

    if [[ -n "$picker" ]]; then
        test_pass "Picker detected (sk available): $picker"
    else
        test_fail "No picker detected" ""
    fi
}

test_picker_detection_peco() {
    if ! (( $+commands[peco] )); then
        skip_test "peco not installed"
        return 0
    fi

    local picker
    picker=$(zsh -c "
        source $PLUGIN_DIR/zsh-jumper.plugin.zsh
        _zsh_jumper_detect_picker
    " 2>&1)

    if [[ -n "$picker" ]]; then
        test_pass "Picker detected (peco available): $picker"
    else
        test_fail "No picker detected" ""
    fi
}

test_zstyle_picker_override() {
    if ! (( $+commands[fzf] )); then
        skip_test "zstyle override (fzf not installed)"
        return 0
    fi

    local picker
    picker=$(zsh -c "
        zstyle ':zsh-jumper:' picker fzf
        source $PLUGIN_DIR/zsh-jumper.plugin.zsh
        _zsh_jumper_detect_picker
    " 2>&1)

    if [[ "$picker" == "fzf" ]]; then
        test_pass "zstyle picker override works"
    else
        test_fail "zstyle override failed" "Expected: fzf, Got: $picker"
    fi
}

test_picker_opts_default() {
    local opts
    opts=$(zsh -c "
        source $PLUGIN_DIR/zsh-jumper.plugin.zsh
        _zsh_jumper_get_picker_opts fzf
    " 2>&1)

    if [[ "$opts" == *"--height"* ]] && [[ "$opts" == *"--reverse"* ]]; then
        test_pass "Default picker opts set for fzf"
    else
        test_fail "Default opts missing" "Got: $opts"
    fi
}

test_picker_opts_custom() {
    local opts
    opts=$(zsh -c "
        zstyle ':zsh-jumper:' picker-opts '--custom-opt'
        source $PLUGIN_DIR/zsh-jumper.plugin.zsh
        _zsh_jumper_get_picker_opts fzf
    " 2>&1)

    if [[ "$opts" == "--custom-opt" ]]; then
        test_pass "Custom picker opts override"
    else
        test_fail "Custom opts not applied" "Got: $opts"
    fi
}

test_disable_bindings() {
    local bound
    bound=$(zsh -c "
        zstyle ':zsh-jumper:' disable-bindings yes
        source $PLUGIN_DIR/zsh-jumper.plugin.zsh
        bindkey -L | grep -c 'zsh-jumper-widget' || true
    " 2>&1)
    # Remove any non-numeric chars (stderr noise)
    bound="${bound//[^0-9]/}"
    bound="${bound:-0}"

    if [[ "$bound" == "0" ]]; then
        test_pass "disable-bindings prevents keybinding"
    else
        test_fail "Binding still set despite disable-bindings" "Count: $bound"
    fi
}

test_unload() {
    local result
    result=$(zsh -c "
        source $PLUGIN_DIR/zsh-jumper.plugin.zsh
        zsh-jumper-unload
        (( \$+functions[zsh-jumper-widget] )) && exit 1
        exit 0
    " 2>&1)
    if [[ $? -eq 0 ]]; then
        test_pass "Unload removes functions"
    else
        test_fail "Unload failed to clean up" "$result"
    fi
}

test_picker_pipe() {
    local picker
    picker=$(zsh -c "
        source $PLUGIN_DIR/zsh-jumper.plugin.zsh
        _zsh_jumper_detect_picker
    " 2>&1)

    if [[ -z "$picker" ]]; then
        skip_test "pipe test (no picker)"
        return 0
    fi

    local result
    case "$picker" in
        fzf|fzf-tmux)
            result=$(print -l foo bar baz | fzf --filter="foo" --no-sort 2>/dev/null | head -1)
            ;;
        sk)
            result=$(print -l foo bar baz | sk --filter="foo" --no-sort 2>/dev/null | head -1)
            ;;
        peco)
            skip_test "pipe test for peco (no filter mode)"
            return 0
            ;;
        *)
            skip_test "pipe test for $picker"
            return 0
            ;;
    esac

    if [[ "$result" == "foo" ]]; then
        test_pass "Picker pipe works ($picker)"
    else
        test_fail "Picker pipe failed" "Expected: foo, Got: $result"
    fi
}

# ------------------------------------------------------------------------------
# Run tests
# ------------------------------------------------------------------------------

print "=== zsh-jumper test suite ==="
print ""

run_test test_plugin_loads
run_test test_functions_defined
run_test test_global_state
run_test test_picker_detection_fzf
run_test test_picker_detection_sk
run_test test_picker_detection_peco
run_test test_zstyle_picker_override
run_test test_picker_opts_default
run_test test_picker_opts_custom
run_test test_disable_bindings
run_test test_unload
run_test test_picker_pipe

print ""
local actual_tests=$((TESTS_RUN - TESTS_SKIPPED))
print "=== Results: $TESTS_PASSED/$actual_tests passed ($TESTS_SKIPPED skipped) ==="

[[ $TESTS_PASSED -eq $actual_tests ]]
