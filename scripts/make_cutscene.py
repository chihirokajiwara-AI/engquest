#!/usr/bin/env python3
"""make_cutscene.py — Pipeline A "plates-in-motion" cutscene renderer (¥0).

Turns one of our existing painted plates into a short Layton-grade cutscene clip
by applying restrained camera motion (Ken Burns: slow zoom + directional pan) plus
a soft cinematic vignette, then encoding to the web-decided delivery format
(H.264 High, ≤720p, yuv420p, +faststart). Restraint over fluidity IS the classic
Layton look (limited animation + art + framing + music), so motion-over-plate lands
much of the feel at zero cost and zero new dependency.

Per the 2026 research (memory: layton-grade-production-research):
  - Pipeline A is the ¥0/no-approval pilot; this is its tool.
  - The musical leitmotif (the #1 "Layton-or-not" signal) is added separately —
    pass --audio to lay a track under the clip; without it the clip is silent PoC.
  - Parallax/depth-layer motion is the next enhancement (needs a depth pass); this
    tool ships the Ken-Burns + vignette base first.

Usage:
  python3 scripts/make_cutscene.py --input assets/art/scenes_layton/town5_lane.webp \
      --output build/cutscenes/ch5_intro.mp4 --duration 9 --zoom in --pan lr
  # optional: --audio path/to/leitmotif.mp3   --height 720   --fps 30

Heavy-job note: a single ~9s 720p render is fast (~seconds); fine inline. For a
large batch, route through scripts/safe-job.sh.
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys


def _zoompan_expr(duration: float, fps: int, zoom: str, pan: str, w: int, h: int):
    frames = max(1, int(round(duration * fps)))
    # Slow, restrained zoom across the whole clip (Layton never whip-zooms).
    if zoom == "out":
        z = "max(1.18-on/{0}*0.18,1.0)".format(frames)
    else:  # "in"
        z = "min(1.0+on/{0}*0.18,1.18)".format(frames)
    # Directional pan; centre keeps the framing still apart from the zoom.
    cx = "iw/2-(iw/zoom/2)"
    cy = "ih/2-(ih/zoom/2)"
    pans = {
        "lr": ("on/{0}*(iw-iw/zoom)".format(frames), cy),
        "rl": ("(iw-iw/zoom)-on/{0}*(iw-iw/zoom)".format(frames), cy),
        "up": (cx, "(ih-ih/zoom)-on/{0}*(ih-ih/zoom)".format(frames)),
        "down": (cx, "on/{0}*(ih-ih/zoom)".format(frames)),
        "center": (cx, cy),
    }
    x, y = pans.get(pan, (cx, cy))
    return (
        "zoompan=z='{z}':d={d}:x='{x}':y='{y}':s={w}x{h}:fps={fps}".format(
            z=z, d=frames, x=x, y=y, w=w, h=h, fps=fps
        )
    )


def build_cmd(args) -> list[str]:
    h = args.height
    w = (h * 16 // 9) // 2 * 2  # 16:9, even width
    fps = args.fps
    # Upscale first so zoompan steps are sub-pixel-smooth (kills the classic jitter).
    pre = "scale={0}:-2".format(w * 2)
    zp = _zoompan_expr(args.duration, fps, args.zoom, args.pan, w, h)
    vf = "{pre},{zp},vignette=PI/5".format(pre=pre, zp=zp)
    # Optional very-light film grain for a painterly, less-digital feel.
    if args.grain:
        vf += ",noise=alls=7:allf=t+u"
    # Cinematic fade from/to black — a Layton beat dissolves in, it never hard-cuts.
    fade = max(0.3, min(0.8, args.duration / 12))
    out_st = max(0.0, args.duration - fade)
    vf += ",fade=t=in:st=0:d={f},fade=t=out:st={o}:d={f}".format(
        f=round(fade, 2), o=round(out_st, 2)
    )
    cmd = ["ffmpeg", "-y", "-loop", "1", "-i", args.input]
    if args.audio:
        cmd += ["-i", args.audio]
    cmd += [
        "-t", str(args.duration),
        "-vf", vf,
        "-c:v", "libx264", "-profile:v", "high", "-crf", "23",
        "-preset", "medium", "-pix_fmt", "yuv420p", "-movflags", "+faststart",
        "-r", str(fps),
    ]
    if args.audio:
        cmd += ["-c:a", "aac", "-b:a", "128k", "-shortest"]
    else:
        cmd += ["-an"]
    cmd += [args.output]
    return cmd


def main() -> int:
    p = argparse.ArgumentParser(description="Render a plates-in-motion cutscene clip.")
    p.add_argument("--input", required=True, help="source plate (webp/png/jpg)")
    p.add_argument("--output", required=True, help="output .mp4 path")
    p.add_argument("--duration", type=float, default=9.0)
    p.add_argument("--height", type=int, default=720)
    p.add_argument("--fps", type=int, default=30)
    p.add_argument("--zoom", choices=["in", "out"], default="in")
    p.add_argument("--pan", choices=["lr", "rl", "up", "down", "center"],
                   default="center")
    p.add_argument("--audio", default=None, help="optional leitmotif track")
    p.add_argument("--grain", action="store_true",
                   help="add very-light film grain (painterly feel)")
    args = p.parse_args()

    if not os.path.exists(args.input):
        print("[make_cutscene] input not found: {0}".format(args.input),
              file=sys.stderr)
        return 2
    os.makedirs(os.path.dirname(os.path.abspath(args.output)), exist_ok=True)

    cmd = build_cmd(args)
    print("[make_cutscene] " + " ".join(cmd))
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        sys.stderr.write(r.stderr[-2000:])
        print("[make_cutscene] FAILED rc={0}".format(r.returncode), file=sys.stderr)
        return r.returncode
    size = os.path.getsize(args.output) if os.path.exists(args.output) else 0
    print("[make_cutscene] OK -> {0} ({1} bytes)".format(args.output, size))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
