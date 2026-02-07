# Bridge AI - Offline Voice Command System

A fully offline voice command system for Star Trek: Starship Command. Control your ship with natural voice commands like a real Starfleet captain.

## Features

- **Fully Offline** - No internet required, all processing happens locally
- **Natural Language** - Speak commands naturally, the AI understands context
- **Full Autopilot Integration** - Voice commands use the same system as click navigation
  - ETA display during warp travel
  - Automatic warp drop-out at destination (1 million km)
  - Disengage button and arrival prompts
- **All Destinations Supported** - Navigate to any planet, moon, or starbase
- **Contextual Memory** - Remembers your last destination and warp factor

## Architecture

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│ Microphone  │────▶│ Whisper.cpp │────▶│   Ollama    │────▶│   Godot     │
│  (Voice)    │     │(Speech→Text)│     │(Text→Intent)│     │   (Game)    │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
      Local              Local              Local            TCP:5005
```

---

## Setup Instructions

### Step 1: Install Python Dependencies

```bash
cd bridge_ai
pip install -r requirements.txt
```

On macOS, if pyaudio fails:
```bash
brew install portaudio
pip install pyaudio
```

### Step 2: Install Whisper.cpp (Speech-to-Text)

Whisper.cpp converts your voice to text locally.

**Option A - Build from source (Recommended):**
```bash
# Clone the repo (outside the game folder)
cd ~
git clone https://github.com/ggerganov/whisper.cpp
cd whisper.cpp

# Build with cmake
mkdir build && cd build
cmake ..
cmake --build . --config Release

# Download the English model (base.en is fast, medium.en is more accurate)
cd ..
bash ./models/download-ggml-model.sh base.en
```

**Option B - Homebrew (macOS):**
```bash
brew install whisper-cpp
```

### Step 3: Configure Whisper Path

Edit `bridge_ai.py` and update the path to match your installation:

```python
class Config:
    WHISPER_CPP_PATH = "/path/to/whisper.cpp/build/bin/whisper-cli"
    # Examples:
    # macOS built from source: "~/whisper.cpp/build/bin/whisper-cli"
    # Homebrew: "/opt/homebrew/bin/whisper-cpp"
```

### Step 4: Install Ollama (Local LLM)

Ollama runs the AI that understands your commands.

**macOS:**
```bash
brew install ollama
```

**Or download from:** https://ollama.ai

**Pull a model:**
```bash
# TinyLlama - Fast, good for simple commands
ollama pull tinyllama

# Or Llama 3.2 - More accurate but slower
ollama pull llama3.2
```

### Step 5: Configure Ollama Model

Edit `bridge_ai.py` if using a different model:

```python
class Config:
    OLLAMA_MODEL = "tinyllama"  # Change to your installed model
```

---

## Usage

### 1. Start Ollama (in a terminal)
```bash
ollama serve
```

### 2. Start the Godot Game
Launch the game and select a ship. The TCP listener starts automatically.

### 3. Run Bridge AI (in another terminal)
```bash
cd bridge_ai
python bridge_ai.py
```

### 4. Speak Commands
Wait for "[LISTENING]" then speak clearly.

---

## Supported Voice Commands

### Navigation (All Planets & Destinations)
| Command | Action |
|---------|--------|
| "Set course for Jupiter, warp 5" | Navigate to Jupiter at warp 5 |
| "Take us to Mars" | Navigate to Mars (default warp 5) |
| "Head to Neptune, warp 7" | Navigate to Neptune at warp 7 |
| "Saturn warp 6" | Navigate to Saturn at warp 6 |
| "The Sun" / "Sol" | Navigate to the Sun |
| "Starbase" / "Starbase 1" | Navigate to Starbase 1 |
| "Earth" / "Home" | Navigate to Earth |
| "Moon" / "Luna" | Navigate to the Moon |

**Valid Destinations:**
Sun, Mercury, Venus, Earth, Moon, Mars, Jupiter, Saturn, Uranus, Neptune, Starbase 1

### Speed Control
| Command | Action |
|---------|--------|
| "Full impulse" | 100% impulse |
| "Half impulse" | 50% impulse |
| "Quarter impulse" | 25% impulse |
| "All stop" | Stop the ship |
| "Disengage" | Disengage autopilot |

### Other Commands
| Command | Action |
|---------|--------|
| "Raise shields" | Raise shields |
| "Lower shields" | Lower shields |
| "Orbit Earth" | Enter orbit (planned) |
| "Status" | Report ship status |

---

## JSON Command Schema

Commands sent to Godot follow this schema:

```json
{
  "department": "helm",
  "intent": "navigate",
  "target": "Jupiter",
  "warp_factor": 5,
  "impulse_percent": null,
  "maneuver": null
}
```

**Valid Intents:**
- `navigate` - Set course to destination
- `warp` - Engage warp (with target)
- `impulse` - Set impulse speed
- `stop` - All stop
- `disengage` - Disengage autopilot
- `raise_shields` / `lower_shields`
- `orbit` - Enter orbit
- `status` - Report status

---

## Configuration

All settings are in the `Config` class in `bridge_ai.py`:

```python
class Config:
    # Network
    GODOT_HOST = "127.0.0.1"
    GODOT_PORT = 5005

    # Whisper (Speech-to-Text)
    WHISPER_CPP_PATH = "/path/to/whisper-cli"
    WHISPER_MODEL = "base.en"  # or "medium.en" for accuracy

    # Ollama (Intent Parsing)
    OLLAMA_MODEL = "tinyllama"

    # Audio
    SILENCE_THRESHOLD = 500    # Adjust if not detecting speech
    SILENCE_DURATION = 1.5     # Seconds of silence before processing

    # Confidence
    MIN_CONFIDENCE = 0.3       # Lower = accept more commands
```

---

## Troubleshooting

### "Cannot connect to Ollama"
```bash
# Make sure Ollama is running
ollama serve

# Check if model is installed
ollama list
```

### "Whisper.cpp not found"
- Check the path in `Config.WHISPER_CPP_PATH`
- Make sure the binary exists: `ls ~/whisper.cpp/build/bin/whisper-cli`

### "No model found"
```bash
# Download the model
cd ~/whisper.cpp
bash ./models/download-ggml-model.sh base.en
```

### "Could not open microphone"
- macOS: System Settings → Privacy & Security → Microphone → Allow Terminal
- Make sure no other app is using the microphone

### Commands not recognized
- Speak clearly after "[LISTENING]" appears
- Reduce background noise
- Try lowering `MIN_CONFIDENCE` in config
- Use simpler phrasing: "Jupiter warp 5" instead of complex sentences

### Game not receiving commands
- Make sure the game is running before Bridge AI
- Check that port 5005 is not blocked
- Look for "[TCP] Connected to Godot" message

---

## Files

```
bridge_ai/
├── bridge_ai.py      # Main voice command system
├── requirements.txt  # Python dependencies
└── README.md         # This file

scripts/bridge_ai/
├── bridge_ai_receiver.gd      # TCP server in Godot
├── bridge_command_handler.gd  # Routes commands to ship systems
└── ship_state_manager.gd      # State machine (legacy)
```

---

## License

MIT License
