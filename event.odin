package onostr

import "core:crypto"
import "core:crypto/hash"
import "core:encoding/hex"
import "core:encoding/json"
import "core:fmt"
import "core:strings"
import "core:time"
import "secp256k1"

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
	return (Event {
				"",
				strings.clone(kp.public_hex, allocator, loc),
				time.time_to_unix(time.now()),
				kind,
				clone_tags(tags, allocator, loc),
				strings.clone(content, allocator, loc),
				"",
			})
}

make_event_from_json :: proc(json_str: string, allocator := context.allocator) -> Maybe(Event) {
	event: Event
	err := json.unmarshal(transmute([]byte)json_str, &event, allocator = allocator)
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
	hash.hash_string_to_buffer(hash.Algorithm.SHA256, string_for_id, hash_id[:])

	id_bytes := hex.encode(hash_id[:], allocator, loc)

	ctx := make_randomized_context()
	defer secp256k1.secp256k1_context_destroy(ctx)

	aux_rand: [32]u8
	crypto.rand_bytes(aux_rand[:])

	sig: [64]u8
	secp256k1.secp256k1_schnorrsig_sign32(ctx, &sig, &hash_id, &kp._keypair, &aux_rand)
	if secp256k1.secp256k1_schnorrsig_verify(
		   ctx,
		   &sig,
		   &hash_id,
		   len(hash_id),
		   &kp._xonly_pubkey,
	   ) !=
	   1 {
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

	string_for_id := string_for_id(event, allocator, loc)
	defer delete(string_for_id, allocator, loc)

	hash_id: [32]u8
	hash.hash_string_to_buffer(hash.Algorithm.SHA256, string_for_id, hash_id[:])

	id_bytes := hex.encode(hash_id[:], allocator, loc)
	defer delete(id_bytes, allocator, loc)

	if event.id != string(id_bytes) {
		return false
	}

	pubkey_bytes, pubkey_bytes_ok := hex.decode(transmute([]u8)event.pubkey[:], allocator, loc)
	defer delete(pubkey_bytes, allocator, loc)

	pubkey_bytes_fixed: [32]u8
	copy(pubkey_bytes_fixed[:], pubkey_bytes)

	if !pubkey_bytes_ok {
		return false
	}

	ctx := make_randomized_context()
	defer secp256k1.secp256k1_context_destroy(ctx)

	xonly_pubkey: secp256k1.secp256k1_xonly_pubkey
	xonly_pubkey_valid :=
		secp256k1.secp256k1_xonly_pubkey_parse(ctx, &xonly_pubkey, &pubkey_bytes_fixed) == 1
	if !xonly_pubkey_valid {
		return false
	}

	sig_bytes, sig_bytes_ok := hex.decode(transmute([]u8)event.sig[:], allocator, loc)
	defer delete(sig_bytes, allocator, loc)
	if !sig_bytes_ok {
		return false
	}

	sig_bytes_fixed: [64]u8
	copy(sig_bytes_fixed[:], sig_bytes)

	return(
		secp256k1.secp256k1_schnorrsig_verify(
			ctx,
			&sig_bytes_fixed,
			&hash_id,
			len(hash_id),
			&xonly_pubkey,
		) ==
		1 \
	)

}

event_id_difficulty :: proc(
	event: Event,
	allocator := context.allocator,
	loc := #caller_location,
) -> int {

	if event.id == "" {
		return -1
	}

	id_bytes, id_bytes_ok := hex.decode(transmute([]u8)event.id[:], allocator, loc)
	defer delete(id_bytes, allocator, loc)

	if !id_bytes_ok {
		return -1
	}

	leading_zero_bits := 0
	for b in id_bytes {
		for i := 7; i >= 0; i -= 1 {
			if (b & (1 << u8(i))) == 0 {
				leading_zero_bits += 1
			} else {
				return leading_zero_bits
			}
		}
	}

	return leading_zero_bits

}

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
		allocator = allocator,
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
