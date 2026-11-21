package guardian

import (
	"context"
	"errors"
	"io"
	"net"
	"net/http"
	"slices"
	"strconv"
	"strings"
	"time"

	"github.com/armanlife/arman-vpn-client/core/internal/controlplane"
	"github.com/armanlife/arman-vpn-client/core/internal/evasion"
	"github.com/armanlife/arman-vpn-client/core/internal/hellosplit"
	"github.com/armanlife/arman-vpn-client/core/internal/logx"
)

// TokenRequestTimeout leaves time for the local attempts and relay recovery.
const TokenRequestTimeout = 25 * time.Second

var (
	// The direct route is either open or it is not: when it is refused, no
	// amount of waiting changes that, and the time is better left to a
	// route that may answer. It is kept short on purpose, which also means
	// an attempt reaches the other routes sooner.
	guardianDirectClient = tokenRouteClient(controlplane.QuickTransportWithMode(3*time.Second, hellosplit.Off), 3500*time.Millisecond)
	// The alternate address is the opposite case: when it connects at all,
	// it is the one route that is getting somewhere, so it is given the
	// time to finish rather than being cut off and tried again.
	guardianAlternateClient = tokenRouteClient(alternateTransport(), 9*time.Second)
	fragmentModes           = []string{hellosplit.SNI, hellosplit.FirstByte, hellosplit.Record}
	guardianFragmentClients = newFragmentClients()
)

func newFragmentClients() map[string]*http.Client {
	clients := make(map[string]*http.Client, len(fragmentModes))
	for _, mode := range fragmentModes {
		clients[mode] = tokenRouteClient(controlplane.QuickTransportWithMode(3*time.Second, mode), 3*time.Second)
	}
	return clients
}

// Only the TCP address changes. TLS and HTTP still identify Guardian: this
// is the direct route's own transport, Firefox's hello and all, pointed at
// another address. Anything less would hand Guardian a connection no
// Firefox ever makes, which is the one thing this route cannot afford.
func alternateTransport() *http.Transport {
	t := controlplane.QuickTransportTo(3*time.Second, hellosplit.Off, evasion.GuardianAlternateAddress())
	t.ResponseHeaderTimeout = 8 * time.Second
	t.IdleConnTimeout = 30 * time.Second
	return t
}

func tokenRouteClient(transport http.RoundTripper, timeout time.Duration) *http.Client {
	return &http.Client{
		Timeout:       timeout,
		Transport:     transport,
		CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse },
	}
}

func isTokenRequest(req *http.Request) bool {
	return req.URL != nil && req.URL.Scheme+"://"+req.URL.Host == DefaultEndpoint &&
		req.URL.Path == "/api/v1/fpn/token" &&
		(req.Method == http.MethodGet || req.Method == http.MethodHead) &&
		(req.Body == nil || req.Body == http.NoBody)
}

// UsesTokenRoutes reports whether the request can use the Guardian connection
// policy. Apply it only to the built-in direct and API relay clients.
func UsesTokenRoutes(req *http.Request) bool {
	return isTokenRequest(req)
}

type tokenAttempt struct {
	name string
	send func(*http.Request) (*http.Response, error)
}

// DoTokenRoutes runs the Guardian connection policy with a configured API relay.
func DoTokenRoutes(req *http.Request, relay func(*http.Request) (*http.Response, error)) (*http.Response, error) {
	return doTokenRoutes(req, tokenAttempt{"personal-relay", relay})
}

func doTokenRoutes(req *http.Request, relay tokenAttempt) (*http.Response, error) {
	routes := []tokenAttempt{{"direct", guardianDirectClient.Do}}
	if evasion.GuardianAlternateAddress() != "" {
		routes = append(routes, tokenAttempt{"alternate", guardianAlternateClient.Do})
	}
	mode := hellosplit.Mode()
	for _, candidate := range fragmentModes {
		if mode == hellosplit.Auto || mode == candidate {
			routes = append(routes, tokenAttempt{candidate, guardianFragmentClients[candidate].Do})
		}
	}
	if relay.send != nil {
		routes = append(routes, relay)
	}
	network := tokenRouteNetwork()
	return tryTokenRoutes(req, routes, tokenRoutesCache.Load(), network)
}

func tryTokenRoutes(req *http.Request, routes []tokenAttempt, cache *tokenRouteCache, network string) (*http.Response, error) {
	personalRelay := routes[len(routes)-1].name == "personal-relay"
	var preferred savedTokenRoute
	if cache != nil && network != "" {
		preferred = cache.preferred(network, time.Now())
		for i, route := range routes {
			if route.name == preferred.Route {
				copy(routes[1:i+1], routes[:i])
				routes[0] = route
				break
			}
		}
	}

	var directResp *http.Response
	var directErr error
	outcomes := make([]string, 0, len(routes))
	for _, route := range routes {
		if req.Context().Err() != nil {
			break
		}
		if directResp != nil && directResp.StatusCode == http.StatusUnavailableForLegalReasons && route.name != "personal-relay" {
			continue
		}
		// Fragmenting the hello cannot help when the direct route never got
		// a connection: the fragments would go down the same dial, to the
		// same address, and time out the same way. Skipping them leaves the
		// budget to the routes that reach Guardian another way.
		if dialTimedOut(directErr) && isFragmentRoute(route.name) {
			continue
		}
		send := route.send
		if route.name == preferred.Route && strings.HasSuffix(route.name, "-relay") {
			send = func(req *http.Request) (*http.Response, error) { return tryPreferredRelay(req, route.send) }
		}
		resp, err := send(req)
		outcomes = append(outcomes, route.name+"="+routeOutcome(resp, err))
		accepted := err == nil && resp != nil && resp.StatusCode != http.StatusNotAcceptable
		if accepted {
			switch {
			case route.name != "direct":
				accepted = resp.StatusCode != http.StatusUnavailableForLegalReasons && resp.StatusCode < 500
			case personalRelay:
				accepted = resp.StatusCode != http.StatusUnavailableForLegalReasons
			}
		}
		if accepted {
			if resp.StatusCode == http.StatusOK {
				recordTokenRoute(req, cache, network, route.name)
			}
			// Which way the request got through, always: when the direct
			// route answers after others failed, a log that says nothing
			// leaves the reader to guess what carried it.
			logx.Info("Guardian reached route=%s profile=%s (%s)",
				route.name, evasion.Name(), strings.Join(outcomes, " "))
			if directResp != nil {
				directResp.Body.Close()
			}
			return resp, nil
		}
		if route.name == preferred.Route && req.Method == http.MethodGet && req.Context().Err() == nil {
			cache.forget(preferred)
		}
		if route.name == "direct" {
			directResp, directErr = resp, err
		} else if resp != nil {
			resp.Body.Close()
		}
	}
	// What came back is the direct route's answer, so without this the log
	// would show that one error for every attempt and say nothing about the
	// routes that were tried after it.
	logx.Info("Guardian answered on no route: %s", strings.Join(outcomes, " "))
	if directResp == nil && directErr == nil {
		if err := req.Context().Err(); err != nil {
			return nil, err
		}
		return nil, io.ErrUnexpectedEOF
	}
	return directResp, directErr
}

// routeOutcome is one route's answer in a few words, for the line above.
func routeOutcome(resp *http.Response, err error) string {
	switch {
	case err != nil && dialTimedOut(err):
		return "no-connection"
	case err != nil && errors.Is(err, context.DeadlineExceeded):
		return "timeout"
	case err != nil:
		return "failed"
	case resp == nil:
		return "nothing"
	default:
		return strconv.Itoa(resp.StatusCode)
	}
}

func tryPreferredRelay(req *http.Request, send func(*http.Request) (*http.Response, error)) (*http.Response, error) {
	ctx, cancel := context.WithTimeout(req.Context(), 5*time.Second)
	resp, err := send(req.WithContext(ctx))
	if err != nil || resp == nil {
		cancel()
		return resp, err
	}
	resp.Body = &preferredRelayBody{ReadCloser: resp.Body, cancel: cancel}
	return resp, nil
}

type preferredRelayBody struct {
	io.ReadCloser
	cancel context.CancelFunc
}

func (b *preferredRelayBody) Close() error {
	defer b.cancel()
	return b.ReadCloser.Close()
}

// dialTimedOut reports a connection that was never established: the address
// took the packets and answered nothing. Anything the hello carries is
// irrelevant to it.
func dialTimedOut(err error) bool {
	if err == nil {
		return false
	}
	var op *net.OpError
	return errors.As(err, &op) && op.Op == "dial" && op.Timeout()
}

func isFragmentRoute(name string) bool {
	return slices.Contains(fragmentModes, name)
}
