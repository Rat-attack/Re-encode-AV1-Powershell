<div align="center">

# Re-Encode AV1 (PowerShell)

PowerShell 7+ script for interactive or batch re‑encoding of video files to AV1 using FFmpeg + FFprobe. Includes optional down‑scaling, VR → 2D ## 13. Troubleshooting

</div>

## Table of Contents
1. [Overview](#1-overview)
2. [Requirements](#2-requirements)
3. [Automated Installation](#3-automated-installation)
4. [Quick Start](#4-quick-start)
5. [Configuration Summary](#5-configuration-summary)
	* [Safety Flags (Deletion Logic)](#safety-flags-deletion-logic)
6. [Usage Modes](#6-usage-modes)
	* [Interactive Single / Mixed Files](#a-interactive-single--mixed-files)
	* [Bulk Defaults Mode](#b-bulk-defaults-mode)
	* [Queue Mode Resume](#c-queue-mode-resume)
	* [VR → 2D Conversion](#d-vr--2d-conversion)
7. [Progress & Control](#7-progress--control)
8. [Comparison & Logging](#8-comparison--logging)
9. [Exit Codes & Failures](#9-exit-codes--failures)
10. [Example Minimal Configuration Block](#10-example-minimal-configuration-block)
11. [Recommended Starting Values](#11-recommended-starting-values)
12. [Known Limitations / Future Ideas](#12-known-limitations--future-ideas)
13. [Troubleshooting](#13-troubleshooting)
14. [Contributing](#14-contributing)
15. [Attribution](#15-attribution)
16. [Disclaimer](#16-disclaimer)

## 1. Overview
This repository contains a single interactive PowerShell script (`Re-Encode AV1.ps1`) plus a simple launcher batch file to enable drag & drop, and an automated FFmpeg installer (`Install-FFmpeg.ps1`) for easy setup. The script can:

* Re‑encode one or many files (you can drop files or folders onto the launcher)
* Build a queue before starting encoding
* Detect and optionally skip files already encoded with AV1
* Down‑scale automatically (global defaults or per‑file prompts)
* Handle VR / 360° content, with optional VR → flat 2D conversion (draft or final)
* Show live FFmpeg progress with ETA and cancellation options (abort now / after current)
* Compare output vs source size and optionally delete the larger file or (dangerous) the source when smaller
* Log key events to text files for later review

The code intentionally keeps configuration in one clearly marked region near the top of the script.

## 2. Requirements
* Windows (developed and tested on Windows with PowerShell 7+)
* PowerShell 7 or later (pwsh)
* FFmpeg + FFprobe binaries (same build version recommended). Script authored against FFmpeg 7.0.1.

Download FFmpeg: https://ffmpeg.org/download.html  
Convenient builds (used during development): https://github.com/GyanD/codexffmpeg/releases

Ensure `ffmpeg.exe` and `ffprobe.exe` are accessible via the configured absolute paths (recommended) or are in the working directory.

## 3. Automated Installation
**The easiest way to get started** is to use the included automated installer:

1. Download or clone this repository
2. Right-click on `Install-FFmpeg.ps1` and select "Run with PowerShell"
   - Or open PowerShell in the folder and run: `.\Install-FFmpeg.ps1`
3. The installer will:
   - Download the latest FFmpeg build with AV1 support
   - Extract and install FFmpeg binaries to the script directory
   - Automatically update the configuration in `Re-Encode AV1.ps1`
   - Verify the installation works correctly

That's it! After the installer completes, you can immediately start using the encoding script by dragging video files onto `Re-encode AV1 launcher.bat`.

### Installer Options
- **Force reinstall**: Run `.\Install-FFmpeg.ps1 -Force` to reinstall even if FFmpeg is already present
- **Custom path**: Run `.\Install-FFmpeg.ps1 -InstallPath "C:\Your\Path"` to install to a different location

## 4. Quick Start
#### Refer to [Automated Installation](#3-automated-installation) first. This is just if you want to do it by hand.
1. Download / clone this repository.
2. Download and extract FFmpeg; place `ffmpeg.exe` and `ffprobe.exe` in your folder.
3. Open `Re-Encode AV1.ps1` and edit the configuration block (top of file):
	* Set `$ffmpegPath` and `$ffprobePath` to wherever you installed the files in step 2.
	* Optionally set log file paths (or leave as relative names to write beside the script / current working directory). (Not tested yet)
4. (Optional) Create a dedicated `logs` folder and point the log-related variables there. (Not tested yet)
5. Run once (right‑click → Run in PowerShell OR launch via the batch file) to verify no path errors.
6. Drag video files or folders onto `Re-encode AV1 launcher.bat` to begin interactive queue building.

## 5. Configuration Summary
All tunables reside at the top of `Re-Encode AV1.ps1`, it is recommended to read and change them all especially for batch running. Key variables:

| Variable | Purpose | Notes |
|----------|---------|-------|
| `$ffmpegPath`, `$ffprobePath` | Absolute (recommended) or relative paths to FFmpeg tools | Required. Script will fail early if not correct. |
| `$queueFile`, `$queuebackupFile` | Main and backup queue persistence | Queue survives interruptions. |
| `$alreadyAv1Log` | Files detected already AV1 | Append‑only. |
| `$errorLog` | Non‑zero FFmpeg exits | Captures exit codes. |
| `$bettersourceLog` | Outputs larger than source (when comparison enabled) | Only written if comparison enabled. |
| `$DeleteSourceLog` | Records deleted sources (if dangerous deletion opt‑in) | Must be set (non‑blank) AND `$sourceDel=$true`. |
| `$global:outName` | Suffix added before `.mkv` | Prevents overwrite. |
| `$compare` | Enable size comparison after each encode | Off by default. |
| `$compareDel` | Delete the new file if it is larger | Requires `$compare=$true`. |
| `$sourceDel` | Delete source if new file is smaller | Strongly discouraged; permanent delete. |
| `$global:debugmode` | Extra verbose internal tracing | Mostly for troubleshooting. |
| `$videoExts` | Recognized input extensions | Extend if FFmpeg supports more. |
| `$global:batchCRF` | Default CRF in bulk mode | AV1 typical good quality: ~28–32; script default 30. |
| `$global:batchScale`, `$global:monitor`, `$global:monitorScale` | Automated down‑scale control | Leave `$batchScale` empty to trigger conditional monitor scaling. |
| `$global:monitorScaleVR` | Base scale for VR → 2D projection | Required for VR 2D conversion. |
| `$global:batchPreset`, `$global:batchVRPreset` | SVT-AV1 preset values | Higher number = slower (in SVT‑AV1 lower = faster). VR preset must be ≥ 8 per inline note. |
| `$global:affinityMask` | Optional CPU affinity bitmask | 0 = no restriction. |
| `$global:priorityLevel` | Process priority (Idle…RealTime) | Use Idle for background encoding. |

### Safety Flags (Deletion Logic)
Deletion is irreversible (no Recycle Bin). To enable source deletion you must:
1. Set `$compare = $true` (size comparison must run)
2. Set `$sourceDel = $true`
3. Provide a non‑empty `$DeleteSourceLog` path (e.g. `"Deleted Sources Log.txt"`)

Without all three, source deletion will not occur. Review log output before trusting automation. Enabling this comes at your own risk as once again files are not recoverable.

## 6. Usage Modes
### a. Interactive Single / Mixed Files
Run the script (or drag items). You will be prompted per file for:
* CRF
* Rename output
* VR / 360° status and (optionally) VR → 2D conversion
* Down‑scaling choice
* Preset (VR conditional)

Each confirmed configuration line is appended to the queue file. Encoding starts only after explicit confirmation.

### b. Bulk Defaults Mode
When prompted “Apply defaults to all…”, answer Yes to enqueue every detected video using the pre‑configured global defaults (`$global:batchCRF`, scaling logic, presets). Useful for hands‑off batch jobs.

### c. Queue Mode Resume
If you pass the queue file itself as the only argument (e.g. drag `Queue.txt` onto the launcher) the script switches to batch execution of the remaining queue entries.

### d. VR → 2D Conversion
Prompts allow a draft encode (very fast, high CRF, preset 13) to test FOV / pitch, then a final pass. Supports fisheye input path and equirectangular handling via FFmpeg `v360` filter. There is no batch mode version of this due to the specific configuration you'll most likely have to do.

## 7. Progress & Control
During encoding a live percentage and ETA are shown (derived from parsed `time=` and total duration). Press `q` then choose:
* Abort Now (kills current job; partial output file is removed)
* Abort After (finish current job, stop before next)

Ctrl+C is also trapped to terminate ungracefully compared to the 'q' method.
It is possible to change 'q' method to trigger on another single key input via going to roughly line 264.

## 8. Comparison & Logging
If `$compare = $true` the script evaluates output vs source file size:
* Larger output → optionally delete new file if `$compareDel = $true` else keep & log.
* Smaller output → optionally delete source if the (dangerous) deletion trio is enabled, a log is always made.

Written logs (most are never overwritten/deleted):
* Already AV1 detections (`$alreadyAv1Log`)
* Larger source cases (`$bettersourceLog`)
* Deleted sources (`$DeleteSourceLog`)
* Non‑zero exit codes (`$errorLog`)
* Queue backup (overwritten whenever an new queue starts) (`$queuebackupFile`)

## 9. Exit Codes & Failures
Failed jobs remain in the queue file; successful jobs are removed. A summary is printed at the end including counts of failed jobs and “bigger output” cases. The codes are what FFMPEG outputs to the script and so it is up to yourself to find out what they mean. However below is commonly reported exit codes and their rough fixes.

### Common exit codes:
| Code | Rough reason | Fix |
|----------|---------|-------|
| 1 | Generic error | Syntax errors, invalid options, missing file. Check command, paths, and quotes. |
| 2 | Invalid input | Input file cannot be read. Verify file exists and FFmpeg can access it. Use `ffprobe` to test. |
| -22 | Invalid argument or can't process the file. Often due to stream mapping issues or unsupported options. | Try slightly different arguements or check the source file is not corrupted. For example if an cover image/art is present use `-map 0:v:0` in place of `-map 0:v` |
| -1 | Unknown / abnormal termination | FFmpeg crashed or was killed. Check system resources, permissions, or update FFmpeg. |
| 255 | File not found / access denied | Output directory does not exist or permission denied. Create folder and check write permissions. |
| Big Long Numbers | Windows got in the way or something else caused it to fail | Try seeing first if it's file specific or not and if you have any special characters in the file name and removing them. Those can mess with Powershell and FFMPEG's ability to find the files.|

## 10. Example Minimal Configuration Block
```powershell
$ffmpegPath      = 'C:\Tools\FFmpeg\ffmpeg.exe'
$ffprobePath     = 'C:\Tools\FFmpeg\ffprobe.exe'
$queueFile       = 'Queue.txt'
$queuebackupFile = 'Queue backup.txt'
$alreadyAv1Log   = 'Already AV1.txt'
$errorLog        = 'Error Log.txt'
$bettersourceLog = 'Better Source.txt'
$global:outName  = 're-encoded'
$compare         = $true          # enable size comparison
$compareDel      = $true          # delete new file if larger
$sourceDel       = $false         # KEEP sources (recommended)
$DeleteSourceLog = ''             # set only if enabling sourceDel
```

## 11. Recommended Starting Values
* CRF 30 (balance quality / size; lower is higher quality)
* Preset 6 (general) / 8 (VR default enforced by comments)
* Leave `$batchScale` empty and set `$monitor = 2160` & `$global:monitorScale = scale='min(3840,iw)':2160` for automatic 4K→downscale gating.

## 12. Known Limitations / Future Ideas
* Source deletion relies solely on relative size; no perceptual quality checks.
* VR 2D branch marked “uncooked” and could be modularized along with more testing.
* No hash comparison to prevent duplicate queue entries across sessions. Easily resulting in script seemingly freezing if an file with same name as the output file to be created exists in the same folder.
* No audio re‑encode options (always copy). Could add bitrate control later.
* No built‑in update mechanism or parameter file; all config is inline.

## 13. Troubleshooting
| Symptom | Check |
|---------|-------|
| FFmpeg not found | Paths to `$ffmpegPath` / `$ffprobePath` correct? Escaped backslashes? |
| Progress stuck at 0% | Very short file or FFmpeg not emitting timing yet (wait up to ~30s). |
| Queue never starts | You answered No to “Start encoding now?” – rerun and choose Yes or drag the queue file. |
| Output overwrote original | `$global:outName` removed/empty? Ensure suffix remains distinct. |
| Source deleted unexpectedly | Verify you set *all three* deletion toggles; review `$DeleteSourceLog`. |
| Script is seemingly frozen after Please wait message | See if an file already exists with the same name as the output intended name, if one does delete or rename it and reattempt. |

Enable `$global:debugmode = $true` for deeper verbose tracing (internal loop messages).

## 14. Contributing
Open an issue or PR with concise description. Please keep style consistent (PowerShell 7+, explicit variable names, minimal external dependencies).
There may be an length wait time prior to it being added to the main branch or there may be comments made to query further about it.

## 15. Attribution
Initial script created with iterative AI assistance and refined manually over ~2 months from an earlier batch (.bat) implementation that has been used for over a year personally.

## 16. Disclaimer
Use at your own risk. Always test on sample copies before enabling any deletion features. No warranty is provided. Any files deleted as a result are your own responsibility.

---

If you need a lighter “quick start” version for end users you can extract the Configuration + Quick Start sections into a separate document.

Enjoy efficient AV1 re‑encoding.






