package onostr

import "core:c"
import "core:crypto"
import "core:encoding/hex"
import "core:fmt"

KeyPair :: struct {
	private_bytes: [32]u8,
	public_bytes:  [32]u8,
	private_hex:   string,
	public_hex:    string,
	_keypair:      secp256k1_keypair,
	_xonly_pubkey: secp256k1_xonly_pubkey,
}

make_keypair :: proc(allocator := context.allocator, loc := #caller_location) -> Maybe(KeyPair) {

	ctx := make_randomized_context()
	defer secp256k1_context_destroy(ctx)

	private_bytes: [32]u8
	crypto.rand_bytes(private_bytes[:])

	return make_keypair_from_bytes(&private_bytes, ctx, allocator, loc)
}

destroy_keypair :: proc(kp: ^KeyPair, allocator := context.allocator, loc := #caller_location) {
	delete(kp.private_hex, allocator, loc)
	delete(kp.public_hex, allocator, loc)
}

make_keypair_from_hex :: proc(
	private_hex: string,
	allocator := context.allocator,
	loc := #caller_location,
) -> Maybe(KeyPair) {

	private_bytes_slice, ok := hex.decode(transmute([]u8)private_hex[:], allocator, loc)
	defer delete(private_bytes_slice, allocator, loc)

	if !ok {
		return nil
	}

	if len(private_bytes_slice) != 32 {
		return nil
	}

	ctx := make_randomized_context()
	defer secp256k1_context_destroy(ctx)

	private_bytes: [32]u8
	copy(private_bytes[:], private_bytes_slice)

	return make_keypair_from_bytes(&private_bytes, ctx, allocator, loc)
}

is_valid_public_hex :: proc(
	public_hex: string,
	allocator := context.allocator,
	loc := #caller_location,
) -> bool {

	public_bytes_slice, ok := hex.decode(transmute([]u8)public_hex[:], allocator, loc)
	defer delete(public_bytes_slice, allocator, loc)

	if !ok {
		return false
	}

	if len(public_bytes_slice) != 32 {
		return false
	}

	public_bytes: [32]u8
	copy(public_bytes[:], public_bytes_slice)

	ctx := make_randomized_context()
	defer secp256k1_context_destroy(ctx)

	xonly_pubkey: secp256k1_xonly_pubkey
	return secp256k1_xonly_pubkey_parse(ctx, &xonly_pubkey, &public_bytes) == 1
}

make_keypair_from_bytes :: proc(
	private_bytes: ^[32]u8,
	ctx: ^secp256k1_context,
	allocator := context.allocator,
	loc := #caller_location,
) -> Maybe(KeyPair) {

	if len(private_bytes) != 32 {
		return nil
	}

	keypair: secp256k1_keypair
	secp256k1_keypair_create(ctx, &keypair, private_bytes)

	xonly_pubkey: secp256k1_xonly_pubkey
	pairty: i32 = 0
	if secp256k1_keypair_xonly_pub(ctx, &xonly_pubkey, &pairty, &keypair) != 1 {
		return nil
	}

	public_bytes: [32]u8
	if secp256k1_xonly_pubkey_serialize(ctx, &public_bytes, &xonly_pubkey) != 1 {
		return nil
	}

	return KeyPair {
		private_bytes^,
		public_bytes,
		string(hex.encode(private_bytes[:], allocator, loc)),
		string(hex.encode(public_bytes[:], allocator, loc)),
		keypair,
		xonly_pubkey,
	}
}

@(private)
make_randomized_context :: proc() -> ^secp256k1_context {
	ctx := secp256k1_context_create(SECP256K1_CONTEXT_NONE)
	seed: [32]u8
	crypto.rand_bytes(seed[:])
	secp256k1_context_randomize(ctx, &seed)
	return ctx
}
