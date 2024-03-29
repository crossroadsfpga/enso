#!/usr/bin/python3
import sys


def parse_line(line):
    empty = 0
    temp = line.replace(" ", "")
    temp = temp.split(":")[1]
    length = len(temp)
    if length - 1 == 32:
        res = temp[:-1]
    else:
        empty = (32 - (length - 1)) // 2
        res = temp[:-1] + (empty * 2) * "f"

    return res, empty


fname = sys.argv[1]
outname = sys.argv[2]
sop = 0
eop = 1
empty_p = 0
empty_c = 0
data_p = [None] * 4
data_c = 0
data_field = 0


f = open(fname)
fout = open(outname, "w")
p = 0
c = 0
cnt = 0
for i, line in enumerate(f):
    if "0x" in line and ">" not in line:
        c = 1
        data_c, empty_c = parse_line(line)
    else:
        c = 0

    if "0x0000:" in line:
        sop = 1

    if p == 1 and c == 1:
        eop = 0

        if cnt == 4:
            data_p_str = ""
            for i in data_p:
                assert i is not None
                data_p_str += i

            fout.write(
                str(sop)
                + str(eop)
                + str(format(empty_p, "x")).zfill(2)
                + data_p_str
                + "\n"
            )
            cnt = 0
            sop = 0
    elif p == 1 and c == 0:
        eop = 1
        empty_p = empty_p + (4 - cnt) * 16
        for j in range(0, cnt):
            d = data_p[j]
            assert d is not None
            if j == 0:
                data_field = d
            else:
                data_field = data_field + d
        data_field = data_field + ((4 - cnt) * 16 * 2) * "f"
        fout.write(
            str(sop)
            + str(eop)
            + str(format(empty_p, "x")).zfill(2)
            + data_field
            + "\n"
        )
        sop = 0
        cnt = 0
    else:
        eop = 0
    p = c

    if c:
        data_p[cnt] = data_c
        cnt += 1
    empty_p = empty_c

f.close()
fout.close()
