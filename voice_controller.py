#!/usr/bin/env python3
"""
Voice Controller untuk Antigravity AI Agent
--------------------------------------------
Mendukung:
- Input Audio: Push-to-Talk (Hotkey) ATAU Voice Activity Detection (VAD)
- STT Lokal: faster-whisper (Base/Small model, latency rendah, multi-bahasa ID/EN)
- Audio Feedback: Beep feedback (winsound di Windows)
- Agent Dispatch: Terintegrasi dengan Antigravity SDK, Antigravity CLI, atau Auto-Type ke IDE
"""

import os
import sys
import time
import queue
import argparse
import tempfile
import threading
import subprocess
import numpy as np
import sounddevice as sd
from scipy.io.wavfile import write as write_wav

# Audio feedback (Windows native)
try:
    import winsound
    HAS_WINSOUND = True
except ImportError:
    HAS_WINSOUND = False

# Global keyboard listener
try:
    import keyboard
    HAS_KEYBOARD = True
except ImportError:
    HAS_KEYBOARD = False

# Auto-type / Clipboard utilities
try:
    import pyperclip
    import pyautogui
    HAS_GUI_AUTOMATION = True
except ImportError:
    HAS_GUI_AUTOMATION = False

# Colorama for colorful terminal logs
try:
    from colorama import init, Fore, Style
    init(autoreset=True)
    COLOR_CYAN = Fore.CYAN
    COLOR_INFO = Fore.CYAN
    COLOR_SUCCESS = Fore.GREEN
    COLOR_WARN = Fore.YELLOW
    COLOR_ERROR = Fore.RED
    COLOR_RESET = Style.RESET_ALL
except ImportError:
    COLOR_CYAN = ""
    COLOR_INFO = ""
    COLOR_SUCCESS = ""
    COLOR_WARN = ""
    COLOR_ERROR = ""
    COLOR_RESET = ""


# ==============================================================================
# 1. AUDIO FEEDBACK HELPER
# ==============================================================================
class AudioFeedback:
    @staticmethod
    def play_start():
        """Beep saat mulai merekam (High Pitch)."""
        if HAS_WINSOUND:
            threading.Thread(target=lambda: winsound.Beep(1200, 120), daemon=True).start()
        else:
            print("\a", end="", flush=True)

    @staticmethod
    def play_stop():
        """Beep saat rekaman selesai & mulai transkripsi."""
        if HAS_WINSOUND:
            threading.Thread(target=lambda: winsound.Beep(900, 100), daemon=True).start()

    @staticmethod
    def play_done():
        """Dua nada ceria saat transkripsi & dispatch selesai."""
        if HAS_WINSOUND:
            def _beep():
                winsound.Beep(1500, 80)
                time.sleep(0.05)
                winsound.Beep(2000, 120)
            threading.Thread(target=_beep, daemon=True).start()

    @staticmethod
    def play_error():
        """Beep nada rendah saat error/batal."""
        if HAS_WINSOUND:
            threading.Thread(target=lambda: winsound.Beep(450, 250), daemon=True).start()


# ==============================================================================
# 2. AUDIO RECORDER (PTT, VAD, & MIC DEVICE SELECTION)
# ==============================================================================
class AudioRecorder:
    def __init__(self, device_index=None, sample_rate=16000, channels=1):
        self.sample_rate = sample_rate
        self.channels = channels
        self.device_index = self._resolve_device_index(device_index)
        self.audio_queue = queue.Queue()
        self.recording = False
        self.stream = None

    @staticmethod
    def get_input_devices():
        """Mendapatkan daftar semua perangkat input (mikrofon) yang tersedia."""
        devices = sd.query_devices()
        input_devs = []
        for i, dev in enumerate(devices):
            if dev['max_input_channels'] > 0:
                input_devs.append((i, dev['name']))
        return input_devs

    @staticmethod
    def print_microphones():
        """Mencetak daftar mikrofon ke terminal."""
        input_devs = AudioRecorder.get_input_devices()
        default_input = sd.default.device[0]
        print(f"\n{COLOR_CYAN}=== DAFTAR MIKROFON YANG TERSEDIA ==={COLOR_RESET}")
        for idx, name in input_devs:
            is_default = " (DEFAULT)" if idx == default_input else ""
            print(f"  [{idx}] {name}{COLOR_SUCCESS}{is_default}{COLOR_RESET}")
        print(f"{COLOR_CYAN}=====================================\n{COLOR_RESET}")

    def _resolve_device_index(self, dev_target):
        if dev_target is None:
            return None
        # Jika user memasukkan angka (contoh: '1' atau 1)
        try:
            idx = int(dev_target)
            return idx
        except ValueError:
            # Jika user memasukkan nama / substring
            query = str(dev_target).lower()
            for idx, name in self.get_input_devices():
                if query in name.lower():
                    print(f"{COLOR_INFO}[Audio] Memilih mic ID [{idx}]: {name}{COLOR_RESET}")
                    return idx
            print(f"{COLOR_WARN}[Audio Warning] Mic '{dev_target}' tidak ditemukan, menggunakan mic default.{COLOR_RESET}")
            return None

    def _audio_callback(self, indata, frames, time_info, status):
        if status:
            print(f"{COLOR_WARN}[Audio Warning] {status}{COLOR_RESET}", file=sys.stderr)
        if self.recording:
            self.audio_queue.put(indata.copy())

    def start_stream(self):
        try:
            self.stream = sd.InputStream(
                device=self.device_index,
                samplerate=self.sample_rate,
                channels=self.channels,
                dtype='int16',
                callback=self._audio_callback
            )
            self.stream.start()
        except Exception as e:
            print(f"{COLOR_ERROR}[Audio Error] Gagal membuka stream mikrofon: {e}{COLOR_RESET}")
            raise

    def stop_stream(self):
        if self.stream:
            self.stream.stop()
            self.stream.close()
            self.stream = None

    def record_ptt_hold(self, hotkey="ctrl+shift+v"):
        """Merekam selama hotkey ditekan (Push-to-Talk)."""
        if not HAS_KEYBOARD:
            raise RuntimeError("Library 'keyboard' belum terinstall. Jalankan: pip install keyboard")

        print(f"{COLOR_INFO}[PTT Mode] Tekan & TAHAN [{hotkey}] untuk bicara...{COLOR_RESET}")
        keyboard.wait(hotkey)
        AudioFeedback.play_start()
        print(f"{COLOR_SUCCESS}>>> Merekam suara... (Lepas [{hotkey}] untuk selesai){COLOR_RESET}")

        frames = []
        self.recording = True
        while keyboard.is_pressed(hotkey):
            try:
                data = self.audio_queue.get(timeout=0.05)
                frames.append(data)
            except queue.Empty:
                pass

        self.recording = False
        AudioFeedback.play_stop()
        print(f"{COLOR_INFO}>>> Rekaman selesai, memproses STT...{COLOR_RESET}")

        if not frames:
            return None
        return np.concatenate(frames, axis=0)

    def record_vad(self, silence_threshold=500, max_silence_sec=1.2, min_speech_sec=0.4):
        """Merekam otomatis berbasis deteksi suara (VAD - Energy / RMS)."""
        print(f"{COLOR_INFO}[VAD Mode] Menunggu suara Anda... (Mulai bicara untuk merekam){COLOR_RESET}")
        
        frames = []
        is_speaking = False
        silence_start_time = None
        speech_start_time = None

        while True:
            try:
                chunk = self.audio_queue.get(timeout=0.05)
            except queue.Empty:
                continue

            # Hitung volume (RMS energy) dari chunk audio
            rms = np.sqrt(np.mean(chunk.astype(np.float32)**2))

            if rms > silence_threshold:
                if not is_speaking:
                    is_speaking = True
                    speech_start_time = time.time()
                    AudioFeedback.play_start()
                    print(f"{COLOR_SUCCESS}>>> Suara terdeteksi! Merekam...{COLOR_RESET}")
                
                frames.append(chunk)
                silence_start_time = None
            else:
                if is_speaking:
                    frames.append(chunk)
                    if silence_start_time is None:
                        silence_start_time = time.time()
                    elif (time.time() - silence_start_time) > max_silence_sec:
                        # Hening > threshold, stop merekam
                        AudioFeedback.play_stop()
                        print(f"{COLOR_INFO}>>> Jeda hening terdeteksi. Memproses STT...{COLOR_RESET}")
                        break
        
        # Validasi durasi suara
        if speech_start_time and (time.time() - speech_start_time) < min_speech_sec:
            print(f"{COLOR_WARN}[VAD] Suara terlalu pendek / noise, dibatalkan.{COLOR_RESET}")
            AudioFeedback.play_error()
            return None

        if not frames:
            return None
        return np.concatenate(frames, axis=0)


# ==============================================================================
# 3. SPEECH-TO-TEXT (FASTER-WHISPER)
# ==============================================================================
class WhisperTranscriber:
    def __init__(self, model_size="base", device="cpu", compute_type="int8", language="id"):
        self.language = None if language == "auto" else language
        print(f"{COLOR_INFO}[STT Init] Memuat model Faster-Whisper '{model_size}' ({device}, {compute_type}, Bahasa: {language.upper()})...{COLOR_RESET}")
        from faster_whisper import WhisperModel
        self.model = WhisperModel(model_size, device=device, compute_type=compute_type)
        print(f"{COLOR_SUCCESS}[STT Init] Model Whisper siap digunakan!{COLOR_RESET}")

    def transcribe(self, audio_data, sample_rate=16000):
        if audio_data is None or len(audio_data) == 0:
            return ""

        # Simpan sementara ke file wav buffer
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp_file:
            tmp_path = tmp_file.name
        
        try:
            write_wav(tmp_path, sample_rate, audio_data)
            
            # Initial prompt untuk memperkuat akurasi kosakata coding dalam Bahasa Indonesia
            prompt_hint = "Halo, tolong buatkan codingan, perbaiki error, buka file, dan jalankan perintah di project saya." if self.language == "id" else None

            # Jalankan transkripsi dengan faster-whisper
            segments, info = self.model.transcribe(
                tmp_path,
                beam_size=5,
                language=self.language, # Mengunci ke Bahasa Indonesia (ID) jika ditentukan
                initial_prompt=prompt_hint,
                vad_filter=True, # Built-in VAD filter whisper
                vad_parameters=dict(min_silence_duration_ms=500)
            )

            text_parts = [segment.text.strip() for segment in segments]
            full_text = " ".join(text_parts).strip()
            detected_lang = (info.language.upper() if info and info.language else "ID") if not self.language else self.language.upper()
            prob = round(info.language_probability * 100, 1) if info else 100

            print(f"{COLOR_INFO}[STT Info] Bahasa: {detected_lang} ({prob}% confidence){COLOR_RESET}")
            return full_text
        finally:
            if os.path.exists(tmp_path):
                os.remove(tmp_path)


# ==============================================================================
# 4. AGENT DISPATCHER (ANTIGRAVITY RUNNER)
# ==============================================================================
class AgentDispatcher:
    def __init__(self, backend="sdk"):
        self.backend = backend.lower()
        self.agent_instance = None
        self._init_backend()

    def _init_backend(self):
        if self.backend == "sdk":
            try:
                import asyncio
                from google.antigravity import Agent, LocalAgentConfig, CapabilitiesConfig
                print(f"{COLOR_SUCCESS}[Dispatcher] Menggunakan Antigravity Python SDK backend.{COLOR_RESET}")
            except ImportError:
                print(f"{COLOR_WARN}[Dispatcher Warning] google-antigravity SDK tidak ditemukan. Fallback ke 'active_window' mode.{COLOR_RESET}")
                self.backend = "active_window"
        elif self.backend == "cli":
            print(f"{COLOR_SUCCESS}[Dispatcher] Menggunakan Antigravity CLI ('agy') backend.{COLOR_RESET}")
        elif self.backend == "active_window":
            print(f"{COLOR_SUCCESS}[Dispatcher] Menggunakan Auto-Type ke IDE / Active Window backend.{COLOR_RESET}")

    def dispatch(self, prompt_text):
        if not prompt_text:
            return

        print(f"\n{Fore.MAGENTA}==================================================")
        print(f"🎙️ HASIL TRANSKRIPSI: {Fore.YELLOW}\"{prompt_text}\"")
        print(f"{Fore.MAGENTA}=================================================={COLOR_RESET}")

        if self.backend == "sdk":
            self._dispatch_sdk(prompt_text)
        elif self.backend == "cli":
            self._dispatch_cli(prompt_text)
        elif self.backend == "active_window":
            self._dispatch_active_window(prompt_text)
        else:
            print(f"{COLOR_INFO}[Output Teks]: {prompt_text}{COLOR_RESET}")

        AudioFeedback.play_done()

    def _dispatch_sdk(self, prompt_text):
        import asyncio
        from google.antigravity import Agent, LocalAgentConfig, CapabilitiesConfig

        async def _run_agent():
            print(f"{COLOR_INFO}[Antigravity Agent] Mengirim prompt ke agent...{COLOR_RESET}")
            config = LocalAgentConfig(
                system_instructions="You are an expert AI developer assistant.",
                capabilities=CapabilitiesConfig()
            )
            async with Agent(config) as agent:
                response = await agent.chat(prompt_text)
                print(f"\n{COLOR_SUCCESS}[Agent Response]:{COLOR_RESET}")
                async for token in response:
                    sys.stdout.write(token)
                    sys.stdout.flush()
                print("\n")

        try:
            asyncio.run(_run_agent())
        except Exception as e:
            print(f"{COLOR_ERROR}[SDK Error] Gagal menjalankan agent SDK: {e}{COLOR_RESET}")
            print(f"{COLOR_INFO}[Fallback] Mengirim via Active Window...{COLOR_RESET}")
            self._dispatch_active_window(prompt_text)

    def _dispatch_cli(self, prompt_text):
        print(f"{COLOR_INFO}[Antigravity CLI] Menjalankan: agy \"{prompt_text}\"{COLOR_RESET}")
        try:
            subprocess.run(["agy", prompt_text], shell=True)
        except Exception as e:
            print(f"{COLOR_ERROR}[CLI Error] {e}{COLOR_RESET}")

    def _dispatch_active_window(self, prompt_text):
        """Mem-paste prompt langsung ke window chat IDE yang sedang aktif dan menekan Enter."""
        if not HAS_GUI_AUTOMATION:
            print(f"{COLOR_WARN}[Warning] pyautogui / pyperclip tidak tersedia. Text tidak dapat di-paste otomatis.{COLOR_RESET}")
            return

        print(f"{COLOR_INFO}[Auto-Type] Menyalin ke clipboard & mengirim ke input chat IDE aktif...{COLOR_RESET}")
        try:
            pyperclip.copy(prompt_text)
            time.sleep(0.1)
            # Paste text (Ctrl+V) dan tekan Enter
            pyautogui.hotkey('ctrl', 'v')
            time.sleep(0.05)
            pyautogui.press('enter')
            print(f"{COLOR_SUCCESS}[Auto-Type] Pesan berhasil dikirim ke chat IDE!{COLOR_RESET}")
        except Exception as e:
            print(f"{COLOR_ERROR}[Auto-Type Error] {e}{COLOR_RESET}")


# ==============================================================================
# 5. MAIN ENTRY POINT
# ==============================================================================
def main():
    parser = argparse.ArgumentParser(description="Antigravity Voice Controller (PTT / VAD)")
    parser.add_argument(
        "--list-mics",
        action="store_true",
        help="Tampilkan daftar semua mikrofon yang tersedia beserta ID-nya, lalu keluar."
    )
    parser.add_argument(
        "--mic",
        default=None,
        help="Pilih mikrofon berdasarkan ID (angka) atau nama (contoh: --mic 1 atau --mic 'Realtek')"
    )
    parser.add_argument(
        "--mode",
        choices=["ptt", "vad"],
        default="ptt",
        help="Mode input audio: 'ptt' (Push-to-Talk) atau 'vad' (Voice Activity Detection / otomatis)"
    )
    parser.add_argument(
        "--hotkey",
        default="ctrl+shift+v",
        help="Shortcut untuk Push-to-Talk (default: 'ctrl+shift+v' atau gunakan 'space')"
    )
    parser.add_argument(
        "--language",
        choices=["id", "en", "auto"],
        default="id",
        help="Kunci bahasa input STT: 'id' (Bahasa Indonesia Only - Rekomendasi), 'en' (Inggris), atau 'auto'"
    )
    parser.add_argument(
        "--model",
        choices=["tiny", "base", "small", "medium", "large-v3"],
        default="base",
        help="Ukuran model Whisper lokal (default: 'base' untuk keseimbangan speed & akurasi)"
    )
    parser.add_argument(
        "--device",
        choices=["cpu", "cuda"],
        default="cpu",
        help="Device untuk komputasi STT (default: 'cpu' atau 'cuda' jika punya GPU NVIDIA)"
    )
    parser.add_argument(
        "--backend",
        choices=["active_window", "sdk", "cli", "print_only"],
        default="active_window",
        help="Cara eksekusi ke Antigravity ('active_window' auto-paste ke IDE chat, 'sdk' via Python SDK, 'cli' via agy)"
    )
    parser.add_argument(
        "--vad-threshold",
        type=int,
        default=400,
        help="Ambang batas sensitivitas suara untuk mode VAD (default: 400)"
    )

    args = parser.parse_args()

    # Jika user ingin melihat daftar mic saja
    if args.list_mics:
        AudioRecorder.print_microphones()
        return

    # Inisialisasi Audio Recorder lebih awal untuk deteksi nama mic
    recorder = AudioRecorder(device_index=args.mic, sample_rate=16000)
    selected_mic_name = "Default System Microphone"
    if recorder.device_index is not None:
        for idx, name in AudioRecorder.get_input_devices():
            if idx == recorder.device_index:
                selected_mic_name = f"[{idx}] {name}"
                break

    lang_display = "Bahasa Indonesia (Locked)" if args.language == "id" else ("English" if args.language == "en" else "Auto-Detect")

    print(f"""
{COLOR_CYAN}=============================================================
🚀 ANTIGRAVITY VOICE CONTROLLER READY
=============================================================
{COLOR_INFO}• Mikrofon    : {Fore.YELLOW}{selected_mic_name}
{COLOR_INFO}• Bahasa STT  : {Fore.GREEN}{lang_display}
{COLOR_INFO}• Mode Audio  : {Fore.YELLOW}{args.mode.upper()} {f'({args.hotkey})' if args.mode == 'ptt' else '(Otomatis saat bicara)'}
{COLOR_INFO}• Model STT   : {Fore.YELLOW}faster-whisper [{args.model}] ({args.device})
{COLOR_INFO}• Dispatcher  : {Fore.YELLOW}{args.backend}
{COLOR_INFO}• Audio Beep  : {Fore.GREEN}{'Aktif (Windows winsound)' if HAS_WINSOUND else 'Nonaktif'}
{COLOR_CYAN}============================================================={COLOR_RESET}
    """)

    # 1. Inisialisasi Transcriber & Dispatcher
    transcriber = WhisperTranscriber(model_size=args.model, device=args.device, language=args.language)
    dispatcher = AgentDispatcher(backend=args.backend)

    # 2. Mulai Audio Stream
    recorder.start_stream()

    print(f"\n{COLOR_SUCCESS}✅ Sistem siap menerima suara! Tekan Ctrl+C di terminal untuk berhenti.{COLOR_RESET}\n")

    try:
        while True:
            if args.mode == "ptt":
                audio_data = recorder.record_ptt_hold(hotkey=args.hotkey)
            else:
                recorder.recording = True
                audio_data = recorder.record_vad(silence_threshold=args.vad_threshold)

            if audio_data is not None and len(audio_data) > 0:
                # Transkripsi
                text = transcriber.transcribe(audio_data)
                if text:
                    # Oper ke Antigravity Agent
                    dispatcher.dispatch(text)
                else:
                    print(f"{COLOR_WARN}[STT] Tidak ada kata yang terbaca jelas.{COLOR_RESET}")
                    AudioFeedback.play_error()
            
            time.sleep(0.2)

    except KeyboardInterrupt:
        print(f"\n{COLOR_INFO}[Voice Controller] Berhenti. Sampai jumpa!{COLOR_RESET}")
    finally:
        recorder.stop_stream()


if __name__ == "__main__":
    main()
