package onostr

import "core:encoding/hex"
import "core:mem"
import "core:strings"
import "core:unicode"

// Specification: https://github.com/bitcoin/bips/blob/master/bip-0173.mediawiki

// Max length of a Bech32 string (spec section "Specification")
MAX_BECH32_LENGTH :: 90
// Min length of HRP (derived: must be >= 1)
MIN_HRP_LENGTH :: 1
// Max length of HRP (derived: 90 - 1 (sep) - 6 (checksum) = 83)
MAX_HRP_LENGTH :: 83
// Length of the checksum in characters/5-bit groups
CHECKSUM_LENGTH :: 6
// Separator character
SEPARATOR :: '1'
// Checksum calculation generator constants (spec section "Chec
CHECKSUM_GEN :: [5]u32{0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3}
// Checksum calculation constant (spec section "Checksum" - verification target / final XOR value)
CHECKSUM_CONST :: 1 // Changed from previous version - BIP173 uses 1, BIP350 (Bech32m) uses 0x2bc830a3
// Encoding character set (spec section "Character set")
CHARSET :: "qpzry9x8gf2tvdw0s3jn54khce6mua7l"
// Character set reverse lookup table (spec section "Character set")
// Maps ASCII values to their corresponding 5-bit values (0-31) or -1 for invalid characters
CHARSET_REV: [128]i8 =  {
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	15,
	-1,
	10,
	17,
	21,
	20,
	26,
	30,
	7,
	5,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	29,
	-1,
	24,
	13,
	25,
	9,
	8,
	23,
	-1,
	18,
	22,
	31,
	27,
	19,
	-1,
	1,
	0,
	3,
	16,
	11,
	28,
	12,
	14,
	6,
	4,
	2,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	29,
	-1,
	24,
	13,
	25,
	9,
	8,
	23,
	-1,
	18,
	22,
	31,
	27,
	19,
	-1,
	1,
	0,
	3,
	16,
	11,
	28,
	12,
	14,
	6,
	4,
	2,
	-1,
	-1,
	-1,
	-1,
	-1,
}

// --- Error Type ---
Error :: enum {
	None,
	// Validation/Input Errors
	Invalid_Length, // Overall string length invalid (<8 or >90)
	Mixed_Case, // String contains both upper and lower case letters
	Invalid_Character_HRP, // HRP contains character outside ASCII 33-126
	Invalid_Character_Data, // Data part contains character not in CHARSET
	Invalid_Separator_Pos, // Separator '1' missing, or HRP/data part length invalid
	// Checksum/Conversion Errors
	Checksum_Mismatch,
	Invalid_Padding, // Padding error during bit conversion (5->8)
}


// --- Internal Helper Functions ---

// Polymod calculation (spec section "Checksum")
@(private)
polymod :: proc(values: []u8) -> u32 {
	checksum_gen := CHECKSUM_GEN
	chk: u32 = 1
	for v_u8 in values {
		top := chk >> 25
		chk = (chk & 0x1ffffff) << 5 ~ u32(v_u8)
		for i := 0; i < 5; i += 1 {
			if ((top >> u32(i)) & 1) != 0 {
				chk ~= checksum_gen[i]
			}
		}
	}
	return chk
}

// Expand HRP for checksum calculation (spec section "Checksum")
// Returns a NEW dynamic array, caller must delete.
@(private)
expand_hrp :: proc(
	hrp: string,
	allocator := context.allocator,
	loc := #caller_location,
) -> (
	result: [dynamic]u8,
	err: Error,
) {
	hrp_len := len(hrp)
	// Assume HRP length/chars validated by caller based on spec context.

	res := make([dynamic]u8, (hrp_len * 2) + 1, allocator, loc)
	// Ownership of `res` transferred on success.

	for r, i in hrp {
		// BIP-173 implies HRP is already validated ASCII 33-126 and lowercased by this point
		res[i] = u8(r >> 5) // High 3 bits
		res[hrp_len + 1 + i] = u8(r & 0x1f) // Low 5 bits
	}
	res[hrp_len] = 0 // Separator for checksum calculation

	return res, .None
}

// Creates the checksum (spec section "Encoding")
// Assumes hrp is already validated and lowercased.
// data_5bit contains only the payload (no checksum yet).
@(private)
create_checksum :: proc(
	hrp: string,
	data_5bit_payload: []u8,
	allocator := context.allocator,
	loc := #caller_location,
) -> (
	checksum: [CHECKSUM_LENGTH]u8,
	err: Error,
) {
	expanded_hrp, hrp_err := expand_hrp(hrp, allocator, loc)
	if hrp_err != .None {
		return {}, hrp_err
	}
	defer delete(expanded_hrp, loc)

	// Values for polymod = expanded_hrp + data_payload + 6 zero bytes
	combined_len := len(expanded_hrp) + len(data_5bit_payload) + CHECKSUM_LENGTH
	values_for_polymod := make([dynamic]u8, combined_len, allocator, loc) // Auto-zeroed by make
	defer delete(values_for_polymod, loc)

	// Copy parts into the combined slice
	offset := 0
	copy(values_for_polymod[offset:offset + len(expanded_hrp)], expanded_hrp[:])
	offset += len(expanded_hrp)
	copy(values_for_polymod[offset:offset + len(data_5bit_payload)], data_5bit_payload)
	// Remaining 6 bytes are already zero

	// Calculate polymod and XOR with the constant (1 for Bech32)
	polymod_val := polymod(values_for_polymod[:]) ~ CHECKSUM_CONST

	// Extract 6 checksum bytes (5 bits each)
	checksum_result: [CHECKSUM_LENGTH]u8
	for i := 0; i < CHECKSUM_LENGTH; i += 1 {
		shift := u32(5 * (CHECKSUM_LENGTH - 1 - i)) // 5*(5-i) equivalent
		checksum_result[i] = u8((polymod_val >> shift) & 0x1f)
	}

	return checksum_result, .None
}

// Verifies the checksum (spec section "Decoding")
// Assumes hrp is already validated and lowercased.
// data_5bit_full includes both payload and the 6 checksum characters decoded to 5-bit values.
@(private)
verify_checksum :: proc(
	hrp: string,
	data_5bit_full: []u8,
	allocator := context.allocator,
	loc := #caller_location,
) -> (
	bool,
	Error,
) {
	expanded_hrp, hrp_err := expand_hrp(hrp, allocator, loc)
	if hrp_err != .None {
		return false, hrp_err
	}
	defer delete(expanded_hrp, loc)

	// Values for polymod = expanded_hrp + full_data_part
	combined_len := len(expanded_hrp) + len(data_5bit_full)
	values_for_polymod := make([dynamic]u8, combined_len, allocator, loc)
	defer delete(values_for_polymod, loc)

	copy(values_for_polymod[:len(expanded_hrp)], expanded_hrp[:])
	copy(values_for_polymod[len(expanded_hrp):], data_5bit_full)

	// A valid checksum must result in a polymod value equal to CHECKSUM_CONST (1 for Bech32)
	return polymod(values_for_polymod[:]) == CHECKSUM_CONST, .None
}


// Convert bits between bases (spec section "Data part")
// Returns a NEW dynamic array on success, caller must delete it.
@(private)
convert_bits :: proc(
	data: []u8,
	from_bits, to_bits: u8,
	pad: bool,
	allocator := context.allocator,
	loc := #caller_location,
) -> (
	result: [dynamic]u8,
	err: Error,
) {
	if from_bits == 0 || to_bits == 0 || from_bits > 8 || to_bits > 8 {
		return nil, .Invalid_Padding // Use a relevant error
	}

	acc: u32 = 0
	bits: u32 = 0
	res := make([dynamic]u8, allocator, loc)
	// Ownership transferred on success.

	maxv := u32(1 << to_bits) - 1

	for value_u8 in data {
		v := u32(value_u8)
		if (v >> from_bits) != 0 {
			delete(res, loc)
			// Input value exceeds `from_bits` width
			return nil, .Invalid_Padding // Or distinct Invalid_Input_Value error
		}

		acc = (acc << from_bits) | v
		bits += u32(from_bits)

		for bits >= u32(to_bits) {
			bits -= u32(to_bits)
			append(&res, u8((acc >> bits) & maxv), loc)
		}
	}

	if pad {
		// Pad with zeros (spec: "implicitly zero-padded")
		if bits > 0 {
			append(&res, u8((acc << (u32(to_bits) - bits)) & maxv), loc)
		}
	} else if bits >= u32(from_bits) || ((acc << (u32(to_bits) - bits)) & maxv) != 0 {
		// Check for non-zero padding when pad=false is disallowed (spec section "Data Part", point 6)
		delete(res, loc)
		return nil, .Invalid_Padding
	}

	return res, .None
}


// --- Public API ---

// Encodes binary data (e.g., witness program) into a Bech32 string.
// hrp: Human-Readable Part (must meet spec requirements: 1-83 chars, ASCII 33-126).
// data_8bit: Data bytes to encode.
bech32_encode :: proc(
	hrp: string,
	data_8bit: []u8,
	allocator := context.allocator,
	loc := #caller_location,
) -> (
	string,
	Error,
) {
	// 1. Validate HRP
	hrp_len := len(hrp)
	if hrp_len < MIN_HRP_LENGTH || hrp_len > MAX_HRP_LENGTH {
		return "", .Invalid_Separator_Pos // Error code implies length/position issue
	}
	hrp_lower := strings.to_lower(hrp, allocator) // Work with lowercase HRP
	defer delete(hrp_lower, allocator, loc) // Ensure cleanup
	for r in hrp_lower {
		if r < 33 || r > 126 {
			return "", .Invalid_Character_HRP
		}
	}

	// 2. Convert data to 5-bit groups (padding required)
	data_5bit_payload, conv_err := convert_bits(data_8bit, 8, 5, true, allocator, loc)
	if conv_err != .None {
		// `convert_bits` cleans up its own allocation on error
		return "", conv_err
	}
	// `data_5bit_payload` is now owned by this function.
	defer delete(data_5bit_payload, loc)

	// 3. Calculate checksum
	checksum, chk_err := create_checksum(hrp_lower, data_5bit_payload[:], allocator, loc)
	if chk_err != .None {
		// Should only fail if expand_hrp fails, which shouldn't happen after validation
		return "", chk_err
	}

	// 4. Combine payload and checksum 5-bit groups
	combined_5bit := make([dynamic]u8, 0, len(data_5bit_payload) + CHECKSUM_LENGTH, allocator, loc)
	defer delete(combined_5bit, loc)
	append(&combined_5bit, ..data_5bit_payload[:])
	append(&combined_5bit, ..checksum[:])

	// 5. Build the final string
	// hrp + '1' + mapped_chars
	final_len := len(hrp_lower) + 1 + len(combined_5bit)
	if final_len > MAX_BECH32_LENGTH {
		// This check should ideally happen earlier based on input lengths,
		// but confirming here is safe.
		return "", .Invalid_Length
	}
	charset := CHARSET
	sb := strings.builder_make(final_len, allocator, loc)
	strings.write_string(&sb, hrp_lower)
	strings.write_rune(&sb, SEPARATOR)
	for val_5bit in combined_5bit[:] {
		// val_5bit is guaranteed < 32 by convert_bits and checksum creation
		strings.write_byte(&sb, charset[val_5bit], loc) // Write the character byte directly
	}

	result_str := strings.to_string(sb)
	// Ownership of result_str transferred to caller.

	return result_str, .None
}


// Decodes a Bech32 string into its HRP and binary data.
// Returns the HRP (always lowercase) and a NEW dynamic array for the 8-bit data.
// Caller must delete the returned string and dynamic array.
bech32_decode :: proc(
	bech_str: string,
	allocator := context.allocator,
	loc := #caller_location,
) -> (
	hrp: string,
	hex_string: string,
	err: Error,
) {
	// 1. Basic validations (length, case)
	bech_len := len(bech_str)
	if bech_len < (MIN_HRP_LENGTH + 1 + CHECKSUM_LENGTH) || bech_len > MAX_BECH32_LENGTH {
		return "", "", .Invalid_Length
	}

	has_lower := false
	has_upper := false
	for r in bech_str {
		// Also check for non-printable ASCII here (spec implicit requirement)
		if r < 32 || r > 126 {
			return "", "", .Invalid_Character_Data // Or maybe a general invalid char error?
		}
		// Check case using rune properties
		if r >= 'a' && r <= 'z' {has_lower = true}
		if r >= 'A' && r <= 'Z' {has_upper = true}
	}
	if has_lower && has_upper {
		return "", "", .Mixed_Case
	}

	// 2. Convert to lowercase for processing
	bech_lower := strings.to_lower(bech_str, allocator)
	defer delete(bech_lower, allocator, loc) // Ensure cleanup

	// 3. Find separator '1'
	sep_pos := strings.last_index_byte(bech_lower, u8(SEPARATOR))
	if sep_pos == -1 {
		return "", "", .Invalid_Separator_Pos // Separator not found
	}

	// 4. Validate HRP and Data part lengths based on separator position
	hrp_part := bech_lower[:sep_pos]
	hrp_len := len(hrp_part)
	data_part_str := bech_lower[sep_pos + 1:]
	data_len := len(data_part_str)

	if hrp_len < MIN_HRP_LENGTH || hrp_len > MAX_HRP_LENGTH {
		return "", "", .Invalid_Separator_Pos // HRP length invalid
	}
	if data_len < CHECKSUM_LENGTH {
		return "", "", .Invalid_Separator_Pos // Data part too short (must include checksum)
	}

	// 5. Validate HRP characters (ASCII 33-126)
	for r in hrp_part {
		if r < 33 || r > 126 {
			// This check technically duplicates the earlier full-string check,
			// but ensures the *HRP part specifically* is valid post-split.
			return "", "", .Invalid_Character_HRP
		}
	}

	// 6. Decode data characters to 5-bit values
	data_5bit_full := make([dynamic]u8, 0, data_len, allocator, loc)
	// Ownership transferred on success (via conversion result). Needs delete on error.
	for r in data_part_str {
		if r > 127 { 	// Ensure it's within ASCII range for lookup table
			delete(data_5bit_full, loc)
			return "", "", .Invalid_Character_Data
		}
		val_5bit := CHARSET_REV[r] // Use the initialized lookup table
		if val_5bit == -1 {
			delete(data_5bit_full, loc)
			return "", "", .Invalid_Character_Data // Character not in Bech32 charset
		}
		append(&data_5bit_full, u8(val_5bit), loc)
	}
	// `data_5bit_full` now holds all decoded 5-bit values (payload + checksum)

	// 7. Verify checksum
	// Uses the lowercased HRP and the full decoded 5-bit data part
	checksum_ok, verify_err := verify_checksum(hrp_part, data_5bit_full[:], allocator, loc)
	if verify_err != .None {
		// Error likely from expand_hrp (shouldn't happen after validation)
		delete(data_5bit_full, loc)
		return "", "", verify_err
	}
	if !checksum_ok {
		delete(data_5bit_full, loc)
		return "", "", .Checksum_Mismatch
	}

	// 8. Separate payload and convert back to 8-bit (no padding allowed)
	payload_5bit_len := len(data_5bit_full) - CHECKSUM_LENGTH
	payload_5bit_slice := data_5bit_full[:payload_5bit_len]

	data_8bit_result, conv_err := convert_bits(payload_5bit_slice, 5, 8, false, allocator, loc)
	defer delete(data_8bit_result, loc) // Clean up the 8-bit result array
	// `convert_bits` cleans up its own allocation on error.
	// We still own data_5bit_full at this point.
	delete(data_5bit_full, loc) // Clean up the full 5-bit data array no~
	if conv_err != .None {
		// HRP copy not needed yet, return error
		return "", "", conv_err
	}
	// Ownership of `data_8bit_result` acquired.

	// 9. Success: Return copied HRP and converted 8-bit data
	hrp_copy := strings.clone(hrp_part, allocator, loc) // Clone HRP since bech_lower will be deleted
	// Ownership of hrp_copy and data_8bit_result transferred to caller.
	hex_str := hex.encode(data_8bit_result[:], allocator, loc)

	return hrp_copy, string(hex_str), .None

}
