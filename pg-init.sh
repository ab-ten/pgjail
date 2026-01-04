#!/bin/sh

set -eu
set -x

# PASSWORD_DIR が定義されているかチェック
if [ -z "${PASSWORD_DIR:-}" ]; then
  echo "Error: PASSWORD_DIR is not defined" >&2
  exit 1
fi

# --check-only オプション：パスワードファイルの存在とパーミッションだけチェックして終了
CHECK_ONLY=0
if [ "$#" -ge 1 ] && [ "$1" = "--check-only" ]; then
  CHECK_ONLY=1
fi

# psql は -X で .psqlrc を読まない（スクリプトの再現性）
# ON_ERROR_STOP は必須（途中で失敗しても続行しない）
PSQL="psql -X -v ON_ERROR_STOP=1 -U postgres -d postgres"

# パスワードファイルチェック（--check-only の時のみ）
if [ "$CHECK_ONLY" -eq 1 ]; then
  echo "==> Checking password files in ${PASSWORD_DIR}" >&2
  for f in services/*.psql; do
    [ -f "$f" ] || continue
    # ${PASSWORD_DIR}/*.passwd ファイルが存在するかチェック
    PASSWD_FILE="${PASSWORD_DIR}/${f##*/}"
    PASSWD_FILE="${PASSWD_FILE%.psql}.passwd"
    if [ ! -r "$PASSWD_FILE" ]; then
      echo "Error: パスワードファイルが見つかりません: ${PASSWD_FILE}" >&2
      exit 1
    fi
    # パーミッションチェック（600 or 400 が望ましい）
    PERM=$(stat -f "%Lp" "$PASSWD_FILE" 2>/dev/null)
    if [ "$PERM" != "600" ] && [ "$PERM" != "400" ]; then
      echo "Warning: パスワードファイルのパーミッションが緩い: ${PASSWD_FILE} (${PERM})" >&2
      exit 1
    fi
  done
fi

# --check-only モードならここで終了（チェックのみ実行）
if [ "$CHECK_ONLY" -eq 1 ]; then
  echo "==> All password files OK" >&2
  exit 0
fi

# サービス定義を全部適用（増えたらファイルを置くだけ）
for f in services/*.psql; do
  [ -f "$f" ] || continue
  echo "==> Applying: $f" >&2
  # passwd ファイル名を postgres_pw_file 変数にセット
  export PASSWD_FILE="${f%.psql}.passwd"
  if ! $PSQL --set postgres_pw_file="$PASSWD_FILE" -f "$f"; then
    echo "ERROR: Failed to apply $f" >&2
    rm -f "${PASSWD_FILE}"
    exit 1
  fi
  rm -f "${PASSWD_FILE}"
  echo "==> Successfully applied: $f" >&2
done
