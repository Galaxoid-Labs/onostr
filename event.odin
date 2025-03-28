package onostr

import "core:crypto"
import "core:crypto/hash"
import "core:encoding/hex"
import "core:encoding/json"
import "core:fmt"
import "core:strings"
import "core:time"

Event :: struct {
	id:         string `json:"id"`,
	pubkey:     string `json:"pubkey"`,
	created_at: i64 `json:"created_at"`,
	kind:       u16 `json:"kind"`,
	tags:       [][]string `json:"tags"`,
	content:    string `json:"content"`,
	sig:        string `json:"sig"`,
}

make_event :: proc(
	kind: u16,
	tags: [][]string,
	content: string,
	kp: KeyPair,
	allocator := context.allocator,
	loc := #caller_location,
) -> Event {
	return Event {
		"",
		strings.clone(kp.public_hex, allocator, loc),
		time.time_to_unix(time.now()),
		kind,
		clone_tags(tags, allocator, loc),
		strings.clone(content, allocator, loc),
		"",
	}
}

make_event_from_json :: proc(json_str: string, allocator := context.allocator) -> Maybe(Event) {
	event := Event{}
	err := json.unmarshal(transmute([]byte)json_str, &event, json.DEFAULT_SPECIFICATION, allocator)
	if err != nil {
		return nil
	}
	return event
}

destroy_event :: proc(event: ^Event, allocator := context.allocator, loc := #caller_location) {
	delete(event.id, allocator, loc)
	delete(event.sig, allocator, loc)
	delete(event.pubkey, allocator, loc)
	delete(event.content, allocator, loc)

	for tag in event.tags {
		for str in tag {
			delete(str, allocator, loc)
		}
		delete(tag, allocator, loc)
	}

	delete(event.tags, allocator, loc)
}

get_event_time :: proc(event: ^Event) -> time.Time {
	return time.unix(event.created_at, 0)
}

sign_event :: proc(
	event: ^Event,
	kp: ^KeyPair,
	allocator := context.allocator,
	loc := #caller_location,
) -> bool {

	string_for_id := string_for_id(event^, allocator, loc)
	defer delete(string_for_id, allocator, loc)

	hash_id: [32]u8
	hash.hash_string_to_buffer(hash.Algorithm.SHA256, string_for_id, hash_id[:]) //

	id_bytes := hex.encode(hash_id[:], allocator, loc)

	id_bytes_fixed: [32]u8
	copy(id_bytes_fixed[:], id_bytes)

	ctx := make_randomized_context()
	defer secp256k1_context_destroy(ctx)

	aux_rand: [32]u8
	crypto.rand_bytes(aux_rand[:])

	sig: [64]u8
	secp256k1_schnorrsig_sign32(ctx, &sig, &id_bytes_fixed, &kp._keypair, &aux_rand)
	if secp256k1_schnorrsig_verify(ctx, &sig, &id_bytes_fixed, 32, &kp._xonly_pubkey) != 1 {
		return false
	}

	event.id = string(id_bytes)
	event.sig = string(hex.encode(sig[:], allocator, loc))

	return true
}

is_valid_signed_event :: proc(
	event: Event,
	allocator := context.allocator,
	loc := #caller_location,
) -> bool {
	if len(event.id) != 32 {
		return false
	}

	if len(event.sig) != 64 {
		return false
	}

	string_for_id := string_for_id(event, allocator, loc)
	defer delete(string_for_id, allocator, loc)

	hash_id: [32]u8
	hash.hash_string_to_buffer(hash.Algorithm.SHA256, string_for_id, hash_id[:]) //

	id_bytes := hex.encode(hash_id[:], allocator, loc)
	defer delete(id_bytes, allocator, loc)

	return event.id == string(id_bytes)
}

@(private)
string_for_id :: proc(
	event: Event,
	allocator := context.allocator,
	loc := #caller_location,
) -> string {
	tags_json, err := json.marshal(event.tags, {}, allocator, loc)
	defer delete(tags_json, allocator, loc)

	return fmt.aprintf(
		`[0,"%s",%d,%d,%s,"%s"]`,
		event.pubkey,
		event.created_at,
		event.kind,
		string(tags_json),
		event.content,
		allocator,
		loc,
	)
}

@(private)
clone_tags :: proc(
	tags: [][]string,
	allocator := context.allocator,
	loc := #caller_location,
) -> [][]string {
	cloned := make([][]string, len(tags), allocator, loc)
	for idx in 0 ..< len(tags) {
		inner := tags[idx]
		cloned_inner := make([]string, len(inner), allocator, loc)
		for j in 0 ..< len(inner) {
			cloned_inner[j] = strings.clone(inner[j], allocator, loc)
		}
		cloned[idx] = cloned_inner
	}
	return cloned
}
