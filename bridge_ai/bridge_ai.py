#!/usr/bin/env python3
"""
=============================================================================
STAR TREK BRIDGE AI - Voice Command System
=============================================================================

This script creates a voice command system for a Star Trek game.
It listens to your voice, understands what you're saying, and sends structured
commands to the Godot game engine.

ARCHITECTURE:
    Microphone → Whisper (speech-to-text) → Gemini (intent parsing) → TCP → Godot

REQUIREMENTS:
    pip install pyaudio numpy google-generativeai

    You also need:
    - Whisper.cpp installed with the base.en model
    - Google Gemini API key (free tier: 1,500 requests/day)
      Get one at: https://aistudio.google.com/apikey

USAGE:
    1. Set GEMINI_API_KEY environment variable
    2. Start your Godot game (with TCP listener enabled)
    3. Run this script: `python bridge_ai.py`
    4. Speak commands like "Helm, set course for Mars, warp factor 5"

Author: Bridge AI System
License: MIT
=============================================================================
"""

import json
import socket
import sys
import time
import threading
import queue
import subprocess
import tempfile
import os
import wave
import struct
from typing import Optional, Dict, Any
from dataclasses import dataclass, asdict
from enum import Enum

# =============================================================================
# CONFIGURATION - Adjust these settings as needed
# =============================================================================

class Config:
    """Central configuration for the Bridge AI system."""

    # Network Settings
    GODOT_HOST = "127.0.0.1"  # localhost - Godot runs on same machine
    GODOT_PORT = 5005         # TCP port for Godot communication

    # Whisper Settings
    WHISPER_MODEL = "base.en"  # Smaller, faster model
    WHISPER_CPP_PATH = "/Users/siddharth/whisper.cpp/build/bin/whisper-cli"  # Path to whisper.cpp executable
    # Common paths: macOS Homebrew: /usr/local/bin/whisper-cpp or /opt/homebrew/bin/whisper-cpp
    # If you built from source, it might be: ~/whisper.cpp/main

    # Gemini Settings
    GEMINI_MODEL = "gemini-2.5-flash"  # Fast and free tier available

    # Audio Settings
    SAMPLE_RATE = 16000       # 16kHz - required by Whisper
    CHANNELS = 1              # Mono audio
    CHUNK_SIZE = 1024         # Audio buffer size
    SILENCE_THRESHOLD = 500   # Volume level below which is considered silence
    SILENCE_DURATION = 1.5    # Seconds of silence before processing speech
    MAX_RECORD_SECONDS = 10   # Maximum recording length

    # Confidence Settings
    MIN_CONFIDENCE = 0.3      # Minimum confidence to accept a command (0.0 - 1.0)


# =============================================================================
# DATA STRUCTURES - Define the format of commands
# =============================================================================

class Department(Enum):
    """Valid ship departments that can receive commands."""
    HELM = "helm"
    TACTICAL = "tactical"
    ENGINEERING = "engineering"
    OPS = "ops"


class Intent(Enum):
    """Valid command intents (what action to take)."""
    # Navigation / Helm
    NAVIGATE = "navigate"              # Set course to destination
    NAVIGATE_COORDINATES = "navigate_coordinates"  # Navigate to coordinates
    WARP = "warp"                      # Change warp speed (no destination)
    IMPULSE = "impulse"                # Set impulse speed
    STOP = "stop"                      # All stop / full stop
    DISENGAGE = "disengage"            # Disengage autopilot/warp
    ORBIT = "orbit"                    # Enter orbit around target
    REVERSE = "reverse"                # Reverse course/engines
    TURN = "turn"                      # Turn/rotate ship
    EVASIVE = "evasive"                # Evasive maneuvers
    DOCK = "dock"                      # Dock with station
    LAND = "land"                      # Land on planet

    # Tactical
    RAISE_SHIELDS = "raise_shields"
    LOWER_SHIELDS = "lower_shields"
    RED_ALERT = "red_alert"
    YELLOW_ALERT = "yellow_alert"
    GREEN_ALERT = "green_alert"
    FIRE = "fire"                      # Fire weapons

    # Operations
    STATUS = "status"                  # Ship status report
    DAMAGE_REPORT = "damage_report"    # Damage report
    SCAN = "scan"                      # Scan target
    HAIL = "hail"                      # Hail target
    VIEWSCREEN = "viewscreen"          # On screen


@dataclass
class BridgeCommand:
    """
    Structured command to send to Godot.

    This is the exact JSON schema that Godot expects.
    All commands must conform to this structure.
    """
    department: str           # Which department handles this (helm, tactical, etc.)
    intent: str               # What action to take (navigate, warp, etc.)
    target: Optional[str]     # Destination or target (e.g., "Mars", "Earth")
    warp_factor: Optional[float]    # Warp speed (1.0 - 9.999)
    impulse_percent: Optional[float] # Impulse as percentage (0 - 100)
    maneuver: Optional[str]   # Special maneuver (e.g., "evasive pattern alpha")

    def to_json(self) -> str:
        """Convert command to JSON string for sending over TCP."""
        return json.dumps(asdict(self))

    def is_valid(self) -> bool:
        """
        Validate that the command has all required fields and valid values.

        Returns:
            True if command is valid, False otherwise
        """
        # Check department is valid
        valid_departments = [d.value for d in Department]
        if self.department not in valid_departments:
            print(f"  [INVALID] Unknown department: {self.department}")
            return False

        # Check intent is valid
        valid_intents = [i.value for i in Intent]
        if self.intent not in valid_intents:
            print(f"  [INVALID] Unknown intent: {self.intent}")
            return False

        # Validate warp factor if present
        if self.warp_factor is not None:
            if not (0 < self.warp_factor < 10):
                print(f"  [INVALID] Warp factor must be between 0 and 10: {self.warp_factor}")
                return False

        # Validate impulse percent if present
        if self.impulse_percent is not None:
            if not (0 <= self.impulse_percent <= 100):
                print(f"  [INVALID] Impulse must be between 0 and 100: {self.impulse_percent}")
                return False

        return True


# =============================================================================
# COMMAND MEMORY - Remember context from previous commands
# =============================================================================

class CommandMemory:
    """
    Stores context from previous commands.

    This allows for follow-up commands like:
    - "Engage" (uses last set course and warp factor)
    - "Increase to warp 7" (remembers we're in warp)
    """

    def __init__(self):
        self.last_destination: Optional[str] = None
        self.last_warp_factor: Optional[float] = None
        self.last_impulse: Optional[float] = None
        self.shields_raised: bool = False
        self.at_warp: bool = False

    def update(self, command: BridgeCommand):
        """Update memory based on a successful command."""
        if command.target:
            self.last_destination = command.target

        if command.warp_factor:
            self.last_warp_factor = command.warp_factor

        if command.impulse_percent is not None:
            self.last_impulse = command.impulse_percent

        # Track warp state
        if command.intent in [Intent.WARP.value, Intent.NAVIGATE.value]:
            if command.warp_factor:
                self.at_warp = True
        elif command.intent in [Intent.STOP.value, Intent.IMPULSE.value, Intent.DISENGAGE.value, Intent.ORBIT.value]:
            self.at_warp = False

        # Track shield state
        if command.intent == Intent.RAISE_SHIELDS.value:
            self.shields_raised = True
        elif command.intent == Intent.LOWER_SHIELDS.value:
            self.shields_raised = False

    def get_context_string(self) -> str:
        """Get memory context for the LLM prompt."""
        context = []
        if self.last_destination:
            context.append(f"Last destination: {self.last_destination}")
        if self.last_warp_factor:
            context.append(f"Last warp factor: {self.last_warp_factor}")
        if self.at_warp:
            context.append("Ship is currently at warp")
        if self.shields_raised:
            context.append("Shields are currently raised")
        return "; ".join(context) if context else "No previous context"


# =============================================================================
# AUDIO RECORDING - Capture voice from microphone
# =============================================================================

class AudioRecorder:
    """
    Records audio from the microphone and detects when speech ends.

    Uses Voice Activity Detection (VAD) to automatically start/stop recording
    based on silence detection.
    """

    def __init__(self):
        self.sample_rate = Config.SAMPLE_RATE
        self.channels = Config.CHANNELS
        self.chunk_size = Config.CHUNK_SIZE
        self.audio_queue = queue.Queue()
        self.is_recording = False

        # Try to import pyaudio
        try:
            import pyaudio
            self.pyaudio = pyaudio
            self.pa = pyaudio.PyAudio()
        except ImportError:
            print("ERROR: pyaudio not installed. Install with: pip install pyaudio")
            print("  On macOS: brew install portaudio && pip install pyaudio")
            print("  On Ubuntu: sudo apt-get install portaudio19-dev && pip install pyaudio")
            sys.exit(1)

    def _get_volume(self, data: bytes) -> float:
        """Calculate the volume (RMS) of an audio chunk."""
        # Convert bytes to integers
        count = len(data) // 2
        shorts = struct.unpack(f"{count}h", data)

        # Calculate RMS (Root Mean Square)
        sum_squares = sum(s * s for s in shorts)
        rms = (sum_squares / count) ** 0.5
        return rms

    def record_until_silence(self) -> Optional[bytes]:
        """
        Record audio until the user stops speaking.

        Returns:
            Raw audio bytes, or None if recording failed
        """
        print("\n[LISTENING] Speak your command...")

        try:
            stream = self.pa.open(
                format=self.pyaudio.paInt16,
                channels=self.channels,
                rate=self.sample_rate,
                input=True,
                frames_per_buffer=self.chunk_size
            )
        except Exception as e:
            print(f"ERROR: Could not open microphone: {e}")
            return None

        frames = []
        silence_chunks = 0
        speech_started = False
        chunks_for_silence = int(Config.SILENCE_DURATION * self.sample_rate / self.chunk_size)
        max_chunks = int(Config.MAX_RECORD_SECONDS * self.sample_rate / self.chunk_size)

        try:
            for _ in range(max_chunks):
                data = stream.read(self.chunk_size, exception_on_overflow=False)
                volume = self._get_volume(data)

                if volume > Config.SILENCE_THRESHOLD:
                    # Speech detected
                    speech_started = True
                    silence_chunks = 0
                    frames.append(data)
                elif speech_started:
                    # Silence after speech
                    frames.append(data)
                    silence_chunks += 1

                    if silence_chunks >= chunks_for_silence:
                        # Enough silence - stop recording
                        break
        finally:
            stream.stop_stream()
            stream.close()

        if not frames:
            print("  [NO AUDIO] No speech detected")
            return None

        print(f"  [RECORDED] {len(frames) * self.chunk_size / self.sample_rate:.1f} seconds")
        return b''.join(frames)

    def save_to_wav(self, audio_data: bytes, filepath: str):
        """Save raw audio bytes to a WAV file."""
        with wave.open(filepath, 'wb') as wf:
            wf.setnchannels(self.channels)
            wf.setsampwidth(2)  # 16-bit = 2 bytes
            wf.setframerate(self.sample_rate)
            wf.writeframes(audio_data)

    def cleanup(self):
        """Release audio resources."""
        self.pa.terminate()


# =============================================================================
# SPEECH-TO-TEXT - Convert audio to text using Whisper.cpp
# =============================================================================

class WhisperTranscriber:
    """
    Transcribes audio to text using Whisper.cpp.

    Whisper.cpp is a C++ implementation of OpenAI's Whisper model that runs
    entirely offline on your local machine.
    """

    def __init__(self):
        self.model = Config.WHISPER_MODEL
        self.whisper_path = Config.WHISPER_CPP_PATH

        # Try to find whisper.cpp
        self._find_whisper()

    def _find_whisper(self):
        """Locate the whisper.cpp executable."""
        # Common installation paths
        possible_paths = [
            Config.WHISPER_CPP_PATH,
            "/Users/siddharth/whisper.cpp/main",
            "/Users/siddharth/whisper.cpp/build/bin/main",
            "/usr/local/bin/whisper-cpp",
            "/opt/homebrew/bin/whisper-cpp",
            os.path.expanduser("~/whisper.cpp/main"),
            os.path.expanduser("~/whisper.cpp/build/bin/main"),
        ]

        for path in possible_paths:
            expanded_path = os.path.expanduser(path)
            if os.path.isfile(expanded_path):
                self.whisper_path = expanded_path
                print(f"[WHISPER] Found at: {expanded_path}")
                return

        print("WARNING: whisper.cpp not found. Speech-to-text may not work.")
        print("  Checked paths:")
        for p in possible_paths:
            print(f"    - {os.path.expanduser(p)}")
        print("  Install with: brew install whisper-cpp (macOS)")
        print("  Or build from: https://github.com/ggerganov/whisper.cpp")

    def _command_exists(self, cmd: str) -> bool:
        """Check if a command exists in PATH."""
        try:
            subprocess.run([cmd, "--help"], capture_output=True, timeout=5)
            return True
        except:
            return False

    def _find_model_path(self) -> Optional[str]:
        """Find the Whisper model file."""
        model_filename = f"ggml-{self.model}.bin"

        possible_paths = [
            os.path.expanduser(f"~/.cache/whisper/{model_filename}"),
            os.path.expanduser(f"~/whisper.cpp/models/{model_filename}"),
            f"/usr/local/share/whisper/{model_filename}",
            f"/opt/homebrew/share/whisper/{model_filename}",
            os.path.join(os.path.dirname(self.whisper_path), "models", model_filename),
        ]

        for path in possible_paths:
            if os.path.isfile(path):
                return path

        return None

    def transcribe(self, audio_data: bytes) -> Optional[str]:
        """
        Transcribe audio data to text.

        Args:
            audio_data: Raw audio bytes (16-bit PCM, 16kHz, mono)

        Returns:
            Transcribed text, or None if transcription failed
        """
        print("[TRANSCRIBING] Converting speech to text...")

        # Save audio to temporary file
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
            tmp_path = tmp.name

        try:
            # Save audio as WAV
            with wave.open(tmp_path, 'wb') as wf:
                wf.setnchannels(Config.CHANNELS)
                wf.setsampwidth(2)
                wf.setframerate(Config.SAMPLE_RATE)
                wf.writeframes(audio_data)

            # Find model
            model_path = self._find_model_path()

            # Build whisper.cpp command
            cmd = [self.whisper_path]

            if model_path:
                cmd.extend(["-m", model_path])
            else:
                print("  [ERROR] No model found!")
                return None

            cmd.extend([
                "-f", tmp_path,
                "--no-timestamps",
                "-l", "en",  # English
            ])

            # Run whisper.cpp
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=30
            )

            if result.returncode != 0:
                print(f"  [ERROR] Whisper failed (code {result.returncode})")
                print(f"  [STDERR] {result.stderr}")
                print(f"  [STDOUT] {result.stdout}")
                return None

            # Parse output
            text = result.stdout.strip()

            # Clean up the text
            text = text.replace("[BLANK_AUDIO]", "").strip()

            if not text:
                print("  [EMPTY] No speech recognized")
                return None

            print(f"  [HEARD] \"{text}\"")
            return text

        except subprocess.TimeoutExpired:
            print("  [ERROR] Whisper timed out")
            return None
        except Exception as e:
            print(f"  [ERROR] Transcription failed: {e}")
            return None
        finally:
            # Clean up temp file
            if os.path.exists(tmp_path):
                os.remove(tmp_path)


# =============================================================================
# INTENT PARSER - Convert text to structured commands using Google Gemini
# =============================================================================
#
# ROLLBACK TO OLLAMA (for offline mode):
# To switch back to local Ollama instead of Gemini:
# 1. pip install ollama
# 2. In Config class, replace GEMINI_MODEL with:
#    OLLAMA_MODEL = "tinyllama"
#    OLLAMA_HOST = "http://localhost:11434"
# 3. Replace _init_gemini() with Ollama connection test
# 4. Replace generate_content() call with ollama.chat()
# 5. Start Ollama with: ollama serve
#
# NOTE: Model names change over time. If you get a 404 error, check
# https://ai.google.dev/gemini-api/docs/models for current model names.
# =============================================================================

class IntentParser:
    """
    Parses natural language commands into structured JSON using Google Gemini.

    Gemini provides fast, accurate intent parsing with a generous free tier
    (1,500 requests/day).
    """

    def __init__(self, memory: CommandMemory):
        self.memory = memory
        self.model_name = Config.GEMINI_MODEL

        # Try to import google-generativeai
        try:
            import google.generativeai as genai
            self.genai = genai
        except ImportError:
            print("ERROR: google-generativeai not installed.")
            print("  Install with: pip3 install google-generativeai")
            sys.exit(1)

        # Initialize Gemini
        self._init_gemini()

    def _init_gemini(self):
        """Initialize the Gemini API client."""
        api_key = os.environ.get("GEMINI_API_KEY")
        if not api_key:
            print("ERROR: GEMINI_API_KEY environment variable not set.")
            print("  1. Get an API key at: https://aistudio.google.com/apikey")
            print("  2. Set it with: export GEMINI_API_KEY='your-key-here'")
            sys.exit(1)

        try:
            self.genai.configure(api_key=api_key)
            self.model = self.genai.GenerativeModel(self.model_name)
            print(f"[GEMINI] Connected, using model: {self.model_name}")
        except Exception as e:
            print(f"ERROR: Cannot initialize Gemini: {e}")
            sys.exit(1)

    def _build_system_prompt(self) -> str:
        """Comprehensive prompt for Star Trek command parsing."""
        return """You are a Star Trek starship computer parsing voice commands into JSON.

Output ONLY valid JSON in this format:
{"department":"helm","intent":"navigate","target":"Jupiter","warp_factor":5,"impulse_percent":null,"maneuver":null,"confidence":0.9}

VALID INTENTS:
- navigate: Set course to a destination (requires target, optional warp_factor)
- warp: Change warp speed only (requires warp_factor, no target)
- impulse: Set impulse speed (requires impulse_percent: 0-100)
- stop: All stop / full stop / drop out of warp
- disengage: Disengage autopilot or current course
- orbit: Enter orbit around target (requires target)
- raise_shields: Raise shields / shields up
- lower_shields: Lower shields / shields down
- red_alert: Red alert
- yellow_alert: Yellow alert
- green_alert: Green alert / stand down
- scan: Scan a target (requires target)
- status: Ship status report
- damage_report: Damage report
- hail: Hail a target (requires target)
- fire: Fire weapons at target (requires target)
- evasive: Evasive maneuvers (optional maneuver name)
- reverse: Reverse course/engines
- dock: Dock with station/target
- land: Land on planet/target

VALID TARGETS (planets/locations):
Sun, Mercury, Venus, Earth, Moon, Mars, Jupiter, Saturn, Uranus, Neptune, Pluto, Starbase 1, Starbase, Deep Space Nine, DS9

NAVIGATION EXAMPLES:
"set course for jupiter warp 5" → {"department":"helm","intent":"navigate","target":"Jupiter","warp_factor":5}
"take us to mars" → {"department":"helm","intent":"navigate","target":"Mars","warp_factor":5}
"head to earth" → {"department":"helm","intent":"navigate","target":"Earth","warp_factor":5}
"plot a course to saturn" → {"department":"helm","intent":"navigate","target":"Saturn","warp_factor":5}
"lay in a course for neptune warp 8" → {"department":"helm","intent":"navigate","target":"Neptune","warp_factor":8}
"let's go to jupiter" → {"department":"helm","intent":"navigate","target":"Jupiter","warp_factor":5}
"let's go home" → {"department":"helm","intent":"navigate","target":"Earth","warp_factor":5}
"take me home" → {"department":"helm","intent":"navigate","target":"Earth","warp_factor":5}
"back to earth" → {"department":"helm","intent":"navigate","target":"Earth","warp_factor":5}

WARP SPEED EXAMPLES (changing speed without destination):
"warp 9" → {"department":"helm","intent":"warp","warp_factor":9}
"warp factor 7" → {"department":"helm","intent":"warp","warp_factor":7}
"increase speed to warp 9" → {"department":"helm","intent":"warp","warp_factor":9}
"increase to warp 8" → {"department":"helm","intent":"warp","warp_factor":8}
"speed up to warp 6" → {"department":"helm","intent":"warp","warp_factor":6}
"faster" → {"department":"helm","intent":"warp","warp_factor":7}
"maximum warp" → {"department":"helm","intent":"warp","warp_factor":9.9}
"warp speed" → {"department":"helm","intent":"warp","warp_factor":5}
"engage warp drive" → {"department":"helm","intent":"warp","warp_factor":5}
"punch it" → {"department":"helm","intent":"warp","warp_factor":9}
"hit it" → {"department":"helm","intent":"warp","warp_factor":9}
"engage" → {"department":"helm","intent":"warp","warp_factor":5}
"make it so" → {"department":"helm","intent":"warp","warp_factor":5}
"energize" → {"department":"helm","intent":"warp","warp_factor":5}
"ahead warp factor 5" → {"department":"helm","intent":"warp","warp_factor":5}
"slow to warp 2" → {"department":"helm","intent":"warp","warp_factor":2}
"reduce speed to warp 3" → {"department":"helm","intent":"warp","warp_factor":3}

IMPULSE EXAMPLES:
"full impulse" → {"department":"helm","intent":"impulse","impulse_percent":100}
"half impulse" → {"department":"helm","intent":"impulse","impulse_percent":50}
"quarter impulse" → {"department":"helm","intent":"impulse","impulse_percent":25}
"one quarter impulse" → {"department":"helm","intent":"impulse","impulse_percent":25}
"three quarter impulse" → {"department":"helm","intent":"impulse","impulse_percent":75}
"impulse power" → {"department":"helm","intent":"impulse","impulse_percent":50}
"ahead one third" → {"department":"helm","intent":"impulse","impulse_percent":33}
"ahead two thirds" → {"department":"helm","intent":"impulse","impulse_percent":66}
"ahead full" → {"department":"helm","intent":"impulse","impulse_percent":100}
"thrusters only" → {"department":"helm","intent":"impulse","impulse_percent":10}

STOP/DISENGAGE EXAMPLES:
"all stop" → {"department":"helm","intent":"stop"}
"full stop" → {"department":"helm","intent":"stop"}
"stop" → {"department":"helm","intent":"stop"}
"hold position" → {"department":"helm","intent":"stop"}
"drop out of warp" → {"department":"helm","intent":"stop"}
"exit warp" → {"department":"helm","intent":"stop"}
"disengage" → {"department":"helm","intent":"disengage"}
"disengage autopilot" → {"department":"helm","intent":"disengage"}
"cancel course" → {"department":"helm","intent":"disengage"}
"abort" → {"department":"helm","intent":"disengage"}

ORBIT EXAMPLES:
"orbit earth" → {"department":"helm","intent":"orbit","target":"Earth"}
"standard orbit" → {"department":"helm","intent":"orbit"}
"enter orbit" → {"department":"helm","intent":"orbit"}
"establish orbit around mars" → {"department":"helm","intent":"orbit","target":"Mars"}
"geosynchronous orbit" → {"department":"helm","intent":"orbit"}

TACTICAL EXAMPLES:
"raise shields" → {"department":"tactical","intent":"raise_shields"}
"shields up" → {"department":"tactical","intent":"raise_shields"}
"lower shields" → {"department":"tactical","intent":"lower_shields"}
"shields down" → {"department":"tactical","intent":"lower_shields"}
"red alert" → {"department":"tactical","intent":"red_alert"}
"yellow alert" → {"department":"tactical","intent":"yellow_alert"}
"green alert" → {"department":"tactical","intent":"green_alert"}
"stand down" → {"department":"tactical","intent":"green_alert"}
"battle stations" → {"department":"tactical","intent":"red_alert"}
"fire phasers" → {"department":"tactical","intent":"fire","target":"enemy"}
"fire torpedoes" → {"department":"tactical","intent":"fire","target":"enemy"}
"target that ship" → {"department":"tactical","intent":"fire","target":"enemy"}
"evasive maneuvers" → {"department":"helm","intent":"evasive"}
"evasive pattern alpha" → {"department":"helm","intent":"evasive","maneuver":"alpha"}
"evasive pattern delta" → {"department":"helm","intent":"evasive","maneuver":"delta"}

OPS/ENGINEERING EXAMPLES:
"status" → {"department":"ops","intent":"status"}
"status report" → {"department":"ops","intent":"status"}
"ship status" → {"department":"ops","intent":"status"}
"report" → {"department":"ops","intent":"status"}
"damage report" → {"department":"engineering","intent":"damage_report"}
"scan jupiter" → {"department":"ops","intent":"scan","target":"Jupiter"}
"scan for life signs" → {"department":"ops","intent":"scan","target":"life signs"}
"hail them" → {"department":"ops","intent":"hail","target":"them"}
"hail starbase" → {"department":"ops","intent":"hail","target":"Starbase 1"}
"open a channel" → {"department":"ops","intent":"hail"}
"on screen" → {"department":"ops","intent":"viewscreen"}

MISC EXAMPLES:
"reverse" → {"department":"helm","intent":"reverse"}
"reverse engines" → {"department":"helm","intent":"reverse"}
"back us off" → {"department":"helm","intent":"reverse"}
"dock with the station" → {"department":"helm","intent":"dock","target":"Starbase 1"}
"land on mars" → {"department":"helm","intent":"land","target":"Mars"}

ALWAYS output valid JSON. No explanation text. confidence should be 0.0-1.0 based on how well you understood the command."""

    def _try_pattern_match(self, text: str) -> Optional[BridgeCommand]:
        """Try to match common commands without using the LLM (faster)."""
        import re
        text_lower = text.lower().strip().rstrip('.').rstrip(',').rstrip('!')

        # Valid destinations for navigation
        valid_targets = {
            "sun": "Sun", "the sun": "Sun", "sol": "Sun",
            "mercury": "Mercury",
            "venus": "Venus",
            "earth": "Earth", "terra": "Earth", "home": "Earth",
            "moon": "Moon", "the moon": "Moon", "luna": "Moon",
            "mars": "Mars",
            "jupiter": "Jupiter",
            "saturn": "Saturn",
            "uranus": "Uranus",
            "neptune": "Neptune",
            "pluto": "Pluto",
            "starbase": "Starbase 1", "starbase 1": "Starbase 1", "starbase one": "Starbase 1",
            "spacedock": "Starbase 1", "space dock": "Starbase 1",
            "deep space nine": "Deep Space Nine", "deep space 9": "Deep Space Nine", "ds9": "Deep Space Nine",
        }

        # =====================================================================
        # WARP SPEED COMMANDS (no destination, just speed change)
        # =====================================================================

        # "warp [number]", "warp factor [number]", "warp speed [number]"
        warp_match = re.search(r'warp\s*(?:factor\s*|speed\s*)?(\d+(?:\.\d+)?)', text_lower)

        # "increase/raise/change speed to warp [number]"
        increase_warp = re.search(r'(?:increase|raise|change|set|adjust)\s+(?:speed\s+)?to\s+warp\s*(\d+(?:\.\d+)?)', text_lower)
        if increase_warp:
            return BridgeCommand("helm", "warp", None, float(increase_warp.group(1)), None, None)

        # "increase to warp [number]"
        increase_warp2 = re.search(r'increase\s+to\s+warp\s*(\d+(?:\.\d+)?)', text_lower)
        if increase_warp2:
            return BridgeCommand("helm", "warp", None, float(increase_warp2.group(1)), None, None)

        # "slow/reduce to warp [number]"
        slow_warp = re.search(r'(?:slow|reduce|decrease)\s+(?:speed\s+)?to\s+warp\s*(\d+(?:\.\d+)?)', text_lower)
        if slow_warp:
            return BridgeCommand("helm", "warp", None, float(slow_warp.group(1)), None, None)

        # "ahead warp factor [number]"
        ahead_warp = re.search(r'ahead\s+warp\s*(?:factor\s*)?(\d+(?:\.\d+)?)', text_lower)
        if ahead_warp:
            return BridgeCommand("helm", "warp", None, float(ahead_warp.group(1)), None, None)

        # Star Trek catchphrases
        if text_lower in ["punch it", "hit it"]:
            return BridgeCommand("helm", "warp", None, 9.0, None, None)
        if text_lower in ["engage", "make it so", "energize"]:
            return BridgeCommand("helm", "warp", None, 5.0, None, None)
        if text_lower in ["maximum warp", "max warp"]:
            return BridgeCommand("helm", "warp", None, 9.9, None, None)
        if text_lower in ["warp speed", "engage warp", "engage warp drive"]:
            return BridgeCommand("helm", "warp", None, 5.0, None, None)
        if text_lower == "faster":
            return BridgeCommand("helm", "warp", None, 7.0, None, None)

        # Simple "warp [number]" without destination context
        if warp_match and not any(t in text_lower for t in valid_targets.keys()):
            # Make sure this isn't a navigation command
            nav_words = ["course", "head", "take", "go to", "set", "plot", "lay"]
            if not any(w in text_lower for w in nav_words):
                return BridgeCommand("helm", "warp", None, float(warp_match.group(1)), None, None)

        # =====================================================================
        # IMPULSE COMMANDS
        # =====================================================================
        if "full impulse" in text_lower or "ahead full" in text_lower:
            return BridgeCommand("helm", "impulse", None, None, 100, None)
        if "half impulse" in text_lower:
            return BridgeCommand("helm", "impulse", None, None, 50, None)
        if "quarter impulse" in text_lower or "one quarter impulse" in text_lower:
            return BridgeCommand("helm", "impulse", None, None, 25, None)
        if "three quarter impulse" in text_lower:
            return BridgeCommand("helm", "impulse", None, None, 75, None)
        if "ahead one third" in text_lower or "one third impulse" in text_lower:
            return BridgeCommand("helm", "impulse", None, None, 33, None)
        if "ahead two thirds" in text_lower or "two thirds impulse" in text_lower:
            return BridgeCommand("helm", "impulse", None, None, 66, None)
        if text_lower in ["impulse", "impulse power", "impulse speed"]:
            return BridgeCommand("helm", "impulse", None, None, 50, None)
        if "thrusters only" in text_lower or "thrusters" in text_lower:
            return BridgeCommand("helm", "impulse", None, None, 10, None)

        # =====================================================================
        # STOP / DISENGAGE COMMANDS
        # =====================================================================
        stop_phrases = ["all stop", "stop", "full stop", "hold position", "holding position",
                        "drop out of warp", "exit warp", "come out of warp"]
        if text_lower in stop_phrases or any(p in text_lower for p in ["drop out of warp", "exit warp"]):
            return BridgeCommand("helm", "stop", None, None, None, None)

        disengage_phrases = ["disengage", "cancel course", "abort", "disengage autopilot"]
        if text_lower in disengage_phrases or "disengage" in text_lower:
            return BridgeCommand("helm", "disengage", None, None, None, None)

        # =====================================================================
        # REVERSE COMMANDS
        # =====================================================================
        if text_lower in ["reverse", "reverse engines", "back up", "back us off", "full reverse"]:
            return BridgeCommand("helm", "reverse", None, None, None, None)

        # =====================================================================
        # SHIELD COMMANDS
        # =====================================================================
        if "raise shields" in text_lower or "shields up" in text_lower:
            return BridgeCommand("tactical", "raise_shields", None, None, None, None)
        if "lower shields" in text_lower or "shields down" in text_lower:
            return BridgeCommand("tactical", "lower_shields", None, None, None, None)

        # =====================================================================
        # ALERT COMMANDS
        # =====================================================================
        if "red alert" in text_lower or "battle stations" in text_lower:
            return BridgeCommand("tactical", "red_alert", None, None, None, None)
        if "yellow alert" in text_lower:
            return BridgeCommand("tactical", "yellow_alert", None, None, None, None)
        if "green alert" in text_lower or text_lower == "stand down":
            return BridgeCommand("tactical", "green_alert", None, None, None, None)

        # =====================================================================
        # STATUS / REPORT COMMANDS
        # =====================================================================
        if text_lower in ["status", "status report", "report", "ship status"]:
            return BridgeCommand("ops", "status", None, None, None, None)
        if "damage report" in text_lower:
            return BridgeCommand("engineering", "damage_report", None, None, None, None)

        # =====================================================================
        # ORBIT COMMANDS
        # =====================================================================
        if text_lower in ["standard orbit", "enter orbit", "establish orbit", "orbit"]:
            return BridgeCommand("helm", "orbit", None, None, None, None)

        orbit_match = re.search(r'(?:orbit|enter orbit around|establish orbit around)\s+(\w+(?:\s+\w+)?)', text_lower)
        if orbit_match:
            target_text = orbit_match.group(1).lower()
            target = valid_targets.get(target_text, target_text.capitalize())
            return BridgeCommand("helm", "orbit", target, None, None, None)

        # =====================================================================
        # SCAN COMMANDS
        # =====================================================================
        scan_match = re.search(r'scan\s+(.+)', text_lower)
        if scan_match:
            target_text = scan_match.group(1).strip()
            target = valid_targets.get(target_text, target_text.capitalize())
            return BridgeCommand("ops", "scan", target, None, None, None)

        # =====================================================================
        # EVASIVE MANEUVERS
        # =====================================================================
        if text_lower == "evasive maneuvers" or text_lower == "evasive":
            return BridgeCommand("helm", "evasive", None, None, None, None)
        evasive_match = re.search(r'evasive\s+(?:pattern\s+)?(\w+)', text_lower)
        if evasive_match:
            maneuver = evasive_match.group(1)
            return BridgeCommand("helm", "evasive", None, None, None, maneuver)

        # =====================================================================
        # HAIL COMMANDS
        # =====================================================================
        if text_lower in ["hail them", "open a channel", "on screen", "open channel"]:
            return BridgeCommand("ops", "hail", None, None, None, None)
        hail_match = re.search(r'hail\s+(.+)', text_lower)
        if hail_match:
            target_text = hail_match.group(1).strip()
            target = valid_targets.get(target_text, target_text.capitalize())
            return BridgeCommand("ops", "hail", target, None, None, None)

        # =====================================================================
        # FIRE COMMANDS
        # =====================================================================
        if "fire phasers" in text_lower or "fire torpedoes" in text_lower or "open fire" in text_lower:
            return BridgeCommand("tactical", "fire", "enemy", None, None, None)
        fire_match = re.search(r'(?:fire|target|fire at|fire on)\s+(.+)', text_lower)
        if fire_match:
            target = fire_match.group(1).strip().capitalize()
            return BridgeCommand("tactical", "fire", target, None, None, None)

        # =====================================================================
        # DOCK / LAND COMMANDS
        # =====================================================================
        if "dock" in text_lower:
            dock_match = re.search(r'dock\s+(?:with\s+)?(?:the\s+)?(.+)', text_lower)
            if dock_match:
                target_text = dock_match.group(1).strip().lower()
                target = valid_targets.get(target_text, target_text.capitalize())
                return BridgeCommand("helm", "dock", target, None, None, None)
            return BridgeCommand("helm", "dock", "Starbase 1", None, None, None)

        land_match = re.search(r'land\s+(?:on\s+)?(?:the\s+)?(.+)', text_lower)
        if land_match:
            target_text = land_match.group(1).strip().lower()
            target = valid_targets.get(target_text, target_text.capitalize())
            return BridgeCommand("helm", "land", target, None, None, None)

        # =====================================================================
        # NAVIGATION COMMANDS (with destination)
        # =====================================================================

        # "let's go home" / "take me home" / "back to earth"
        if "go home" in text_lower or "take me home" in text_lower or "back to earth" in text_lower:
            return BridgeCommand("helm", "navigate", "Earth", 5.0, None, None)

        # Complex navigation patterns
        nav_patterns = [
            # "set course for X warp Y" / "plot a course to X"
            r"(?:set|plot|lay\s+in)\s+(?:a\s+)?course\s+(?:for|to)\s+(?:the\s+)?(\w+(?:\s+\w+)?)(?:.*warp\s*(?:factor\s*)?(\d+(?:\.\d+)?))?",
            # "course to X"
            r"course\s+(?:for|to)\s+(?:the\s+)?(\w+(?:\s+\w+)?)(?:.*warp\s*(?:factor\s*)?(\d+(?:\.\d+)?))?",
            # "take us to X" / "head to X" / "go to X" / "let's go to X"
            r"(?:take\s+us\s+to|head\s+(?:for|to)|go\s+to|let'?s\s+go\s+to)\s+(?:the\s+)?(\w+(?:\s+\w+)?)(?:.*warp\s*(?:factor\s*)?(\d+(?:\.\d+)?))?",
            # "X warp Y" (destination then warp)
            r"^(\w+(?:\s+\w+)?)\s+warp\s*(?:factor\s*)?(\d+(?:\.\d+)?)",
            # Just destination name if it's a valid target
            r"^(?:the\s+)?(\w+(?:\s+\w+)?)\s*$",
        ]

        for pattern in nav_patterns:
            match = re.search(pattern, text_lower)
            if match:
                target_text = match.group(1).strip().lower()
                warp = float(match.group(2)) if match.lastindex >= 2 and match.group(2) else 5.0

                # Check if target is valid
                if target_text in valid_targets:
                    target = valid_targets[target_text]
                    return BridgeCommand("helm", "navigate", target, warp, None, None)

        return None

    def parse(self, text: str) -> Optional[BridgeCommand]:
        """
        Parse natural language text into a structured command.

        Args:
            text: The transcribed voice command

        Returns:
            BridgeCommand if parsing succeeded, None otherwise
        """
        print("[PARSING] Interpreting command...")

        # Try fast pattern matching first
        quick_match = self._try_pattern_match(text)
        if quick_match:
            print("  [QUICK MATCH] Recognized common command")
            return quick_match

        # Build the prompt with context
        context = self.memory.get_context_string()
        system_prompt = self._build_system_prompt()
        full_prompt = f"{system_prompt}\n\nContext: {context}\n\nCommand: \"{text}\"\n\nJSON:"

        try:
            # Call Gemini API
            response = self.model.generate_content(
                full_prompt,
                generation_config=self.genai.types.GenerationConfig(
                    temperature=0.1,  # Low temperature for consistent output
                    max_output_tokens=150,  # Limit response length
                )
            )

            # Extract the response text
            response_text = response.text.strip()

            # Try to extract JSON from response
            json_data = self._extract_json(response_text)

            if not json_data:
                print(f"  [ERROR] Could not parse JSON from: {response_text}")
                return None

            # Check confidence (convert to float if string)
            confidence = json_data.get('confidence', 0.5)
            try:
                confidence = float(confidence) if confidence else 0.5
            except (ValueError, TypeError):
                confidence = 0.5

            if confidence < Config.MIN_CONFIDENCE:
                print(f"  [LOW CONFIDENCE] {confidence:.2f} < {Config.MIN_CONFIDENCE}")
                print("  Please repeat your command more clearly.")
                return None

            print(f"  [CONFIDENCE] {confidence:.2f}")

            # Normalize intent (LLM sometimes returns variations)
            intent = json_data.get('intent', 'stop')
            intent_map = {
                # Navigation variations
                'navigation': 'navigate',
                'set_course': 'navigate',
                'course': 'navigate',
                'go_to': 'navigate',
                'goto': 'navigate',
                'head_to': 'navigate',
                'take_us_to': 'navigate',
                'plot_course': 'navigate',
                'lay_in_course': 'navigate',
                # Warp variations
                'engage': 'warp',
                'engage_warp': 'warp',
                'warp_speed': 'warp',
                'increase_speed': 'warp',
                'change_speed': 'warp',
                # Stop variations
                'full_stop': 'stop',
                'all_stop': 'stop',
                'halt': 'stop',
                'hold': 'stop',
                'hold_position': 'stop',
                'drop_out': 'stop',
                'exit_warp': 'stop',
                # Shield variations
                'shields_up': 'raise_shields',
                'shields_down': 'lower_shields',
                # Orbit variations
                'enter_orbit': 'orbit',
                'standard_orbit': 'orbit',
                'establish_orbit': 'orbit',
                # Status variations
                'report': 'status',
                'ship_status': 'status',
                'status_report': 'status',
                # Alert variations
                'battlestations': 'red_alert',
                'battle_stations': 'red_alert',
                'condition_red': 'red_alert',
                'condition_yellow': 'yellow_alert',
                'condition_green': 'green_alert',
                'stand_down': 'green_alert',
                # Evasive variations
                'evasive_maneuvers': 'evasive',
                'evasive_action': 'evasive',
                # Hail variations
                'open_channel': 'hail',
                'hail_ship': 'hail',
                'on_screen': 'viewscreen',
                'onscreen': 'viewscreen',
                # Fire variations
                'attack': 'fire',
                'fire_weapons': 'fire',
                'fire_phasers': 'fire',
                'fire_torpedoes': 'fire',
            }
            intent = intent_map.get(intent, intent)

            # Normalize target names
            target = json_data.get('target')
            if target:
                target_map = {
                    'sol': 'Sun',
                    'the sun': 'Sun',
                    'terra': 'Earth',
                    'home': 'Earth',
                    'luna': 'Moon',
                    'the moon': 'Moon',
                    'starbase one': 'Starbase 1',
                    'starbase': 'Starbase 1',
                    'spacedock': 'Starbase 1',
                    'space dock': 'Starbase 1',
                    'deep space nine': 'Deep Space Nine',
                    'deep space 9': 'Deep Space Nine',
                    'ds9': 'Deep Space Nine',
                }
                target_lower = target.lower()
                target = target_map.get(target_lower, target.capitalize())
                json_data['target'] = target

            # Create command object
            command = BridgeCommand(
                department=json_data.get('department', 'helm'),
                intent=intent,
                target=json_data.get('target'),
                warp_factor=json_data.get('warp_factor'),
                impulse_percent=json_data.get('impulse_percent'),
                maneuver=json_data.get('maneuver')
            )

            return command

        except Exception as e:
            print(f"  [ERROR] Gemini request failed: {e}")
            return None

    def _extract_json(self, text: str) -> Optional[Dict[str, Any]]:
        """
        Extract JSON from the LLM response.

        The LLM might include extra text, so we try to find and parse the JSON.
        """
        # First, try parsing the whole thing
        try:
            return json.loads(text)
        except json.JSONDecodeError:
            pass

        # Try to find JSON in the text
        start_idx = text.find('{')
        end_idx = text.rfind('}')

        if start_idx != -1 and end_idx != -1:
            try:
                return json.loads(text[start_idx:end_idx + 1])
            except json.JSONDecodeError:
                pass

        return None


# =============================================================================
# TCP CLIENT - Send commands to Godot
# =============================================================================

class GodotClient:
    """
    TCP client for communicating with the Godot game.

    Sends JSON commands and waits for acknowledgment.
    """

    def __init__(self):
        self.host = Config.GODOT_HOST
        self.port = Config.GODOT_PORT
        self.socket: Optional[socket.socket] = None
        self.connected = False

    def connect(self) -> bool:
        """
        Connect to the Godot TCP server.

        Returns:
            True if connected successfully, False otherwise
        """
        try:
            self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.socket.settimeout(5.0)
            self.socket.connect((self.host, self.port))
            self.connected = True
            print(f"[TCP] Connected to Godot at {self.host}:{self.port}")
            return True
        except socket.error as e:
            print(f"[TCP] Could not connect to Godot: {e}")
            print("  Make sure the game is running with the TCP listener enabled.")
            self.connected = False
            return False

    def send_command(self, command: BridgeCommand) -> bool:
        """
        Send a command to Godot and wait for acknowledgment.

        Args:
            command: The validated command to send

        Returns:
            True if command was sent and acknowledged, False otherwise
        """
        if not self.connected:
            if not self.connect():
                return False

        try:
            # Convert command to JSON
            json_str = command.to_json()

            # Send with newline delimiter
            message = json_str + "\n"
            self.socket.sendall(message.encode('utf-8'))

            print(f"[SENT] {json_str}")

            # Wait for acknowledgment
            self.socket.settimeout(5.0)
            response = self.socket.recv(1024).decode('utf-8').strip()

            if response:
                print(f"[ACK] {response}")
                return True
            else:
                print("[ACK] Empty response")
                return True

        except socket.timeout:
            print("[TCP] Timeout waiting for acknowledgment")
            return False
        except socket.error as e:
            print(f"[TCP] Connection error: {e}")
            self.connected = False
            return False

    def disconnect(self):
        """Close the connection to Godot."""
        if self.socket:
            try:
                self.socket.close()
            except:
                pass
        self.connected = False
        print("[TCP] Disconnected")


# =============================================================================
# MAIN BRIDGE AI SYSTEM
# =============================================================================

class BridgeAI:
    """
    Main Bridge AI system that coordinates all components.

    This is the central controller that:
    1. Listens for voice input
    2. Transcribes speech to text
    3. Parses text into commands
    4. Validates and sends commands to Godot
    """

    def __init__(self):
        print("=" * 60)
        print("STAR TREK BRIDGE AI - Initializing...")
        print("=" * 60)

        # Initialize components
        self.memory = CommandMemory()
        self.recorder = AudioRecorder()
        self.transcriber = WhisperTranscriber()
        self.parser = IntentParser(self.memory)
        self.godot = GodotClient()

        self.running = False

        print("=" * 60)
        print("Bridge AI Ready!")
        print("=" * 60)

    def process_voice_command(self) -> bool:
        """
        Process a single voice command through the entire pipeline.

        Returns:
            True if a command was successfully processed, False otherwise
        """
        # Step 1: Record audio
        audio_data = self.recorder.record_until_silence()
        if not audio_data:
            return False

        # Step 2: Transcribe to text
        text = self.transcriber.transcribe(audio_data)
        if not text:
            return False

        # Step 3: Parse into command
        command = self.parser.parse(text)
        if not command:
            return False

        # Step 4: Validate command
        print("[VALIDATING] Checking command structure...")
        if not command.is_valid():
            print("  Please rephrase your command.")
            return False

        print(f"  [VALID] {command.department} → {command.intent}")

        # Step 5: Send to Godot
        if self.godot.send_command(command):
            # Update memory on success
            self.memory.update(command)
            print("[SUCCESS] Command executed!")
            return True
        else:
            print("[FAILED] Could not send to Godot")
            return False

    def run(self):
        """
        Main loop - continuously listen for and process commands.

        Press Ctrl+C to stop.
        """
        self.running = True

        print("\n" + "=" * 60)
        print("BRIDGE AI ACTIVE - Listening for commands...")
        print("Press Ctrl+C to stop")
        print("=" * 60)

        # Try to connect to Godot at startup
        self.godot.connect()

        try:
            while self.running:
                try:
                    self.process_voice_command()
                    time.sleep(0.5)  # Brief pause between commands
                except KeyboardInterrupt:
                    raise
                except Exception as e:
                    print(f"[ERROR] {e}")
                    time.sleep(1)
        except KeyboardInterrupt:
            print("\n\n[SHUTDOWN] Bridge AI shutting down...")
        finally:
            self.cleanup()

    def cleanup(self):
        """Release all resources."""
        self.running = False
        self.recorder.cleanup()
        self.godot.disconnect()
        print("[SHUTDOWN] Complete.")


# =============================================================================
# ENTRY POINT
# =============================================================================

def main():
    """Main entry point for the Bridge AI system."""
    print("""
    ╔═══════════════════════════════════════════════════════════╗
    ║           STAR TREK: BRIDGE AI VOICE COMMAND              ║
    ╠═══════════════════════════════════════════════════════════╣
    ║  NAVIGATION:                                              ║
    ║  • "Set course for Jupiter, warp 5"                       ║
    ║  • "Take us to Mars"                                      ║
    ║  • "Head to Neptune, warp 7"                              ║
    ║  • "Saturn warp 6"                                        ║
    ║                                                           ║
    ║  VALID DESTINATIONS:                                      ║
    ║  Sun, Mercury, Venus, Earth, Moon, Mars, Jupiter,         ║
    ║  Saturn, Uranus, Neptune, Starbase 1                      ║
    ║                                                           ║
    ║  SPEED CONTROL:                                           ║
    ║  • "Full impulse" / "Half impulse"                        ║
    ║  • "All stop" / "Disengage"                               ║
    ║                                                           ║
    ║  OTHER:                                                   ║
    ║  • "Raise shields" / "Lower shields"                      ║
    ║  • "Orbit Earth"                                          ║
    ║  • "Status"                                               ║
    ╚═══════════════════════════════════════════════════════════╝
    """)

    bridge = BridgeAI()
    bridge.run()


if __name__ == "__main__":
    main()
