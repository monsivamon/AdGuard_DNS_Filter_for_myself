#!/bin/bash
set -e

# 各種変数の設定
WORK_DIR="Filters/tmp_dir"
BASE_URL="https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters"
OUTPUT_FILE="Filters/ublock_filters_merge.txt"

# 1. 作業ディレクトリ作成とベースファイルの取得
mkdir -p "$WORK_DIR"
curl -sf "${BASE_URL}/filters.txt" -o "$WORK_DIR/filters.txt"

# 2. includeファイルの抽出とダウンロード
includes=$(grep '^!#include ' "$WORK_DIR/filters.txt" | awk '{print $2}')
for file in $includes; do
  curl -sf "${BASE_URL}/${file}" -o "$WORK_DIR/${file}"
done

# 3. フィルターの合成
mapfile -t includes < <(ls "$WORK_DIR" | grep -v '^filters.txt$')
echo "${includes[@]}"
includes_str=$(IFS=,; echo "${includes[*]}")

awk -v dir="$WORK_DIR" -v includes="$includes_str" '
BEGIN {
  n = split(includes, arr, ",")
}
/^\s*$/ || (/^!/ && $0 !~ /^!#include/) {
  next
}
{
  i = 1
  while (i <= n) {
    if ($0 ~ ("^!#include[ \t]+" arr[i] "$")) {
      fname = dir "/" arr[i]
      print ""
      print "!# Begin include: " fname
      print ""
      while ((getline line < fname) > 0) {
        if (!(line ~ /^\s*$/ || (line ~ /^!/ && line !~ /^!#include/))) {
          print line
        }
      }
      print ""
      print "!# End include: " fname
      print ""
      close(fname)
      next
    }
    i++
  }
  print
}
' "$WORK_DIR/filters.txt" > "$WORK_DIR/filters_merge.txt"

# 4. ヘッダーの付与
Now="$(TZ=Asia/Tokyo date '+%Y-%m-%d %H:%M JST')"
Today="$(TZ=Asia/Tokyo date '+%Y%m%d')"

awk -v ver="${Today}" -v modifi="${Now}" -v br="${branch}" '        
BEGIN {
  print "! Title: uBlock Filters merge"
  print "! Description: Combined list from uBlock includes"
  print "! Version: " ver
  print "! Homepage: https://github.com/monsivamon/AdGuard_DNS_Filter_for_myself"
  print "! License: https://github.com/monsivamon/AdGuard_DNS_Filter_for_myself/blob/"br"/LICENSE"
  print "! Last modified: "modifi
  print ""
}
{
  print 
}
' "$WORK_DIR/filters_merge.txt" > "$OUTPUT_FILE"

# 5. クリーンアップ
rm -rf "$WORK_DIR"