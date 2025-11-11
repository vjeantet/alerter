# Building Alerter 2.0

## Platform Requirements

**Alerter 2.0 is macOS-only and must be built on macOS.**

- ✅ **macOS 10.14+** required for build and runtime
- ❌ **Cannot be built on Linux or Windows** (uses macOS-specific frameworks)
- ❌ **Cross-compilation not supported** (requires Objective-C runtime)

## Prerequisites

### 1. macOS System

You must be running macOS 10.14 (Mojave) or later.

```bash
# Check your macOS version
sw_vers
```

### 2. Xcode Command Line Tools

Required for Objective-C compilation via CGo.

```bash
# Install Xcode Command Line Tools
xcode-select --install

# Verify installation
xcode-select -p
# Should output: /Library/Developer/CommandLineTools (or similar)
```

### 3. Go 1.21 or Later

```bash
# Install Go using Homebrew
brew install go

# Or download from https://go.dev/dl/

# Verify installation
go version
# Should output: go version go1.21.x darwin/amd64 (or later)
```

### 4. Required Frameworks (Built into macOS)

The following frameworks are used and must be available:
- `Foundation.framework`
- `UserNotifications.framework` (macOS 10.14+)
- `Cocoa.framework`

These are included with macOS and Xcode Command Line Tools.

## Quick Build

### Using Make (Recommended)

```bash
# Clone the repository
git clone https://github.com/vjeantet/alerter.git
cd alerter

# Build the binary
make build

# Output: build/alerter
```

### Manual Build

```bash
# Enable CGo (required for Objective-C bridge)
export CGO_ENABLED=1

# Build with Go
go build -o alerter .

# The binary will be created in the current directory
```

### Optimized Build

```bash
# Build with size and symbol optimizations
CGO_ENABLED=1 go build -ldflags="-s -w" -o alerter .
```

## Build Options

### Debug Build

For development with debugging symbols:

```bash
go build -gcflags="all=-N -l" -o alerter .
```

### Race Detector Build

For testing concurrency issues:

```bash
go build -race -o alerter .
```

### Verbose Build

To see detailed build steps:

```bash
go build -x -o alerter .
```

## Code Signing

Code signing is **strongly recommended** for proper system integration, especially for notification authorization dialogs.

### Self-Signing (Development)

```bash
# Build first
make build

# Self-sign for local use
codesign --force --sign - build/alerter

# Verify signature
codesign --verify --verbose build/alerter
```

### Developer ID Signing (Distribution)

```bash
# Build
make build

# Sign with your Apple Developer certificate
codesign --force --sign "Developer ID Application: Your Name (TEAM_ID)" build/alerter

# Verify
codesign --verify --verbose build/alerter
spctl --assess --verbose build/alerter
```

### Using Makefile

```bash
# Build and self-sign in one command
make build-release
```

## Installation

### System-Wide Installation

```bash
# Install to /usr/local/bin (requires sudo)
make install

# Or manually
sudo cp build/alerter /usr/local/bin/alerter
sudo chmod +x /usr/local/bin/alerter
```

### User Installation

```bash
# Install to ~/bin
mkdir -p ~/bin
cp build/alerter ~/bin/alerter
chmod +x ~/bin/alerter

# Add to PATH if needed (add to ~/.zshrc or ~/.bash_profile)
export PATH="$HOME/bin:$PATH"
```

## Testing the Build

### Basic Test

```bash
# Run from build directory
./build/alerter -message "Hello from alerter 2.0!" -title "Test"
```

### Run Test Suite

```bash
# Simple notification test
make test

# Action buttons test
make test-actions

# Reply notification test
make test-reply
```

### Manual Tests

```bash
# Test piped input
echo "Build successful!" | ./build/alerter -sound default

# Test JSON output
./build/alerter -message "Test JSON" -json

# Test actions
./build/alerter -message "Choose" -actions "A,B,C"

# Test reply
./build/alerter -reply "Type here" -message "Enter name"

# Test timeout
./build/alerter -message "5 second timeout" -timeout 5

# Test group management
./build/alerter -message "Task 1" -group "tasks"
./build/alerter -list "tasks"
./build/alerter -remove "tasks"
```

## Build Troubleshooting

### Error: "cannot find package"

**Problem:** Go module dependencies not initialized.

**Solution:**
```bash
go mod tidy
go mod download
```

### Error: "xcrun: error: invalid active developer path"

**Problem:** Xcode Command Line Tools not installed.

**Solution:**
```bash
xcode-select --install
```

### Error: "ld: framework not found UserNotifications"

**Problem:** Building on macOS version older than 10.14.

**Solution:**
- Upgrade to macOS 10.14 or later
- Or use the old 1.x version of alerter for older systems

### Error: "gcc: command not found"

**Problem:** No C compiler available.

**Solution:**
```bash
# Install Xcode Command Line Tools
xcode-select --install

# Verify
gcc --version
```

### Error: "clang: error: unsupported option '-x objective-c'"

**Problem:** Incorrect compiler being used.

**Solution:**
```bash
# Ensure using Apple's clang
export CC=clang
go build -o alerter .
```

### Warning: "CGO_ENABLED=0 ignoring CGo code"

**Problem:** CGo disabled in environment.

**Solution:**
```bash
export CGO_ENABLED=1
go build -o alerter .
```

### Building on Non-macOS Systems

**This will not work.** Alerter requires macOS-specific frameworks that don't exist on Linux or Windows.

If you see errors like:
```
ld: framework not found Foundation
ld: framework not found UserNotifications
```

You are trying to build on a non-macOS system. You **must** build on macOS.

## Build Artifacts

After a successful build:

```
alerter/
├── build/
│   └── alerter          # Compiled binary
├── go.mod
├── go.sum               # Created after first build
└── ...
```

### Binary Info

```bash
# Check binary size
ls -lh build/alerter
# Typical size: 2-3 MB

# Check architecture
file build/alerter
# Should show: Mach-O 64-bit executable arm64 (or x86_64)

# Check linked frameworks
otool -L build/alerter
# Should list Foundation, UserNotifications, Cocoa frameworks
```

## Continuous Integration

### GitHub Actions Example

```yaml
name: Build

on: [push, pull_request]

jobs:
  build:
    runs-on: macos-latest

    steps:
    - uses: actions/checkout@v3

    - name: Set up Go
      uses: actions/setup-go@v4
      with:
        go-version: '1.21'

    - name: Install dependencies
      run: |
        xcode-select --install || true
        go mod download

    - name: Build
      run: make build

    - name: Test
      run: |
        ./build/alerter -help

    - name: Upload artifact
      uses: actions/upload-artifact@v3
      with:
        name: alerter
        path: build/alerter
```

## Distribution

### Creating a Release

```bash
# Build optimized binary
make build-release

# Create tarball
tar -czf alerter-2.0.0-macos.tar.gz -C build alerter

# Or create zip
zip -j alerter-2.0.0-macos.zip build/alerter
```

### Universal Binary (Apple Silicon + Intel)

To create a universal binary that runs on both Apple Silicon (M1/M2) and Intel Macs:

```bash
# Build for arm64 (Apple Silicon)
GOARCH=arm64 CGO_ENABLED=1 go build -o alerter-arm64 .

# Build for amd64 (Intel)
GOARCH=amd64 CGO_ENABLED=1 go build -o alerter-amd64 .

# Create universal binary
lipo -create -output alerter alerter-arm64 alerter-amd64

# Verify
lipo -info alerter
# Should show: Architectures in the fat file: alerter are: x86_64 arm64
```

## Clean Build

To start fresh:

```bash
# Using make
make clean

# Manual
rm -rf build/
go clean
go clean -cache
go clean -modcache
```

## Build Performance

Typical build times:
- **First build**: 5-10 seconds (includes CGo compilation)
- **Incremental build**: 1-3 seconds (Go caching)
- **Clean build**: 5-10 seconds

## Summary

**Minimum Requirements:**
1. ✅ macOS 10.14+
2. ✅ Xcode Command Line Tools
3. ✅ Go 1.21+
4. ✅ CGO_ENABLED=1

**Build Command:**
```bash
make build
```

**Install Command:**
```bash
make install
```

**Test Command:**
```bash
make test
```

That's it! You now have a working alerter 2.0 binary using modern macOS APIs.
