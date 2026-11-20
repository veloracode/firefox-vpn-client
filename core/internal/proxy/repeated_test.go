package proxy

import (
	"fmt"
	"net"
	"sync"
	"testing"
	"time"
)

// One outage makes every waiting connection fail for the same reason: a
// browser opening a page produces a hundred in a second. The log must show
// the reason once with a count, not a hundred identical lines (users' logs,
// 2026-11-15: ~150 lines in the same second, all one cause).
func TestRepeatedFailuresCollapseOneOutage(t *testing.T) {
	var r repeatedFailures
	const outage = "connecting to Mozilla failed: context deadline exceeded"

	// The first is worth saying at once.
	log, held := r.note(outage)
	if !log || held != 0 {
		t.Fatalf("first failure: log=%v held=%d", log, held)
	}
	// The burst behind it is only counted.
	for i := 0; i < 149; i++ {
		if log, _ := r.note(outage); log {
			t.Fatalf("failure %d was logged again", i+2)
		}
	}

	// A different reason reports what was held and then speaks for itself.
	log, held = r.note("dial tcp: i/o timeout")
	if !log || held != 149 {
		t.Fatalf("new reason: log=%v held=%d, want log with 149 held", log, held)
	}

	// Nothing is left owing once it has been reported.
	if _, held := r.settled(); held != 0 {
		t.Fatalf("settled still owed %d", held)
	}
}

func TestRepeatedFailuresSpeakAgainAfterTheWindow(t *testing.T) {
	var r repeatedFailures
	const outage = "connecting to Mozilla failed"
	r.note(outage)
	r.note(outage)
	r.note(outage)

	// An outage that goes on must say so again, with the count, rather than
	// going quiet forever.
	r.mu.Lock()
	r.at = time.Now().Add(-repeatWindow - time.Second)
	r.mu.Unlock()

	log, held := r.note(outage)
	if !log || held != 2 {
		t.Fatalf("after the window: log=%v held=%d, want log with 2 held", log, held)
	}
}

// A recovery closes the account, so the last few failures are not left
// unreported.
func TestRepeatedFailuresSettleOnRecovery(t *testing.T) {
	var r repeatedFailures
	const outage = "connecting to Mozilla failed"
	r.note(outage)
	for i := 0; i < 5; i++ {
		r.note(outage)
	}
	reason, held := r.settled()
	if reason != outage || held != 5 {
		t.Fatalf("settled: %q %d, want %q 5", reason, held, outage)
	}
	// And it forgets, so a recovery is reported once.
	if _, held := r.settled(); held != 0 {
		t.Fatalf("settled twice reported %d", held)
	}
	// After that, the next failure is a first one again.
	if log, held := r.note(outage); !log || held != 0 {
		t.Fatalf("after recovery: log=%v held=%d", log, held)
	}
}

// The connections that fail arrive on many goroutines at once.
func TestRepeatedFailuresAreSafeInParallel(t *testing.T) {
	var r repeatedFailures
	var wg sync.WaitGroup
	var logged int
	var mu sync.Mutex
	for i := 0; i < 50; i++ {
		wg.Add(1)
		go func(n int) {
			defer wg.Done()
			// Two reasons interleaved, as a real outage and a refused port do.
			reason := fmt.Sprintf("reason %d", n%2)
			if log, _ := r.note(reason); log {
				mu.Lock()
				logged++
				mu.Unlock()
			}
		}(i)
	}
	wg.Wait()
	if logged == 0 || logged > 50 {
		t.Fatalf("logged %d of 50", logged)
	}
}

// A browser whose connections pile up on a stalled session retries in a
// burst once the limit is reached: hundreds of refusals within a second
// (users' logs, 2026-11-15). They are counted, not logged one by one, and a
// client getting in again closes the account.
func TestConnectionLimitRefusalsAreCollapsed(t *testing.T) {
	s := NewSOCKSServer(nil, time.Second, time.Second, 1)
	if !s.acquireConnSlot() {
		t.Fatal("the first slot must be free")
	}
	for i := 0; i < 150; i++ {
		client, server := net.Pipe()
		client.Close()
		s.handleConn(server)
	}
	s.rejections.mu.Lock()
	held := s.rejections.held
	s.rejections.mu.Unlock()
	if held != 149 {
		t.Fatalf("held %d refusals, want 149 (the first is logged)", held)
	}

	s.releaseConnSlot()
	client, server := net.Pipe()
	client.Close()
	s.handleConn(server)
	if reason, held := s.rejections.settled(); held != 0 || reason != "" {
		t.Fatalf("an accepted client must close the account, still %q %d", reason, held)
	}
}
