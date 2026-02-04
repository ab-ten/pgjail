# pgjail

FreeBSD の AppJail を使って PostgreSQL サーバーを jail 環境で構築・管理するためのプロジェクトです。

## 概要

ホスト環境から分離した jail 上で PostgreSQL を動かし、構成の自動化と再現性を重視したセットアップを提供します。設定は spec ベースで冪等に反映し、サービス定義ファイルを追加するだけで DB/ユーザーを増やせます。

## 主な特徴

- **AppJail による隔離**: jail 環境で PostgreSQL を安全に運用
- **冪等な設定更新**: `manage_conf.sh` により spec ベースで構成を再生成
- **SSL 対応**: 自己署名証明書を自動生成し、TLS 接続を有効化
- **サービス定義の自動適用**: `services/*.psql` を追加するだけで DB/ユーザー作成
- **ホスト側パスワード管理**: パスワードファイルはホスト側の専用ディレクトリで管理
- **アクセス制御**: `ALLOWED_CIDR_LIST` のみ許可し、それ以外は拒否

## 必要要件

- FreeBSD (ZFS 推奨)
- AppJail がインストール済み、かつ `appjail fetch` で基本イメージ取得済み
- root 権限
- DBデータディレクトリが作成済みであること（デフォルト: `/ztank/pgdata`、`DB_DATA_DIR` で変更）
- パッケージキャッシュ領域（デフォルト: `/home/appjail-pkgcache`）

## セットアップ

### 1. パスワードファイルの作成

サービス定義に対応するパスワードファイルを **ホスト側** に作成します:

```bash
sudo mkdir -p /root/pgjail-passwd
echo "your_secure_password" | sudo tee /root/pgjail-passwd/00-postgres.passwd
echo "nextcloud_password" | sudo tee /root/pgjail-passwd/10-nextcloud.passwd
echo "redmine_password" | sudo tee /root/pgjail-passwd/20-redmine.passwd
sudo chmod 600 /root/pgjail-passwd/*.passwd
```

パスワードファイル名は `services/*.psql` と同名で、拡張子を `.passwd` にしたものにします。

### 2. 環境のカスタマイズ (オプション)

`.build.env` を作成するとデフォルト値を上書きできます:

```bash
cat > .build.env <<EOF
JAIL_NAME=pgjail
PG_VERSION=17
PASSWORD_DIR=/root/pgjail-passwd
DB_DATA_DIR=/ztank/pgdata
PKGCACHE=/home/appjail-pkgcache
JAIL_IPADDR=192.168.1.16
ALLOWED_CIDR_LIST="192.168.1.16/32 192.168.1.100/32"
EOF
```

### 3. jail のビルドと起動

```bash
sudo sh build-pgsql.sh
```

## デフォルト設定

| 項目 | デフォルト値 | 説明 |
|------|-------------|------|
| `JAIL_NAME` | `pgjail` | jail 名 |
| `PG_VERSION` | `17` | PostgreSQL バージョン |
| `PASSWORD_DIR` | `/root/pgjail-passwd` | パスワードファイル保存先 (ホスト側) |
| `DB_DATA_DIR` | `/ztank/pgdata` | jail にマウントするDBデータディレクトリ|
| `PKGCACHE` | `/home/appjail-pkgcache` | pkg キャッシュ (ホスト側) |
| `JAIL_IPADDR` | `192.168.1.16` | jail の IP |
| `ALLOWED_CIDR_LIST` | `192.168.1.16/32 192.168.1.100/32` | 許可する接続元 |

## ディレクトリ構成

```
.
├── build-pgsql.sh
├── Makejail
├── pgsql-template.conf
├── manage_conf.sh
├── pgconf_filter.awk
├── postgresql.spec
├── pg_hba.conf
├── pg_ident.spec
├── setup_certs.sh
├── pg-init.sh
├── render.subr
├── template-service_common.psql
├── certs/
│   ├── server.crt
│   └── server.key
└── services/
    ├── 00-postgres.psql
    └── 10-nextcloud.psql
    └── 20-redmine.psql
```

## サービスの追加方法

1. `services/20-myapp.psql` を作成:

```sql
\set db_name myapp
\set db_user myapp
\set db_pass `head -n 1 "$PASSWD_FILE"`

\ir ../template-service_common.psql
```

2. パスワードファイルを作成:

```bash
echo "myapp_password" | sudo tee /root/pgjail-passwd/20-myapp.passwd
sudo chmod 600 /root/pgjail-passwd/20-myapp.passwd
```

3. 再ビルド:

```bash
sudo sh build-pgsql.sh
```

## 設定の仕組み

### manage_conf.sh

`postgresql.spec` と `pg_ident.spec` を元に設定を冪等に再生成します:

```bash
sh manage_conf.sh <spec_file> <target_conf>
```

- 初回実行時に `<target_conf>.orig` を保存
- `D` 行は削除、`A` 行は追加

### pg_hba.conf

`pg_hba.conf` をベースに以下が自動追加されます:

- `ALLOWED_CIDR_LIST` の `hostssl ... scram-sha-256`
- `host all all 0.0.0.0/0 reject`
- `host all all ::0/0 reject`

### SSL 証明書

`certs/server.crt` と `certs/server.key` が無い場合、ビルド時に自己署名証明書を生成します。  
jail 内では `setup_certs.sh` が所有者・権限を調整します。

## 管理コマンド

```bash
# 状態確認
appjail status pgjail

# 起動・停止・再起動
appjail start pgjail
appjail stop pgjail
appjail restart pgjail

# jail に入る
appjail login pgjail
```

### PostgreSQL 操作

```bash
# jail 内から接続
sudo appjail cmd jexec pgjail psql -U postgres

# Unix ソケット経由 (ホスト)
sudo psql -U postgres -h /usr/local/appjail/jails/pgjail/jail/tmp

# ログ確認
sudo appjail cmd jexec pgjail tail -f /var/log/messages
```

## トラブルシューティング

### パスワードファイルのチェック

```bash
sudo env PASSWORD_DIR=/root/pgjail-passwd sh pg-init.sh --check-only
```

### ビルドが失敗する

```bash
appjail stop pgjail
appjail cmd local pgjail rm
sudo sh build-pgsql.sh
```

## アンインストール

```bash
appjail stop pgjail
appjail jail destroy pgjail
```

## ライセンス

MIT License - 詳細は [LICENSE](LICENSE) を参照してください。

## 免責事項

**このソフトウェアは「現状のまま」で提供され、いかなる保証もありません。**

- 本プロジェクトは個人的な学習・実験目的で作成された小規模なツールです
- 作者は、このソフトウェアの使用によって生じたいかなる損害についても責任を負いません
- セキュリティの脆弱性、データ損失、システム障害などのリスクを理解した上でご使用ください
- 本番環境での使用は推奨しません。使用する場合は必ず自己責任で十分なテストを行ってください
- このプロジェクトは積極的にメンテナンスされない可能性があります
- 必要に応じて fork して独自に改造・メンテナンスすることを想定しています
- サポートやバグ修正の保証はありません

**使用前に必ず [LICENSE](LICENSE) ファイルの全文をお読みください。**

## 注意事項

- このプロジェクトは root 権限で実行する必要があります
- パスワードファイルは必ず安全な場所に保管してください
- 本番環境で使用する場合は、適切なバックアップ体制を構築してください
- ファイアウォールとアクセス制御の設定を適切に行ってください

## 免責事項

このプロジェクトは現状のまま提供され、明示または黙示を問わずいかなる保証もありません。
