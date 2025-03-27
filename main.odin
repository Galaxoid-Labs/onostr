package onostr

import "core:fmt"
import "core:mem"

main :: proc() {

	when ODIN_DEBUG {
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
					fmt.eprintf("%v bad free at %v\n", entry.location, entry.memory)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

	//ints := make([]int, 10)

	kp, ok := make_keypair().?
	defer if ok {
		destroy_keypair(&kp)
	}

	fmt.println("make_keypair: ", ok)
	fmt.println("private_hex: ", kp.private_hex)
	fmt.println("public_hex: ", kp.public_hex)

	evt := make_event(0, [][]string{{"a", "b"}}, "content", kp)
	defer destroy_event(&evt)

	// signed := sign_event(&evt, &kp)
	fmt.println("make_event: ", evt)

	//fmt.println("private_hex: ", kp.private_hex)

	//testing.expect(t, ok, "make_keypair failed to generate a keypair")
	//testing.expect(t, len(kp.private_hex) == 64, "private_hex is empty")
	//testing.expect(t, len(kp.public_hex) == 64, "public_hex is empty")
}
