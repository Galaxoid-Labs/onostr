# onostr

A Nostr package for Odin that provides Nostr types and procedures for handling all things Nostr!

Included is a wrapper for the secp256k1 library and OpenSSL. The C libraries for these are vendored as static library files to make it as portable as possible.

* secp256k1 version 0.6.0 static library
* OpenSSL version 3.5.2 static library

Full support for Nostr keys available. Also, some basic support for creating, encoding and decoding Events. Currently working on Websocket client.

### Platform Support

* ✅ - Linux amd64
* ✅ - Linux aarch
* 🏗️ - MacOS amd64
* ✅ - MacOS aarch
* 🏗️ - Win amd64
* 🏗️ - Win aarch