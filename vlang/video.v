import gg
import gx


const (
	width      = 64
	height     = 32
  scale      = 20
  fg_color   = gx.white
  bg_color   = gx.black
)

struct Video {
mut:
	gg     &gg.Context
  matrix [width][height]bool = [width][height]bool{init: [height]bool{init: false}}
}

fn get_video() &Video {
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
		window_title: 'CHIP-8 in VLang'
		frame_fn: frame
		user_data: video
    event_fn: on_event
	)
  return video
}

fn (video &Video) run() {
	video.gg.run()
}

fn frame(video &Video) {
	video.gg.begin()
	video.render()
	video.gg.end()
}

fn on_event(evt &gg.Event, mut video Video) {
  if evt.typ == .quit_requested {
    exit(0)
  }
}

fn (video &Video) render() {
  for x in 0..width {
    for y in 0..height {
      color := if video.matrix[x][y] {fg_color} else {bg_color}
      video.gg.draw_rect(x * scale, y * scale, scale, scale, color)
    }
  }
}

fn (mut video Video) clear_screen() {
  for x in 0..width {
    for y in 0..height {
      video.matrix[x][y] = false
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
      video.matrix[modx + col][mody] = prev != bit
      off = off || (prev && !bit)
    }
    mody += 1
  }
  return off
}
