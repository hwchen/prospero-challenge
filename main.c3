module prospero;
import std::core::mem;
import std::encoding::hex;
import std::io;
import std::math;
import std::core::test;

const usz IMAGE_SIZE = 1024;
const usz IMAGE_PIXEL_COUNT = IMAGE_SIZE * IMAGE_SIZE;

fn int main(String[] cli_args) {
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
	Coord[] coords = meshgrid(space, space_neg);
	double[] output = mem::temp_array(double, IMAGE_PIXEL_COUNT);

	Instr[] instrs = instructions::parse(tmem, input);

	double[] v = mem::temp_array(double, instrs.len);
	foreach (idx, coord : coords) {
		//io::printfn("%f %f", coord.x, coord.y);
		uint last_out;
		foreach (instr : instrs) {
			//if (instr.op == CONST) {
			//	io::printfn("%d %s %f", instr.out, instr.op, instr.const_value);
			//} else {
			//	io::printfn("%d %s %s", instr.out, instr.op, instr.args);
			//}
			uint out = instr.out;
			Op op = instr.op;
			uint[2] args = instr.args;
			switch (op) {
				case VAR_X:  v[out] = coord.x;
				case VAR_Y:  v[out] = coord.y;
				case CONST:  v[out] = instr.const_value;
				case ADD:    v[out] = v[args[0]] + v[args[1]];
				case SUB:    v[out] = v[args[0]] - v[args[1]];
				case MUL:    v[out] = v[args[0]] * v[args[1]];
				case MAX:    v[out] = max(v[args[0]], v[args[1]]);
				case MIN:    v[out] = min(v[args[0]], v[args[1]]);
				case NEG:    v[out] = -v[args[0]];
				case SQUARE: v[out] = v[args[0]] * v[args[0]];
				case SQRT:   v[out] = math::sqrt(v[args[0]]);
				default:
					io::eprintfn("unknown opcode '%s'", op);
					return 1;
			}
			last_out = out;
		}
		output[idx] = v[last_out];

		if (idx % 1000 == 0) {
			io::eprintfn("Finished cell %d/%d", idx, IMAGE_PIXEL_COUNT);
		}
	}
	//io::eprintfn("%s", output);

	File? f_out = file::open("out.ppm", "wb");
	if (catch err = f_out) {
		io::eprintfn("Error opening out.ppm");
		return 1;
	}
	// P5 expects raw bytes
	io::fprintf(&f_out, "P5\n%d %d\n255\n", IMAGE_SIZE, IMAGE_SIZE)!!;
	foreach (cell : output) {
		//if (cell < 0) io::printfn("HIT, %b, %d", (cell < 0), (int)(cell < 0) * 255);
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

struct Coord {
	double x;
	double y;
}
macro meshgrid(xs, ys) {
	Coord[] coords = mem::temp_array(Coord, xs.len * ys.len);
	// careful not to get these switched
	foreach (i, y: ys) {
		foreach (j, x : xs) {
			coords[(xs.len * i) + j] = { .x = x, .y = y};
		}
	}
	return coords;
}
