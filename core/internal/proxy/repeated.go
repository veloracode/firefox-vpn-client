package proxy

import (
	"sync"
	"time"
)

// repeatWindow is how long one reason stays collapsed before the log says
// again that it is still going, with a count.
const repeatWindow = 30 * time.Second

// repeatedFailures collapses the identical warnings that one upstream
// outage produces. While Mozilla cannot be reached, every waiting
// connection fails for the same reason: a browser opening a page can make
// a hundred of them in the same second, and a hundred identical lines bury
// the one fact that matters. The first is logged at once, the rest are
// counted, and the count is reported when the reason changes, when the
// window has passed, or when a connection finally opens.
type repeatedFailures struct {
	mu     sync.Mutex
	reason string
	at     time.Time
	held   int
}

// note records one failure for reason and reports whether to log it now,
// along with how many were held back since the last log. A new reason, or
// one that has gone on past the window, is logged; a repeat inside the
// window is only counted.
func (r *repeatedFailures) note(reason string) (log bool, held int) {
	now := time.Now()
	r.mu.Lock()
	defer r.mu.Unlock()
	if reason == r.reason && now.Sub(r.at) < repeatWindow {
		r.held++
		return false, 0
	}
	held, r.held = r.held, 0
	r.reason, r.at = reason, now
	return true, held
}

// settled reports how many failures were held back and the reason, then
// forgets them, so a recovery closes the account rather than leaving the
// last few unreported. It returns held == 0 when there is nothing to say.
func (r *repeatedFailures) settled() (reason string, held int) {
	r.mu.Lock()
	defer r.mu.Unlock()
	if r.held == 0 && r.reason == "" {
		return "", 0
	}
	reason, held = r.reason, r.held
	r.reason, r.held, r.at = "", 0, time.Time{}
	return reason, held
}
