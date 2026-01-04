#!/bin/sh
# build-pgsql.sh - PostgreSQL jail を構築するためのラッパスクリプト
# 使い方:
#   sh build-pgsql.sh
#
# 前提:
#   * /san/pgsql が IP-SAN 上のファイルシステムとしてマウント済み
#   * /root/pgsql-master-pass に 1 行だけパスワードが書かれている

set -eu

# root でなければエラー
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root." >&2
  exit 1
fi

. render.subr

# 環境設定
set -a
JAIL_NAME=pgjail
MAKEJAIL=./Makejail
PG_VERSION=17
DB_DATA_DIR=/ztank/pgdata
PASSWORD_DIR=/root/pgjail-passwd
PKGCACHE=/home/appjail-pkgcache
JAIL_IPADDR=192.168.1.16
ALLOWED_CIDR_LIST="${JAIL_IPADDR}/32 192.168.1.100/32"
set +a

# 環境変数のローカルカスタマイズファイルを読み込む
if [ -f .build.env ]; then
  . .build.env
fi

render pgsql-template.conf > .pgsql-template.conf

# パスワードファイルの事前チェック
echo "==> Checking password files..."
if ! sh pg-init.sh --check-only; then
  echo "ERROR: Password file check failed" >&2
  exit 1
fi

# DB_DATA_DIR ディレクトリ存在チェック
if [ ! -d "${DB_DATA_DIR}" ]; then
  echo "ERROR: DB data source directory not found: ${DB_DATA_DIR}" >&2
  exit 1
fi

install -d -p -m 700 certs
if [ ! -f "certs/server.key" ] || [ ! -f "certs/server.crt" ]; then
    openssl req -new -x509 -days 7300 -nodes -text \
	    -out certs/server.crt -keyout certs/server.key \
	    -subj "/CN=pghost.uhoria.local"
fi

echo "Building jail: ${JAIL_NAME}"
appjail makejail -v \
  -j "${JAIL_NAME}" \
  -f "${MAKEJAIL}" \
  -- \
  --pkgcache "${PKGCACHE}" \
  --allowed_cidr_list "${ALLOWED_CIDR_LIST}" \
  --pg_version "${PG_VERSION}" \
  --db_data_dir "${DB_DATA_DIR}" \
  --PASSWORD_DIR "${PASSWORD_DIR}"

echo "Done. You can check status with:"
echo "  appjail status ${JAIL_NAME}"
