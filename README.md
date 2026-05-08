# OpenShark

A Tesla-aesthetic network packet analyzer built with Qt6/QML and libpcap.

## Features

- Live packet capture on any network interface
- PCAP file import/export
- Protocol dissection: Ethernet, IPv4/IPv6, TCP, UDP, ICMP, DNS, HTTP, TLS
- Hex view with field highlighting
- TCP stream reassembly (Follow Stream)
- Packet search and bookmarks
- Network map and traffic statistics

## Requirements

- macOS (BPF access required)
- Qt 6.x (via Homebrew: `brew install qt`)
- libpcap (included with macOS)
- CMake 3.21+

## Build

```bash
cmake -B build -DCMAKE_PREFIX_PATH=$(brew --prefix qt)
cmake --build build
```

## Usage

```bash
sudo ./build/openshark.app/Contents/MacOS/openshark
```

Sudo is required for BPF packet capture. Alternatively, add your user to the `access_bpf` group to capture without sudo.
