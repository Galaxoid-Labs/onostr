package onostr

import "core:c"
import "core:crypto"
import "core:encoding/hex"

KeyPair :: struct {
	private_bytes: [32]u8,
	public_bytes:  [32]u8,
	private_hex:   string,
	public_hex:    string,
	_keypair:      secp256k1_keypair,
	_xonly_pubkey: secp256k1_xonly_pubkey,
}

make_keypair :: proc() -> KeyPair {
	ctx := make_randomized_context()
	defer secp256k1_context_destroy(ctx)

	private_bytes: [32]u8
	crypto.rand_bytes(private_bytes[:])

	keypair: secp256k1_keypair
	secp256k1_keypair_create(ctx, &keypair, &private_bytes)

	xonly_pubkey: secp256k1_xonly_pubkey
	pairty: i32 = 0
	secp256k1_keypair_xonly_pub(ctx, &xonly_pubkey, &pairty, &keypair)

	public_bytes: [32]u8
	secp256k1_xonly_pubkey_serialize(ctx, &public_bytes, &xonly_pubkey)

	public_hex_bytes := hex.encode(public_bytes[:])
	private_hex_bytes := hex.encode(private_bytes[:])

	public_hex := string(public_hex_bytes)
	private_hex := string(private_hex_bytes)

	return KeyPair{private_bytes, public_bytes, private_hex, public_hex, keypair, xonly_pubkey}
}

destroy_keypair :: proc(kp: ^KeyPair) {
	delete(kp.private_hex)
	delete(kp.public_hex)
}

@(private)
make_randomized_context :: proc() -> ^secp256k1_context {
	ctx := secp256k1_context_create(SECP256K1_CONTEXT_NONE)
	seed: [32]u8
	crypto.rand_bytes(seed[:])
	secp256k1_context_randomize(ctx, &seed)
	return ctx
}
