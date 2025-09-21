module gvvideo

import time
import gg
import sokol.gfx

pub enum PlayerState {
	stopped
	playing
	paused
}

pub struct GVPlayer {
mut:
	video         gvvideo.GVVideo
	frame_image   int // gg.Image
	frame_buf     []u8
	state         PlayerState
	start_time    time.Time
	pause_time    time.Time
	seek_time     f64
	looping       bool
	async         bool
	frame_ch      chan []u8
	stop_ch       chan bool
	last_frame_id u32
	last_frame_time f64
}

pub fn new_gvplayer(path string) !GVPlayer {
	return new_gvplayer_with_option(path, true)
}

pub fn new_gvplayer_with_option(path string, async bool) !GVPlayer {
	mut video := gvvideo.load_gvvideo(path)!
	width := int(video.header.width)
	height := int(video.header.height)
	frame_buf := []u8{len: width * height * 4}
	frame_image := 0
	return GVPlayer{
		video: video
		frame_image: frame_image
		frame_buf: frame_buf
		state: .stopped
		looping: false
		async: async
		frame_ch: chan []u8{cap: 1}
		stop_ch: chan bool{}
	}
}

pub fn (p &GVPlayer) width() int {
	return int(p.video.header.width)
}

pub fn (p &GVPlayer) height() int {
	return int(p.video.header.height)
}

pub fn (mut p GVPlayer) play() {
	if p.state == .playing {
		return
	}
	p.state = .playing
	p.start_time = time.now()
	if p.async {
		go p.async_update_loop()
	}
}

pub fn (mut p GVPlayer) pause() {
	if p.state != .playing {
		return
	}
	p.state = .paused
	p.pause_time = time.now()
}

pub fn (mut p GVPlayer) stop() {
	p.state = .stopped
	p.seek_time = 0
	if p.async {
		p.stop_ch <- true
	}
}

pub fn (mut p GVPlayer) seek(to f64) {
	p.seek_time = to
}

pub fn (mut p GVPlayer) update() ! {
	if p.state != .playing {
		return
	}
	elapsed_sec := f32((time.now() - p.start_time).nanoseconds()) / 1000_000_000.0 + p.seek_time
	fps := p.video.header.fps
	mut frame_id := u32(elapsed_sec * fps)
	if frame_id >= p.video.header.frame_count {
		if p.looping {
			p.start_time = time.now()
			p.seek_time = 0
			frame_id = 0
			p.last_frame_id = 0
		} else {
			p.state = .stopped
			return
		}
	}
	if p.async {
		if frame_id != p.last_frame_id {
			if p.frame_ch.len > 0 {
				pix := <-p.frame_ch
				unsafe { p.frame_buf = pix.clone() }
				p.last_frame_id = frame_id
				p.last_frame_time = f64(frame_id) / f64(fps) * 1000.0
			}
		}
		return
	}
	p.video.read_frame_to(frame_id, mut p.frame_buf) or { return }
	p.last_frame_id = frame_id
	p.last_frame_time = f64(frame_id) / f64(fps) * 1000.0
}

pub fn (p &GVPlayer) current_frame() u32 {
	return p.last_frame_id
}

pub fn (p &GVPlayer) current_time() f64 {
	// return f64(p.last_frame_time) / 1000_000_000.0
    return p.last_frame_time / 1000.0
}

pub fn (mut p GVPlayer) set_loop(b bool) {
	p.looping = b
}

pub fn (p &GVPlayer) get_loop() bool {
	return p.looping
}

pub fn (p &GVPlayer) get_pixel_format() gfx.PixelFormat {
	match p.video.header.format {
		gvvideo.gv_format_dxt1 { return .bc1_rgba }
		gvvideo.gv_format_dxt3 { return .bc2_rgba }
		gvvideo.gv_format_dxt5 { return .bc3_rgba }
		else { return .bc3_rgba }
	}
}

pub fn (mut p GVPlayer) draw(mut ctx gg.Context, x int, y int, w int, h int) {
	if p.frame_image == 0 {
		// p.frame_image = ctx.create_image_from_byte_array(p.frame_buf) or { return }
		p.frame_image = ctx.new_streaming_image(int(p.video.header.width), int(p.video.header.height), 4, gg.StreamingImageConfig{
			// pixel_format: p.get_pixel_format()
			pixel_format: .rgba8
		})
		// println("pixel_format: ${p.get_pixel_format()}")
		ctx.update_pixel_data(p.frame_image, p.frame_buf.data)
	} else {
		ctx.update_pixel_data(p.frame_image, p.frame_buf.data)
	}
	// println("p.frame_image: ${p.frame_image}")
	ctx.draw_image_by_id(x, y, w, h, p.frame_image)
}

pub fn (mut p GVPlayer) async_update_loop() {
	for {
		if p.stop_ch.len > 0 {
			_ := <-p.stop_ch
			return
		}
		elapsed_sec := f32((time.now() - p.start_time).nanoseconds()) / 1000_000_000.0 + p.seek_time
		fps := p.video.header.fps
		mut frame_id := u32(elapsed_sec * fps)
		if frame_id >= p.video.header.frame_count {
			if p.looping {
				p.start_time = time.now()
				p.seek_time = 0
				frame_id = 0
				p.last_frame_id = 0
			} else {
				p.state = .stopped
				return
			}
		}
		if frame_id != p.last_frame_id && frame_id < p.video.header.frame_count {
			width := int(p.video.header.width)
			height := int(p.video.header.height)
			mut buf := []u8{len: width * height * 4}
			p.video.read_frame_to(frame_id, mut buf) or { continue }
			if p.frame_ch.len == 0 {
				p.frame_ch <- buf
			}
			p.last_frame_id = frame_id
		}
		time.sleep(5 * time.millisecond)
	}
}
