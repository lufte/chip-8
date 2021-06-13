import gg
import gx
import math

const (
	win_width  = 64
	win_height = 32
  scale      = 20
  fg_color   = gx.white
  bg_color   = gx.black
)

struct App {
mut:
	gg     &gg.Context
  matrix [win_width][win_height]bool
}

fn main() {
	mut app := &App{
		gg: 0
    matrix: [win_width][win_height]bool{init:[win_height]bool{init: false}}
	}
	app.gg = gg.new_context(
		bg_color: gx.black
		width: win_width * scale
		height: win_height * scale
		use_ortho: true // This is needed for 2D drawing
		create_window: true
    resizable: false
		window_title: 'CHIP-8 in VLang'
		frame_fn: frame
    event_fn: on_event
		user_data: app
	)
	app.gg.run()
}

fn frame(app &App) {
	app.gg.begin()
	app.draw()
	app.gg.end()
}

fn on_event(evt &gg.Event, mut app App) {
  if evt.typ == .mouse_down {
    x := int(math.floor(evt.mouse_x / scale))
    y := int(math.floor(evt.mouse_y / scale))
    app.matrix[x][y] = !app.matrix[x][y]
  }
}

fn (app &App) draw() {
  for x in 0..win_width {
    for y in 0..win_height {
      color := if app.matrix[x][y] {fg_color} else {bg_color}
      app.gg.draw_rect(x * scale, y * scale, scale, scale, color)
    }
  }
}
