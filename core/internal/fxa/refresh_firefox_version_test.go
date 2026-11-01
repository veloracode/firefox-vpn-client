package fxa

import (
	"context"
	"errors"
	"sync/atomic"
	"testing"
	"time"
)

// stubVersionFetch swaps the product-details fetch for a counting
// fake and resets the refresh state; restore with the returned func.
func stubVersionFetch(t *testing.T, err error) (*atomic.Int32, func()) {
	t.Helper()
	calls := &atomic.Int32{}
	original := fetchLatestFirefoxVersion
	fetchLatestFirefoxVersion = func(ctx context.Context) (string, error) {
		calls.Add(1)
		if err != nil {
			return "", err
		}
		return "999.0", nil
	}
	firefoxVersionState.Lock()
	savedSuccess, savedFailure := firefoxVersionState.lastSuccess, firefoxVersionState.lastFailure
	firefoxVersionState.lastSuccess, firefoxVersionState.lastFailure = time.Time{}, time.Time{}
	firefoxVersionState.Unlock()
	return calls, func() {
		fetchLatestFirefoxVersion = original
		firefoxVersionState.Lock()
		firefoxVersionState.lastSuccess, firefoxVersionState.lastFailure = savedSuccess, savedFailure
		firefoxVersionState.Unlock()
	}
}

func TestRefreshFetchesWhenStaleThenCachesForADay(t *testing.T) {
	calls, restore := stubVersionFetch(t, nil)
	defer restore()

	refreshFirefoxVersionBeforeTokenExchange(context.Background())
	refreshFirefoxVersionBeforeTokenExchange(context.Background())
	if got := calls.Load(); got != 1 {
		t.Fatalf("fetches = %d, want 1 (second call inside the success interval)", got)
	}
}

func TestRefreshFailureBacksOffAndNeverFails(t *testing.T) {
	calls, restore := stubVersionFetch(t, errors.New("product details unreachable"))
	defer restore()

	// Must not panic or block sign-in; the exchange proceeds regardless.
	refreshFirefoxVersionBeforeTokenExchange(context.Background())
	refreshFirefoxVersionBeforeTokenExchange(context.Background())
	if got := calls.Load(); got != 1 {
		t.Fatalf("fetches = %d, want 1 (second call inside the failure backoff)", got)
	}
}

func TestRefreshRefetchesAfterTheSuccessInterval(t *testing.T) {
	calls, restore := stubVersionFetch(t, nil)
	defer restore()

	refreshFirefoxVersionBeforeTokenExchange(context.Background())
	firefoxVersionState.Lock()
	firefoxVersionState.lastSuccess = time.Now().Add(-firefoxVersionSuccessInterval - time.Minute)
	firefoxVersionState.Unlock()
	refreshFirefoxVersionBeforeTokenExchange(context.Background())
	if got := calls.Load(); got != 2 {
		t.Fatalf("fetches = %d, want 2 (stale after a day)", got)
	}
}
