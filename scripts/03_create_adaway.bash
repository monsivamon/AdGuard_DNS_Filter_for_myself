#!/bin/bash
set -e

# 各種変数の設定
OUTPUT_FILE="Filters/converted_for_adaway.txt"
WORK_DIR="Filters/tmp_adaway_dir"

# 1. 作業環境の準備
mkdir -p "$WORK_DIR"
cp Filters/main_filter.txt "$WORK_DIR/main_filter.txt"

curl -sSL https://publicsuffix.org/list/public_suffix_list.dat -o "$WORK_DIR/public_suffix_list.dat" || true

if [[ ! -e "$WORK_DIR/public_suffix_list.dat" ]]; then
  echo "download failed" >&2
  exit 1
fi

# 2. 誤爆ドメインの除外用ホワイトリスト作成
awk '!/^\/\// && NF' "$WORK_DIR/public_suffix_list.dat" > "$WORK_DIR/tld_rules.txt"

awk -v tld_file="$WORK_DIR/tld_rules.txt" '
BEGIN {
  while ((getline line < tld_file) > 0) {
    tld[line] = 1
  }
  close(tld_file)
}
/^@@\|\|/ {
  sub(/^@@\|\|/, "")
  sub(/\^\|$/, "")
  n = split($0, parts, ".")
  base = ""
  tld_candidate = parts[n]
  i = n - 1
  while (i >= 1) {
    tld_candidate = parts[i] "." tld_candidate
    if (tld_candidate in tld) {
      if (i > 1) {
        base = parts[i-1] "." tld_candidate
        print base
        break
      }
    }
    i--
  }
  if (base == "" && n > 1) {
    base = parts[n-1] "." parts[n]
    print base
  }
}
' "$WORK_DIR/main_filter.txt" | sort -u > "$WORK_DIR/white_rules.txt"

# 3. AdAway形式への変換
awk -v white="$WORK_DIR/white_rules.txt" '
BEGIN {
  while ((getline line < white) > 0) {
    whitelist[line] = 1
  }
  close(white)
}
/^\|\|/ && !/\$/{
  sub(/^\|\|/, "")
  sub(/\^$/, "")
  if (!($0 in whitelist)) {
    print "0.0.0.0 "$0
  }
}
' "$WORK_DIR/main_filter.txt" > "$WORK_DIR/not_matched_rules.txt"

# 4. ヘッダーの付与
Now="$(TZ=Asia/Tokyo date '+%Y-%m-%d %H:%M JST')"
Today="$(TZ=Asia/Tokyo date '+%Y%m%d')"

awk -v ver="${Today}" -v modifi="${Now}" -v br="${branch}" '
BEGIN {
  print "# Title: AdGuard_DNS_Filter_for_myself for AdAway"
  print "# Description: Auto Converted from AdGuard_DNS_Filter_for_myself"
  print "# Version: "ver
  print "# Homepage: https://github.com/monsivamon/AdGuard_DNS_Filter_for_myself"
  print "# License: https://github.com/monsivamon/AdGuard_DNS_Filter_for_myself/blob/"br"/LICENSE"
  print "# Last modified: "modifi
  print ""
}
{
  print
}
' "$WORK_DIR/not_matched_rules.txt" > "$OUTPUT_FILE"

# 5. クリーンアップ
rm -rf "$WORK_DIR"