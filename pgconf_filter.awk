#!/usr/bin/awk -f
# pgconf_filter.awk
#
# usage:
#   pgconf_filter.awk spec.txt original.conf > new.conf

FNR==NR {
  # spec file phase
  # skip empty / comment lines
  if ($0 ~ /^[[:space:]]*$/) next
  if ($0 ~ /^[[:space:]]*#/) next

  kind = $1
  sub(/^[^[:space:]]+[[:space:]]+/, "", $0)  # remove first token+space

  if (kind == "D") {
    del_n++
    del_re[del_n]=$0
  }else if (kind == "A") {
    add_n++
    add_line[add_n]=$0
  }
  next
}

{
  # original.conf phase
  drop=0
  for (i=1; i<=del_n; i++) {
    if ($0 ~ del_re[i]) {
      drop=1
      print "deleted: " $0 > "/dev/stderr"
      break
    }
  }
  if (!drop) print
}

END {
  for (i=1; i<=add_n; i++) {
    print add_line[i]
  }
}
