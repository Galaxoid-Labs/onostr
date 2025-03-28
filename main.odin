package onostr

import "core:fmt"
import "core:mem"
import vmem "core:mem/virtual"

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

	// arena: vmem.Arena
	// arena_err := vmem.arena_init_growing(&arena)
	// ensure(arena_err == nil)
	// arena_alloc := vmem.arena_allocator(&arena)
	// defer vmem.arena_destroy(&arena)

	// context.allocator = arena_alloc

	// kp, ok := make_keypair().?
	// defer if ok {
	// 	destroy_keypair(&kp)
	// }


	// fmt.println("make_keypair: ", ok)
	// fmt.println("private_hex: ", kp.private_hex)
	// fmt.println("public_hex: ", kp.public_hex)

	// evt := make_event(0, [][]string{{"a", "b"}}, "content", kp)
	// defer destroy_event(&evt)

	// signed := sign_event(&evt, &kp)
	// fmt.println("make_event: ", evt)


	raw_event_json := `{
	    "id": "4376c65d2f232afbe9b882a35baa4f6fe8667c4e684749af565f981833ed6a65",
	    "pubkey": "6e468422dfb74a5738702a8823b9b28168abab8655faacb6853cd0ee15deee93",
	    "created_at": 1673347337,
	    "kind": 1,
	    "content": "Walled gardens became prisons, and nostr is the first step towards tearing down the prison walls.",
	    "tags": [
	      ["e", "3da979448d9ba263864c4d6f14984c423a3838364ec255f03c7904b1ae77f206"],
	      ["p", "bf2376e17ba4ec269d10fcc996a4746b451152be9031fa48e74553dde5526bce"]
	    ],
	    "sig": "908a15e46fb4d8675bab026fc230a0e3542bfade63da02d542fb78b2a8513fcd0092619a2c8c1221e581946e0191f2af505dfdf8657a414dbca329186f009262"
	  }`


	event, event_ok := make_event_from_json(raw_event_json).?
	defer if event_ok {
		destroy_event(&event)
	}

	fmt.println("Parsed event:")
	fmt.printf("  id:       %s\n", event.id)
	fmt.printf("  pubkey:   %s\n", event.pubkey)
	fmt.printf("  kind:     %d\n", event.kind)
	fmt.printf("  content:  %s\n", event.content)

	//fmt.println("private_hex: ", kp.private_hex)

	//testing.expect(t, ok, "make_keypair failed to generate a keypair")
	//testing.expect(t, len(kp.private_hex) == 64, "private_hex is empty")
	//testing.expect(t, len(kp.public_hex) == 64, "public_hex is empty")
}
