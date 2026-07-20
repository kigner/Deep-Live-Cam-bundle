# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Run the app (GUI mode)
python run.py

# Run headless/CLI mode (any --source, --target, or --output triggers CLI)
python run.py --source face.jpg --target video.mp4 --output result.mp4

# Run with GPU acceleration
python run.py --execution-provider cuda
python run.py --execution-provider coreml      # macOS
python run.py --execution-provider directml    # Windows AMD/Intel

# Run benchmark (webcam pipeline perf test, no UI)
python benchmark_pipeline.py

# Run tests
python -m pytest tests/
```

**Installation**: Python 3.11 recommended. `pip install -r requirements.txt`. Requires `ffmpeg` on PATH. Models (inswapper, GFPGAN, etc.) must be downloaded from HuggingFace and placed in `models/`. See README for full setup. On macOS, `brew install python-tk@3.11` is needed for the GUI.

## Architecture

### Entry point and startup

`run.py` is the launcher. Before importing app code, it patches PATH/DLL directories so native CUDA/cuDNN libraries are discoverable by ONNX Runtime and PyTorch. It then prints a platform banner and calls `core.run()`.

`modules/core.py:run()` is the real entry. Two modes:
- **Headless (CLI)**: When `--source`, `--target`, or `--output` are passed. Parses args, calls `start()` which runs the video/image processing pipeline directly.
- **GUI**: Default. Initializes PySide6 via `ui.init(start, destroy, lang)` and enters the Qt event loop.

The global `modules.globals` module holds all shared mutable state: source/target paths, frame processor list, execution providers, toggles for mouth mask/many faces/map faces/poisson blend, slider values, etc. Parse args → write to globals → everything else reads globals.

### Frame processing pipeline

**Two pipelines exist** in `modules/core.py:start()`:

1. **In-memory** (default, `process_video_in_memory`): Reads raw BGR24 frames from source video via FFmpeg pipe → runs each frame through active frame processors → writes directly to FFmpeg encoder pipe. No disk I/O. Uses a pipelined detection approach: while frame N is being swapped, frame N's face is already being detected for frame N+1 (overlaps GPU/ANE work). Falls back to disk pipeline on failure.

2. **Disk-based** (fallback, also used for `--map-faces`): Extract frames to PNG files with FFmpeg → process each PNG through frame processors in parallel via `ThreadPoolExecutor` → re-encode to video. Required for map_faces because the face mapping analysis needs per-frame path lookups.

Both pipelines use the same frame processor modules. The in-memory path pre-loads the source face once and passes it through; the disk path re-reads faces per frame.

### Frame processor system

Frame processors are pluggable modules loaded via `importlib` from `modules/processors/frame/`. Each must implement the interface: `pre_check`, `pre_start`, `process_frame`, `process_image`, `process_video`.

**Allowed processors** (whitelist in `modules/processors/frame/core.py`):
- `face_swapper` — inswapper_128 ONNX model via insightface. The main swap.
- `face_enhancer` — GFPGAN v1.4 ONNX model (no torch dependency).
- `face_enhancer_gpen256` / `face_enhancer_gpen512` — GPEN-BFR ONNX models at different resolutions.

`get_frame_processors_modules()` lazily loads and caches modules. The UI toggles (`fp_ui` dict in globals) can add/remove enhancers at runtime via `set_frame_processors_modules_from_ui`.

### Face detection and analysis

`modules/face_analyser.py` wraps insightface's `buffalo_l` model. Key functions:
- `get_face_analyser()` — thread-safe singleton init with providers config
- `get_one_face(frame, faces=None)` — returns leftmost face by bbox. Accepts pre-detected faces to skip re-detection.
- `get_many_faces(frame)` — all detected faces
- `detect_one_face_fast(frame)` / `detect_many_faces_fast(frame)` — detection only, skips landmark/recognition models (~10ms vs ~16ms)
- `ensure_landmarks(frame, faces)` — on-demand 2d106 landmark computation when mouth mask needs them

InsightFace's standard `get()` is replaced with `_analyse_faces()` which conditionally skips the landmark model when only face_swapper is active (saves ~1ms per face).

**Face mapping** (`--map-faces`): `get_unique_faces_from_target_video()` extracts face embeddings from all frames, runs KMeans clustering (`modules/cluster_analysis.py`), and builds a `source_target_map` mapping centroids to source faces. In live mode, `simple_map` matches detected faces to target embeddings via cosine similarity.

**DirectML note**: DML isn't thread-safe for ONNX inference. `dml_lock` in globals serializes all face detection/swap calls when using DirectML.

### Face swapper (face_swapper.py)

The core logic in `swap_face()`:
1. Runs `face_swapper.get(temp_frame, target_face, source_face, paste_back=False)` — returns `(bgr_fake, M)` where bgr_fake is the swapped aligned face and M is the affine matrix
2. `_fast_paste_back()` composites the swapped face back onto the frame using the inverse affine with a precomputed feathered elliptical alpha mask (GPU-accelerated via PyTorch when CUDA available, otherwise cv2 SIMD)
3. Applies optional mouth mask, Poisson blending (`cv2.seamlessClone`), opacity blend, sharpening, and temporal interpolation

**CUDA graph**: When CUDA is available, the swap model's ONNX session is wrapped in a CUDA graph adapter (`_CudaGraphSessionAdapter`) that records the GPU kernel launch sequence once and replays it with near-zero CPU overhead.

**Paste-back cache**: The feathered alpha template (`_get_soft_alpha`) is cached per size, computed once in aligned-face space then warped per-frame — O(crop_area) instead of O(face_size²).

### UI (PySide6)

`modules/ui.py` defines `MainWindow` with:
- Source/target image selection rows
- Option checkboxes (many faces, mouth mask, poison blend, etc.)
- Sliders (opacity, sharpness, interpolation weight)
- Execution provider and camera device selection
- Live preview via `_CaptureWorker` thread that reads camera frames, swaps, and blits to a QLabel
- Face mapping popup for assigning different source faces to different target faces

`update_status(text)` is thread-safe — routed through Qt signals when called from non-UI threads.

The `modules/ui.json` file defines checkbox-to-global mappings, slider ranges, and tooltips declaratively. `modules/ui_tooltip.py` sets hover tooltips on widgets.

### GPU acceleration

`modules/gpu_processing.py` provides drop-in CUDA replacements for `cv2.GaussianBlur`, `addWeighted`, `resize`, `cvtColor`, `flip`. These are **disabled by default** (the upload/download overhead exceeds savings at webcam resolution). Set `OPENCV_CUDA_PROCESSING=1` to enable. The real GPU work happens via ONNX Runtime execution providers.

`modules/onnx_optimize.py` applies CoreML-specific ONNX graph optimizations for Apple Silicon: Shape/Gather constant folding, Pad(reflect) decomposition, Split→Slice, scalar Gather widening. Results are cached to disk with `_coreml` suffix.

### Models

Stored in `models/` at the project root. Key files:
- `inswapper_128.onnx` / `inswapper_128_fp16.onnx` — face swap model
- `GFPGANv1.4.onnx` — face enhancement
- `GPEN-BFR-256.onnx` / `GPEN-BFR-512.onnx` — alternative enhancer
- `xseg.onnx` — face segmentation (used by GFPGAN enhancer)
- `buffalo_l` — insightface detection/recognition/landmark models (auto-downloaded to `~/.insightface`)

`modules/paths.py` defines `ROOT_DIR` and `MODELS_DIR`. Most processors resolve `models_dir` relative to the module file since they live two directories deep.

### Utilities and helpers

- `modules/utilities.py` — FFmpeg wrappers (extract frames, create video, restore audio), temp file management, video metadata, model downloading
- `modules/video_capture.py` — `VideoCapturer` class wrapping OpenCV `cv2.VideoCapture` with DirectShow/MSMF fallback chain and empirical FPS measurement
- `modules/capturer.py` — reads single frames from video files
- `modules/predicter.py` — NSFW detection via opennsfw2
- `modules/platform_info.py` — centralized platform/accelerator detection (CUDA, CoreML, DirectML availability)
- `modules/gettext.py` — multi-language support, loads JSON from `locales/`
- `modules/custom_types.py` / `modules/typing.py` — duplicated `Face` / `Frame` type aliases

### Test

Only one test file: `tests/test_face_analyser_get_one_face.py`. Uses stub modules to avoid importing heavy dependencies (insightface, cv2, numpy). Tests the face selection logic (leftmost by bbox, DML locking path, pre-supplied faces).
