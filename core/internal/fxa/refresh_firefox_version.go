package fxa

import (
	"context"
	"sync"
	"time"

	"github.com/armanlife/firefox-vpn-client/core/internal/logx"
	"github.com/armanlife/firefox-vpn-client/core/internal/serverlist"
)

// This file carries the one piece of upstream phone v2.0.0's sign-in
// fix this client did not already have. The identity itself — a
// desktop-Firefox User-Agent whose major version tracks Mozilla's
// product details (controlplane.ApplyFirefoxHeaders /
// SetFirefoxVersion) — is upstream's and unchanged, as is the Fastly
// challenge solver. What v2.0.0 added, and what was missing here, is
// the refresh placement: the version is refreshed immediately BEFORE
// the FxA token exchanges (sign-in completion and token refresh),
// because those are the requests Fastly's bot check rejects. Here the
// version otherwise only refreshes as a side effect of the daemon's
// server-list evaluation, which a fresh install's first sign-in has
// not run yet — it would go out under the compiled-in default major.
//
// The cadence mirrors v2.0.0: at most one fetch a day on success, a
// one-hour backoff after a failure, a five-second timeout, and a
// failure never blocks or fails the exchange it precedes.

// fetchLatestFirefoxVersion is serverlist.LatestFirefoxVersion in
// production; tests replace it. Its side effect —
// controlplane.SetFirefoxVersion with the release version — is what
// updates the User-Agent the token exchanges carry.
var fetchLatestFirefoxVersion = serverlist.LatestFirefoxVersion

const (
	firefoxVersionSuccessInterval = 24 * time.Hour
	firefoxVersionFailureBackoff  = time.Hour
	firefoxVersionFetchTimeout    = 5 * time.Second
)

var firefoxVersionState struct {
	sync.Mutex
	lastSuccess time.Time
	lastFailure time.Time
}

// refreshFirefoxVersionBeforeTokenExchange fetches the current
// Firefox version when the cached one is stale, so the token exchange
// that follows carries a current desktop-Firefox User-Agent.
func refreshFirefoxVersionBeforeTokenExchange(ctx context.Context) {
	now := time.Now()
	firefoxVersionState.Lock()
	if !firefoxVersionState.lastSuccess.IsZero() &&
		now.Sub(firefoxVersionState.lastSuccess) < firefoxVersionSuccessInterval {
		firefoxVersionState.Unlock()
		return
	}
	if !firefoxVersionState.lastFailure.IsZero() &&
		now.Sub(firefoxVersionState.lastFailure) < firefoxVersionFailureBackoff {
		firefoxVersionState.Unlock()
		return
	}
	firefoxVersionState.Unlock()

	fetchCtx, cancel := context.WithTimeout(ctx, firefoxVersionFetchTimeout)
	_, err := fetchLatestFirefoxVersion(fetchCtx)
	cancel()
	firefoxVersionState.Lock()
	if err != nil {
		firefoxVersionState.lastFailure = time.Now()
		firefoxVersionState.Unlock()
		// Never block sign-in on the version service: the exchange
		// proceeds under the last known (or default) major.
		logx.Warn("refreshing the Firefox version before the token exchange failed err=%s", logx.Err(err))
		return
	}
	firefoxVersionState.lastSuccess = time.Now()
	firefoxVersionState.lastFailure = time.Time{}
	firefoxVersionState.Unlock()
}
