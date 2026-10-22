# The distribution

A release of the current tree has two zips. Both unpack into one
directory, `saostoic/` (on VMS, `[.SAOSTOIC]`), with KERNEL, STOIC and RED
under it, so they can be unpacked side by side.

| Zip | Made by | What it holds |
|---|---|---|
| `saostoic-current-src.zip` | `tools/make-dist`, on Unix, from the commit HEAD | Every file of `current/` (56), `LICENSE-UNKNOWN.md`, and in `doc/` 12 of these documents with their own README (`dist/doc-README.md`) |
| `saostoic-current-exe.zip` | `tools/dist-exe.com`, on the VAX with `ZIP "-V"` | `[.KERNEL]HEAD0.EXE`, `[.STOIC]STOIC.EXE`, `[.RED]RED.EXE` and `REDHIREZ.EXE`, from `[.WORK.CURRENT...]` |

`current/README.md` tells a user how to use each one ("From the zip", "Or
use the prebuilt exes").

## The source zip

The documents in it are `language`, `errata`, `current`, `defects`,
`patches`, `red`, `float`, `image`, `kernel`, `words`, `build` and
`cpm-compare`. The last two are there because `patches.md`,
`language.md` and `errata.md` link to them. This README, `gm-variant.md`
(the GM kernel is not in the zip) and `data/` are left out. The
documents' own README warns that most of them describe the 1985 exes,
whose comparisons are the other way round, and that the tests and tools
they cite are in the repository.

`make-dist` rewrites `current/README.md` for the zip's layout: `../doc/`
becomes `doc/`, and `../tests/` becomes "the repository's `tests/`". It
dates every file as the commit, so the zip depends only on HEAD.

## The exe zip

The exes can go in a plain zip only since defect 50 was fixed: IMAGE now
writes them as fixed 512-byte records, as LINK does. `ZIP "-V"` keeps
that record format, and UnZip on VMS restores it. The `-V` must be in
quotes, because the VAX C run-time library lowercases the arguments, and
`-v` is a different option. HEAD0.EXE is in it because IMAGE needs the
HEAD0 of the same build to write a new exe.

## How they were tested

On 22 October 2026, on VAX/VMS V5.5-2H4, with Zip 3.0 and UnZip 6.00:

- **The source zip** went up by binary FTP and was unpacked with
  `UNZIP -a` in an empty directory. The text came out as variable-length
  records (RFM=VAR), 70 files in five directories. `@STOBUILD MAC` and
  `@HIREZ.CRE` printed the lines in `current/README.md` and nothing
  else, and the exes had the usual sizes: HEAD0 and RKERNEL 44 blocks,
  STOIC 110, RED and REDHIREZ 189. STOIC gave `0 -1` for
  `1 2 GT = 2 1 GT =` and printed `Hello, World`, and CALC gave
  `1024.000000000000` and `3.141592653589793`. With the build, the tree
  took 2875 blocks. (An earlier test of a zip of the 34 build files alone
  showed that plain `UNZIP`, which writes Stream_LF files, builds too.)
- **The exe zip** went down by binary FTP and back up, and was unpacked
  with `UNZIP` in an empty directory. STOIC.EXE came out as fixed 512-byte
  records. With SAO$KERNEL, SAO$STOIC and SAO$RED pointed at it, STOIC gave
  `0 -1`, CALC gave `1024.000000000000`, and IMAGE wrote a child exe that
  ran and printed ` 5`.

Each test ran in a scratch directory in `[.WORK]`, which was deleted
afterwards.
