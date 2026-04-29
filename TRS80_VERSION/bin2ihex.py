import sys

if len(sys.argv) != 4:
    print("Usage: python bin2ihex.py input.bin output.hex load_address_hex")
    print("Example: python bin2ihex.py BEAST.bin BEAST.hex 5200")
    sys.exit(1)

infile = sys.argv[1]
outfile = sys.argv[2]
addr = int(sys.argv[3], 16)

with open(infile, "rb") as f:
    data = f.read()

def record(address, rectype, payload):
    count = len(payload)
    bytes_for_sum = [count, (address >> 8) & 0xFF, address & 0xFF, rectype] + list(payload)
    checksum = ((~sum(bytes_for_sum) + 1) & 0xFF)
    return ":" + "".join(f"{b:02X}" for b in bytes_for_sum) + f"{checksum:02X}"

lines = []

for offset in range(0, len(data), 16):
    chunk = data[offset:offset + 16]
    lines.append(record(addr + offset, 0x00, chunk))

lines.append(record(0x0000, 0x01, b""))

with open(outfile, "w", newline="\n") as f:
    f.write("\n".join(lines) + "\n")

print(f"Wrote {outfile}")
print(f"Load address: {addr:04X}")
print(f"End address:  {addr + len(data) - 1:04X}")