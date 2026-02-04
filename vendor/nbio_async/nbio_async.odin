package nbio_async

import "core:nbio"
import "core:sync"
import "core:time"

/*
Blocking await wrappers for nbio operations.

NOTE: These are meant to be used from worker threads, not from the nbio I/O
event loop thread, otherwise you can deadlock the event loop.
*/

Await_Open :: struct {
	ev:     sync.Auto_Reset_Event,
	handle: nbio.Handle,
	err:    nbio.FS_Error,
}

await_open :: proc(
	l: ^nbio.Event_Loop,
	path: string,
	mode: nbio.File_Flags = {.Read},
	perm: nbio.Permissions = nbio.Permissions_Default_File,
	dir: nbio.Handle = nbio.CWD,
) -> (handle: nbio.Handle, err: nbio.FS_Error) {
	a: Await_Open
	nbio.open_poly(path, &a, proc(op: ^nbio.Operation, a: ^Await_Open) {
		a.handle = op.open.handle
		a.err = op.open.err
		sync.auto_reset_event_signal(&a.ev)
	}, mode, perm, dir, l)
	sync.auto_reset_event_wait(&a.ev)
	return a.handle, a.err
}

Await_Send :: struct {
	ev:   sync.Auto_Reset_Event,
	sent: int,
	err:  nbio.Send_Error,
}

await_send :: proc(
	l: ^nbio.Event_Loop,
	socket: nbio.Any_Socket,
	bufs: [][]byte,
	endpoint: nbio.Endpoint = {},
	all := true,
	timeout: time.Duration = nbio.NO_TIMEOUT,
) -> (sent: int, err: nbio.Send_Error) {
	a: Await_Send
	nbio.send_poly(socket, bufs, &a, proc(op: ^nbio.Operation, a: ^Await_Send) {
		a.sent = op.send.sent
		a.err = op.send.err
		sync.auto_reset_event_signal(&a.ev)
	}, endpoint, all, timeout, l)
	sync.auto_reset_event_wait(&a.ev)
	return a.sent, a.err
}

Await_SendFile :: struct {
	ev:   sync.Auto_Reset_Event,
	sent: int,
	err:  nbio.Send_File_Error,
}

await_sendfile :: proc(
	l: ^nbio.Event_Loop,
	socket: nbio.TCP_Socket,
	file: nbio.Handle,
	offset: int = 0,
	nbytes: int = nbio.SEND_ENTIRE_FILE,
	progress_updates := false,
	timeout: time.Duration = nbio.NO_TIMEOUT,
) -> (sent: int, err: nbio.Send_File_Error) {
	a: Await_SendFile
	nbio.sendfile_poly(socket, file, &a, proc(op: ^nbio.Operation, a: ^Await_SendFile) {
		a.sent = op.sendfile.sent
		a.err = op.sendfile.err
		sync.auto_reset_event_signal(&a.ev)
	}, offset, nbytes, progress_updates, timeout, l)
	sync.auto_reset_event_wait(&a.ev)
	return a.sent, a.err
}

