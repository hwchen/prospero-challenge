module prospero::instructions;
import std::collections;
import std::math;

fn Instr[] parse(Allocator alloc, String input) {
	List{Instr} instrs_list;
	@pool() {
		instrs_list.tinit();
		foreach (idx, line : input.tsplit("\n")) {
			if (line.len == 0) break;
			if (line[0] == '#') continue;
			String[] parts = line.tsplit(" ");
			Op op = str_to_op(parts[1]);
			Instr instr = {
				.out = arg_to_idx(parts[0]),
				.op = op,
			};
			if (op == CONST) {
				instr.const_value = parts[2].to_double()!!;
			} else {
				instr.args[0] = arg_to_idx(parts[2]);
				if (parts.len == 4) {
					instr.args[1] = arg_to_idx(parts[3]);
				}
			};
			instrs_list.push(instr);
		}
		return instrs_list.to_array(alloc);
	};
}

struct Instr {
	uint out;
	Op op;
	union {
		uint[2] args;
		double const_value;
	}
}

enum Op : char {
	VAR_X,
	VAR_Y,
	CONST,
	ADD,
	SUB,
	MUL,
	MAX,
	MIN,
	NEG,
	SQUARE,
	SQRT,
}

fn Op str_to_op(String s) {
	switch (s) {
	case "var-x": return VAR_X;
	case "var-y": return VAR_Y;
	case "const": return CONST;
	case "add": return ADD;
	case "sub": return SUB;
	case "mul": return MUL;
	case "max": return MAX;
	case "min": return MIN;
	case "neg": return NEG;
	case "square": return SQUARE;
	case "sqrt": return SQRT;
	default: unreachable();
	}
}

fn uint arg_to_idx(String arg) {
	uint total;
	uint i = arg.len;
	while (i != 0) {
		i -= 1;
		uint place = arg.len - i - 1;
		switch (arg[i]) {
			case '0'..'9':
				total += (uint)math::pow(16, place) * (arg[i] - '0');
			case 'a'..'f':
				total += (uint)math::pow(16, place) * (10 + arg[i] - 'a');
			default:
				continue;
		}
	}
	return total;
}

fn void test_hex() @test {
	test::eq(arg_to_idx("_f"), 15);
	test::eq(arg_to_idx("_2"), 2);
	test::eq(arg_to_idx("_1eb9"), 7865);
}
