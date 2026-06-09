# mini-qr-builder

Automatischer Build des [mini-qr](https://github.com/lyqht/mini-qr)-Docker-Images mit HWKDO-Templates.

## Ablauf

1. Der Workflow prüft per Cron (täglich 08:00 UTC) die [latest Release-API](https://api.github.com/repos/lyqht/mini-qr/releases/latest).
2. Liegt ein neuer Tag vor dem in `.github/last-built-version` gespeicherten Stand, wird das Upstream-Repo ausgecheckt und mit euren Build-Args gebaut.
3. Das Image wird als `ghcr.io/hwkdo/mini-qr-builder:<version>` und `:latest` nach [GHCR](https://ghcr.io) gepusht (z.B. `0.31.0` ohne führendes `v`).
4. Die gebaute Version wird in `.github/last-built-version` festgehalten (Commit durch den Workflow).

## Einrichtung

### 1. GHCR-Berechtigungen

Keine extra Secrets nötig: Der Workflow nutzt den eingebauten `GITHUB_TOKEN` mit `packages: write` und pusht nach `ghcr.io/hwkdo/mini-qr-builder`.

Nach dem ersten Push das Package unter **GitHub → Organisation hwkdo → Packages → mini-qr-builder** ggf. auf „public“ stellen, wenn es auch außerhalb der Org pullbar sein soll (Standard: nur für die Org sichtbar).

Lokale Pulls benötigen ein PAT mit `read:packages`:

```bash
echo "$GITHUB_TOKEN" | docker login ghcr.io -u USERNAME --password-stdin
docker pull ghcr.io/hwkdo/mini-qr-builder:0.31.0
```

### 2. Konfiguration anpassen

| Datei | Inhalt |
|-------|--------|
| `config/build.env` | Einfache Build-Args und GHCR-Image-Name |
| `config/frame-presets.json` | Frame-Vorlagen |
| `config/qr-code-presets.json` | QR-Code-Vorlagen (Farben, Frame, Default-Text) |
| `config/logo.png` | Logo für die QR-Code-Mitte (wird beim Build eingebettet) |

### Logo einbinden

mini-qr erwartet das Logo als **Data-URI** im Preset-Feld `image`. Beim `docker build` passiert das über den Build-Arg `VITE_QR_CODE_PRESETS` – der Wert wird zur Build-Zeit in die statischen Assets eingebacken.

**Empfohlen:** PNG-Datei ins Repo legen:

```bash
cp /pfad/zu/hwkdo-logo.png config/logo.png
```

Das Build-Skript (`scripts/build-image.sh`) kodiert die Datei automatisch zu `data:image/png;base64,...` und setzt sie in alle Presets.

**Aus dem bisherigen manuellen Build übernehmen:** Falls ihr den Base64-String noch im alten `docker build`-Befehl habt, daraus wieder eine PNG erzeugen:

```bash
# Data-URI aus Zwischenablage/Datei → config/logo.png
sed 's/^data:image\/png;base64,//' alte-data-uri.txt | base64 -d > config/logo.png
```

**Alternative:** `image` direkt in `config/qr-code-presets.json` setzen (ohne `config/logo.png`). Nur sinnvoll, wenn ihr die JSON-Datei ohnehin pflegen wollt – die Base64-Zeile ist sehr lang.

### 3. Erste Version setzen

`.github/last-built-version` enthält die zuletzt gebaute Upstream-Version. Beim ersten Lauf nur setzen, wenn ihr die aktuelle Version **nicht** neu bauen wollt:

```
v0.31.0
```

Wenn ihr v0.31.0 noch einmal bauen wollt, lasst `v0.30.2` stehen oder startet manuell mit erzwungener Version (siehe unten).

### 4. Manueller Lauf

Actions → **Build custom mini-qr image** → **Run workflow**

Optional `force_version` setzen (z.B. `v0.31.0`), um unabhängig von `last-built-version` zu bauen.

## Lokaler Test

```bash
export RELEASE_TAG=v0.31.0
git clone --depth 1 --branch "$RELEASE_TAG" https://github.com/lyqht/mini-qr.git /tmp/mini-qr
export SOURCE_DIR=/tmp/mini-qr
echo "$GITHUB_TOKEN" | docker login ghcr.io -u DEIN_USER --password-stdin
./scripts/build-image.sh
# Ergebnis: ghcr.io/hwkdo/mini-qr-builder:0.31.0
```

## Hinweise

- `VITE_ENABLE_ANALYTICS` wird vom Upstream-Dockerfile (v0.31.0) nicht unterstützt und ist daher nicht im Build-Skript.
- `VITE_APP_VERSION` wird automatisch auf den Release-Tag gesetzt.
- Für schnellere Reaktion auf Releases kann der Cron in `.github/workflows/build-on-release.yml` verkürzt werden (z.B. `0 */6 * * *` = alle 6 Stunden).
