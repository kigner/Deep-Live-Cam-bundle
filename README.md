# Deep-Live-Cam 2.1.6

Real-time face swap and video deepfake with a single click and only a single image.   

## Disclaimer

This deepfake software is designed to be a productive tool for the AI-generated media industry. It can assist artists in animating custom characters, creating engaging content, and even using models for clothing design.

We are aware of the potential for unethical applications and are committed to preventative measures. A built-in check prevents the program from processing inappropriate media (nudity, graphic content, sensitive material like war footage, etc.). We will continue to develop this project responsibly, adhering to the law and ethics. We may shut down the project or add watermarks if legally required.

- Ethical Use: Users are expected to use this software responsibly and legally. If using a real person's face, obtain their consent and clearly label any output as a deepfake when sharing online.
- Content Restrictions: The software includes built-in checks to prevent processing inappropriate media, such as nudity, graphic content, or sensitive material.
- Legal Compliance: We adhere to all relevant laws and ethical guidelines. If legally required, we may shut down the project or add watermarks to the output.
- User Responsibility: We are not responsible for end-user actions. Users must ensure their use of the software aligns with ethical standards and legal requirements.

By using this software, you agree to these terms and commit to using it in a manner that respects the rights and dignity of others.

Users are expected to use this software responsibly and legally. If using a real person's face, obtain their consent and clearly label any output as a deepfake when sharing online. We are not responsible for end-user actions.

## Installation (Manual)

**Please be aware that the installation requires technical skills and is not for beginners. Consider downloading the quickstart version.**

<details>
<summary>Click to see the process</summary>

### Installation

This is more likely to work on your computer but will be slower as it utilizes the CPU.

**1. Set up Your Platform**

-   Python (3.11 recommended)
-   pip
-   git
-   [ffmpeg](https://www.youtube.com/watch?v=OlNWCpFdVMA) - ```iex (irm ffmpeg.tc.ht)```
-   [Visual Studio 2022 Runtimes (Windows)](https://visualstudio.microsoft.com/visual-cpp-build-tools/)

**2. Clone the Repository**

```bash
git clone --depth 1 https://github.com/hacksider/Deep-Live-Cam.git
cd Deep-Live-Cam
```

**3. Download the Models**

1. [GFPGANv1.4](https://huggingface.co/hacksider/deep-live-cam/resolve/main/GFPGANv1.4.onnx)
2. [inswapper\_128\_fp16.onnx](https://huggingface.co/hacksider/deep-live-cam/resolve/main/inswapper_128_fp16.onnx)

Place these files in the "**models**" folder.

**4. Install Dependencies**

We highly recommend using a `venv` to avoid issues.


For Windows:
```bash
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
```
For Linux:
```bash
# Ensure you use the installed Python 3.11
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

**For macOS:**

Apple Silicon (M1/M2/M3) requires specific setup:

```bash
# Install Python 3.11 (specific version is important)
brew install python@3.11

# Install tkinter package (required for the GUI)
brew install python-tk@3.11

# Create and activate virtual environment with Python 3.11
python3.11 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

** In case something goes wrong and you need to reinstall the virtual environment **

```bash
# Deactivate the virtual environment
rm -rf venv

# Reinstall the virtual environment
python -m venv venv
source venv/bin/activate

# install the dependencies again
pip install -r requirements.txt

# gfpgan and basicsrs issue fix
pip install git+https://github.com/xinntao/BasicSR.git@master
pip uninstall gfpgan -y
pip install git+https://github.com/TencentARC/GFPGAN.git@master
```

**Run:** If you don't have a GPU, you can run Deep-Live-Cam using `python run.py`. Note that initial execution will download models (~300MB).

### GPU Acceleration

**CUDA Execution Provider (Nvidia)**

1. Install [CUDA Toolkit 12.8.0](https://developer.nvidia.com/cuda-12-8-0-download-archive)
2. Install [cuDNN v8.9.7 for CUDA 12.x](https://developer.nvidia.com/rdp/cudnn-archive) (required for onnxruntime-gpu):
   - Download cuDNN v8.9.7 for CUDA 12.x
   - Make sure the cuDNN bin directory is in your system PATH
3. Install dependencies:

```bash
pip install -U torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128
pip uninstall onnxruntime onnxruntime-gpu
pip install onnxruntime-gpu==1.21.0
```

3. Usage:

```bash
python run.py --execution-provider cuda
```

**CoreML Execution Provider (Apple Silicon)**

Apple Silicon (M1/M2/M3) specific installation:

1. Make sure you've completed the macOS setup above using Python 3.11.
2. Install dependencies:

```bash
pip uninstall onnxruntime onnxruntime-silicon
pip install onnxruntime-silicon==1.13.1
```

3. Usage:

```bash
python3.11 run.py --execution-provider coreml
```

**Important Notes for macOS:**
- You **must** use Python 3.11, not newer versions like 3.13
- Always run with `python3.11` command not just `python` if you have multiple Python versions installed
- If you get error about `_tkinter` missing, reinstall the tkinter package: `brew reinstall python-tk@3.11`
- If you get model loading errors, check that your models are in the correct folder
- If you encounter conflicts with other Python versions, consider uninstalling them:
  ```bash
  # List all installed Python versions
  brew list | grep python

  # Uninstall conflicting versions if needed
  brew uninstall --ignore-dependencies python@3.13

  # Keep only Python 3.11
  brew cleanup
  ```

**CoreML Execution Provider (Apple Legacy)**

1. Install dependencies:

```bash
pip uninstall onnxruntime onnxruntime-coreml
pip install onnxruntime-coreml==1.21.0
```

2. Usage:

```bash
python run.py --execution-provider coreml
```

**DirectML Execution Provider (Windows)**

1. Install dependencies:

```bash
pip uninstall onnxruntime onnxruntime-directml
pip install onnxruntime-directml==1.21.0
```

2. Usage:

```bash
python run.py --execution-provider directml
```

**OpenVINO™ Execution Provider (Intel)**

1. Install dependencies:

```bash
pip uninstall onnxruntime onnxruntime-openvino
pip install onnxruntime-openvino==1.21.0
```

2. Usage:

```bash
python run.py --execution-provider openvino
```
</details>

## Download all models in this huggingface link

- [**Download models here**](https://huggingface.co/hacksider/deep-live-cam/tree/main)

## Command Line Arguments (Unmaintained)

```
options:
  -h, --help                                               show this help message and exit
  -s SOURCE_PATH, --source SOURCE_PATH                     select a source image
  -t TARGET_PATH, --target TARGET_PATH                     select a target image or video
  -o OUTPUT_PATH, --output OUTPUT_PATH                     select output file or directory
  --frame-processor FRAME_PROCESSOR [FRAME_PROCESSOR ...]  frame processors (choices: face_swapper, face_enhancer, ...)
  --keep-fps                                               keep original fps
  --keep-audio                                             keep original audio
  --keep-frames                                            keep temporary frames
  --many-faces                                             process every face
  --map-faces                                              map source target faces
  --mouth-mask                                             mask the mouth region
  --video-encoder {libx264,libx265,libvpx-vp9}             adjust output video encoder
  --video-quality [0-51]                                   adjust output video quality
  --live-mirror                                            the live camera display as you see it in the front-facing camera frame
  --live-resizable                                         the live camera frame is resizable
  --max-memory MAX_MEMORY                                  maximum amount of RAM in GB
  --execution-provider {cpu} [{cpu} ...]                   available execution provider (choices: cpu, ...)
  --execution-threads EXECUTION_THREADS                    number of execution threads
  -v, --version                                            show program's version number and exit
```

Looking for a CLI mode? Using the -s/--source argument will make the run program in cli mode.
