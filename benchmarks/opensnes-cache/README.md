# OpenSNES cache benchmark

Four GSU jobs taken from the hand-written Super FX programs of
[OpenSNES](https://github.com/k0b3n4irb/opensnes), ported to DiscoC. They give
a concrete size target for the backend: the GSU code cache.

OpenSNES prefers to run a job from the 512-byte cache, because the SNES CPU
then keeps the Game Pak ROM while the GSU works. A job qualifies when it is at
most 512 bytes and uses no CACHE, no LJMP and no ROM read.

## Jobs

| Job | Reference | Hand-written | What it does |
| --- | --- | --- | --- |
| `add_job.dc` | `gsu_job.sfx`, `gsu_start` | 40 bytes | 200 x 3000 additions under LOOP, three word stores |
| `mul_job.dc` | `gsu_job.sfx`, `mul_job` | 20 bytes | multiply by repeated addition |
| `rom_job.dc` | `gsu_job.sfx`, `rom_job` | 29 bytes | combine two bytes of a ROM table (not a cache job) |
| `fixed_job.dc` | `gsu_hello.sfx` | 57 bytes | byte and word stores, two 4.12 products |

The references are in `testing/fixtures/libtests_gsu/` and
`examples/chips/superfx_hello/` of the OpenSNES repository.

## Running it

```sh
cmake -DDISCO_TOOLS_DIR=build/release/bin -P benchmarks/opensnes-cache/report.cmake
```

The script compiles and links each job with `--init-runtime`, checks its
results in the execution model and prints its size next to the hand-written
one. Wrong results always fail. Add `-DENFORCE_BUDGET=ON` to also fail while a
cache job is larger than 512 bytes. CTest runs the non-enforcing form as
`opensnes_cache_benchmark`.

## Differences from the references

The ports are not byte-for-byte equivalents, because some things the
references do cannot be written today:

- Results go to `$70:0010` and up. The references write from `$70:0000`,
  which a near pointer cannot address (it is the null pointer).
- `mul_job` reads its operands from RAM. The reference receives them in R1
  and R2, written by the host before the start.
- Each job is its own payload with one entry. The reference file holds three
  entry points and exports their offsets in a generated header.
- `fixed_job` multiplies without FMULT.
- `add_job` is checked with a 30-step inner loop: the full 600 000 iterations
  exceed the model's instruction limit. Its size is measured unmodified.

Cache code runs at `$0000-$01FF`. `discld` does not accept an origin there, so
the payloads are linked at the default origin and only measured.
