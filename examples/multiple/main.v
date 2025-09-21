module main

import gg
import time
import os
import gvvideo

const win_width = 800
const win_height = 600

struct App {
mut:
	gg         &gg.Context = unsafe { nil }
	players    []gvvideo.GVPlayer
	errs       []string
	async      bool
	gv_paths   []string
	start_times []time.Time
}

fn main() {
	mut gv_paths := []string{}
	if os.args.len > 1 {
		first := os.args[1]
		if os.is_dir(first) {
			entries := os.ls(first) or { []string{} }
			for entry in entries {
				if !os.is_dir(os.join_path(first, entry)) && entry.to_lower().ends_with('.gv') {
					gv_paths << os.join_path(first, entry)
				}
			}
		} else {
			gv_paths = os.args[1..]
		}
	} else {
		gv_paths = ['test_asset/test-10px.gv', 'test_asset/test-10px.gv']
		println('[INFO] Playing default GV videos. You can specify multiple .gv files as arguments or a directory.')
	}
	mut players := []gvvideo.GVPlayer{}
	mut errs := []string{}
	mut start_times := []time.Time{}
	for path in gv_paths {
		mut player := gvvideo.new_gvplayer_with_option(path, false, false) or {
			errs << err.msg()
			continue
		}
		player.set_loop(true)
		player.play()
		players << player
		start_times << time.now()
	}
	mut app := &App{
		players: players
		errs: errs
		async: true
		gv_paths: gv_paths
		start_times: start_times
	}
	app.gg = gg.new_context(
		bg_color: gg.gray
		width: win_width
		height: win_height
		create_window: true
		window_title: 'GV Video Multiple (V+gg Demo)'
		frame_fn: frame
		user_data: app
	)
	app.gg.run()
}

fn frame(mut app App) {
	app.gg.begin()

	n := app.players.len
	if n == 0 {
		app.gg.end()
		return
	}
	mut cols := 1
	for cols * cols < n {
		cols++
	}
	rows := (n + cols - 1) / cols
	w := win_width / cols
	h := win_height / rows
	for i, mut player in app.players {
		if i < app.errs.len && app.errs[i] != '' {
			continue
		}
		player.update() or {
			if i < app.errs.len {
				app.errs[i] = err.msg()
			}
			continue
		}
		row := i / cols
		col := i % cols
		video_w := player.width()
		video_h := player.height()
		scale_x := f32(w) / f32(video_w)
		scale_y := f32(h) / f32(video_h)
		scale := if scale_y < scale_x { scale_y } else { scale_x }
		ww := int(f32(video_w) * scale)
		hh := int(f32(video_h) * scale)
		tx := col * w + (w - ww) / 2
		ty := row * h + (h - hh) / 2
		player.draw(mut app.gg, tx, ty, ww, hh)
		video_time := player.current_time()
		elapsed := f32((time.now() - app.start_times[i]).nanoseconds()) / 1000_000_000.0
		msg := 'Video ${i+1}: ${video_time:.2f}s | Elapsed: ${elapsed:.2f}s'
		app.gg.draw_text_def(col * w, row * h + 16, msg)
	}
	app.gg.draw_text_def(10, 10, 'Async: $app.async')

	app.gg.end()
}