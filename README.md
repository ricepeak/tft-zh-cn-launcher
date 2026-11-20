# Teamfight Tactics zh_CN Launcher

**English** | [简体中文](README.zh-CN.md)

A small Windows helper that opens Riot Client and continuously keeps TFT's
active metadata locale set to Simplified Chinese (`zh_CN`).

🔥 Only for TFT, league of legend is not included. NA TFT (Teamfight Tactics) standalone client language change tool after v18.6, tests show in-game Chinese voice acting. Based on [Karl-Cao/league-zh-cn-launcher](https://github.com/Karl-Cao/league-zh-cn-launcher).

> [!IMPORTANT]
> This is an unofficial community workaround. It is not affiliated with,
> endorsed by, or supported by Riot Games. A future Riot Client update may
> change the configuration format and require changes to this project.

## What it does

- Opens Riot Client normally without automatically starting TFT.
- Watches `teamfighttactics.live.product_settings.yaml` while Riot or the TFT client is open
  and restores its active `locale` whenever Riot changes it to `en_US`.
- When a fresh Riot session resets the locale to `en_US`, restores `zh_CN`,
  restarts Riot Client once, and continues watching across matches. This makes
  the reopened client select the Chinese update path instead of continuing the
  full English language-package download.
- Allows the user to manually click **Update** or **Play** after Riot reopens.
- Does not modify Riot Client settings, `default_locale`, `available_locales`, or
  `TFTClientSettings.yaml`.
- Creates a desktop shortcut using the installed TFT client icon.
- Starts the watcher without a console window from the desktop shortcut.
- Leaves Riot configuration files writable so normal patching and repair are
  not intentionally blocked.

## Requirements

- Windows 10 or Windows 11
- Riot Client and the live Teamfight Tactics client already installed
- TFT launched normally at least once

## Installation

1. Download `TFT-zh_CN-Portable-v2.0.zip` from the latest
   [GitHub Release](../../releases/latest).
2. Extract the ZIP. Do not run the installer from inside the ZIP preview.
3. Double-click **`Install TFT zh_CN.cmd`**.
4. Launch TFT from **TFT_SC** on the desktop.

The launcher is installed for the current Windows user under:

```text
%LOCALAPPDATA%\TFT-zh_CN-Launcher
```

## Uninstallation

Double-click **`Uninstall TFT zh_CN.cmd`** in the installed folder shown
above. This removes the launcher and its desktop shortcut. It does not remove
Riot Client or Teamfight Tactics.

## Troubleshooting

The launcher writes a diagnostic log to:

```text
%LOCALAPPDATA%\TFT-zh_CN-Launcher\launcher.log
```

If Windows blocks downloaded script files, right-click the extracted ZIP or
script, open **Properties**, select **Unblock** if shown, and extract/run it
again.

## How it works

The launcher opens Riot Client normally and monitors only the active `locale`
field in TFT's product metadata. When it observes Riot's fresh `en_US` reset,
it restores `zh_CN` and restarts Riot Client once. It then keeps restoring
`zh_CN` in the TFT client lobby. When a Teamfight
Tactics match executable starts, the helper pauses all metadata access. It
resumes after the match, so later account changes and updates are still
monitored. The helper exits ten seconds after Riot and TFT are both closed.
It never restarts Riot repeatedly within one launcher run.

## License

The same as.
