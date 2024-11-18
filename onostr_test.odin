package onostr

import "core:fmt"
import "core:testing"

@(test)
test_make_keypair_from_hex :: proc(t: ^testing.T) {

	hex_key := "1a98ff7486267e4fcffc055851e80a66e44315c057b8c7db50dbbf2977aec2d9"

	kp, ok := make_keypair_from_hex(hex_key).?

	defer if ok {
		destroy_keypair(&kp)
	}

	testing.expect(t, ok, "make_keypair_from_hex failed to generate a keypair")
	testing.expect(t, kp.private_hex == hex_key, "Generated private key does not match input hex")
	testing.expect(t, len(kp.public_hex) == 64, "public_hex is empty")
}

@(test)
test_make_keypair :: proc(t: ^testing.T) {
	kp, ok := make_keypair().?
	defer if ok {
		destroy_keypair(&kp)
	}

	testing.expect(t, ok, "make_keypair failed to generate a keypair")
	testing.expect(t, len(kp.private_hex) == 64, "private_hex is empty")
	testing.expect(t, len(kp.public_hex) == 64, "public_hex is empty")
}
