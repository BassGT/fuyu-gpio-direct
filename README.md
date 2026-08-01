# fuyu-gpio-direct

[![Build & Docs](https://github.com/BassGT/fuyu-gpio-direct/actions/workflows/haddock.yml/badge.svg)](https://github.com/BassGT/fuyu-gpio-direct/actions/workflows/haddock.yml)
[![Haskell](https://img.shields.io/badge/Language-Haskell-purple.svg)](https://www.haskell.org/)
[![License](https://img.shields.io/badge/License-LGPL_2.1--or--later-blue.svg)](LICENSE)
[![Haddock Docs](https://img.shields.io/badge/Docs-GitHub%20Pages-brightgreen.svg)](https://BassGT.github.io/fuyu-gpio-direct/)

Direct, high-performance Haskell bindings for the Linux **`libgpiod v2`** character device API.

`fuyu-gpio-direct` provides both low-level raw FFI wrappers (`Fuyu.GPIO.Direct.Bindings`) and a type-safe, idiomatic Haskell interface (`Fuyu.GPIO.Direct`) for controlling Linux GPIO lines, reading inputs, driving outputs, and monitoring hardware edge events.

---

## ⚡ Features

- **Libgpiod v2 Native**: Fully compatible with Linux kernel GPIO character device ABI v2 (`/dev/gpiochipX`).
- **Type Safety**: Strong newtype wrappers (`LineOffset`, `LineValue`, `LineDirection`, `LineBias`, etc.) prevent parameter transposition bugs.
- **FFI Performance**: Fast in-memory setters, getters, allocators, and deallocators use `unsafe` FFI imports for zero-overhead performance, while kernel ioctl and blocking event waiting calls use `safe` imports to preserve RTS thread concurrency.
- **Explicit Error Handling**: Return types wrap POSIX error codes in `Either Errno a` for predictable, exception-free error management.
- **Full Haddock Coverage**: 100% documented API with hyperlinked source code.

---

## 📋 Prerequisites

Before compiling `fuyu-gpio-direct`, ensure your Linux system has `libgpiod v2` installed.

### Debian / Ubuntu / Raspberry Pi OS
```bash
sudo apt update
sudo apt install -y libgpiod-dev gpiod
```

### Arch Linux
```bash
sudo pacman -S libgpiod
```

---

## 📦 Installation

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

## 💡 Quick Start Example

The following example demonstrates opening a GPIO chip, configuring pin 17 as an output, setting its value high, reading back line status, and releasing resources:

```haskell
{-# LANGUAGE OverloadedStrings #-}

module Main where

import Fuyu.GPIO.Direct
import Foreign.C.Error (Errno)
import qualified Data.Vector.Storable as V

main :: IO ()
main = do
  -- 1. Open GPIO chip 0 (/dev/gpiochip0)
  resChip <- chipOpen "/dev/gpiochip0"
  case resChip of
    Left err -> putStrLn $ "Failed to open chip: " ++ show err
    Right chip -> do
      putStrLn "GPIO chip opened successfully."

      -- 2. Configure settings for line offset 17 (Output, Push-Pull)
      Right settings <- lineSettingsNew
      _ <- lineSettingsSetDirection settings DirOutput
      _ <- lineSettingsSetOutputValue settings LineActive

      -- 3. Build line configuration map
      Right config <- lineConfigNew
      let offsets = V.singleton (LineOffset 17)
      _ <- lineConfigAddLineSettings config offsets settings

      -- 4. Create request configuration with consumer label
      Right reqConfig <- requestConfigNew
      requestConfigSetConsumer reqConfig "fuyu-gpio-example"

      -- 5. Request control over the lines from the kernel
      resRequest <- chipRequestLines chip (Just reqConfig) config
      case resRequest of
        Left err -> putStrLn $ "Failed to request lines: " ++ show err
        Right request -> do
          putStrLn "Line 17 requested successfully."

          -- Read back current logical value of line 17
          resVal <- lineRequestValue request (LineOffset 17)
          case resVal of
            Left err -> putStrLn $ "Error reading line value: " ++ show err
            Right val -> putStrLn $ "Line 17 value: " ++ show val

          -- Clean up line request
          lineRequestRelease request

      -- Clean up line settings and config accumulators
      lineSettingsFree settings
      lineConfigFree config
      requestConfigFree reqConfig

      -- Close the GPIO chip handle
      chipClose chip
```

---

## 🐳 Cross-Compilation & Container Environment

`fuyu-gpio-direct` includes a `Dockerfile` targeting **Debian Trixie (ARM64)** pre-configured with GHC 9.10.3, Cabal, and `libgpiod v2`. This is ideal for cross-compiling or building binaries for single-board computers (Raspberry Pi, Orange Pi, BeagleBone, etc.) using Podman or Docker.

### 1. Build the Development Image

```bash
podman build -t fuyu-dev:latest .
```

### 2. Run the Container Environment

Mount your local repository directory into the container to compile:

```bash
podman run --rm -it --userns=keep-id -v $PWD:/app:z fuyu-dev:latest bash
```

#### Flags breakdown:
- `--rm`: Automatically remove the container when exiting the shell.
- `-it`: Interactive pseudo-TTY session with colors and shell autocompletion.
- `--userns=keep-id`: Maps host UID/GID to prevent file permission lockouts on build artifacts (`dist-newstyle`).
- `-v $PWD:/app:z`: Mounts current workspace into `/app` with proper SELinux security context.

### 3. Build inside the Container

Once inside the container shell, build the library and executables using Cabal for **Linux ARM64**:

```bash
cabal update
cabal build
```

---

## 📚 Documentation

Complete online Haddock API documentation with hyperlinked source code is published at:

👉 **[https://BassGT.github.io/fuyu-gpio-direct/](https://BassGT.github.io/fuyu-gpio-direct/)**

To generate documentation locally with hyperlinked source code:

```bash
cabal haddock --haddock-hyperlinked-source --open
```

---

## 🛠️ Module Architecture

- **`Fuyu.GPIO.Direct`**: Primary high-level, type-safe API for Haskell applications.
- **`Fuyu.GPIO.Direct.Types`**: Core data types, opaque handles, newtype wrappers, and C enum pattern synonyms.
- **`Fuyu.GPIO.Direct.Bindings`**: Raw Foreign Function Interface (FFI) bindings mapping directly to C `libgpiod v2` symbols.

---

## 📄 License

This library is licensed under the **LGPL-2.1-or-later** license. See the [LICENSE](LICENSE) file for details.

---

## 👤 Author & Maintainer

- **Author**: BassGT
- **Maintainer**: `springtrap9397@gmail.com`
- **Repository**: [https://github.com/BassGT/fuyu-gpio-direct](https://github.com/BassGT/fuyu-gpio-direct)
