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

test_cursor_position() {
    # Test that cursor zstyle is read (can't test actual cursor movement without ZLE)
    local result
    result=$(zsh -c "
        zstyle ':zsh-jumper:' cursor end
        source $PLUGIN_DIR/zsh-jumper.plugin.zsh
        zstyle -s ':zsh-jumper:' cursor val && echo \$val
    " 2>&1)

    if [[ "$result" == "end" ]]; then
        test_pass "Cursor position config works"
    else
        test_fail "Cursor config not read" "Got: $result"
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

test_position_substring_bug() {
    # Test that -u at index 3 is found correctly, not inside --user
    local result
    result=$(zsh -c '
        emulate -L zsh
        BUFFER="journalctl --user -u service"
        words=(${(z)BUFFER})
        idx=3  # -u is 3rd word
        target="${words[$idx]}"

        pos=0 j=1 remaining="$BUFFER"
        while (( j < idx )); do
            wpos="${remaining[(i)${words[$j]}]}"
            (( pos += wpos + ${#words[$j]} - 1 ))
            remaining="${remaining:$((wpos + ${#words[$j]} - 1))}"
            (( j++ ))
        done
        (( pos += ${remaining[(i)$target]} - 1 ))
        echo $pos
    ' 2>&1)

    # -u starts at position 18 in "journalctl --user -u service"
    if [[ "$result" == "18" ]]; then
        test_pass "Position finds -u correctly (not inside --user)"
    else
        test_fail "Position bug: -u found at wrong position" "Expected: 18, Got: $result"
    fi
}

test_many_words() {
    # Test with 15 words - index extraction must handle double digits
    local result
    result=$(zsh -c '
        emulate -L zsh
        BUFFER="a b c d e f g h i j k l m n TARGET"
        words=(${(z)BUFFER})
        idx=15  # TARGET is 15th word
        target="${words[$idx]}"

        pos=0 j=1 remaining="$BUFFER"
        while (( j < idx )); do
            wpos="${remaining[(i)${words[$j]}]}"
            (( pos += wpos + ${#words[$j]} - 1 ))
            remaining="${remaining:$((wpos + ${#words[$j]} - 1))}"
            (( j++ ))
        done
        (( pos += ${remaining[(i)$target]} - 1 ))
        echo "$pos:$target"
    ' 2>&1)

    if [[ "$result" == "28:TARGET" ]]; then
        test_pass "Handles 15+ words correctly"
    else
        test_fail "Many words failed" "Expected: 28:TARGET, Got: $result"
    fi
}

test_special_chars() {
    # Test words with special characters
    local result
    result=$(zsh -c '
        emulate -L zsh
        BUFFER="echo \$HOME /path/to/file --opt=value"
        words=(${(z)BUFFER})
        idx=3  # /path/to/file is 3rd word
        target="${words[$idx]}"

        pos=0 j=1 remaining="$BUFFER"
        while (( j < idx )); do
            wpos="${remaining[(i)${words[$j]}]}"
            (( pos += wpos + ${#words[$j]} - 1 ))
            remaining="${remaining:$((wpos + ${#words[$j]} - 1))}"
            (( j++ ))
        done
        (( pos += ${remaining[(i)$target]} - 1 ))
        echo "$pos:$target"
    ' 2>&1)

    if [[ "$result" == "11:/path/to/file" ]]; then
        test_pass "Handles special chars correctly"
    else
        test_fail "Special chars failed" "Expected: 11:/path/to/file, Got: $result"
    fi
}

test_duplicate_words() {
    # Test duplicate words - should find correct occurrence by index
    local result
    result=$(zsh -c '
        emulate -L zsh
        BUFFER="echo test echo final"
        words=(${(z)BUFFER})
        idx=3  # second "echo" is 3rd word
        target="${words[$idx]}"

        pos=0 j=1 remaining="$BUFFER"
        while (( j < idx )); do
            wpos="${remaining[(i)${words[$j]}]}"
            (( pos += wpos + ${#words[$j]} - 1 ))
            remaining="${remaining:$((wpos + ${#words[$j]} - 1))}"
            (( j++ ))
        done
        (( pos += ${remaining[(i)$target]} - 1 ))
        echo $pos
    ' 2>&1)

    # Second "echo" starts at position 10 in "echo test echo final"
    if [[ "$result" == "10" ]]; then
        test_pass "Handles duplicate words correctly"
    else
        test_fail "Duplicate words failed" "Expected: 10, Got: $result"
    fi
}

test_numbered_format() {
    # Test that numbered format is correct
    local result
    result=$(zsh -c '
        emulate -L zsh
        words=("kubectl" "get" "pods")
        numbered=()
        for i in {1..${#words[@]}}; do
            numbered+=("$i: ${words[$i]}")
        done
        printf "%s\n" "${numbered[@]}"
    ' 2>&1)

    if [[ "$result" == *"1: kubectl"* ]] && [[ "$result" == *"2: get"* ]] && [[ "$result" == *"3: pods"* ]]; then
        test_pass "Numbered format correct"
    else
        test_fail "Numbered format wrong" "Got: $result"
    fi
}

test_index_extraction() {
    # Test extracting index from selection (handles double digits)
    local result
    result=$(zsh -c '
        selection="15: TARGET"
        idx="${selection%%:*}"
        echo $idx
    ' 2>&1)

    if [[ "$result" == "15" ]]; then
        test_pass "Index extraction handles double digits"
    else
        test_fail "Index extraction failed" "Expected: 15, Got: $result"
    fi
}

test_empty_buffer() {
    # Empty buffer should return early
    local result
    result=$(zsh -c '
        emulate -L zsh
        BUFFER=""
        words=(${=BUFFER})
        echo "${#words[@]}"
    ' 2>&1)

    if [[ "$result" == "0" ]]; then
        test_pass "Empty buffer handled"
    else
        test_fail "Empty buffer failed" "Expected: 0 words, Got: $result"
    fi
}

test_single_word() {
    # Single word buffer
    local result
    result=$(zsh -c '
        emulate -L zsh
        BUFFER="kubectl"
        words=(${=BUFFER})
        echo "${#words[@]}:${words[1]}"
    ' 2>&1)

    if [[ "$result" == "1:kubectl" ]]; then
        test_pass "Single word handled"
    else
        test_fail "Single word failed" "Got: $result"
    fi
}

test_only_spaces() {
    # Buffer with only spaces
    local result
    result=$(zsh -c '
        emulate -L zsh
        BUFFER="     "
        words=(${=BUFFER})
        echo "${#words[@]}"
    ' 2>&1)

    if [[ "$result" == "0" ]]; then
        test_pass "Only spaces handled"
    else
        test_fail "Only spaces failed" "Expected: 0, Got: $result"
    fi
}

test_unicode() {
    # Unicode characters
    local result
    result=$(zsh -c '
        emulate -L zsh
        BUFFER="echo 你好 мир 🚀 λ"
        words=(${=BUFFER})
        idx=4
        target="${words[$idx]}"
        echo "${#words[@]}:$target"
    ' 2>&1)

    if [[ "$result" == "5:🚀" ]]; then
        test_pass "Unicode handled"
    else
        test_fail "Unicode failed" "Expected: 5:🚀, Got: $result"
    fi
}

test_all_special_chars() {
    # All kinds of special characters
    local result
    result=$(zsh -c '
        emulate -L zsh
        BUFFER="!@#\$%^&*()_+-=[]{}|;:,.<>? \\\\ \`\` \"\" ~"
        words=(${=BUFFER})
        echo "${#words[@]}"
    ' 2>&1)

    # Should split into individual tokens
    if (( result >= 5 )); then
        test_pass "Special chars split correctly ($result words)"
    else
        test_fail "Special chars failed" "Got only $result words"
    fi
}

test_numbers() {
    # Numeric tokens
    local result
    result=$(zsh -c '
        emulate -L zsh
        BUFFER="123 456.789 0x1F -99 1e10"
        words=(${=BUFFER})
        idx=3
        target="${words[$idx]}"

        pos=0 j=1 remaining="$BUFFER"
        while (( j < idx )); do
            wpos="${remaining[(i)${words[$j]}]}"
            (( pos += wpos + ${#words[$j]} - 1 ))
            remaining="${remaining:$((wpos + ${#words[$j]} - 1))}"
            (( j++ ))
        done
        (( pos += ${remaining[(i)$target]} - 1 ))
        echo "$pos:$target"
    ' 2>&1)

    if [[ "$result" == "12:0x1F" ]]; then
        test_pass "Numbers handled"
    else
        test_fail "Numbers failed" "Expected: 12:0x1F, Got: $result"
    fi
}

test_long_buffer() {
    # Very long buffer (100 words)
    local result
    result=$(zsh -c '
        emulate -L zsh
        BUFFER=""
        for i in {1..100}; do BUFFER+="word$i "; done
        words=(${=BUFFER})
        idx=99
        target="${words[$idx]}"
        echo "${#words[@]}:$target"
    ' 2>&1)

    if [[ "$result" == "100:word99" ]]; then
        test_pass "Long buffer (100 words) handled"
    else
        test_fail "Long buffer failed" "Got: $result"
    fi
}

test_tabs_and_newlines() {
    # Tabs and mixed whitespace
    local result
    result=$(zsh -c '
        emulate -L zsh
        BUFFER=$'"'"'first\tsecond   third'"'"'
        words=(${=BUFFER})
        echo "${#words[@]}:${words[2]}"
    ' 2>&1)

    if [[ "$result" == "3:second" ]]; then
        test_pass "Tabs and whitespace handled"
    else
        test_fail "Tabs failed" "Got: $result"
    fi
}

test_quoted_strings() {
    # Quoted strings (not shell-parsed, just tokens)
    local result
    result=$(zsh -c '
        emulate -L zsh
        BUFFER="echo \"hello world\" done"
        words=(${=BUFFER})
        echo "${#words[@]}:${words[2]}:${words[3]}"
    ' 2>&1)

    # With whitespace split, quotes are just chars
    if [[ "$result" == '4:"hello:world"' ]]; then
        test_pass "Quoted strings split on whitespace"
    else
        test_fail "Quoted strings failed" "Got: $result"
    fi
}

test_pipes_and_redirects() {
    # Shell operators as separate tokens
    local result
    result=$(zsh -c '
        emulate -L zsh
        BUFFER="cat file | grep foo > out 2>&1"
        words=(${=BUFFER})
        echo "${#words[@]}"
    ' 2>&1)

    if [[ "$result" == "8" ]]; then
        test_pass "Pipes and redirects handled (8 tokens)"
    else
        test_fail "Pipes failed" "Expected: 8, Got: $result"
    fi
}

test_cyrillic() {
    # Cyrillic alphabet
    local result
    result=$(zsh -c '
        emulate -L zsh
        BUFFER="привет мир команда"
        words=(${=BUFFER})
        echo "${#words[@]}:${words[2]}"
    ' 2>&1)

    if [[ "$result" == "3:мир" ]]; then
        test_pass "Cyrillic handled"
    else
        test_fail "Cyrillic failed" "Got: $result"
    fi
}

test_chinese() {
    # Chinese characters
    local result
    result=$(zsh -c '
        emulate -L zsh
        BUFFER="你好 世界 测试"
        words=(${=BUFFER})
        echo "${#words[@]}:${words[3]}"
    ' 2>&1)

    if [[ "$result" == "3:测试" ]]; then
        test_pass "Chinese handled"
    else
        test_fail "Chinese failed" "Got: $result"
    fi
}

test_arabic() {
    # Arabic (RTL)
    local result
    result=$(zsh -c '
        emulate -L zsh
        BUFFER="مرحبا عالم اختبار"
        words=(${=BUFFER})
        echo "${#words[@]}:${words[1]}"
    ' 2>&1)

    if [[ "$result" == "3:مرحبا" ]]; then
        test_pass "Arabic handled"
    else
        test_fail "Arabic failed" "Got: $result"
    fi
}

test_japanese() {
    # Japanese (hiragana, katakana, kanji)
    local result
    result=$(zsh -c '
        emulate -L zsh
        BUFFER="こんにちは カタカナ 漢字"
        words=(${=BUFFER})
        echo "${#words[@]}:${words[2]}"
    ' 2>&1)

    if [[ "$result" == "3:カタカナ" ]]; then
        test_pass "Japanese handled"
    else
        test_fail "Japanese failed" "Got: $result"
    fi
}

test_korean() {
    # Korean hangul
    local result
    result=$(zsh -c '
        emulate -L zsh
        BUFFER="안녕하세요 세계 테스트"
        words=(${=BUFFER})
        echo "${#words[@]}:${words[2]}"
    ' 2>&1)

    if [[ "$result" == "3:세계" ]]; then
        test_pass "Korean handled"
    else
        test_fail "Korean failed" "Got: $result"
    fi
}

test_greek() {
    # Greek alphabet
    local result
    result=$(zsh -c '
        emulate -L zsh
        BUFFER="αλφα βητα γαμμα δελτα"
        words=(${=BUFFER})
        echo "${#words[@]}:${words[3]}"
    ' 2>&1)

    if [[ "$result" == "4:γαμμα" ]]; then
        test_pass "Greek handled"
    else
        test_fail "Greek failed" "Got: $result"
    fi
}

test_hebrew() {
    # Hebrew (RTL)
    local result
    result=$(zsh -c '
        emulate -L zsh
        BUFFER="שלום עולם בדיקה"
        words=(${=BUFFER})
        echo "${#words[@]}:${words[2]}"
    ' 2>&1)

    if [[ "$result" == "3:עולם" ]]; then
        test_pass "Hebrew handled"
    else
        test_fail "Hebrew failed" "Got: $result"
    fi
}

test_mixed_scripts() {
    # Mixed scripts in one buffer
    local result
    result=$(zsh -c '
        emulate -L zsh
        BUFFER="hello 你好 привет مرحبا 🎉"
        words=(${=BUFFER})
        idx=3
        target="${words[$idx]}"

        pos=0 j=1 remaining="$BUFFER"
        while (( j < idx )); do
            wpos="${remaining[(i)${words[$j]}]}"
            (( pos += wpos + ${#words[$j]} - 1 ))
            remaining="${remaining:$((wpos + ${#words[$j]} - 1))}"
            (( j++ ))
        done
        (( pos += ${remaining[(i)$target]} - 1 ))
        echo "$pos:$target"
    ' 2>&1)

    # "hello 你好 привет" - привет starts at 0-based position 9 (for CURSOR)
    if [[ "$result" == "9:привет" ]]; then
        test_pass "Mixed scripts position correct"
    else
        test_fail "Mixed scripts failed" "Got: $result"
    fi
}

test_emoji_sequence() {
    # Various emoji
    local result
    result=$(zsh -c '
        emulate -L zsh
        BUFFER="🚀 🎉 💻 🔥 ⭐"
        words=(${=BUFFER})
        echo "${#words[@]}:${words[4]}"
    ' 2>&1)

    if [[ "$result" == "5:🔥" ]]; then
        test_pass "Emoji sequence handled"
    else
        test_fail "Emoji failed" "Got: $result"
    fi
}

test_accented_latin() {
    # Accented Latin characters
    local result
    result=$(zsh -c '
        emulate -L zsh
        BUFFER="café naïve résumé piñata"
        words=(${=BUFFER})
        echo "${#words[@]}:${words[3]}"
    ' 2>&1)

    if [[ "$result" == "4:résumé" ]]; then
        test_pass "Accented Latin handled"
    else
        test_fail "Accented Latin failed" "Got: $result"
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
run_test test_cursor_position
run_test test_disable_bindings
run_test test_unload
run_test test_picker_pipe
run_test test_position_substring_bug
run_test test_many_words
run_test test_special_chars
run_test test_duplicate_words
run_test test_numbered_format
run_test test_index_extraction
run_test test_empty_buffer
run_test test_single_word
run_test test_only_spaces
run_test test_unicode
run_test test_all_special_chars
run_test test_numbers
run_test test_long_buffer
run_test test_tabs_and_newlines
run_test test_quoted_strings
run_test test_pipes_and_redirects
run_test test_cyrillic
run_test test_chinese
run_test test_arabic
run_test test_japanese
run_test test_korean
run_test test_greek
run_test test_hebrew
run_test test_mixed_scripts
run_test test_emoji_sequence
run_test test_accented_latin

print ""
local actual_tests=$((TESTS_RUN - TESTS_SKIPPED))
print "=== Results: $TESTS_PASSED/$actual_tests passed ($TESTS_SKIPPED skipped) ==="

[[ $TESTS_PASSED -eq $actual_tests ]]
