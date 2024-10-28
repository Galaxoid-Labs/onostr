package onostr

import "core:crypto"
import "core:crypto/hash"
import "core:encoding/hex"
import "core:encoding/json"
import "core:fmt"
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

make_event :: proc(kind: u16, tags: [][]string, content: string, kp: ^KeyPair) -> Event {
	return Event{"", kp.public_hex, time.time_to_unix(time.now()), kind, tags, content, ""}
}

get_event_time :: proc(event: ^Event) -> time.Time {
	return time.unix(event.created_at, 0)
}

sign_event :: proc(event: ^Event, kp: ^KeyPair) -> bool {

	string_for_id := string_for_id(event)
	defer delete(string_for_id)

	hash := hash.hash_string(hash.Algorithm.SHA256, string_for_id)
	defer delete(hash)

	id_bytes := hex.encode(hash[:])

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
	event.sig = string(hex.encode(sig[:]))

	return true
}

@(private)
string_for_id :: proc(event: ^Event) -> string {
	tags_json, err := json.marshal(event.tags)
	defer delete(tags_json)

	tags_str := string(tags_json)
	return fmt.aprintf(
		`[0,"%s",%d,%d,%s,"%s"]`,
		event.pubkey,
		event.created_at,
		event.kind,
		tags_str,
		event.content,
	)
}

destroy_event :: proc(event: ^Event) {
	delete(event.id)
	delete(event.sig)
}
