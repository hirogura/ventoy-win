#!/usr/bin/env bash
set -euo pipefail

ISO_FILE="Win11_25H2_Japanese_x64_v2.iso"
VENTOY_PART=""
VENTOY_MNT=""

# --- Ventoy USBドライブを自動検出 ---
detect_ventoy_drive() {
    local target="${1:-}"

    # 引数でマウント先が指定された場合
    if [ -n "$target" ]; then
        if [ ! -d "$target" ]; then
            echo "エラー: 指定されたディレクトリが存在しません: $target" >&2
            exit 1
        fi
        VENTOY_MNT="$target"
        return
    fi

    # VTOYEFI パーティション（Ventoy のEFI用パーティション）を持つディスクを特定
    local -A efi_parents=()
    local pk name label mp
    while read -r pk name label mp; do
        [ -n "$name" ] || continue
        [ "$label" = "VTOYEFI" ] || continue
        efi_parents["$pk"]=1
    done < <(lsblk -ln -o PKNAME,NAME,LABEL,MOUNTPOINT 2>/dev/null || true)

    # 同じディスク上の「Ventoy」ラベルのデータパーティションを探す
    while read -r pk name label mp; do
        [ -n "$name" ] || continue
        [ "$label" = "Ventoy" ] || continue
        [ -n "${efi_parents[$pk]:-}" ] || continue
        VENTOY_PART="/dev/$name"
        VENTOY_MNT="$mp"
        return
    done < <(lsblk -ln -o PKNAME,NAME,LABEL,MOUNTPOINT 2>/dev/null || true)
}

# --- 未マウントならマウントを試みる ---
mount_if_needed() {
    [ -n "$VENTOY_MNT" ] && return

    echo "Ventoyパーティションがマウントされていません。マウントを試みます..."
    if command -v udisksctl >/dev/null 2>&1; then
        udisksctl mount -b "$VENTOY_PART" >/dev/null 2>&1 || true
    fi
    read -r VENTOY_MNT < <(lsblk -no MOUNTPOINT "$VENTOY_PART" 2>/dev/null || echo "")
    if [ -z "$VENTOY_MNT" ]; then
        echo "エラー: $VENTOY_PART をマウントできませんでした。" >&2
        exit 1
    fi
}

# --- ventoy/ventoy.json を作成 ---
write_json() {
    local mnt="$1"
    cat > "$mnt/ventoy/ventoy.json" << 'EOF'
{
    "control": [
        { "VTOY_WIN11_BYPASS_CHECK": "1" }
    ],
    "auto_install": [
        {
            "image": "/Win11_25H2_Japanese_x64_v2.iso",
            "template": "/ventoy/autounattend.xml"
        }
    ]
}
EOF
}

# --- ventoy/autounattend.xml を作成 ---
write_xml() {
    local mnt="$1"
    cat > "$mnt/ventoy/autounattend.xml" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
<settings pass="windowsPE">
<component name="Microsoft-Windows-International-Core-WinPE" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
<SetupUILanguage>
<UILanguage>ja-JP</UILanguage>
</SetupUILanguage>
<InputLocale>0411:00000411</InputLocale>
<SystemLocale>ja-JP</SystemLocale>
<UILanguage>ja-JP</UILanguage>
<UserLocale>ja-JP</UserLocale>
</component>
</settings>
<settings pass="specialize">
<component name="Microsoft-Windows-Deployment" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
<!-- BitLocker（デバイス暗号化）の自動有効化を禁止 -->
<RunSynchronous>
<RunSynchronousCommand wcm:action="add">
<Order>1</Order>
<Path>reg add HKLM\SYSTEM\CurrentControlSet\Control\BitLocker /v PreventDeviceEncryption /t REG_DWORD /d 1 /f</Path>
</RunSynchronousCommand>
</RunSynchronous>
</component>
<component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
<ComputerName>*</ComputerName>
</component>
</settings>
<settings pass="oobeSystem">
<component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
<!-- ローカルアカウント「user」（パスワードなし）を作成 -->
<UserAccounts>
<LocalAccounts>
<LocalAccount wcm:action="add">
<Password>
<Value></Value>
<PlainText>true</PlainText>
</Password>
<Description>Local Administrator</Description>
<DisplayName>user</DisplayName>
<Group>Administrators</Group>
<Name>user</Name>
</LocalAccount>
</LocalAccounts>
</UserAccounts>
<!-- 作成したuserアカウントで自動ログイン -->
<AutoLogon>
<Password>
<Value></Value>
<PlainText>true</PlainText>
</Password>
<Enabled>true</Enabled>
<LogonCount>1</LogonCount>
<Username>user</Username>
</AutoLogon>
<!-- 初期設定画面（OOBE）のプライバシー質問等をすべてスキップ -->
<OOBE>
<HideEULAPage>true</HideEULAPage>
<HideLocalAccountScreen>true</HideLocalAccountScreen>
<HideOnlineAccountScreens>true</HideOnlineAccountScreens>
<HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
<NetworkLocation>Work</NetworkLocation>
<ProtectYourPC>3</ProtectYourPC>
</OOBE>
<!-- 高速スタートアップを無効化するコマンドを実行 -->
<FirstLogonCommands>
<SynchronousCommand wcm:action="add">
<Order>1</Order>
<CommandLine>reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v HiberbootEnabled /t REG_DWORD /d 0 /f</CommandLine>
<Description>Disable Fast Startup</Description>
</SynchronousCommand>
</FirstLogonCommands>
</component>
</settings>
</unattend>
EOF
}

# --- ISO がドライブのルートにあるか確認 ---
check_iso() {
    local mnt="$1"
    if [ -f "$mnt/$ISO_FILE" ]; then
        echo "確認: $mnt/$ISO_FILE を検出しました。"
    else
        echo "警告: $mnt/$ISO_FILE が見つかりません。ドライブのルートに配置してください。"
    fi
}

main() {
    detect_ventoy_drive "${1:-}"

    if [ -z "$VENTOY_MNT" ]; then
        echo "エラー: Ventoy USBドライブが見つかりません。" >&2
        echo "Ventoy で作成した USB メモリを接続してください。" >&2
        echo "またはインストール先を引数で指定: $0 /path/to/mountpoint" >&2
        exit 1
    fi

    mount_if_needed

    echo "Ventoy USBドライブを検出しました:"
    echo "  デバイス  : ${VENTOY_PART:-（引数で指定）}"
    echo "  マウント先: $VENTOY_MNT"
    echo ""
    echo "以下のファイルを作成します:"
    echo "  $VENTOY_MNT/ventoy/ventoy.json"
    echo "  $VENTOY_MNT/ventoy/autounattend.xml"
    echo "  ※ 既存の同名ファイルは上書きされます。"
    echo ""
    read -r -p "このドライブに作成してよいですか? [y/N]: " ans
    case "$ans" in
        [yY] | [yY][eE][sS]) ;;
        *)
            echo "中止しました。"
            exit 1
            ;;
    esac

    mkdir -p "$VENTOY_MNT/ventoy"
    write_json "$VENTOY_MNT"
    write_xml "$VENTOY_MNT"

    echo ""
    echo "作成完了: $VENTOY_MNT/ventoy/ventoy.json"
    echo "作成完了: $VENTOY_MNT/ventoy/autounattend.xml"
    echo ""
    check_iso "$VENTOY_MNT"
    echo ""
    echo "※ 起動時にこのドライブを選択すると Windows 11 が自動インストールされます。"
}

main "$@"
