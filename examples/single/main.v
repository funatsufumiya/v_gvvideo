
module main

import gg
import time
import os
import gvvideo

const win_width = 800
const win_height = 600

// TODO: async

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
	mut gv_path := 'test_asset/test-10px.gv'
	if os.args.len > 1 {
		gv_path = os.args[1]
	} else {
		println('[INFO] Playing the default GV video. You can specify a .gv file as an argument.')
	}
	mut player := gvvideo.new_gvplayer_with_option(gv_path, true, false) or {
		panic('Failed to load GV: '+err.msg())
	}
	player.set_loop(true)
	player.play()
	mut app := &App{
		player: player
		async: true
		gv_path: gv_path
		start_time: time.now()
	}
	app.gg = gg.new_context(
		bg_color: gg.gray
		width: win_width
		height: win_height
		create_window: true
		window_title: 'GV Video (V+gg Demo)'
		frame_fn: frame
		// keydown_fn: on_keydown
		user_data: app
	)
	app.gg.run()
}

// fn on_keydown(keycode gg.KeyCode, modifier gg.Modifier, mut app App) {
// 	if keycode == .a {
// 		app.toggle_async()
// 	}
// }

// fn (mut app App) toggle_async() {
// 	app.async = !app.async
// 	app.player.set_async(app.async)
// 	app.start_time = time.now()
// }

fn frame(mut app App) {
	app.gg.begin()

	if app.err != '' {
		app.gg.draw_text_def(20, 20, 'Error: '+app.err)
		app.gg.end()
		return
	}
	app.player.update() or {
		app.err = err.msg()
		return
	}
	// scale and center
	video_w := app.player.width()
	video_h := app.player.height()
	scale_x := f32(win_width) / f32(video_w)
	scale_y := f32(win_height) / f32(video_h)
	scale := if scale_y < scale_x { scale_y } else { scale_x }
	w := int(f32(video_w) * scale)
	h := int(f32(video_h) * scale)
	// println("w x h: ${w} x ${h}")
	tx := (win_width - w) / 2
	ty := (win_height - h) / 2
	// println("x x y: ${tx} x ${ty}")

	app.player.draw(mut app.gg, tx, ty, w, h)

	// app.gg.draw_text_def(10, 10, 'Async: $app.async (A key to toggle)')
	app.gg.draw_text_def(10, 10, 'Async: $app.async')
	video_time := app.player.current_time()
	elapsed := f32((time.now() - app.start_time).nanoseconds()) / 1000_000_000.0
	app.gg.draw_text_def(10, 30, 'VideoTime: ${video_time:.2f}s | Elapsed: ${elapsed:.2f}s')

	app.gg.end()
}
