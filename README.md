# ventoy-win

Windows 11 を Ventoy 経由で自動インストールするための設定ファイル（`ventoy/ventoy.json` と `ventoy/autounattend.xml`）を、Ventoy で作成した USB メモリ内に自動作成するスクリプトです。

## 概要

- Ventoy USB メモリを自動検出し、確認後に `ventoy/` フォルダと設定ファイルを作成します
- ドライブのルートにある ISO ファイル名を自動検出して `ventoy.json` の `image` に埋め込みます（複数ある場合は選択）
- Windows 11 の要件チェック回避（TPM 等）、BitLocker の自動有効化を無効化
- ローカルアカウント `user`（パスワードなし）を作成して自動ログイン
- OOBE の質問（プライバシー等）をすべてスキップ、高速スタートアップを無効化

## 必要環境

- Linux（Ubuntu 等）
- Ventoy でフォーマット済みの USB メモリ（`Ventoy` / `VTOYEFI` パーティション）
- bash と `lsblk` が必要です
- 未マウントの場合は自動マウントに `udisksctl` を使用します（任意）

## 使い方

### 1. リポジトリをクローン

```bash
git clone https://github.com/hirogura/ventoy-win.git
cd ventoy-win
```

### 2. Ventoy USB メモリを接続してスクリプトを実行

```bash
./ventoy-win.sh
```

- ラベル `Ventoy` のデータパーティション（同じディスクに `VTOYEFI` があるもの）を自動検出します
- 検出結果と作成内容を表示し、確認メッセージが表示されるので `y` を入力して続行します
- 自動検出できない場合や別の場所に作成したい場合は、マウント先を引数で指定できます

```bash
./ventoy-win.sh /run/media/<ユーザー名>/Ventoy
```

### 3. 生成されるファイル

| ファイル | 内容 |
| --- | --- |
| `ventoy/ventoy.json` | Windows 11 チェック回避と自動インストールの設定（ISO ファイル名を自動検出して `image` に設定） |
| `ventoy/autounattend.xml` | 無人インストール用の応答ファイル |

### 4. Windows 11 の ISO をドライブのルートに配置

```
/run/media/<ユーザー名>/Ventoy/
├── Win11_25H2_Japanese_x64_v2.iso
└── ventoy/
    ├── ventoy.json
    └── autounattend.xml
```

※ スクリプト実行時にドライブのルートにある `*.iso` を自動検出し、`ventoy.json` の `image` にそのファイル名を設定します。
ISO が 1 つしかない場合は自動で使用し、複数ある場合はどれを使うか選択できます。ISO がない場合は既定のファイル名（`Win11_25H2_Japanese_x64_v2.iso`）を設定して警告を表示します。

### 5. USB メモリから起動

Ventoy のブートメニューから対象の Windows 11 ISO を選択すると、自動インストールが始まります。

## 作成される設定の内容

- `VTOY_WIN11_BYPASS_CHECK=1` : Windows 11 の要件チェック（TPM / CPU 等）を回避
- BitLocker（デバイス暗号化）の自動有効化を禁止
- ローカルアカウント `user`（Administrators グループ、パスワードなし）を作成して自動ログイン
- OOBE の質問（プライバシー、オンラインアカウント等）をスキップ
- 高速スタートアップ（ハイバネーション）を無効化

## 注意

- ローカルアカウントのパスワードは空です。セキュリティ上重要な環境では使用しないでください
- 既存の `ventoy/` フォルダ内の同名ファイルは上書きされます
- 設定のパスワード等はすべて自動生成され、リポジトリには個人情報は含まれません

## ライセンス

このリポジトリは [MIT License](LICENSE) の下で公開されています。

Copyright (c) 2026 hirogura

See the [LICENSE](LICENSE) file for license rights and limitations (MIT).
