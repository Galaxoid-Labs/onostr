package onostr

// import "core:crypto"
// import "core:crypto/hash"
// import "core:encoding/hex"
import "core:encoding/json"
// import "core:fmt"
import "core:slice"
import "core:strings"
// import "core:time"
// import "secp256k1"

Filter :: struct {
	ids:     []string `json:"ids"`,
	authors: []string `json:"authors"`,
	kinds:   []u16 `json:"kinds"`,
	since:   i64 `json:"since"`,
	until:   i64 `json:"until"`,
	limit:   u32 `json:"limit"`,
	tags:    [][]string `json:"tags"`,
}

make_filter :: proc(
	kinds: []u16,
	ids: []string = {},
	authors: []string = {},
	since: i64 = 0,
	until: i64 = 0,
	limit: u32 = 0,
	tags: [][]string = {},
	allocator := context.allocator,
	loc := #caller_location,
) -> Filter {

	assert(len(kinds) > 0, "kinds must not be empty")

	return(
		Filter {
			clone_string_array(ids, allocator, loc),
			clone_string_array(authors, allocator, loc),
			slice.clone(kinds, allocator, loc),
			since,
			until,
			limit,
			clone_tags(tags, allocator, loc),
		} \
	)

}

destroy_filter :: proc(filter: ^Filter, allocator := context.allocator, loc := #caller_location) {
	for id in filter.ids {
		delete(id, allocator, loc)
	}
	delete(filter.ids, allocator, loc)

	for author in filter.authors {
		delete(author, allocator, loc)
	}
	delete(filter.authors, allocator, loc)

	delete(filter.kinds, allocator, loc)

	for tag in filter.tags {
		for str in tag {
			delete(str, allocator, loc)
		}
		delete(tag, allocator, loc)
	}

	delete(filter.tags, allocator, loc)
}

@(private)
clone_filter :: proc(
	original: Filter,
	allocator := context.allocator,
	loc := #caller_location,
) -> Filter {
	cloned: Filter

	cloned.since = original.since
	cloned.until = original.until
	cloned.limit = original.limit

	cloned.kinds = slice.clone(original.kinds, allocator, loc)
	cloned.ids = clone_string_array(original.ids, allocator, loc)
	cloned.authors = clone_string_array(original.authors, allocator, loc)

	cloned.tags = clone_tags(original.tags, allocator, loc)

	return cloned
}

@(private)
clone_string_array :: proc(
	strs: []string,
	allocator := context.allocator,
	loc := #caller_location,
) -> []string {
	if len(strs) == 0 {
		return make([]string, 0, allocator, loc)
	}
	clone: []string = make([]string, len(strs), allocator, loc)
	for str, i in strs {
		clone[i] = strings.clone(str, allocator, loc)
	}
	return clone
}
