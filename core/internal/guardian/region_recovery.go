package guardian

import (
	"context"
	"errors"
	"net/http"
	"strings"
	"sync"

	"github.com/armanlife/arman-vpn-client/core/internal/controlplane"
)

var regionRecovery struct {
	sync.RWMutex
	retry func(*http.Request) (*http.Response, error)
}

// SetRegionRecovery supplies optional recovery for a Guardian request that
// either came back HTTP 451 or could not be made at all. It does not replace
// the shared control-plane transport or its TLS profile. A nil response or a
// failed retry leaves the original error, or the 451 response, as it was.
func SetRegionRecovery(retry func(*http.Request) (*http.Response, error)) {
	regionRecovery.Lock()
	regionRecovery.retry = retry
	regionRecovery.Unlock()
}

func do(req *http.Request) (*http.Response, error) {
	if isTokenRequest(req) || (req.URL != nil && req.URL.Scheme+"://"+req.URL.Host == DefaultEndpoint &&
		req.Method == http.MethodPost && req.URL.Path == "/api/v1/fpn/activate") {
		if resp, err, handled := controlplane.TryRenewalTunnel(req); handled {
			return resp, err
		}
	}
	regionRecovery.RLock()
	retry := regionRecovery.retry
	regionRecovery.RUnlock()

	tokenRoutes := controlplane.UsesDefaultTransport() && UsesTokenRoutes(req)
	var resp *http.Response
	var err error
	triedRelay := false
	if tokenRoutes {
		var shared tokenAttempt
		if retry != nil {
			shared = tokenAttempt{"shared-relay", func(r *http.Request) (*http.Response, error) {
				triedRelay = true
				return retry(r)
			}}
		}
		resp, err = doTokenRoutes(req, shared)
		if err != nil || resp.StatusCode != http.StatusUnavailableForLegalReasons {
			return resp, err
		}
	} else {
		resp, err = controlplane.Do(req)
	}
	// A region refusal is one reason to recover; a request that never
	// arrived is the other. Iranian networks have been timing Guardian out
	// rather than answering 451, and recovering only from 451 left those
	// users with nothing (users' logs, 2026-11-15).
	refused := err == nil && resp.StatusCode == http.StatusUnavailableForLegalReasons
	unreachable := err != nil && !errors.Is(err, context.Canceled)
	if !refused && !unreachable {
		return resp, err
	}

	// Mozilla's CDN edge refuses the region for the literal Guardian path
	// before the request reaches Guardian. A doubled leading slash does not
	// match that edge rule, while the origin still routes it to the same
	// handler. Try that direct route first, so no relay is needed, and fall
	// back to the configured recovery only if it is still refused. It is no
	// use when the request did not arrive at all: the path is not the issue.
	if refused {
		if direct, ok := doubledPathRequest(req); ok {
			doubled, doubledErr := controlplane.Do(direct)
			if doubledErr == nil && doubled != nil {
				if doubled.StatusCode != http.StatusUnavailableForLegalReasons {
					resp.Body.Close()
					return doubled, nil
				}
				doubled.Body.Close()
			}
		}
	}

	if retry != nil && !triedRelay {
		if recovered, retryErr := retry(recoverable(req)); retryErr == nil && recovered != nil {
			if resp != nil {
				resp.Body.Close()
			}
			if tokenRoutes && recovered.StatusCode == http.StatusOK {
				recordTokenRoute(req, tokenRoutesCache.Load(), tokenRouteNetwork(), "shared-relay")
			}
			return recovered, nil
		}
	}
	return resp, err
}

// recoverable is req with a context the recovery can still work in. A
// request that timed out carries an expired deadline, so reusing it would
// make every recovery fail before it started: this detaches that deadline
// and lets the recovery set its own budget. Cancellation is detached with
// it, so the recovery must stay bounded on its own; it is, by its budget.
func recoverable(req *http.Request) *http.Request {
	if req.Context().Err() == nil {
		return req
	}
	return req.Clone(context.WithoutCancel(req.Context()))
}

// doubledPathRequest clones req with one more leading slash on its path. It
// returns false when the path is already doubled or the body cannot be
// replayed.
func doubledPathRequest(req *http.Request) (*http.Request, bool) {
	if req.URL == nil || !strings.HasPrefix(req.URL.Path, "/") || strings.HasPrefix(req.URL.Path, "//") {
		return nil, false
	}
	if req.Body != nil && req.GetBody == nil {
		return nil, false
	}
	out := req.Clone(req.Context())
	u := *req.URL
	u.Path = "/" + u.Path
	u.RawPath = ""
	out.URL = &u
	if req.GetBody != nil {
		body, err := req.GetBody()
		if err != nil {
			return nil, false
		}
		out.Body = body
	}
	return out, true
}
