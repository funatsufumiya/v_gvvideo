module gvvideo

import time
import gg

pub enum PlayerState {
	stopped
	playing
	paused
}

pub struct GVPlayer {
mut:
	video         gvvideo.GVVideo
	frame_image   gg.Image
	frame_buf     []u8
	state         PlayerState
	start_time    time.Time
	pause_time    time.Time
	seek_time     i64
	looping       bool
	last_frame_id u32
	last_frame_time i64
}

pub fn new_gvplayer(path string) !GVPlayer {
	mut video := gvvideo.load_gvvideo(path)!
	width := int(video.header.width)
	height := int(video.header.height)
	frame_buf := []u8{len: width * height * 4}
	frame_image := gg.Image{ id: 0, width: width, height: height }
	return GVPlayer{
		video: video
		frame_image: frame_image
		frame_buf: frame_buf
		state: .stopped
		looping: false
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
}

pub fn (mut p GVPlayer) seek(to i64) {
	p.seek_time = to
}

pub fn (mut p GVPlayer) update() ! {
	if p.state != .playing {
		return
	}
	elapsed := time.now() - p.start_time + p.seek_time
	fps := p.video.header.fps
	mut frame_id := u32(f64(elapsed) / 1000.0 * f64(fps))
	if frame_id >= p.video.header.frame_count {
		if p.looping {
			p.start_time = time.now()
			p.seek_time = 0
			frame_id = 0
		} else {
			p.state = .stopped
			return
		}
	}
	p.video.read_frame_to(frame_id, mut p.frame_buf) or { return }
	p.last_frame_id = frame_id
	p.last_frame_time = i64(f64(frame_id) / f64(fps) * 1000.0)
}

pub fn (p &GVPlayer) current_time() f64 {
	return f64(p.last_frame_time) / 1000.0
}

pub fn (mut p GVPlayer) set_loop(b bool) {
	p.looping = b
}

pub fn (p &GVPlayer) get_loop() bool {
	return p.looping
}

pub fn (mut p GVPlayer) draw(mut ctx gg.Context, x int, y int, w int, h int) {
	if p.frame_image.id == 0 {
		p.frame_image = ctx.create_image_from_byte_array(p.frame_buf) or { return }
	} else {
		p.frame_image.update_pixel_data(p.frame_buf.data)
	}
	ctx.draw_image(x, y, w, h, p.frame_image)
}
