module prospero;
import std::core::mem;
import std::encoding::hex;
import std::io;
import std::math;
import std::core::test;

const usz IMAGE_SIZE = 1024;
const usz IMAGE_PIXEL_COUNT = IMAGE_SIZE * IMAGE_SIZE;
const usz SIMD_CHUNK_SIZE = 16;

// Manually chunk into 1 double (8 bytes) x 16 register chunks, for simd.
// This should be better than numpy vectors which have to create an entire frame
// for each instruction in order to get vectorization. instead, we just need to
// hold the intermediate frames for just 8 at a time. I assume this also avoids having
// to allocate for each frame.
//
// 16 seems best, maps to 128 bits register
alias Chunk = double[<SIMD_CHUNK_SIZE>];

fn int main(String[] cli_args) {
	$assert(IMAGE_SIZE % SIMD_CHUNK_SIZE == 0);

	String? input = (String)file::load_temp(cli_args[1]);
	if (catch err = input) {
		io::eprintfn("Error loading prospero.vm");
		return 1;
	}
	double[] space = linspace(-1, 1, IMAGE_SIZE);
	double[] space_neg = mem::temp_array(double, IMAGE_SIZE);
	foreach (idx, x : space) {
		space_neg[idx] = x * -1;
	}

	double[] x_coords = mem::temp_array(double, IMAGE_PIXEL_COUNT);
	double[] y_coords = mem::temp_array(double, IMAGE_PIXEL_COUNT);
	foreach (i, y: space_neg) {
		foreach (j, x : space) {
			x_coords[(IMAGE_SIZE * i) + j] = x;
			y_coords[(IMAGE_SIZE * i) + j] = y;
		}
	}

	Instr[] instrs = instructions::parse(tmem, input);
	Chunk[] v = mem::temp_array(Chunk, instrs.len);
	double[] output = mem::temp_array(double, IMAGE_PIXEL_COUNT);

	for (usz idx = 0; idx < IMAGE_PIXEL_COUNT; idx += SIMD_CHUNK_SIZE) {
		uint last_out;
		foreach (instr : instrs) {
			uint out = instr.out;
			Op op = instr.op;
			uint[2] args = instr.args;
			switch (op) {
				case VAR_X:  v[out] = x_coords[idx:SIMD_CHUNK_SIZE];
				case VAR_Y:  v[out] = y_coords[idx:SIMD_CHUNK_SIZE];
				case CONST:  v[out] = (double[<SIMD_CHUNK_SIZE>])instr.const_value;
				case ADD:    v[out] = v[args[0]] + v[args[1]];
				case SUB:    v[out] = v[args[0]] - v[args[1]];
				case MUL:    v[out] = v[args[0]] * v[args[1]];
				case MAX:    v[out] = math::max(v[args[0]], v[args[1]]);
				case MIN:    v[out] = math::min(v[args[0]], v[args[1]]);
				case NEG:    v[out] = -v[args[0]];
				case SQUARE: v[out] = v[args[0]] * v[args[0]];
				case SQRT:   v[out] = math::sqrt(v[args[0]]);
				default:
					io::eprintfn("unknown opcode '%s'", op);
					return 1;
			}
			last_out = out;
		}
		foreach (chunk_idx, value: v[last_out]) {
			output[idx + chunk_idx] = value;
		}

		//if (idx % IMAGE_SIZE == 0) {
		//	io::eprintfn("Finished cell %d/%d", idx, IMAGE_PIXEL_COUNT);
		//}
	}

	File? f_out = file::open("out.ppm", "wb");
	if (catch err = f_out) {
		io::eprintfn("Error opening out.ppm");
		return 1;
	}
	// P5 expects raw bytes
	io::fprintf(&f_out, "P5\n%d %d\n255\n", IMAGE_SIZE, IMAGE_SIZE)!!;
	foreach (cell : output) {
		f_out.write_byte((int)(cell < 0) * 255)!!;
	}

	return 0;
}

macro linspace(start, end, samples) {
	double interval = (double)(end - start) / (double)(samples - 1);
	double[] space = mem::temp_array(double, samples);
	int idx;
	double x = start;
	while (idx < samples) {
		space[idx] = x;
		x += interval;
		idx += 1;
	}
	return space;
}
