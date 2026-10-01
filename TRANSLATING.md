# Translating the setup

Translations are welcome, but please only contribute languages you speak natively or fluently.
Several texts of this setup were machine translated in the past and read badly (see
[Review wanted](#review-wanted)); new texts are therefore not machine translated, they stay
English until a speaker of the language translates them.

## Where the texts are

- `messages.iss`, section `[CustomMessages]`: every text of this script (own wizard pages,
  installation types, tasks and components, status texts, message boxes).
- `messages.iss`, section `[Messages]`: overrides of Inno Setup's own password texts, only shown
  by encrypted setups.
- All other texts of the wizard (buttons, standard pages) come from the Inno Setup language files
  listed in `[Languages]` of `setup_is6.iss` (`compiler:Languages\*.isl`, and
  `internal\unofficial_isl` for Korean and Chinese). They are not maintained in this repository.

## Format

```ini
; English default: required, shown by every language without its own entry
TaskDirectPlay=Install DirectPlay
; One line per language, prefixed with the name of its [Languages] entry
de.TaskDirectPlay=DirectPlay installieren
fr.TaskDirectPlay=Installer DirectPlay
```

- Language prefixes: `de`, `es`, `fr`, `it`, `ko`, `pl`, `pt_BR`, `ru`, `zh_CN`, `zh_TW` (game and
  setup languages); `hy`, `bg`, `ca`, `cs`, `da`, `nl`, `fi`, `he`, `is`, `ja`, `nb`, `pt_PT`, `sk`,
  `sl`, `tr`, `uk` (setup languages only). The unprefixed entry is English.
- Message names: `LIQP_` texts belong to the game language page, `MIQP_` to the installation mode
  page, `GPUIQP_` to the graphics card page; the other names say where they are used.
- Keep the placeholders: `%1`, `%2`, ... are filled in by the setup (a comment above the message
  says with what), `%n` is a line break, `{#...}` is replaced when the setup is built (e.g. the
  game version) and `[LAST]` is the latest version in the update questions. A `\` at the end of a
  line continues the text on the next line.
- Not translated on purpose: names of games, mods and content packs (Empire Earth, The Art of
  Conquest, NeoEE, dreXmod, Omega Pack, the HD pack names, ...), the shortcut names in `[Icons]`
  (they are file names and must not change with the setup language) and the Mute/Unmute button
  of the setup music (kept short and English on purpose).
- `messages.iss` is UTF-8 **with BOM** and CRLF, like all own `.iss` files.
- Order: the English default first, then the translations in alphabetical order of their prefix
  (`de`, `es`, `fr`, `it`, `ko`, `pl`, `pt_BR`, `ru`, `zh_CN`, `zh_TW`, then the setup-only
  languages). `python ci/check_messages.py --sort` puts new lines in place.
- After editing run `python ci/check_messages.py`: it reports duplicate entries, `==` typos,
  unknown language prefixes, translations out of order and messages that are used but not
  defined.

A new game language (one the game itself can be installed in) also needs an entry in `GameLangs`
and `GameLangLobbyDirs` of `setup_is6.iss`, its `LIQP_<name>` message and its files, see the
comment above `GameLangs`.

## Status

`python ci/check_messages.py --coverage` lists, for every game language, the custom messages it
has no translation for (they are shown in English) and the `zh_TW` texts that are copies of the
`zh_CN` ones. Its output is the current to-do list; the overview below is the state when this
file was last updated.

Custom messages to translate: 97 (14 of them only used by NeoEE setups; the Mute/Unmute button
texts `SoundCtrlButtonCaptionSoundOn/Off` stay English on purpose and are not counted).

| Language | Translated | Missing |
|---|---|---|
| English (default) | 97 | - |
| German `de`, French `fr` | 97 | - |
| Spanish `es`, Italian `it`, Polish `pl`, Russian `ru`, Korean `ko`, Chinese Simplified `zh_CN`, Chinese Traditional `zh_TW` | 35 | 62: the messages added after setup 1.7.2 |
| Brazilian Portuguese `pt_BR` | 13 | 84: everything except the game language page (`LIQP_*`), see below |
| Setup-only languages (`hy`, `bg`, `ca`, ...) | 0 | all; these languages only have Inno Setup's own texts |

## Help wanted

### Brazilian Portuguese (pt_BR)

`pt_BR` is a game language and a setup language, but only the game language page is translated.
Besides the messages added after 1.7.2 it misses the 22 texts that the other game languages have
(`LegalQuestion`, `PortableQuestion`, `GameUpdate`, `SetupUpdate`, `UserInstallMode`, the `MIQP_*`
texts of the installation mode page and the `GPUIQP_*` texts of the graphics card page) and the
`[Messages]` entries `PasswordLabel3` and `IncorrectPassword`.

### Messages added after setup 1.7.2

These exist in English, German and French only (`--coverage` lists them by name): installation
types, task and component descriptions, the DirectX wrapper part of the graphics card page,
status texts, the reports about online localized files and random map scripts, the NeoEE CD key
messages (NeoEE setups only) and the Wine notice of NeoEE setups. `TestSetupWarning` is only shown
by test builds and has low priority.

### Chinese Traditional (zh_TW)

20 `zh_TW` entries are copies of the Simplified Chinese (`zh_CN`) text, written in simplified
characters (e.g. 选择, 设置, 安装 instead of 選擇, 設置, 安裝); `--coverage` lists them. The
brand names (`GPUIQP_NVIDIA`, `GPUIQP_AMD`, `GPUIQP_Intel`) and `GPUIQP_Default` (我不知道) are the
same in both scripts and only need a check; the others need a Traditional Chinese translation.
The same applies to the `[Messages]` entries `zh_TW.PasswordLabel3` and `zh_TW.IncorrectPassword`.
Please do not convert the simplified text character by character: vocabulary differs between the
two as well.

## Review wanted

The Chinese (`zh_CN`, `zh_TW`), Russian (`ru`) and Korean (`ko`) texts were machine translated
(see the note at the top of `messages.iss`). A known example: `ko.MIQP_Recommended` reads
"명령된 설정" ("commanded settings") instead of "recommended settings". Corrections from native
speakers are welcome for all of them.
