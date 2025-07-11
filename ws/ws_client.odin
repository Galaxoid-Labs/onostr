package ws

import openssl "../openssl"

import "core:bufio"
import "core:bytes"
import "core:mem"
import "core:mem/virtual"
import "core:net"
import "core:os"
import "core:strconv"
import "core:time"

Request :: struct {
	headers: Headers,
	body:    bytes.Buffer,
}

Request_Error :: enum {
	Invalid_Response_HTTP_Version,
	Invalid_Response_Method,
	Invalid_Response_Header,
	Invalid_Response_Cookie,
}

Error :: union #shared_nil {
	bufio.Scanner_Error,
	mem.Allocator_Error,
	Request_Error,
	Connection_Error,
}

Client :: struct {
	socket:    Communication,
	allocator: mem.Allocator,
}

client_init :: proc(allocator := context.allocator) -> Client {
	return {allocator = allocator}
}

client_deinit :: proc(client: ^Client) {
	mem.free_all(client.allocator)
}

client_connect :: proc(client: ^Client, url: string) -> (conn: Connection, err: Error) {
	r: Request
	request_init(&r)
	defer request_destroy(&r)
	res := request(url, &r, client.allocator) or_return
	return {com = res._socket, arena = client.allocator}, nil
}
