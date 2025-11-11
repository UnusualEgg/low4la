# low4la

[LoLa](https://lola.random-projects.net) vm for [WASM-4](https://wasm4.org) fantasy console. This project adds an interface for LoLa code to interact with the WASM-4 console as well as a vm to run LoLa code. It compile the LoLa code at build-time then embeds the LoLa bytecode into the cart and runs that.

## Requirements
- [WASM-4](https://wasm4.org/docs/getting-started/setup)
## Setup

Make a `prg` directory in the root directory of this repo. Place a `main.lola` in the `prg` directory. Then build.

```
prg/main.lola
src/...
build.zig
README.md
```

## Building

Build the cart by running:

```shell
zig build --release=small
```

there are also options for enabling modules. just run:

```
-D<module>=true
```

for the modules:
- math
- stdlib
- runtime
- byte_array
- array
- string

for example:
```shell
zig build -Dmath=true --release=fast run
```

Then run it with:

```shell
w4 run zig-out/bin/cart.wasm
```

or build and run:

```shell
zig build --release=small run
```

For more info about setting up WASM-4, see the [quickstart guide](https://wasm4.org/docs/getting-started/setup?code-lang=zig#quickstart).

## Info
for more info on the API, refer to files in `src/libs/`

## Links

- [Documentation](https://wasm4.org/docs): Learn more about WASM-4.
- [Snake Tutorial](https://wasm4.org/docs/tutorials/snake/goal): Learn how to build a complete game
  with a step-by-step tutorial.
- [GitHub](https://github.com/aduros/wasm4): Submit an issue or PR. Contributions are welcome!
