module prospero;
import std::core::mem;
import std::encoding::hex;
import std::io;
import std::math;
import std::core::test;

const usz IMAGE_SIZE = 1024;
const usz IMAGE_PIXEL_COUNT = IMAGE_SIZE * IMAGE_SIZE;
const usz SIMD_CHUNK_SIZE = 32;
const float STEP = 2 / IMAGE_SIZE;

// Manually chunk into 1 float (4 bytes) x 32 register chunks, for simd.
// This should be better than numpy vectors which have to create an entire frame
// for each instruction in order to get vectorization. instead, we just need to
// hold the intermediate frames for just 8 at a time. I assume this also avoids having
// to allocate for each frame.
//
// 32 seems best, maps to 128 bits register
alias Chunk = float[<SIMD_CHUNK_SIZE>];

fn int main(String[] cli_args) {
	$assert(IMAGE_SIZE % SIMD_CHUNK_SIZE == 0);

	String? input = (String)file::load_temp(cli_args[1]);
	if (catch err = input) {
		io::eprintfn("Error loading prospero.vm");
		return 1;
	}


	Instr[] instrs = instructions::parse(tmem, input);
	Chunk[] v = mem::temp_array(Chunk, instrs.len);
	char[] output = mem::temp_array(char, IMAGE_PIXEL_COUNT);

	for (usz y_idx = 0; y_idx < IMAGE_SIZE; y_idx += 1) {
		for (usz x_idx = 0; x_idx < IMAGE_SIZE; x_idx += SIMD_CHUNK_SIZE) {
			uint last_out;
			foreach (instr : instrs) {
				uint out = instr.out;
				Op op = instr.op;
				uint[2] args = instr.args;
				switch (op) {
					case VAR_X:
						for (int chunk_idx = 0; chunk_idx < SIMD_CHUNK_SIZE; chunk_idx += 1) {
							v[out][chunk_idx] = -1 + ((float)(x_idx + chunk_idx) * STEP);
						}
					case VAR_Y:  v[out] = (float[<SIMD_CHUNK_SIZE>])-(-1 + (y_idx * STEP));
					case CONST:  v[out] = (float[<SIMD_CHUNK_SIZE>])instr.const_value;
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
				output[(IMAGE_SIZE * y_idx) + x_idx + chunk_idx] = (int)(value < 0) * 255;
			}

			//if ((x_idx * y_idx) % IMAGE_SIZE == 0) {
			//	io::eprintfn("Finished cell %d x %d: %d/%d", x_idx, y_idx, x_idx * y_idx, IMAGE_PIXEL_COUNT);
			//}
		}
	}

	File? f_out = file::open("out.ppm", "wb");
	if (catch err = f_out) {
		io::eprintfn("Error opening out.ppm");
		return 1;
	}
	// P5 expects raw bytes
	io::fprintf(&f_out, "P5\n%d %d\n255\n", IMAGE_SIZE, IMAGE_SIZE)!!;
	f_out.write(output)!!;

	return 0;
}
