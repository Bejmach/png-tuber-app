package png_tuber

import "base:runtime"
import "core:math"
import ma "vendor:miniaudio"

MAX_SAMPLES :: 512

AudioData :: struct {
	samples:      [MAX_SAMPLES]f32,
	sample_count: int,
}

AudioAnalysis :: struct {
	rms:  f32,
	peak: f32,
}

audio_data: AudioData
audio_analysis: AudioAnalysis

data_callback :: proc "c" (device: ^ma.device, output: rawptr, input: rawptr, frame_count: u32) {
	context = runtime.default_context()

	samples := cast([^]f32)input
	sample_count := min(int(frame_count), MAX_SAMPLES)

	copy(audio_data.samples[:sample_count], samples[:sample_count])

	audio_data.sample_count = sample_count
}

analyze_audio :: proc() {
	audio_analysis = {}

	for i in 0 ..< audio_data.sample_count {
		sample := audio_data.samples[i]
		audio_analysis.rms += sample * sample
		audio_analysis.peak = math.max(audio_analysis.peak, math.abs(sample))
	}
	if audio_data.sample_count > 0 {
		audio_analysis.rms = math.sqrt(audio_analysis.rms / f32(audio_data.sample_count))
	}
}

get_db :: proc() -> f32 {
	return 20.0 * math.log10(audio_analysis.rms)
}
