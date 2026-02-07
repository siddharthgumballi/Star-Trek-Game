#!/usr/bin/env python3
"""
=============================================================================
STAR TREK BRIDGE AI - Voice Command System
=============================================================================

This script creates a fully offline voice command system for a Star Trek game.
It listens to your voice, understands what you're saying, and sends structured
commands to the Godot game engine.

ARCHITECTURE:
    Microphone → Whisper (speech-to-text) → Ollama (intent parsing) → TCP → Godot

REQUIREMENTS:
    pip install pyaudio numpy ollama

    You also need:
    - Whisper.cpp installed with the medium.en model
    - Ollama installed and running locally
    - A model pulled in Ollama (e.g., `ollama pull llama3.2` or `ollama pull mistral`)

USAGE:
    1. Start Ollama: `ollama serve`
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

    # Ollama Settings
    OLLAMA_MODEL = "tinyllama"  # Local LLM model (change to your installed model)
    OLLAMA_HOST = "http://localhost:11434"  # Default Ollama server

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
    NAVIGATE = "navigate"      # Set course to destination
    NAVIGATE_COORDINATES = "navigate_coordinates"  # Navigate to coordinates
    WARP = "warp"              # Engage warp drive
    IMPULSE = "impulse"        # Set impulse speed
    STOP = "stop"              # All stop
    TURN = "turn"              # Turn/rotate ship
    RAISE_SHIELDS = "raise_shields"
    LOWER_SHIELDS = "lower_shields"
    ORBIT = "orbit"            # Enter orbit around target
    DISENGAGE = "disengage"    # Disengage autopilot/warp
    STATUS = "status"          # Report ship status


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

        if command.intent == Intent.WARP.value:
            self.at_warp = True
        elif command.intent in [Intent.STOP.value, Intent.IMPULSE.value]:
            self.at_warp = False

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
# INTENT PARSER - Convert text to structured commands using Ollama
# =============================================================================

class IntentParser:
    """
    Parses natural language commands into structured JSON using Ollama.

    Ollama runs large language models locally on your machine, ensuring
    complete privacy and offline operation.
    """

    def __init__(self, memory: CommandMemory):
        self.memory = memory
        self.model = Config.OLLAMA_MODEL

        # Try to import ollama
        try:
            import ollama
            self.ollama = ollama
        except ImportError:
            print("ERROR: ollama not installed. Install with: pip install ollama")
            sys.exit(1)

        # Test connection to Ollama
        self._test_connection()

    def _test_connection(self):
        """Test that Ollama is running and the model is available."""
        try:
            models_response = self.ollama.list()

            # Handle different response formats (dict or object)
            model_names = []
            if hasattr(models_response, 'models'):
                # Newer ollama library returns object
                for m in models_response.models:
                    name = m.model if hasattr(m, 'model') else str(m)
                    model_names.append(name.split(':')[0])
            elif isinstance(models_response, dict):
                # Older format returns dict
                for m in models_response.get('models', []):
                    name = m.get('name', m.get('model', str(m)))
                    model_names.append(name.split(':')[0])

            if self.model not in model_names:
                print(f"WARNING: Model '{self.model}' not found in Ollama.")
                print(f"  Available models: {model_names}")
                print(f"  Pull it with: ollama pull {self.model}")
            else:
                print(f"[OLLAMA] Connected, using model: {self.model}")
        except Exception as e:
            print(f"ERROR: Cannot connect to Ollama: {e}")
            print("  Make sure Ollama is running: ollama serve")
            sys.exit(1)

    def _build_system_prompt(self) -> str:
        """Short prompt for faster responses."""
        return """Parse Star Trek commands to JSON. Output ONLY JSON:
{"department":"helm","intent":"navigate","target":"Jupiter","warp_factor":5,"impulse_percent":null,"maneuver":null,"confidence":0.9}

Valid intents: navigate, warp, impulse, stop, turn, raise_shields, lower_shields, orbit, disengage, status

Valid targets (case-insensitive):
Sun, Mercury, Venus, Earth, Moon, Mars, Jupiter, Saturn, Uranus, Neptune, Starbase 1

Examples:
"set course for jupiter warp 5" → {"intent":"navigate","target":"Jupiter","warp_factor":5}
"course to mars" → {"intent":"navigate","target":"Mars","warp_factor":5}
"take us to earth" → {"intent":"navigate","target":"Earth","warp_factor":5}
"head to neptune warp 7" → {"intent":"navigate","target":"Neptune","warp_factor":7}
"saturn warp 6" → {"intent":"navigate","target":"Saturn","warp_factor":6}
"uranus" → {"intent":"navigate","target":"Uranus","warp_factor":5}
"the sun" → {"intent":"navigate","target":"Sun","warp_factor":5}
"starbase" → {"intent":"navigate","target":"Starbase 1","warp_factor":5}
"full impulse" → {"intent":"impulse","impulse_percent":100}
"half impulse" → {"intent":"impulse","impulse_percent":50}
"quarter impulse" → {"intent":"impulse","impulse_percent":25}
"all stop" → {"intent":"stop"}
"disengage" → {"intent":"disengage"}
"drop out of warp" → {"intent":"stop"}
"orbit earth" → {"intent":"orbit","target":"Earth"}
"raise shields" → {"intent":"raise_shields"}
"status" → {"intent":"status"}

JSON ONLY. No explanation."""

    def parse(self, text: str) -> Optional[BridgeCommand]:
        """
        Parse natural language text into a structured command.

        Args:
            text: The transcribed voice command

        Returns:
            BridgeCommand if parsing succeeded, None otherwise
        """
        print("[PARSING] Interpreting command...")

        # Build the prompt with context
        context = self.memory.get_context_string()
        user_prompt = f"Context: {context}\n\nCommand: \"{text}\"\n\nJSON:"

        try:
            # Call Ollama
            response = self.ollama.chat(
                model=self.model,
                messages=[
                    {"role": "system", "content": self._build_system_prompt()},
                    {"role": "user", "content": user_prompt}
                ],
                options={
                    "temperature": 0.1,  # Low temperature for consistent output
                }
            )

            # Extract the response (handle both dict and object formats)
            if hasattr(response, 'message'):
                response_text = response.message.content.strip()
            else:
                response_text = response['message']['content'].strip()

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
                'navigation': 'navigate',
                'set_course': 'navigate',
                'course': 'navigate',
                'go_to': 'navigate',
                'goto': 'navigate',
                'head_to': 'navigate',
                'take_us_to': 'navigate',
                'engage': 'warp',
                'full_stop': 'stop',
                'all_stop': 'stop',
                'halt': 'stop',
                'shields_up': 'raise_shields',
                'shields_down': 'lower_shields',
                'drop_out': 'stop',
                'enter_orbit': 'orbit',
                'standard_orbit': 'orbit',
                'report': 'status',
                'ship_status': 'status',
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
            print(f"  [ERROR] Ollama request failed: {e}")
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
