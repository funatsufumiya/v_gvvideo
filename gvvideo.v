module gvvideo

import os
import dxt_decoder
import lz4

pub const gv_format_dxt1 = 1
pub const gv_format_dxt3 = 3
pub const gv_format_dxt5 = 5

pub struct GVHeader {
pub mut:
	width       u32
	height      u32
	frame_count u32
	fps         f32
	format      u32
	frame_bytes u32
}

pub struct GVAddressSizeBlock {
pub mut:
	address u64
	size    u64
}

pub struct GVVideo {
pub mut:
	header              GVHeader
	address_size_blocks []GVAddressSizeBlock
	file                os.File
}

// Read header from file
pub fn read_header(mut f os.File) !GVHeader {
	mut header := GVHeader{}
	header.width = f.read_le[u32]()!
	header.height = f.read_le[u32]()!
	header.frame_count = f.read_le[u32]()!
	header.fps = f.read_le[f32]()!
	header.format = f.read_le[u32]()!
	header.frame_bytes = f.read_le[u32]()!
	return header
}

// Read address/size blocks from file
pub fn read_address_size_blocks(mut f os.File, frame_count u32) ![]GVAddressSizeBlock {
	mut blocks := []GVAddressSizeBlock{len: int(frame_count)}
	f.seek(-i64(frame_count * 16), .end)!
	for i in 0 .. int(frame_count) {
		blocks[i].address = f.read_le[u64]()!
		blocks[i].size = f.read_le[u64]()!
	}
	return blocks
}

// Load GVVideo from file path
pub fn load_gvvideo(path string) !GVVideo {
	mut f := os.open(path)!
	header := read_header(mut f)!
	blocks := read_address_size_blocks(mut f, header.frame_count)!
	f.seek(0, .start)!
	return GVVideo{
		header:              header
		address_size_blocks: blocks
		file:                f
	}
}

// Read compressed frame (LZ4 decompress only, no DXT decode)
pub fn (mut v GVVideo) read_frame_compressed(frame_id u32) ![]u8 {
	if frame_id >= v.header.frame_count {
		return error('end of video')
	}
	block := v.address_size_blocks[frame_id]
	compressed := v.file.read_bytes_at(int(block.size), block.address)
	width := int(v.header.width)
	height := int(v.header.height)
	uncompressed_size := width * height * 4
	mut decompressed := []u8{len: uncompressed_size, init: 0}
	decompressed_size := lz4.lz_4_decompress_safe(&u8(compressed.data), &u8(decompressed.data),
		compressed.len, uncompressed_size)
	if decompressed_size < 0 {
		return error('LZ4 decompress failed')
	}
	return decompressed[..uncompressed_size]
}

// Read and decode frame to RGBA buffer
pub fn (mut v GVVideo) read_frame_to(frame_id u32, mut buf []u8) ! {
	if frame_id >= v.header.frame_count {
		return error('end of video')
	}
	block := v.address_size_blocks[frame_id]
	compressed := v.file.read_bytes_at(int(block.size), block.address)
	width := int(v.header.width)
	height := int(v.header.height)
	uncompressed_size := width * height * 4
	mut decompressed := []u8{len: uncompressed_size, init: 0}
	decompressed_size := lz4.lz_4_decompress_safe(&u8(compressed.data), &u8(decompressed.data),
		compressed.len, uncompressed_size)
	if decompressed_size < 0 {
		return error('LZ4 decompress failed')
	}
	// DXT decode
	mut dxt_format := dxt_decoder.DxtFormat.dxt1
	if v.header.format == gv_format_dxt3 {
		dxt_format = dxt_decoder.DxtFormat.dxt3
	} else if v.header.format == gv_format_dxt5 {
		dxt_format = dxt_decoder.DxtFormat.dxt5
	}
	decoded := dxt_decoder.decode(decompressed[..uncompressed_size], width, height, dxt_format)!
	if buf.len < decoded.len {
		return error('buffer too small')
	}
	for i in 0 .. decoded.len {
		buf[i] = decoded[i]
	}
}

// Read and decode frame, return RGBA []u8
pub fn (mut v GVVideo) read_frame(frame_id u32) ![]u8 {
	width := int(v.header.width)
	height := int(v.header.height)
	mut buf := []u8{len: width * height * 4}
	v.read_frame_to(frame_id, mut buf) or { return error(err.msg()) }
	return buf
}
