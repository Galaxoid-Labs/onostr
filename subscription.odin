package onostr

import "core:crypto"
import "core:encoding/json"
import "core:encoding/uuid"
import "core:fmt"
import "core:strings"

Subscription :: struct {
	id:      string `json:"id"`,
	filters: []Filter `json:"filters"`,
}

make_subscription :: proc(
	filters: []Filter,
	id: string = "",
	allocator := context.allocator,
	loc := #caller_location,
) -> Subscription {
	assert(len(filters) > 0, "filters must not be empty")

	_filters := make([]Filter, len(filters), allocator)
	if len(filters) > 0 {
		for filter, i in filters {
			_filters[i] = clone_filter(filter, allocator, loc)
		}
	}

	_id: string
	if id == "" {
		context.random_generator = crypto.random_generator()
		_id = uuid.to_string(uuid.generate_v4(), allocator, loc)
	} else {
		_id = strings.clone(id, allocator, loc)
	}

	return Subscription{_id, _filters}
}

destroy_subscription :: proc(
	sub: ^Subscription,
	allocator := context.allocator,
	loc := #caller_location,
) {
	delete(sub.id, allocator, loc)

	for filter, i in sub.filters {
		destroy_filter(&sub.filters[i], allocator, loc)
	}
	delete(sub.filters, allocator, loc)
}

subscription_req_string :: proc(
	sub: Subscription,
	allocator := context.allocator,
	loc := #caller_location,
) -> string {
	assert(len(sub.filters) > 0, "filters must not be empty")

	builder := strings.builder_make(allocator, loc)
	defer strings.builder_destroy(&builder)

	fmt.sbprintf(&builder, `["REQ", "%s"`, sub.id)

	for filter in sub.filters {
		filter_json, err := json.marshal(filter, allocator = allocator, loc = loc)
		defer delete(filter_json, allocator, loc)
		if err != nil {
			return ""
		}
		fmt.sbprintf(&builder, `, `)
		fmt.sbprintf(&builder, `%s`, string(filter_json))
	}

	fmt.sbprintf(&builder, `]`)

	return strings.clone(strings.to_string(builder), allocator, loc)
}

subscription_close_string :: proc(
	sub: Subscription,
	allocator := context.allocator,
	loc := #caller_location,
) -> string {
	return fmt.aprintf(`["CLOSE", "%s"]`, sub.id, allocator = allocator)
}

subscription_event_string :: proc(
	sub: Subscription,
	event: Event,
	allocator := context.allocator,
	loc := #caller_location,
) -> string {
	assert(event.id != "", "event id must not be empty")
	// TODO: Validate event by checking signature, etc.

	event_json, err := json.marshal(event, allocator = allocator, loc = loc)
	defer delete(event_json, allocator, loc)

	return fmt.aprintf(`["EVENT", %s]`, string(event_json), allocator = allocator)
}

unmarshal_ws_response :: proc(
	data: []byte,
	allocator := context.allocator,
) -> (
	res: RelayResponse,
	ok: bool,
) {

	root, parse_err := json.parse(data, allocator = allocator)
	defer json.destroy_value(root)

	if parse_err != .None {
		fmt.eprintln("JSON parse error:", parse_err)
		return {}, false
	}

	arr, is_array := root.(json.Array)
	if !is_array || len(arr) < 2 {
		fmt.eprintln("Expected array with at least 2 elements")
		return {}, false
	}

	msg_type, type_ok := arr[0].(string)
	if !type_ok {
		fmt.eprintln("Expected string message type as first element")
		return {}, false
	}

	fmt.println("Received message type:", msg_type)
	//assert(msg_type != "EVENT", "EVENT messages should be handled separately")

	switch msg_type {
	case "EVENT":
		// if len(arr) != 3 {
		// 	fmt.eprintln("EVENT expects 3 elements")
		// 	return {}, false
		// }
		// sub_id, id_ok := arr[1].(string)
		// if !id_ok {
		// 	fmt.eprintln("Expected sub_id string for EVENT")
		// 	return {}, false
		// }
		// obj, obj_ok := arr[2].(json.Object)
		// if !obj_ok {
		// 	fmt.eprintln("Expected event object for EVENT")
		// 	return {}, false
		// }

		// event_bytes, event_marshal_err := json.marshal(obj, allocator = allocator)
		// if event_marshal_err != nil {
		// 	fmt.eprintln("Marshal error for EVENT:", event_marshal_err)
		// 	return {}, false
		// }
		// defer delete(event_bytes, allocator)

		// event: Event
		// unmarshal_err := json.unmarshal_any(event_bytes, &event, allocator = allocator)
		// if unmarshal_err != .None {
		// 	fmt.eprintln("Unmarshal error for EVENT:", unmarshal_err)
		// 	return {}, false
		// }

		// res = EventMessage{sub_id, event}
		return {}, false

	case "OK":
		if len(arr) != 4 {
			fmt.eprintln("OK expects 4 elements")
			return {}, false
		}
		event_id, id_ok := arr[1].(string)
		if !id_ok {
			fmt.eprintln("Expected event_id string for OK")
			return {}, false
		}
		success, bool_ok := arr[2].(bool)
		if !bool_ok {
			fmt.eprintln("Expected bool for OK")
			return {}, false
		}
		msg, msg_ok := arr[3].(string)
		if !msg_ok {
			fmt.eprintln("Expected message string for OK")
			return {}, false
		}
		res = OkMessage{event_id, success, msg}

	case "EOSE":
		if len(arr) != 2 {
			fmt.eprintln("EOSE expects 2 elements")
			return {}, false
		}
		sub_id, id_ok := arr[1].(string)
		if !id_ok {
			fmt.eprintln("Expected sub_id string for EOSE")
			return {}, false
		}
		res = EoseMessage{sub_id}

	case "CLOSED":
		if len(arr) != 3 {
			fmt.eprintln("CLOSED expects 3 elements")
			return {}, false
		}
		sub_id, id_ok := arr[1].(string)
		if !id_ok {
			fmt.eprintln("Expected sub_id string for CLOSED")
			return {}, false
		}
		msg, msg_ok := arr[2].(string)
		if !msg_ok {
			fmt.eprintln("Expected message string for CLOSED")
			return {}, false
		}
		res = ClosedMessage{sub_id, msg}

	case "NOTICE":
		if len(arr) != 2 {
			fmt.eprintln("NOTICE expects 2 elements")
			return {}, false
		}
		msg, msg_ok := arr[1].(string)
		if !msg_ok {
			fmt.eprintln("Expected message string for NOTICE")
			return {}, false
		}
		res = NoticeMessage{msg}

	case:
		fmt.eprintln("Unknown message type:", msg_type)
		return {}, false
	}

	return res, true
}

RelayResponse :: union {
	EventMessage,
	OkMessage,
	EoseMessage,
	ClosedMessage,
	NoticeMessage,
}

EventMessage :: struct {
	sub_id: string `json:"sub_id"`,
	event:  Event `json:"event"`,
}

OkMessage :: struct {
	event_id: string `json:"event_id"`,
	ok:       bool `json:"ok"`,
	message:  string `json:"message"`,
}

EoseMessage :: struct {
	sub_id: string `json:"sub_id"`,
}

ClosedMessage :: struct {
	sub_id:  string `json:"sub_id"`,
	message: string `json:"message"`,
}

NoticeMessage :: struct {
	message: string `json:"message"`,
}
