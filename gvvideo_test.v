module main

import os
import gvvideo

fn almost_equal(a u8, b u8) bool {
	mut d := int(a) - int(b)
	if d < 0 {
		d = -d
	}
	return d <= 8
}

fn assert_rgba(got []u8, want_r u8, want_g u8, want_b u8, want_a u8, msg string) {
	assert almost_equal(got[0], want_r), msg + ': R mismatch (got ${got[0]}, expected ${want_r})'
	assert almost_equal(got[1], want_g), msg + ': G mismatch (got ${got[1]}, expected ${want_g})'
	assert almost_equal(got[2], want_b), msg + ': B mismatch (got ${got[2]}, expected ${want_b})'
	assert almost_equal(got[3], want_a), msg + ': A mismatch (got ${got[3]}, expected ${want_a})'
}

fn test_gvvideo_read_header() {
	gv_path := os.join_path('test_asset', 'test-10px.gv')
	mut video := gvvideo.load_gvvideo(gv_path) or { panic('failed to load gv: ' + err.msg()) }
	w := int(video.header.width)
	h := int(video.header.height)
	assert w == 10 && h == 10, 'unexpected size: ${w}x${h}'
	assert video.header.frame_count == 5, 'unexpected frame count: ${video.header.frame_count}'
	assert video.header.fps == 1.0, 'unexpected fps: ${video.header.fps}'
	assert video.header.format == gvvideo.gv_format_dxt1, 'unexpected format: ${video.header.format}'
	assert video.header.frame_bytes == 72, 'unexpected frame bytes: ${video.header.frame_bytes}'
}

fn test_gvvideo_read_frame() {
	gv_path := os.join_path('test_asset', 'test-10px.gv')
	mut video := gvvideo.load_gvvideo(gv_path) or { panic('failed to load gv: ' + err.msg()) }
	w := int(video.header.width)
	h := int(video.header.height)
	assert w == 10 && h == 10, 'unexpected size: ${w}x${h}'
	assert video.header.frame_count == 5, 'unexpected frame count: ${video.header.frame_count}'
	assert video.header.fps == 1.0, 'unexpected fps: ${video.header.fps}'
	assert video.header.format == gvvideo.gv_format_dxt1, 'unexpected format: ${video.header.format}'
	assert video.header.frame_bytes == 72, 'unexpected frame bytes: ${video.header.frame_bytes}'

	frame := video.read_frame(3) or {
		assert false, 'failed to read frame: ' + err.msg()
		return
	}
	assert frame.len == w * h * 4, 'unexpected frame length: ${frame.len}'
	// assert_rgba(frame[..4], 255, 0, 0, 255, '(0,0) should be red')
	// assert_rgba(frame[6*4..6*4+4], 0, 0, 255, 255, '(6,0) should be blue')
	// assert_rgba(frame[(0+w*6)*4..(0+w*6)*4+4], 0, 255, 0, 255, '(0,6) should be green')
	// assert_rgba(frame[(6+w*6)*4..(6+w*6)*4+4], 231, 255, 0, 255, '(6,6) should be yellow (allow error)')

	// video.read_frame(5) or { panic('could not read frame') }
}

fn test_gvvideo_read_frame_at() {
	gv_path := os.join_path('test_asset', 'test-10px.gv')
	mut video := gvvideo.load_gvvideo(gv_path) or { panic('failed to load gv: ' + err.msg()) }
	frame := video.read_frame(0) or { panic('failed to read frame at 0: ' + err.msg()) }
	// assert_rgba(frame[..4], 255, 0, 0, 255, '(0,0) should be red')
}
