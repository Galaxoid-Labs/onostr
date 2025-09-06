package onostr

import "core:bufio"
import "core:bytes"
import "core:encoding/hex"
import "core:fmt"
import "core:log"
import "core:mem"
import vmem "core:mem/virtual"
import "ws"


str := "[\"REQ\", \"sub\", {\"kinds\":[1]}]"

import "core:encoding/json"
import "core:strings"

ODIN_DEBUG :: true

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

	// Make keypair

	// kp, kp_ok := make_keypair().?
	// defer if kp_ok {
	// 	destroy_keypair(&kp)
	// }

	tags := [][]string {
		{"miner", "notemine"},
		{"client", "https://sandwichfarm.github.io/notemine"},
		{"nonce", "1404078877", "31"},
	}

	filter := make_filter(
		ids = []string{"000000006b1732820aec3b7f9d4cfa24ac79396a96a0f1fed54391f901f9cd3e"},
		kinds = []u16{1},
		since = 123,
		tags = tags,
		allocator = context.allocator,
	)
	defer destroy_filter(&filter)

	sub := make_subscription(
	[]Filter {
		Filter {
			ids = []string{"000000006b1732820aec3b7f9d4cfa24ac79396a96a0f1fed54391f901f9cd3e"},
			kinds = []u16{1},
			since = 123,
			tags = [][]string {
				{"miner", "notemine"},
				{"client", "https://sandwichfarm.github.io/notemine"},
				{"nonce", "1404078877", "31"},
			},
		},
		Filter {
			ids = []string{"assadfafd"},
			kinds = []u16{1},
			since = 123,
			tags = [][]string {
				{"miner", "noteasdfmine"},
				{"client", "https://sandwichfarm.github.io/noteminelasdflkjh;alksdf"},
				{"nonce", "1404078877", "31"},
			},
		},
	},
	//id = "sub",
	)
	defer destroy_subscription(&sub)

	suba := Subscription {
		//id      = "sub",
		filters = []Filter {
			Filter {
				ids = []string{"000000006b1732820aec3b7f9d4cfa24ac79396a96a0f1fed54391f901f9cd3e"},
				kinds = []u16{1},
				since = 123,
				tags = [][]string {
					{"miner", "notemine"},
					{"client", "https://sandwichfarm.github.io/notemine"},
					{"nonce", "1404078877", "31"},
				},
			},
		},
	}

	sub_str := subscription_req_string(sub)
	defer delete(sub_str)

	fmt.println("make_subscription: ", sub_str)

	close_str := subscription_close_string(sub)
	defer delete(close_str)

	fmt.println("subscription_close_string: ", close_str)

	// fmt.println("make_keypair: ", kp_ok)
	// fmt.println("private_hex: ", kp.private_hex)
	// fmt.println("public_hex: ", kp.public_hex)

	kp, kp_ok := make_keypair().?
	defer if kp_ok {
		destroy_keypair(&kp)
	}

	event := make_event(0, [][]string{{"a", "b"}}, "content", kp)
	defer destroy_event(&event)

	sign_event(&event, &kp)

	sub_event_str := subscription_event_string(sub, event)
	defer delete(sub_event_str)

	fmt.println("subscription_event_string: ", sub_event_str)


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


	// event, event_ok := make_event_from_json(raw_event_json).?
	// defer if event_ok {
	// 	destroy_event(&event)
	// }

	// str := "asdf"

	// event := make_event(
	// 	kind = 1,
	// 	tags = tags,
	// 	content = str,
	// 	kp = kp,
	// 	allocator = context.allocator,
	// )

	// defer destroy_event(&event)

	// fmt.println(event.id)
	// fmt.println(event.pubkey)

	// fmt.println(event_id_difficulty(event))

	// // fmt.printfln(string_for_id(event))
	// // fmt.println(event.sig)

	// // fmt.println("make_event_from_json: ", event)

	// is_valid := is_valid_signed_event(event)

	// fmt.println("is_valid_signed_event: ", is_valid)

	// bbb := "npub1r0rs5q2gk0e3dk3nlc7gnu378ec6cnlenqp8a3cjhyzu6f8k5sgs4sq9ac"
	// //bech32_init()
	// de, dc, er := bech32_decode(bbb)
	// fmt.println("decode: ", de, dc, er)
	// defer delete(de)
	// defer delete(dc)

	// // enchode
	// hex_bytes, hex_ok := hex.decode(transmute([]u8)dc[:])
	// enc, ec := bech32_encode("npub", hex_bytes)
	// fmt.println("encode: ", enc, ec)
	// defer delete(hex_bytes)
	// defer delete(enc)


	context.logger = log.create_console_logger()

	// scratch := mem.Scratch_Allocator{}
	// fba := mem.scratch_allocator_init(&scratch, 8 * 64 * 1024)

	client := ws.client_init()
	defer ws.client_deinit(&client)

	//connection, err := client_connect(&client, "wss://stream.bybit.com/v5/public/linear")
	connection, err := ws.client_connect(&client, "wss://relay.damus.io")
	if err != nil {
		log.error(err)
	}

	write_err := ws.connection_send(&connection, str)
	log.debug(write_err)
	if write_err != nil {
		log.error(write_err)
		panic("done")
	}

	for {
		msg, recv_err := ws.connection_recv(&connection)
		// convert msg bytes to string
		if msg != nil && len(msg) > 0 {

			// res_array: []any
			// json_err := json.unmarshal_any(msg, &res_array)
			// if json_err != nil {
			// 	log.error(json_err)
			// 	continue
			// }

			// fmt.println("Received message: ", res_array)
			res, ok := unmarshal_ws_response(msg, context.allocator)
			if !ok {
				log.error("Failed to unmarshal WS response")
				continue
			}
			switch m in res {
			case OkMessage:
				ok_msg := res.(OkMessage)
			// fmt.println(
			// 	"OK message for event ID:",
			// 	ok_msg.event_id,
			// 	"Success:",
			// 	ok_msg.success,
			// 	"Message:",
			// 	ok_msg.message,
			// )
			case EoseMessage:
				eose_msg := res.(EoseMessage)
				fmt.println(eose_msg.sub_id)
			case ClosedMessage:
				closed_msg := res.(ClosedMessage)
				fmt.println(
					"CLOSED message for subscription ID:",
					closed_msg.sub_id,
					"Message:",
					closed_msg.message,
				)
			case NoticeMessage:
				notice_msg := res.(NoticeMessage)
				fmt.println("NOTICE message:", notice_msg.message)
			case EventMessage:
			// event_msg := res.(EventMessage)
			// fmt.println("Event message for subscription ID:", event_msg.sub_id)
			// fmt.println("Event ID:", event_msg.event.id)
			// fmt.println("Event Pubkey:", event_msg.event.pubkey)
			// fmt.println("Event Created At:", event_msg.event.created_at)
			// fmt.println("Event Kind:", event_msg.event.kind)
			// fmt.println("Event Tags:", event_msg.event.tags)
			// fmt.println("Event Content:", event_msg.event.content)
			// fmt.println("Event Signature:", event_msg.event.sig)
			}

			delete(msg)
		}

	}


	// fmt.print(CHARSET_REV)

	// fmt.println("Parsed event:")
	// fmt.printf("  id:       %s\n", event.id)
	// fmt.printf("  pubkey:   %s\n", event.pubkey)
	// fmt.printf("  kind:     %d\n", event.kind)
	// fmt.printf("  created_at: %d\n", event.created_at)
	// fmt.printf("  tags:     %s\n", event.tags)
	// fmt.printf("  content:  %s\n", event.content)

}
