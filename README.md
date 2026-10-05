# App Chat — desktop builds

Flutter client for App Chat (https://chat.langlachill.net). This repository only exists to build
the **macOS** and **Linux** apps on GitHub Actions. It is generated from the main project by
`build_win.bat`; do not edit files here by hand, they are overwritten on every export.

## Getting builds

- Push to `main` (or run **Actions → Build desktop apps → Run workflow**): download the
  `AppChat-macos` / `AppChat-linux-x64` artifacts from the run.
- Push a tag such as `v1.0.0`: the same files are also attached to a GitHub Release.

## Running

**macOS** — unzip `AppChat-macos.zip`. The app is not notarized, so the first time either
right-click → Open, or run:

```sh
xattr -dr com.apple.quarantine app_chat.app
```

macOS asks for camera, microphone and (when sharing) Screen Recording permission on first use.

**Linux** — extract and run:

```sh
mkdir app-chat && tar -xzf AppChat-linux-x64.tar.gz -C app-chat && ./app-chat/app_chat
```

Runtime packages: `libgtk-3-0`, `libsecret-1-0`, `libjsoncpp25` (Ubuntu 22.04+ names).

Release builds connect to the production server; override with
`flutter build <platform> --dart-define=API_URL=https://example.com/api`.
