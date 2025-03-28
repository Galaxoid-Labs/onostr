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
	} else {
		// Use arean allocator
		// arena: vmem.Arena
		// arena_err := vmem.arena_init_growing(&arena)
		// ensure(arena_err == nil)
		// arena_alloc := vmem.arena_allocator(&arena)
		// defer vmem.arena_destroy(&arena)
		// context.allocator = arena_alloc
	}

	kp, kp_ok := make_keypair().?
	defer if kp_ok {
		destroy_keypair(&kp)
	}


	// fmt.println("make_keypair: ", kp_ok)
	// fmt.println("private_hex: ", kp.private_hex)
	// fmt.println("public_hex: ", kp.public_hex)

	// event := make_event(0, [][]string{{"a", "b"}}, "content", kp)
	// defer destroy_event(&event)

	// id_first := string_for_id(event)
	// fmt.println("string_for_id: ", id_first)

	// id_second := string_for_id(event)
	// fmt.println("string_for_id: ", id_second)

	// signed := sign_event(&event, &kp)
	//fmt.println("make_event: ", event)

	// signed_again := sign_event(&event, &kp)
	// fmt.println("signed_again: ", event)


	raw_event_json := `{
  "id": "000000006b1732820aec3b7f9d4cfa24ac79396a96a0f1fed54391f901f9cd3e",
  "pubkey": "3e7878d43299adeaf042da1972fc562702abbe0087c2bb9af15810782c6be31e",
  "created_at": 1742896304,
  "kind": 1,
  "tags": [
    [
      "miner",
      "notemine"
    ],
    [
      "client",
      "https://sandwichfarm.github.io/notemine"
    ],
    [
      "nonce",
      "1404078877",
      "31"
    ]
  ],
  "content": "neat good.",
  "sig": "17856c4bc9a306e075f5efbc0abddb51fc7ee6fb844a821215099c8170ffa9f919421cbc7cccf4f8797289d5c6dd9adbdfdeea82231e3bcbce7fc1f73e079cf6"
}`


	event, event_ok := make_event_from_json(raw_event_json).?
	defer if event_ok {
		destroy_event(&event)
	}

	fmt.println(event.id)
	fmt.println(event.pubkey)

	fmt.println(event_id_difficulty(event))

	// fmt.printfln(string_for_id(event))
	// fmt.println(event.sig)

	// fmt.println("make_event_from_json: ", event)

	is_valid := is_valid_signed_event(event)

	fmt.println("is_valid_signed_event: ", is_valid)

	// fmt.println("Parsed event:")
	// fmt.printf("  id:       %s\n", event.id)
	// fmt.printf("  pubkey:   %s\n", event.pubkey)
	// fmt.printf("  kind:     %d\n", event.kind)
	// fmt.printf("  created_at: %d\n", event.created_at)
	// fmt.printf("  tags:     %s\n", event.tags)
	// fmt.printf("  content:  %s\n", event.content)

}
