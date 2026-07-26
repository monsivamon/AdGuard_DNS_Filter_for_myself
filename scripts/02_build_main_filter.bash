#!/bin/bash
set -e

# 各種変数の設定
OUTPUT_FILE="Filters/main_filter.txt"
WORK_DIR="Filters/tmp_dir"

# 1. 事前ファイルの取得
mkdir -p "$WORK_DIR"
curl -sSfL https://raw.githubusercontent.com/AdguardTeam/AdGuardSDNSFilter/master/Filters/exclusions.txt -o Filters/exclusions.txt
echo "STEP 1 Finish: Downloaded prerequisite files (exclusions)"
ls -la "$WORK_DIR"

# 2. 依存関係のインストールとフィルタービルド
yarn install
./node_modules/.bin/hostlist-compiler -c configuration.json -o "$OUTPUT_FILE"
echo "STEP 2 Finish: Generated base filter via hostlist-compiler"
ls -la "$WORK_DIR"

# 3. 異常フィルターの事前修正
cp "$OUTPUT_FILE" Filters/generated_org.txt

awk '
!/^!/ && !/^\|\|/ && !/^@@/ {
  print
}
' "$OUTPUT_FILE" | sort -u > "$WORK_DIR/tmp_before_bad_filter.txt"

awk '
/^#/ || /^!/ || /[+?(){}\\]/ {
  next
}
{
  sub(/^:[/][/]/, "||")
  sub(/^\./, "||")
  if ($0 !~ /^\|\|/) {
    $0 = "||" $0
  }
  print
}
' "$WORK_DIR/tmp_before_bad_filter.txt" | sort -u > "$WORK_DIR/tmp_before_bad_filter_fix.txt"

cat "$WORK_DIR/tmp_before_bad_filter_fix.txt" >> "$OUTPUT_FILE"
echo "STEP 3 Finish: Fixed abnormal filter syntax and saved to working file"
ls -la "$WORK_DIR"

# 4. badfilterの抽出と除外
awk '
$0 ~ /\$badfilter/ {
  sub(/\$badfilter/, "")
  print
}
' "$OUTPUT_FILE" | sort -u > "$WORK_DIR/tmp_found_bad_filter.txt"

awk '
FNR==NR {
  bad[$0] = 1
  next
}
/@@/ {
  print
}
!/@@/ {
  if (!($0 in bad)) {
    print
  }
}
' "$WORK_DIR/tmp_found_bad_filter.txt" "$OUTPUT_FILE" | sort -u > "$WORK_DIR/tmp_body_filter_before_pre.txt"
echo "STEP 4 Finish: Extracted badfilters and disabled target rules"
ls -la "$WORK_DIR"

# 5. フィルター構文のクリーンアップ
awk '
/^#/ || /^!/ || /[+?(){}\\]/ {
  next
}
/^\|\|/ || /^@@/ && $0 !~ /\$badfilter/ {
  if ($0 ~ /^@@/ && $0 !~ /^@@\|\|/) {
    sub(/^@@\|?/, "@@||")
  }
  if ($0 !~ /\$/) {
    if (/^@@/) {
      if ($0 !~ /\^\|$/) {
        sub(/[\^|]+$/, "")
        $0 = $0 "^|"
      }
    }
    if (!/^@@/) {
      sub(/\^+$/, "")
      if (!/\^$/) {
        $0 = $0 "^"
      }
    }
  }
  print
}
' "$WORK_DIR/tmp_body_filter_before_pre.txt" | sort -u > "$WORK_DIR/tmp_body_filter.txt"
echo "STEP 5 Finish: Cleaned up and formatted final filter syntax"
ls -la "$WORK_DIR"

# 6. massdnsによる存在確認準備 (全ルールのドメイン抽出)
awk '
{
  tmp = $0
  sub(/^@@\|\|/, "", tmp)
  sub(/^\|\|/, "", tmp)
  sub(/[\^$|].*$/, "", tmp)
  if (tmp != "") {
    print tmp
  }
}
' "$WORK_DIR/tmp_body_filter.txt" | sort -u > "$WORK_DIR/tmp_domains_for_massdns.txt"
echo "STEP 6 Finish: Extracted ALL domains for massdns (No bypass)"
ls -la "$WORK_DIR"

# 7. massdnsの実行 (全ドメイン対象)
if [ -s "$WORK_DIR/tmp_domains_for_massdns.txt" ]; then
  sudo apt-get update
  sudo apt-get install -y git make gcc
  git clone https://github.com/blechschmidt/massdns.git
  make -C massdns

  curl -sf https://public-dns.info/nameservers.txt > "$WORK_DIR/resolvers.txt" || true
  if [ ! -s "$WORK_DIR/resolvers.txt" ]; then
    curl -sSfL https://raw.githubusercontent.com/DNSet/public-dns/master/resources/public-dns/nameservers.txt -o "$WORK_DIR/resolvers.txt"
  fi

  massdns/bin/massdns -r "$WORK_DIR/resolvers.txt" -t A -o S \
    -w "$WORK_DIR/tmp_Exist_domains_raw.txt" "$WORK_DIR/tmp_domains_for_massdns.txt" || true
fi
echo "STEP 7 Finish: Completed domain live-checking via massdns"
ls -la "$WORK_DIR"

# 8. 結果の比較と元のルールの復元
if [ -f "$WORK_DIR/tmp_Exist_domains_raw.txt" ]; then
  awk '
  FNR==NR {
    sub(/\.$/, "", $1)
    alive[$1] = 1
    next
  }
  {
    tmp = $0
    sub(/^@@\|\|/, "", tmp)
    sub(/^\|\|/, "", tmp)
    sub(/[\^$|].*$/, "", tmp)
    
    if (tmp in alive) {
      print $0
    }
  }
  ' "$WORK_DIR/tmp_Exist_domains_raw.txt" "$WORK_DIR/tmp_body_filter.txt" > "$WORK_DIR/tmp_body_filter_base.txt"
else
  > "$WORK_DIR/tmp_body_filter_base.txt"
fi
echo "STEP 8 Finish: Reconstructed filter list (Kept original formatting & modifiers)"
ls -la "$WORK_DIR"

# 9. 独自除外リスト (Unique_Exclude.txt) の適用
UNIQUE_EXCLUDE="Filters/Unique_Exclude.txt"
if [ -f "$UNIQUE_EXCLUDE" ]; then
  awk '
  FNR==NR {
    if ($0 !~ /^!/ && NF > 0) {
      tmp = $0
      sub(/\r$/, "", tmp)
      exclude[tmp] = 1
    }
    next
  }
  {
    tmp = $0
    sub(/^@@\|\|/, "", tmp)
    sub(/^\|\|/, "", tmp)
    sub(/[\^$|].*$/, "", tmp)
    
    matched = 0
    for (pattern in exclude) {
      if (index(tmp, pattern) > 0) {
        matched = 1
        break
      }
    }
    if (matched == 1) {
      next
    }
    print $0
  }
  ' "$UNIQUE_EXCLUDE" "$WORK_DIR/tmp_body_filter_base.txt" > "$WORK_DIR/tmp_body_filter_base_excluded.txt"
  
  mv "$WORK_DIR/tmp_body_filter_base_excluded.txt" "$WORK_DIR/tmp_body_filter_base.txt"
  echo "STEP 9 Finish: Applied Unique_Exclude.txt (Plain Domain List)"
else
  echo "STEP 9 Skip: Unique_Exclude.txt not found"
fi
ls -la "$WORK_DIR"

# 10. コンパイラ外の外部フィルター追加 (独自リストのマージ)
echo "STEP 10 Start: Merging external manual list (Unique_List.txt)..."
cp "$WORK_DIR/tmp_body_filter_base.txt" "$WORK_DIR/tmp_body_filter_merged.txt"
if [ -f "Filters/Unique_List.txt" ]; then
  cat Filters/Unique_List.txt >> "$WORK_DIR/tmp_body_filter_merged.txt"
fi
awk '
!/^!/ && !/^#/ {
  print
}
' "$WORK_DIR/tmp_body_filter_merged.txt" | sort -u > "$WORK_DIR/tmp_body_filter_merged_clean.txt"
mv "$WORK_DIR/tmp_body_filter_merged_clean.txt" "$WORK_DIR/tmp_body_filter_merged.txt"
echo "STEP 10 Finish: Merged Unique_List.txt and removed duplicates"
ls -la "$WORK_DIR"

# 11. 冗長なサブドメインルールを削除
echo "STEP 11 Start: Removing redundant subdomain rules..."

# 許可ルール抽出と最適化
awk '/^@@\|\|/' "$WORK_DIR/tmp_body_filter_merged.txt" | \
awk '
{
    line = $0
    domain = line
    sub(/^@@\|\|/, "", domain)
    sub(/[\^$].*$/, "", domain)
    
    split(domain, parts, ".")
    rev = ""
    for (i = length(parts); i >= 1; i--) {
        if (rev != "") rev = rev "."
        rev = rev parts[i]
    }
    printf "%s\t%s\n", rev, line
}' | sort -k1,1 | \
awk -F '\t' '
BEGIN { prev_rev = "" }
{
    curr_rev = $1
    curr_line = $2
    if (prev_rev != "" && index(curr_rev, prev_rev ".") == 1) {
        next
    }
    print curr_line
    prev_rev = curr_rev
}' > "$WORK_DIR/tmp_allowed_optimized.txt"

# ブロックルール抽出と最適化
awk '/^\|\|/' "$WORK_DIR/tmp_body_filter_merged.txt" | \
awk '
{
    line = $0
    domain = line
    sub(/^\|\|/, "", domain)
    sub(/[\^$].*$/, "", domain)
    
    split(domain, parts, ".")
    rev = ""
    for (i = length(parts); i >= 1; i--) {
        if (rev != "") rev = rev "."
        rev = rev parts[i]
    }
    printf "%s\t%s\n", rev, line
}' | sort -k1,1 | \
awk -F '\t' '
BEGIN { prev_rev = "" }
{
    curr_rev = $1
    curr_line = $2
    if (prev_rev != "" && index(curr_rev, prev_rev ".") == 1) {
        next
    }
    print curr_line
    prev_rev = curr_rev
}' > "$WORK_DIR/tmp_block_optimized.txt"

# 結合 + 重複排除
cat "$WORK_DIR/tmp_allowed_optimized.txt" "$WORK_DIR/tmp_block_optimized.txt" | sort -u > "$WORK_DIR/tmp_body_filter_complete.txt"

echo "STEP 11 Finish: Redundant rules removed and duplicates eliminated"
ls -la "$WORK_DIR"

# 12. ヘッダーの付与
Now="$(TZ=Asia/Tokyo date '+%Y-%m-%d %H:%M JST')"

awk -v ver="1.0.0" -v modifi="${Now}" -v br="${branch}" '
BEGIN {
  print "! Title: AdGuard_DNS_Filter_for_myself"
  print "! Description: AdGuard DNS filter Customized by monsivamon"
  print "! Version: "ver
  print "! Homepage: https://github.com/monsivamon/AdGuard_DNS_Filter_for_myself"
  print "! License: https://github.com/monsivamon/AdGuard_DNS_Filter_for_myself/blob/"br"/LICENSE"
  print "! Last modified: "modifi
  print ""
}
{
  print 
}
' "$WORK_DIR/tmp_body_filter_complete.txt" > "$OUTPUT_FILE"
echo "STEP 12 Finish: Added headers and exported final filter"
ls -la "$WORK_DIR"

# 13. クリーンアップと最終確認
rm -rf "$WORK_DIR"
rm -f Filters/exclusions.txt

awk '
!/^!/ && NF {
  if ($0 !~ /^@@\|\|/ && $0 !~ /^\|\|/) {
    print
  }
}
' "$OUTPUT_FILE" | sort -u > Filters/bad_filter.txt

if [ $(wc -l < Filters/bad_filter.txt) -eq 0 ]; then
  rm Filters/bad_filter.txt
else
  cat Filters/bad_filter.txt
fi