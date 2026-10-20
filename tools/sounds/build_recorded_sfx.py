"""Prepare the game's softer SFX from downloaded Kenney CC0 audio packs.

Source folders must contain their original Audio/ and License.txt files.
Nothing is downloaded or installed by this script. Existing asset metadata stays
unchanged. Run with --sources PATH --output PATH --ffmpeg PATH.
"""
import argparse
import hashlib
import json
import shutil
import subprocess
import wave
from pathlib import Path

import numpy as np

RATE = 44100
PACKS = {
    'impact-sounds': 'https://kenney.nl/assets/impact-sounds',
    'interface-sounds': 'https://kenney.nl/assets/interface-sounds',
    'rpg-audio': 'https://kenney.nl/assets/rpg-audio',
    'casino-audio': 'https://kenney.nl/assets/casino-audio',
}
# name: pack, original recording, duration cap, peak ceiling, RMS ceiling (dBFS)
SOUNDS = {
    'buy': ('rpg-audio', 'handleCoins2.ogg', .70, -13, -25),
    'collect': ('rpg-audio', 'handleCoins.ogg', .65, -14, -26),
    'click': ('interface-sounds', 'click_001.ogg', .14, -17, -28),
    'jump': ('rpg-audio', 'cloth1.ogg', .26, -15, -27),
    'land': ('impact-sounds', 'impactSoft_heavy_000.ogg', .30, -12, -25),
    'step1': ('impact-sounds', 'footstep_concrete_000.ogg', .23, -14, -26),
    'step2': ('impact-sounds', 'footstep_concrete_001.ogg', .23, -14, -26),
    'swing': ('rpg-audio', 'knifeSlice2.ogg', .34, -14, -26),
    'hit': ('impact-sounds', 'impactPunch_medium_003.ogg', .30, -11, -24),
    'steal': ('rpg-audio', 'clothBelt2.ogg', .45, -14, -26),
    'alarm': ('impact-sounds', 'impactBell_heavy_002.ogg', .80, -15, -26),
    'deliver': ('interface-sounds', 'confirmation_003.ogg', .70, -14, -26),
    'error': ('interface-sounds', 'back_002.ogg', .35, -17, -29),
    'lock': ('rpg-audio', 'metalLatch.ogg', .50, -13, -25),
    'unlock': ('rpg-audio', 'metalClick.ogg', .40, -14, -26),
    'rebirth': ('impact-sounds', 'impactBell_heavy_004.ogg', 1.10, -13, -25),
    'rare': ('impact-sounds', 'impactBell_heavy_000.ogg', .90, -14, -26),
    'shop': ('interface-sounds', 'open_002.ogg', .35, -17, -28),
    'sell': ('casino-audio', 'chips-stack-2.ogg', .45, -13, -25),
    'pop': ('casino-audio', 'card-place-2.ogg', .20, -17, -28),
}


def levels(samples):
    peak = max(float(np.max(np.abs(samples))), 1e-9)
    rms = max(float(np.sqrt(np.mean(samples.astype(np.float64)**2))), 1e-9)
    return 20*np.log10(peak), 20*np.log10(rms)


def write_wav(path, samples):
    with wave.open(str(path), 'wb') as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(np.round(np.clip(samples, -1, 1)*32767).astype('<i2').tobytes())


def prepare(ffmpeg, path, cap, peak_limit, rms_limit):
    converted = subprocess.run([
        ffmpeg, '-v', 'error', '-i', str(path), '-vn', '-ac', '1', '-ar', str(RATE),
        '-af', 'highpass=f=60,lowpass=f=4200:p=2', '-f', 'f32le', 'pipe:1',
    ], check=True, capture_output=True).stdout
    samples = np.frombuffer(converted, dtype='<f4').copy()
    assert len(samples) > 0 and np.all(np.isfinite(samples)), str(path)
    samples -= np.mean(samples)
    # Remove quiet padding while keeping the actual attack and tail.
    audible = np.flatnonzero(np.abs(samples) > max(np.max(np.abs(samples))*.008, .00001))
    if len(audible):
        samples = samples[max(0, audible[0]-int(.005*RATE)):min(len(samples), audible[-1]+int(.04*RATE))]
    samples = samples[:int(cap*RATE)]
    # Coin/metal recordings contain needle-like peaks. A soft knee reduces those
    # peaks without a hard clip; the quieter part of the recording stays audible.
    soft_ceiling = max(float(np.sqrt(np.mean(samples**2)))*5, .002)
    samples = soft_ceiling*np.tanh(samples/soft_ceiling)
    attack = min(int(.004*RATE), len(samples)//4)
    release = min(int(.035*RATE), len(samples)//4)
    samples[:attack] *= np.linspace(0, 1, attack)
    samples[-release:] *= np.linspace(1, 0, release)
    peak, rms = levels(samples)
    # Respect both ceilings instead of normalizing every file to full scale.
    gain_db = min(peak_limit-peak, rms_limit-rms, 6)
    samples *= 10**(gain_db/20)
    return samples, gain_db


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sources', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--ffmpeg', required=True)
    parser.add_argument('--preview', type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    licenses = args.output/'licenses'
    licenses.mkdir(exist_ok=True)
    for pack in PACKS:
        license_path = args.sources/pack/'License.txt'
        assert 'CC0' in license_path.read_text(encoding='utf-8-sig'), str(license_path)
        shutil.copyfile(license_path, licenses/f'Kenney-{pack}.txt')
    manifest = []
    prepared = {}
    for name, (pack, recording, cap, peak_cap, rms_cap) in SOUNDS.items():
        original = args.sources/pack/'Audio'/recording
        samples, gain = prepare(args.ffmpeg, original, cap, peak_cap, rms_cap)
        destination = args.output/f'{name}.wav'
        write_wav(destination, samples)
        peak, rms = levels(samples)
        assert peak <= peak_cap+.02 and rms <= rms_cap+.02
        manifest.append({
            'asset': f'{name}.wav', 'source': f'{pack}/Audio/{recording}',
            'url': PACKS[pack], 'license': 'CC0-1.0',
            'processing': 'mono 44100 Hz; highpass 60 Hz; lowpass 4200 Hz; soft transient ceiling at 5 x RMS; 4 ms attack / 35 ms release; peak and RMS ceilings',
            'gain_db': round(gain, 2), 'duration_seconds': round(len(samples)/RATE, 3),
            'peak_dbfs': round(peak, 2), 'rms_dbfs': round(rms, 2),
            'sha256': hashlib.sha256(destination.read_bytes()).hexdigest(),
        })
        prepared[name] = samples
    (args.output/'recorded-sfx-sources.json').write_text(json.dumps(manifest, indent=2)+'\n', encoding='utf-8')
    if args.preview:
        order = ('click', 'shop', 'buy', 'collect', 'step1', 'step2', 'jump', 'land', 'swing', 'hit', 'lock', 'unlock', 'steal', 'alarm', 'deliver', 'sell', 'error', 'rare', 'rebirth')
        preview = []
        for name in order:
            preview.extend((prepared[name], np.zeros(int(.45*RATE), dtype=np.float32)))
        write_wav(args.preview, np.concatenate(preview))
        args.preview.with_suffix('.json').write_text(json.dumps({'order': order, 'silence_between_seconds': .45}, indent=2), encoding='utf-8')
    print(json.dumps({'prepared': len(manifest), 'output': str(args.output), 'max_peak_dbfs': max(x['peak_dbfs'] for x in manifest), 'max_rms_dbfs': max(x['rms_dbfs'] for x in manifest)}))


if __name__ == '__main__':
    main()
