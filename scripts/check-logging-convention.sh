#!/bin/bash

set -uo pipefail

VIOLATIONS=0
WARNINGS=0
XBMC_DIR="${HOME}/xbmc"
LINUX_DIR="${HOME}/linux-amlogic"

while [ $# -gt 0 ]; do
    case "$1" in
        --xbmc)  XBMC_DIR="$2"; shift 2 ;;
        --linux) LINUX_DIR="$2"; shift 2 ;;
        --help|-h)
            cat <<'USAGE'
check-logging-convention.sh

Usage: scripts/check-logging-convention.sh [--xbmc DIR] [--linux DIR]

Exits non-zero on violation.
USAGE
            exit 0
            ;;
        *) echo "Unknown arg: $1" >&2; exit 2 ;;
    esac
done

bold() { printf '\033[1m%s\033[0m\n' "$1"; }
fail() { printf '  \033[31m✗\033[0m %s\n' "$1"; VIOLATIONS=$((VIOLATIONS+1)); }
warn() { printf '  \033[33m!\033[0m %s\n' "$1"; WARNINGS=$((WARNINGS+1)); }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; }

bold "[1/6] Kernel: bit-map debug macros must contain KT2 ratelimit (Phase 3c)"
if [ -d "$LINUX_DIR" ]; then
    AMDV="$LINUX_DIR/drivers/amlogic/media/enhancement/amdolby_vision/amdolby_vision.c"
    DIDH="$LINUX_DIR/drivers/amlogic/media/di_multi/di_data_l.h"
    AAUH="$LINUX_DIR/sound/soc/amlogic/auge/aml_audio_debug.h"

    if [ -f "$AMDV" ]; then
        if awk '/^#define pr_dolby_dbg/,/^[^\\]*$/' "$AMDV" | grep -q "__ratelimit"; then
            ok "pr_dolby_dbg in $AMDV has __ratelimit"
        else
            fail "pr_dolby_dbg in $AMDV is MISSING __ratelimit (Phase 3c regression)"
        fi
    else
        warn "amdolby_vision.c not found at $AMDV"
    fi

    if [ -f "$DIDH" ]; then
        if awk '/^#define dbg_m\(/,/^[^\\]*$/' "$DIDH" | grep -q "__ratelimit"; then
            ok "dbg_m in $DIDH has __ratelimit"
        else
            fail "dbg_m in $DIDH is MISSING __ratelimit (Phase 3c regression)"
        fi
    else
        warn "di_data_l.h not found at $DIDH"
    fi

    if [ -f "$AAUH" ]; then
        if awk '/^#define aml_audio_dbg/,/^[^\\]*$/' "$AAUH" | grep -q "__ratelimit"; then
            ok "aml_audio_dbg in $AAUH has __ratelimit"
        else
            fail "aml_audio_dbg in $AAUH is MISSING __ratelimit (Phase 3c regression)"
        fi
    else
        warn "aml_audio_debug.h not found at $AAUH"
    fi
else
    warn "linux-amlogic dir $LINUX_DIR not found, skipping kernel checks"
fi

bold "[2/6] Kernel: no naked pr_info inside debug_dolby/di_dbg bit gates"
if [ -f "$AMDV" ]; then
    NAKED=$(awk '
        /if[[:space:]]*\(debug_dolby/ { in_gate=1; next }
        in_gate && /pr_info/ && !/pr_dolby_dbg/ && !/pr_dolby_error/ && !/" fmt,/ && !/##args/ {
            printf "%s:%d: pr_info inside debug_dolby gate (use pr_dolby_dbg macro)\n", FILENAME, NR
        }
        /^[[:space:]]*}/ || /^[[:space:]]*$/ { in_gate=0 }
    ' "$AMDV")
    if [ -z "$NAKED" ]; then
        ok "no naked pr_info inside debug_dolby gates"
    else
        while IFS= read -r line; do fail "$line"; done <<< "$NAKED"
    fi
fi

bold "[3/6] Kernel: bit-map format prefixes must be exclusive (log-axis depends on these)"
if [ -d "$LINUX_DIR" ]; then
    OFFENDERS=$(grep -rn 'pr_info[[:space:]]*([[:space:]]*"DOLBY:' "$LINUX_DIR/drivers/" 2>/dev/null \
        | grep -v 'pr_dolby_' \
        | grep -v '" fmt,' \
        | grep -v '##args' || true)
    if [ -z "$OFFENDERS" ]; then
        ok "DOLBY: prefix exclusively used via pr_dolby_dbg/pr_dolby_error"
    else
        while IFS= read -r line; do
            warn "DOLBY: prefix used outside macro (grandfathered): $line"
        done <<< "$OFFENDERS"
    fi

    OFFENDERS=$(grep -rn 'pr_info[[:space:]]*([[:space:]]*"AMLAUDIO:' "$LINUX_DIR/sound/" 2>/dev/null \
        | grep -v 'aml_audio_dbg' \
        | grep -v '" fmt' \
        | grep -v '##__VA_ARGS__' || true)
    if [ -z "$OFFENDERS" ]; then
        ok "AMLAUDIO: prefix exclusively used via aml_audio_dbg"
    else
        while IFS= read -r line; do
            warn "AMLAUDIO: prefix used outside macro (grandfathered): $line"
        done <<< "$OFFENDERS"
    fi
fi

bold "[4/6] Kodi: hot-path LOG sites (ANY level) must use logComponentM"
if [ -d "$XBMC_DIR" ]; then
    HOT_FILES=(
        "xbmc/cores/VideoPlayer/VideoPlayer.cpp"
        "xbmc/cores/VideoPlayer/VideoPlayerVideo.cpp"
        "xbmc/cores/VideoPlayer/VideoPlayerAudio.cpp"
        "xbmc/cores/VideoPlayer/VideoPlayerSubtitle.cpp"
        "xbmc/cores/VideoPlayer/AudioSinkAE.cpp"
        "xbmc/cores/VideoPlayer/DVDClock.cpp"
        "xbmc/cores/VideoPlayer/DVDCodecs/Video/AMLCodec.cpp"
        "xbmc/cores/VideoPlayer/DVDCodecs/Video/DVDVideoCodecAmlogic.cpp"
        "xbmc/cores/VideoPlayer/DVDCodecs/Video/DVDVideoCodecFFmpeg.cpp"
        "xbmc/cores/VideoPlayer/DVDCodecs/Audio/DVDAudioCodecFFmpeg.cpp"
        "xbmc/cores/VideoPlayer/DVDCodecs/Audio/DVDAudioCodecPassthrough.cpp"
        "xbmc/cores/VideoPlayer/DVDCodecs/Overlay/DVDOverlayCodecFFmpeg.cpp"
        "xbmc/cores/VideoPlayer/VideoRenderers/RenderManager.cpp"
        "xbmc/cores/VideoPlayer/VideoRenderers/OverlayRenderer.cpp"
        "xbmc/cores/VideoPlayer/VideoRenderers/OverlayRendererGLES.cpp"
        "xbmc/cores/VideoPlayer/VideoRenderers/HwDecRender/RendererAML.cpp"
        "xbmc/rendering/gles/RenderSystemGLES.cpp"
        "xbmc/rendering/gles/GLESShader.cpp"
        "xbmc/cores/AudioEngine/Engines/ActiveAE/ActiveAE.cpp"
        "xbmc/cores/AudioEngine/Sinks/AESinkALSA.cpp"
        "xbmc/cores/VideoPlayer/DVDInputStreams/DVDInputStreamBluray.cpp"
        "xbmc/utils/BitstreamConverter.cpp"
        "xbmc/cores/VideoPlayer/DVDSubtitles/DVDSubtitlesLibass.cpp"
    )
    REGRESSIONS=0
    skip_comments() { grep -vE '^[0-9]+:[[:space:]]*(//|\*|/\*)'; }

    HOT_FUNC_RE='^(Render|Process|Output|Sync|Pump|Tick|Drive|Update|GetPicture|GetDelay|GetFrame|GetSample|GetBuffer|GetOverlayCount|AddData|AddPackets|AddSample|AddBuffer|ReleaseFrame|ReleaseBuffer|ReleaseOutput|Decode|Convert|BitstreamConvert|HandlePlaySpeed|HandleMessages|OnDiscNavResult|CheckContinuity|EnableGUIShader|RunStages|SyncStream|PollFrame|PrepareNextRender|FlushBuffers|ProcessOverlays|ProcessSync|ProcessPacket|ProcessVideoData|ProcessAudioData|ProcessDecoderOutput|OverlayFlush|OverlayClose|RenderSSA|Read|Iterate|MainLoop|Step|DispatchMessage|OnAction|OnMenu|UserInput|StateMachine|ProcessEvent)$'

    classify_at() {
        awk -v target="$2" '
            /^[A-Za-z_][A-Za-z_0-9 *&<>:]*::[A-Za-z_~][A-Za-z_0-9]*\(/ {
                if (match($0, /::[A-Za-z_~][A-Za-z_0-9]*\(/)) {
                    last_func = substr($0, RSTART+2, RLENGTH-3)
                }
            }
            NR == target { print last_func; exit }
        ' "$1"
    }

    for f in "${HOT_FILES[@]}"; do
        path="$XBMC_DIR/$f"
        [ -f "$path" ] || continue

        ALL=$( {
            grep -nE 'CLog::Log\(LOG[A-Z]+,' "$path" 2>/dev/null | skip_comments
            grep -nE 'CLog::LogF\(LOG[A-Z]+' "$path" 2>/dev/null \
              | grep -vE 'CLog::LogFC\(' | skip_comments
            grep -nE 'CLog::LogFC\(LOG[A-Z]+' "$path" 2>/dev/null | skip_comments
            grep -nE '(^|[^a-zA-Z_])logM\(LOG[A-Z]+' "$path" 2>/dev/null | skip_comments
            grep -nE 'logNoFormatM\(LOG[A-Z]+' "$path" 2>/dev/null | skip_comments
        } | sort -t: -k1 -n -u || true)

        [ -z "$ALL" ] && continue
        while IFS= read -r line; do
            lineno=$(echo "$line" | cut -d: -f1)
            func=$(classify_at "$path" "$lineno")
            if echo "$func" | grep -qE "$HOT_FUNC_RE"; then
                fail "non-logComponentM in HOT $func: $f → ${line}"
                REGRESSIONS=$((REGRESSIONS + 1))
            else
                warn "grandfathered COLD ${func:-(top-level)}: $f → ${line}"
            fi
        done <<< "$ALL"
    done
    if [ "$REGRESSIONS" -eq 0 ]; then
        ok "all HOT-function LOG sites use logComponentM (full short-circuit)"
    fi
else
    warn "xbmc dir $XBMC_DIR not found, skipping Kodi checks"
fi

bold "[5/6] Kodi: T2 modulo gates should mark intent + not be used for sporadic events"
if [ -d "$XBMC_DIR" ]; then
    SUSPECT=$(grep -rn '% [0-9]\+) == 0' "$XBMC_DIR/xbmc/" 2>/dev/null \
        | grep 'static.*[Cc]ount\|s_callCount' || true)
    if [ -z "$SUSPECT" ]; then
        ok "no remaining T2 modulo gates (post-Phase 2 conversion to T3)"
    else
        while IFS= read -r line; do
            file=$(echo "$line" | cut -d: -f1)
            lineno=$(echo "$line" | cut -d: -f2)
            ctx=$(sed -n "$((lineno+1)),$((lineno+5))p" "$file" 2>/dev/null)
            if echo "$ctx" | grep -q '(sampled 1/'; then
                ok "T2 site at $file:$lineno is marked"
            else
                warn "T2 modulo at $file:$lineno without '(sampled 1/N)' marker — review T2 vs T3"
            fi
        done <<< "$SUSPECT"
    fi
fi

bold "[6/6] Kodi: prior cycling-state T1 fixes still in place"
if [ -d "$XBMC_DIR" ]; then
    GLES="$XBMC_DIR/xbmc/rendering/gles/RenderSystemGLES.cpp"
    if [ -f "$GLES" ]; then
        if awk '/EnableGUIShader\(/,/^}/' "$GLES" | grep -q 's_lastEnabledLogged'; then
            fail "EnableGUIShader has resurfaced raw T1 gate (cycling-state regression)"
        else
            ok "EnableGUIShader has no raw T1 gate (T3 ratelimit intact)"
        fi
    fi

    RM="$XBMC_DIR/xbmc/cores/VideoPlayer/VideoRenderers/RenderManager.cpp"
    if [ -f "$RM" ]; then
        if awk '/RenderManager\.Render gui=true/,/^[[:space:]]*}/' "$RM" \
                | grep -q 'm_presentsource != s_lastSrc'; then
            fail "RenderManager.Render gate re-includes m_presentsource (cycling regression)"
        else
            ok "RenderManager.Render gates exclude m_presentsource (Phase 2 fix intact)"
        fi
    fi
fi

echo
bold "Summary"
if [ "$VIOLATIONS" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
    ok "All logging convention checks passed"
    exit 0
elif [ "$VIOLATIONS" -eq 0 ]; then
    printf '  \033[33m%d warning(s) — review but not blocking\033[0m\n' "$WARNINGS"
    exit 0
else
    printf '  \033[31m%d violation(s)\033[0m, %d warning(s)\n' "$VIOLATIONS" "$WARNINGS"
    exit 1
fi
