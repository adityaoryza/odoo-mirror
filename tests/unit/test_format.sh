#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2016  # the tests set globals read by the sourced modules; $ in single quotes is intended
# shellcheck source=../lib/bootstrap.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/bootstrap.sh"

assert_eq "00:00" "$(fmt_dur 0)" "fmt_dur: zero"
assert_eq "01:05" "$(fmt_dur 65)" "fmt_dur: minutes and seconds"
assert_eq "59:59" "$(fmt_dur 3599)" "fmt_dur: just under an hour"
assert_eq "1:01:01" "$(fmt_dur 3661)" "fmt_dur: hours"

assert_eq "0 B" "$(fmt_bytes 0)" "fmt_bytes: zero"
assert_eq "512 B" "$(fmt_bytes 512)" "fmt_bytes: bytes"
assert_eq "1.5 KB" "$(fmt_bytes 1536)" "fmt_bytes: kilobytes"
assert_eq "1.0 GB" "$(fmt_bytes 1073741824)" "fmt_bytes: gigabytes"

finish
