import gg
import gx


const (
	width           = 64
	height          = 32
  scale           = 10
  pixel_fade_step = 0x15  // Set to 0xFF to disable fade effect
  keymap          = map{
    gg.KeyCode.x: 0
    gg.KeyCode._1: 1
    gg.KeyCode._2: 2
    gg.KeyCode._3: 3
    gg.KeyCode.q: 4
    gg.KeyCode.w: 5
    gg.KeyCode.e: 6
    gg.KeyCode.a: 7
    gg.KeyCode.s: 8
    gg.KeyCode.d: 9
    gg.KeyCode.z: 10
    gg.KeyCode.c: 11
    gg.KeyCode._4: 12
    gg.KeyCode.r: 13
    gg.KeyCode.f: 14
    gg.KeyCode.v: 15
  }
)

struct Video {
mut:
	gg       &gg.Context
  matrix   [width][height]byte = [width][height]byte{init: [height]byte{init: 0x00}}
  keyboard [16]bool
}

fn get_video(window_title string) &Video {
  mut video := &Video{
    gg: 0
  }
  video.gg = gg.new_context(
		bg_color: gx.black
		width: width * scale
		height: height * scale
		use_ortho: true // This is needed for 2D drawing
		create_window: true
    resizable: false
		window_title: window_title
		frame_fn: frame
		user_data: video
    event_fn: on_event
	)
  return video
}

fn (video &Video) run() {
	video.gg.run()
}

fn frame(mut video &Video) {
	video.gg.begin()
	video.render()
	video.gg.end()
}

fn on_event(evt &gg.Event, mut video Video) {
  if evt.typ == .quit_requested || (evt.typ == .key_down && evt.key_code == .escape) {
    exit(0)
  } else if (evt.typ == .key_down || evt.typ == .key_up) && evt.key_code in keymap {
    i := keymap[evt.key_code]  // intermediate variable to work around V bug
    video.keyboard[i] = evt.typ == .key_down
  }
}

fn (mut video Video) render() {
  for x in 0..width {
    for y in 0..height {
      color := gx.Color {
        r: video.matrix[x][y]
        g: video.matrix[x][y]
        b: video.matrix[x][y]
      }
      if video.matrix[x][y] > 0 && video.matrix[x][y] < 0xFF {
        if video.matrix[x][y] >= pixel_fade_step {
          video.matrix[x][y] -= pixel_fade_step
        } else {
          video.matrix[x][y] = 0
        }
      }
      video.gg.draw_rect(x * scale, y * scale, scale, scale, color)
    }
  }
}

fn (mut video Video) clear_screen() {
  for x in 0..width {
    for y in 0..height {
      video.matrix[x][y] = 0x00
    }
  }
}

fn (mut video Video) draw_sprite(x byte, y byte, sprite []byte) bool {
  modx := x % width
  mut mody := y % height
  mut off := false
  for row in sprite {
    if mody >= height {
      continue
    }
    for col in 0..8 {
      if modx + col >= width {
        continue
      }
      bit := (row & (0x80 >> col)) > 0
      prev := video.matrix[modx + col][mody]
      if prev == 0xFF && bit {
        video.matrix[modx + col][mody] -= pixel_fade_step
      } else if bit {
        video.matrix[modx + col][mody] = 0xFF
      }
      off = off || (prev == 0xFF && bit)
    }
    mody += 1
  }
  return off
}
