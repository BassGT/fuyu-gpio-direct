# fuyu-gpio-direct

[![Build & Docs](https://github.com/BassGT/fuyu-gpio-direct/actions/workflows/haddock.yml/badge.svg)](https://github.com/BassGT/fuyu-gpio-direct/actions/workflows/haddock.yml)
[![Haskell](https://img.shields.io/badge/Language-Haskell-purple.svg)](https://www.haskell.org/)
[![License](https://img.shields.io/badge/License-LGPL_2.1--or--later-blue.svg)](LICENSE)
[![Haddock Docs](https://img.shields.io/badge/Docs-GitHub%20Pages-brightgreen.svg)](https://BassGT.github.io/fuyu-gpio-direct/)

Direct, high-performance Haskell bindings for the Linux **`libgpiod v2`** character device API.

`fuyu-gpio-direct` provides both low-level raw FFI wrappers (`Fuyu.GPIO.Direct.Bindings`) and type-safe abstraction, idiomatic Haskell interface (`Fuyu.GPIO.Direct`) for controlling Linux GPIO lines, reading inputs, driving outputs, and monitoring hardware edge events.

---

## Features

- **Libgpiod v2 Native**: Fully compatible with Linux kernel GPIO character device ABI v2 (`/dev/gpiochipX`).
- **Type Safety**: Strong newtype wrappers (`LineOffset`, `LineValue`, `LineDirection`, `LineBias`, etc.) prevent parameter transposition bugs.
- **FFI Performance**: Fast in-memory setters, getters, allocators, and deallocators use `unsafe` FFI imports for zero-overhead performance, while kernel ioctl and blocking event waiting calls use `safe` imports to preserve RTS thread concurrency.
- **Explicit Error Handling**: Return types wrap POSIX error codes in `Either Errno a` for predictable, exception-free error management.
- **Full Haddock Coverage**: 100% documented API with hyperlinked source code.

---

## Prerequisites

Before compiling `fuyu-gpio-direct`, ensure your Linux system has `libgpiod v2` installed.

### Debian / Ubuntu / Raspberry Pi OS
```bash
sudo apt update
sudo apt install -y libgpiod-dev gpiod
```

### Arch Linux
```bash
sudo pacman -Syu
sudo pacman -S libgpiod
```

### Fedora Linux
```bash
sudo dnf update
sudo dnf install libgpiod libgpiod-dev
```

---

## Installation

Add `fuyu-gpio-direct` to your project's `.cabal` file under `build-depends`:

```cabal
build-depends:
    base >= 4.18 && < 5,
    bytestring,
    vector,
    fuyu-gpio-direct
```

Or configure it in your `cabal.project` file for local development:

```cabal
packages:
  .
  /path/to/fuyu-gpio-direct
```

---

## Documentation

Complete online Haddock API documentation with hyperlinked source code is published at:

**[Hackage](https://hackage.haskell.org/package/fuyu-gpio-direct-0.1.0.0)**

---

## Module Architecture

- **`Fuyu.GPIO.Direct`**: Primary Mid-level, type-safe API for Haskell applications.
- **`Fuyu.GPIO.Direct.Types`**: Core data types, opaque handles, newtype wrappers, and C enum pattern synonyms.
- **`Fuyu.GPIO.Direct.Bindings`**: Raw Foreign Function Interface (FFI) bindings mapping directly to C `libgpiod v2` symbols.

---

## License

This library is licensed under the **LGPL-2.1-or-later** license. See the [LICENSE](LICENSE) file for details.

---

## Author & Maintainer

- **Author**: BassGT
- **Maintainer**: `sebastian11medrano@gmail.com`
