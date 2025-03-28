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
	  "id": "ad5f1d299021bc437b432123f8de9eb23928afa5eb58731f2f056570fe0ccc89",
	  "pubkey": "04c915daefee38317fa734444acee390a8269fe5810b2241e5e6dd343dfbecc9",
	  "created_at": 1743177458,
	  "kind": 1,
	  "tags": [
	    [
	      "e",
	      "8671a9f028ef39da20d228df2208213eb566564a53718587ad88ef02cf04dcec",
	      "ws://192.168.18.7:7777",
	      "root"
	    ],
	    [
	      "e",
	      "000d190ae61e314703647ff41fb29de8a6e49034fd3109fb43fb140652cef62a",
	      "wss://nos.lol",
	      "reply"
	    ],
	    [
	      "p",
	      "e96911258fabb7c235ffbb052c96a07bf91f3ef91cfa036e4f442fd23320261f",
	      "",
	      "mention"
	    ],
	    [
	      "p",
	      "04c915daefee38317fa734444acee390a8269fe5810b2241e5e6dd343dfbecc9",
	      "",
	      "mention"
	    ]
	  ],
	  "content": "great advice",
	  "sig": "58d457548a5f0c2cb58de2f5ff8ab80b5e8e7d4a140d115ac4091d022ca68eb7ac27ff06494db7a8bb6aa9dc4e37788614f6ecfe4c99a1c86d7433d051c3ad9d"
	}`


	event, event_ok := make_event_from_json(raw_event_json).?
	defer if event_ok {
		destroy_event(&event)
	}

	fmt.println(event.id)
	fmt.println(event.pubkey)

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
