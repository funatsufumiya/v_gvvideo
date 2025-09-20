
module main

import gg
import time
import gvvideo

const win_width = 800
const win_height = 600

struct App {
mut:
	gg         &gg.Context = unsafe { nil }
	player     gvvideo.GVPlayer
	async      bool
	gv_path    string
	start_time time.Time
	err        string
}

fn main() {
	gv_path := 'test_asset/test-10px.gv'
	mut player := gvvideo.new_gvplayer(gv_path) or {
		panic('Failed to load GV: '+err.msg())
	}
	player.set_loop(true)
	player.play()
	mut app := &App{
		player: player
		async: false
		gv_path: gv_path
		start_time: time.now()
	}
	app.gg = gg.new_context(
		bg_color: gg.white
		width: win_width
		height: win_height
		create_window: true
		window_title: 'GV Video (V+gg Demo)'
		frame_fn: frame
		keydown_fn: on_keydown
		user_data: app
	)
	app.gg.run()
}

fn on_keydown(keycode gg.KeyCode, modifier gg.Modifier, mut app App) {
	if keycode == .a {
		app.async = !app.async
	}
}

fn frame(mut app App) {
	app.gg.begin()
	if app.err != '' {
		app.gg.draw_text_def(20, 20, 'Error: '+app.err)
		app.gg.end()
		return
	}
	app.player.update() or {
		app.err = err.msg()
	}
	// scale and center
	video_w := app.player.width()
	video_h := app.player.height()
	scale_x := f32(win_width) / f32(video_w)
	scale_y := f32(win_height) / f32(video_h)
	scale := if scale_y < scale_x { scale_y } else { scale_x }
	w := int(f32(video_w) * scale)
	h := int(f32(video_h) * scale)
	tx := (win_width - w) / 2
	ty := (win_height - h) / 2
	app.player.draw(mut app.gg, tx, ty, w, h)
	app.gg.draw_text_def(10, 10, 'Async: $app.async (A key to toggle)')
	video_time := app.player.current_time()
	elapsed := f32((time.now() - app.start_time).nanoseconds()) / 1000_000_000.0
	app.gg.draw_text_def(10, 30, 'VideoTime: ${video_time:.2f}s | Elapsed: ${elapsed:.2f}s')
	app.gg.end()
}
