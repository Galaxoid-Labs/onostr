package onostr

import "core:c"
import "core:fmt"

when ODIN_OS == .Linux {
	when ODIN_ARCH == .arm64 {
		foreign import secp256k1 "lib/linux-arm/libsecp256k1.a" // TODO:
	} else {
		foreign import secp256k1 "lib/linux/libsecp256k1.a"
	}
} else when ODIN_OS == .Darwin {
	when ODIN_ARCH == .arm64 {
		foreign import secp256k1 "lib/macos-arm/libsecp256k1.a" // TODO:
	} else {
		foreign import secp256k1 "lib/macos/libsecp256k1.a"
	}
} else when ODIN_OS == .Windows {
	when ODIN_ARCH == .arm64 {
		foreign import secp256k1 "lib/windows-arm/libsecp256k1.lib" // TODO:
	} else {
		foreign import secp256k1 "lib/windows/libsecp256k1.lib"
	}
}

@(private)
SECP256K1_FLAGS_TYPE_CONTEXT :: 1 << 0

@(private)
SECP256K1_FLAGS_BIT_CONTEXT_VERIFY :: 1 << 8

@(private)
SECP256K1_FLAGS_BIT_CONTEXT_SIGN :: 1 << 9

@(private)
SECP256K1_CONTEXT_NONE :: SECP256K1_FLAGS_TYPE_CONTEXT

@(private)
SECP256K1_CONTEXT_VERIFY :: SECP256K1_FLAGS_TYPE_CONTEXT | SECP256K1_FLAGS_BIT_CONTEXT_VERIFY

@(private)
SECP256K1_CONTEXT_SIGN :: SECP256K1_FLAGS_TYPE_CONTEXT | SECP256K1_FLAGS_BIT_CONTEXT_SIGN

@(private)
secp256k1_context :: struct {}

@(private)
secp256k1_keypair :: struct {
	data: [96]c.uchar,
}

@(private)
secp256k1_xonly_pubkey :: struct {
	data: [64]c.uchar,
}

@(private)
@(default_calling_convention = "contextless")
foreign secp256k1 {
	secp256k1_context_create :: proc(flags: c.uint) -> ^secp256k1_context ---
	secp256k1_context_randomize :: proc(ctx: ^secp256k1_context, seed32: ^[32]c.uchar) -> ^secp256k1_context ---
	secp256k1_context_destroy :: proc(ctx: ^secp256k1_context) ---
	secp256k1_ec_seckey_verify :: proc(ctx: ^secp256k1_context, seckey: ^[32]c.uchar) -> c.int ---
	secp256k1_keypair_create :: proc(ctx: ^secp256k1_context, keypair: ^secp256k1_keypair, seckey: ^[32]c.uchar) -> c.int ---
	secp256k1_keypair_xonly_pub :: proc(ctx: ^secp256k1_context, pubkey: ^secp256k1_xonly_pubkey, pk_parity: ^c.int, keypair: ^secp256k1_keypair) -> c.int ---
	secp256k1_xonly_pubkey_serialize :: proc(ctx: ^secp256k1_context, output32: ^[32]c.uchar, pubkey: ^secp256k1_xonly_pubkey) -> c.int ---
	secp256k1_xonly_pubkey_parse :: proc(ctx: ^secp256k1_context, pubkey: ^secp256k1_xonly_pubkey, input32: ^[32]c.uchar) -> c.int ---
	secp256k1_schnorrsig_sign32 :: proc(ctx: ^secp256k1_context, sig64: ^[64]c.uchar, msg32: ^[32]c.uchar, keypair: ^secp256k1_keypair, aux_rand32: ^[32]c.uchar) -> c.int ---
	secp256k1_schnorrsig_verify :: proc(ctx: ^secp256k1_context, sig64: ^[64]c.uchar, msg: ^[32]c.uchar, msglen: c.size_t, pubkey: ^secp256k1_xonly_pubkey) -> c.int ---
}
