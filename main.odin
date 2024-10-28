package onostr

import "core:crypto"
import "core:crypto/hash"
import "core:encoding/hex"
import "core:fmt"
import "core:mem"

main :: proc() {

	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)

	defer {
		if len(track.allocation_map) > 0 {
			fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
			for _, entry in track.allocation_map {
				fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
			}
		}
		if len(track.bad_free_array) > 0 {
			fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
			for entry in track.bad_free_array {
				fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
			}
		}
		mem.tracking_allocator_destroy(&track)
	}

	kp, ok := make_keypair().?
	defer if ok {
		destroy_keypair(&kp)
	}

	fmt.println(kp.private_hex)
	fmt.println(kp.public_hex)

	nkp, nkpok := make_keypair_from_hex(
		"1a98ff7486267e4fcffc055851e80a66e44315c057b8c7db50dbbf2977aec2d9",
	).?

	defer if nkpok {
		destroy_keypair(&nkp)
	}

	fmt.println(kp.private_hex)
	fmt.println(nkp.private_hex)
	fmt.println(nkp.public_hex)

	if is_valid_public_hex(nkp.public_hex) {
		fmt.println("Its valid")
	}


	// event := make_event(1, [][]string{{"Cool stuff"}}, "hello", &kp)
	// defer destroy_event(&event)

	// sign_event(&event, &kp)

	// fmt.println(event.id)
	// fmt.println(event.sig)
	// fmt.println(event.created_at)

}
