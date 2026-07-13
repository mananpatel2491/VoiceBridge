#!/usr/bin/env python3
"""inspect_wav.py -- parse a WAV file's 44-byte header and check it against
the VoiceBridge audio contract (PCM 16-bit, 16 kHz, mono).

The header layout parsed here mirrors AudioRecorder.buildWavHeader()
(android/app/src/main/java/com/mananpatel/voicebridge/AudioRecorder.kt:97),
which always writes the canonical 44-byte header:

    offset  size  field
    0       4     "RIFF"
    4       4     riff_size (uint32 LE) = pcm_data_size + 36
    8       4     "WAVE"
    12      4     "fmt "
    16      4     fmt_chunk_size (uint32 LE) = 16 for PCM
    20      2     audio_format (uint16 LE)   = 1 for PCM
    22      2     channels (uint16 LE)       = 1 (mono)
    24      4     sample_rate (uint32 LE)    = 16000
    28      4     byte_rate (uint32 LE)      = sample_rate * channels * 2
    32      2     block_align (uint16 LE)    = channels * 2
    34      2     bits_per_sample (uint16 LE)= 16
    36      4     "data"
    40      4     data_size (uint32 LE)      = PCM byte count

Known failure mode detected: AudioRecorder reserves the 44 header bytes as
zeros and only overwrites them in writeWavHeader() AFTER the recording
coroutine finishes. If the app is killed mid-recording (or the coroutine
never completes), the file starts with 44 zero bytes -- this script reports
that explicitly as "header-not-written".

Pure stdlib. Exit codes: 0 = valid + contract OK, 1 = violations found,
2 = unreadable/not a WAV.
"""

import argparse
import json
import struct
import sys

CONTRACT_SAMPLE_RATE = 16000
CONTRACT_BITS = 16
CONTRACT_CHANNELS = 1
HEADER_SIZE = 44


def inspect(path):
    """Return (info_dict, violations_list, fatal_error_or_None)."""
    info = {"file": path}
    violations = []

    try:
        with open(path, "rb") as f:
            header = f.read(HEADER_SIZE)
            f.seek(0, 2)
            file_size = f.tell()
    except OSError as e:
        return info, violations, "cannot read file: %s" % e

    info["file_size_bytes"] = file_size

    if len(header) < HEADER_SIZE:
        return info, violations, (
            "file is only %d bytes (< 44-byte WAV header). "
            "Recording produced no data at all." % len(header)
        )

    # Header-not-written failure mode: AudioRecorder writes 44 zero bytes as a
    # placeholder and back-fills them in writeWavHeader() after recording ends.
    if header == b"\x00" * HEADER_SIZE:
        return info, violations, (
            "first 44 bytes are all zero: the WAV header was never written "
            "(app killed mid-recording, or the recording coroutine never "
            "finished; see AudioRecorder.writeWavHeader). The file body may "
            "still contain raw PCM after byte 44."
        )

    if header[0:4] != b"RIFF":
        return info, violations, (
            "no RIFF magic at offset 0 (got %r) -- not a WAV file."
            % header[0:4]
        )
    if header[8:12] != b"WAVE":
        return info, violations, (
            "no WAVE magic at offset 8 (got %r) -- not a WAV file."
            % header[8:12]
        )

    (riff_size,) = struct.unpack_from("<I", header, 4)
    fmt_tag = header[12:16]
    (fmt_chunk_size, audio_format, channels, sample_rate, byte_rate,
     block_align, bits_per_sample) = struct.unpack_from("<IHHIIHH", header, 16)
    data_tag = header[36:40]
    (data_size,) = struct.unpack_from("<I", header, 40)

    info.update({
        "riff_size": riff_size,
        "fmt_chunk_size": fmt_chunk_size,
        "audio_format": audio_format,
        "audio_format_name": "PCM" if audio_format == 1 else "non-PCM(%d)" % audio_format,
        "channels": channels,
        "sample_rate_hz": sample_rate,
        "byte_rate": byte_rate,
        "block_align": block_align,
        "bits_per_sample": bits_per_sample,
        "data_size_bytes": data_size,
    })

    if fmt_tag != b"fmt ":
        # Non-canonical chunk order (not produced by AudioRecorder, but seen
        # in WAVs from other tools that insert LIST/INFO chunks).
        return info, violations, (
            "chunk at offset 12 is %r, not 'fmt '. This WAV has non-canonical "
            "chunk layout (not produced by VoiceBridge's AudioRecorder); "
            "inspect it with a full RIFF walker instead." % fmt_tag
        )
    if data_tag != b"data":
        return info, violations, (
            "chunk at offset 36 is %r, not 'data'. Non-canonical layout; "
            "not produced by VoiceBridge's AudioRecorder." % data_tag
        )

    if byte_rate:
        info["duration_seconds"] = round(data_size / float(byte_rate), 3)
    else:
        info["duration_seconds"] = None
        violations.append("byte_rate is 0 -- duration cannot be computed")

    # --- contract checks (PATTERNS.md 'Audio Format Contract') ---
    if audio_format != 1:
        violations.append(
            "audio_format=%d, contract requires 1 (PCM)" % audio_format)
    if sample_rate != CONTRACT_SAMPLE_RATE:
        violations.append(
            "sample_rate=%d Hz, contract requires %d Hz"
            % (sample_rate, CONTRACT_SAMPLE_RATE))
    if bits_per_sample != CONTRACT_BITS:
        violations.append(
            "bits_per_sample=%d, contract requires %d"
            % (bits_per_sample, CONTRACT_BITS))
    if channels != CONTRACT_CHANNELS:
        violations.append(
            "channels=%d, contract requires %d (mono)"
            % (channels, CONTRACT_CHANNELS))

    # --- internal consistency checks ---
    if data_size == 0:
        violations.append(
            "data chunk size is 0 -- no audio was captured (recording "
            "stopped instantly, mic returned nothing, or header written "
            "over an empty file)")
    expected_byte_rate = sample_rate * channels * (bits_per_sample // 8)
    if byte_rate != expected_byte_rate:
        violations.append(
            "byte_rate=%d inconsistent with fields (expected %d)"
            % (byte_rate, expected_byte_rate))
    if riff_size != data_size + 36:
        violations.append(
            "riff_size=%d != data_size+36=%d (header fields disagree)"
            % (riff_size, data_size + 36))
    actual_pcm = file_size - HEADER_SIZE
    if data_size != actual_pcm:
        violations.append(
            "data_size=%d but file actually contains %d PCM bytes after the "
            "header (truncated file, or header written at the wrong time)"
            % (data_size, actual_pcm))

    return info, violations, None


def main():
    ap = argparse.ArgumentParser(
        description="Inspect a WAV header against the VoiceBridge audio "
                    "contract (PCM 16-bit / 16 kHz / mono).")
    ap.add_argument("wav_file", help="path to the .wav file to inspect")
    ap.add_argument("--json", action="store_true",
                    help="emit machine-readable JSON instead of text")
    args = ap.parse_args()

    info, violations, fatal = inspect(args.wav_file)

    if args.json:
        print(json.dumps({
            "info": info,
            "violations": violations,
            "fatal_error": fatal,
            "contract_ok": fatal is None and not violations,
        }, indent=2))
    else:
        print("== inspect_wav: %s ==" % info.get("file"))
        for k, v in info.items():
            if k != "file":
                print("  %-20s %s" % (k, v))
        if fatal:
            print("FATAL: %s" % fatal)
        elif violations:
            print("CONTRACT VIOLATIONS (%d):" % len(violations))
            for v in violations:
                print("  - %s" % v)
        else:
            print("OK: valid WAV, meets the 16 kHz / 16-bit / mono contract.")

    if fatal:
        sys.exit(2)
    sys.exit(1 if violations else 0)


if __name__ == "__main__":
    main()
