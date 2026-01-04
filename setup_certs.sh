#!/bin/sh#
# setup_certs.sh - PostgreSQL SSL証明書ファイルの権限設定
#
# 使い方: setup_certs.sh <data_directory>
#

set -e

if [ $# -ne 1 ]; then
    echo "Error: データディレクトリを指定してください" >&2
    echo "使い方: $0 <data_directory>" >&2
    exit 1
fi

DATA_DIR="$1"
CERT_FILE="${DATA_DIR}/server.crt"
KEY_FILE="${DATA_DIR}/server.key"

# ファイルの存在確認
if [ ! -f "${CERT_FILE}" ]; then
    echo "Error: 証明書ファイルが見つかりません: ${CERT_FILE}" >&2
    exit 1
fi

if [ ! -f "${KEY_FILE}" ]; then
    echo "Error: 秘密鍵ファイルが見つかりません: ${KEY_FILE}" >&2
    exit 1
fi

# postgres ユーザーの存在確認
if ! id postgres >/dev/null 2>&1; then
    echo "Error: postgres ユーザーが存在しません" >&2
    exit 1
fi

echo "証明書ファイルの権限を設定中..."

# server.crt のオーナーと権限を設定（postgres ユーザーが読めればOK）
chown postgres:postgres "${CERT_FILE}"
chmod 600 "${CERT_FILE}"
echo "  ${CERT_FILE}: postgres:postgres 600"

# server.key のオーナーと権限を設定（必ず 600 にする）
chown postgres:postgres "${KEY_FILE}"
chmod 600 "${KEY_FILE}"
echo "  ${KEY_FILE}: postgres:postgres 600"

echo "証明書ファイルの設定が完了しました"
exit 0