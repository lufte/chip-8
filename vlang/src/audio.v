import math
import sokol.audio

// Credits: taken almost entirely from
// https://github.com/vlang/v/blob/master/examples/sokol/sounds/simple_sin_tones.v

fn sintone(periods int, frame int, num_frames int) f32 {
  return math.sinf(f32(periods) * (2 * math.pi) * f32(frame) / f32(num_frames))
}

fn audio_stream_callback(buffer &f32, num_frames int, num_channels int, audio_obj &Audio) {
  unsafe {
    mut soundbuffer := buffer
    for frame := 0; frame < num_frames; frame++ {
      for ch := 0; ch < num_channels; ch++ {
        idx := frame * num_channels + ch
        if audio_obj.is_on {
          soundbuffer[idx] = 0.5 * sintone(20, frame, num_frames)
        } else {
          soundbuffer[idx] = 0
        }
      }
    }
  }
}

struct Audio {
mut:
  is_on bool
}

fn get_audio() &Audio {
  mut audio_obj := &Audio {
    is_on: false
  }
  audio.setup(
    stream_userdata_cb: audio_stream_callback
    user_data: audio_obj
  )
  return audio_obj
}

fn (mut audio_obj Audio) beep_on() {
  audio_obj.is_on = true
}

fn (mut audio_obj Audio) beep_off() {
  audio_obj.is_on = false
}

fn (audio_obj &Audio) shutdown() {
  audio.shutdown()
}
