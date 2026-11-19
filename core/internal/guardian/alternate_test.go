package guardian

import (
	"context"
	"errors"
	"io"
	"net"
	"net/http"
	"path/filepath"
	"slices"
	"strings"
	"testing"
	"time"
)

func TestTokenRoutesOnlyForReadOnlyProductionTokenRequests(t *testing.T) {
	for _, tc := range []struct {
		name, method, endpoint string
		want                   bool
	}{
		{"get", http.MethodGet, DefaultEndpoint + "/api/v1/fpn/token", true},
		{"head", http.MethodHead, DefaultEndpoint + "/api/v1/fpn/token", true},
		{"post", http.MethodPost, DefaultEndpoint + "/api/v1/fpn/token", false},
		{"other path", http.MethodGet, DefaultEndpoint + "/api/v1/fpn/status", false},
		{"other service", http.MethodGet, "https://other.example/api/v1/fpn/token", false},
	} {
		t.Run(tc.name, func(t *testing.T) {
			req, err := http.NewRequestWithContext(t.Context(), tc.method, tc.endpoint, nil)
			if err != nil {
				t.Fatal(err)
			}
			if isTokenRequest(req) != tc.want {
				t.Fatal("unexpected alternate connection decision")
			}
		})
	}
}

func TestTokenRouteOrder(t *testing.T) {
	dialErr := errors.New("dial failed")
	for _, tc := range []struct {
		name                        string
		direct, alternate, fragment int
		order                       []string
		wantStatus                  int
	}{
		{"direct works", 200, 200, 200, []string{"direct"}, 200},
		{"alternate works", 0, 200, 200, []string{"direct", "alternate"}, 200},
		{"fragment works", 0, 406, 200, []string{"direct", "alternate", "fragment"}, 200},
		{"all unsuccessful", 406, 503, 0, []string{"direct", "alternate", "fragment"}, 406},
		{"auth rejection", 401, 200, 200, []string{"direct"}, 401},
		{"quota rejection", 429, 200, 200, []string{"direct"}, 429},
	} {
		t.Run(tc.name, func(t *testing.T) {
			var order []string
			send := func(name string, status int) func(*http.Request) (*http.Response, error) {
				return func(req *http.Request) (*http.Response, error) {
					order = append(order, name)
					if status == 0 {
						return nil, dialErr
					}
					return regionResponse(req, status, name), nil
				}
			}
			req, _ := http.NewRequestWithContext(t.Context(), http.MethodGet, DefaultEndpoint+"/api/v1/fpn/token", nil)
			resp, err := tryTokenRoutes(req, []tokenAttempt{
				{"direct", send("direct", tc.direct)},
				{"alternate", send("alternate", tc.alternate)},
				{"fragment", send("fragment", tc.fragment)},
			}, nil, "")
			if err != nil {
				t.Fatal(err)
			}
			defer resp.Body.Close()
			if resp.StatusCode != tc.wantStatus || !slices.Equal(order, tc.order) {
				t.Fatalf("got HTTP %d via %v, want HTTP %d via %v", resp.StatusCode, order, tc.wantStatus, tc.order)
			}
		})
	}
}

func TestTokenRoutesStopOnCancellation(t *testing.T) {
	ctx, cancel := context.WithCancel(t.Context())
	defer cancel()
	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, DefaultEndpoint+"/api/v1/fpn/token", nil)
	direct := func(*http.Request) (*http.Response, error) {
		cancel()
		return nil, ctx.Err()
	}
	alternate := func(*http.Request) (*http.Response, error) {
		t.Fatal("alternate route was tried after cancellation")
		return nil, nil
	}
	if _, err := tryTokenRoutes(req, []tokenAttempt{{"direct", direct}, {"alternate", alternate}}, nil, ""); !errors.Is(err, context.Canceled) {
		t.Fatalf("got %v, want cancellation", err)
	}
}

func TestTokenRoutesReuseAndForgetSavedRoute(t *testing.T) {
	path := filepath.Join(t.TempDir(), "routes.json")
	cache := &tokenRouteCache{path: path}
	previous := tokenRoutesCache.Load()
	t.Cleanup(func() { tokenRoutesCache.Store(previous) })
	tokenRoutesCache.Store(cache)
	now := time.Now()
	cache.remember("same-network", "record", now)
	LoadTokenRouteCache(path)
	cache = tokenRoutesCache.Load()
	if got := cache.preferred("other-network", now); got.Route != "" {
		t.Fatalf("used route from another network: %q", got.Route)
	}
	if got := cache.preferred("same-network", now.Add(tokenRouteTTL)); got.Route != "" {
		t.Fatalf("used expired route: %q", got.Route)
	}
	var order []string
	req, _ := http.NewRequestWithContext(t.Context(), http.MethodGet, DefaultEndpoint+"/api/v1/fpn/token", nil)
	makeRoute := func(name string, success bool) tokenAttempt {
		return tokenAttempt{name, func(req *http.Request) (*http.Response, error) {
			order = append(order, name)
			if success {
				return regionResponse(req, http.StatusOK, ""), nil
			}
			return nil, errors.New("route failed")
		}}
	}
	resp, err := tryTokenRoutes(req, []tokenAttempt{
		makeRoute("direct", false), makeRoute("alternate", false), makeRoute("record", false),
		makeRoute("personal-relay", true),
	}, cache, "same-network")
	if err != nil {
		t.Fatal(err)
	}
	resp.Body.Close()
	if !slices.Equal(order, []string{"record", "direct", "alternate", "personal-relay"}) {
		t.Fatalf("unexpected route order: %v", order)
	}
	LoadTokenRouteCache(path)
	if got := tokenRoutesCache.Load().preferred("same-network", time.Now()); got.Route != "" {
		t.Fatalf("failed route remained on disk: %q", got.Route)
	}
}

func TestPassRequestPreservesGuardianHTTPRejection(t *testing.T) {
	calls := 0
	pass, err := fetchProxyPassWith(t.Context(), DefaultEndpoint, "fixture", func(req *http.Request) (*http.Response, error) {
		calls++
		if req.URL.String() != DefaultEndpoint+"/api/v1/fpn/token" || req.Header.Get("Authorization") != "Bearer fixture" {
			t.Fatal("request changed the Guardian endpoint or authorization")
		}
		return &http.Response{StatusCode: http.StatusNotAcceptable, Body: io.NopCloser(strings.NewReader("rejected"))}, nil
	})
	var status *HTTPError
	if pass != nil || calls != 1 || !errors.As(err, &status) || status.StatusCode != http.StatusNotAcceptable {
		t.Fatal("Guardian rejection was not returned as received")
	}
}

type fakeTimeout struct{}

func (fakeTimeout) Error() string   { return "i/o timeout" }
func (fakeTimeout) Timeout() bool   { return true }
func (fakeTimeout) Temporary() bool { return true }

func dialTimeoutError() error {
	return &net.OpError{
		Op:   "dial",
		Net:  "tcp",
		Addr: &net.TCPAddr{IP: net.IPv4(151, 101, 1, 91), Port: 443},
		Err:  fakeTimeout{},
	}
}

func routeResponse(r *http.Request, status int) *http.Response {
	return &http.Response{
		StatusCode: status,
		Header:     make(http.Header),
		Body:       io.NopCloser(strings.NewReader("")),
		Request:    r,
	}
}

func recordingRoute(tried *[]string, name string, send func(*http.Request) (*http.Response, error)) tokenAttempt {
	return tokenAttempt{name, func(r *http.Request) (*http.Response, error) {
		*tried = append(*tried, name)
		return send(r)
	}}
}

// A hello that never leaves cannot be fragmented into one that does, so the
// fragment routes are a waste of the budget when the direct dial timed out.
func TestFragmentRoutesAreSkippedWhenTheDirectDialTimedOut(t *testing.T) {
	req, err := http.NewRequest(http.MethodGet, DefaultEndpoint+"/api/v1/fpn/token", nil)
	if err != nil {
		t.Fatal(err)
	}
	var tried []string
	fail := func(*http.Request) (*http.Response, error) { return nil, dialTimeoutError() }
	routes := []tokenAttempt{
		recordingRoute(&tried, "direct", fail),
		recordingRoute(&tried, "alternate", fail),
		recordingRoute(&tried, "sni", fail),
		recordingRoute(&tried, "first-byte", fail),
		recordingRoute(&tried, "record", fail),
		recordingRoute(&tried, "personal-relay", func(r *http.Request) (*http.Response, error) {
			return routeResponse(r, http.StatusOK), nil
		}),
	}
	resp, err := tryTokenRoutes(req, routes, nil, "")
	if err != nil || resp == nil || resp.StatusCode != http.StatusOK {
		t.Fatalf("expected the relay to answer, got %v %v", resp, err)
	}
	if want := "direct,alternate,personal-relay"; strings.Join(tried, ",") != want {
		t.Errorf("tried %v, want %s", tried, want)
	}
}

// A connection that was made and then refused or reset is exactly what the
// fragment routes are for, so such a failure keeps them.
func TestFragmentRoutesStillRunWhenTheConnectionWasMade(t *testing.T) {
	req, err := http.NewRequest(http.MethodGet, DefaultEndpoint+"/api/v1/fpn/token", nil)
	if err != nil {
		t.Fatal(err)
	}
	var tried []string
	reset := func(*http.Request) (*http.Response, error) {
		return nil, &net.OpError{Op: "read", Net: "tcp", Err: errors.New("connection reset by peer")}
	}
	routes := []tokenAttempt{
		recordingRoute(&tried, "direct", reset),
		recordingRoute(&tried, "sni", func(r *http.Request) (*http.Response, error) {
			return routeResponse(r, http.StatusOK), nil
		}),
	}
	if _, err := tryTokenRoutes(req, routes, nil, ""); err != nil {
		t.Fatalf("expected the fragment route to answer: %v", err)
	}
	if want := "direct,sni"; strings.Join(tried, ",") != want {
		t.Errorf("tried %v, want %s", tried, want)
	}
}

func TestDialTimedOutOnlyAcceptsADialThatTimedOut(t *testing.T) {
	wrapped := &dialErrorWrapper{dialTimeoutError()}
	for _, c := range []struct {
		name string
		err  error
		want bool
	}{
		{"a dial that timed out", dialTimeoutError(), true},
		{"the same error inside a url error", wrapped, true},
		{"no error at all", nil, false},
		{"a read that timed out", &net.OpError{Op: "read", Err: fakeTimeout{}}, false},
		{"a dial that was refused", &net.OpError{Op: "dial", Err: errors.New("connection refused")}, false},
	} {
		if got := dialTimedOut(c.err); got != c.want {
			t.Errorf("%s: dialTimedOut = %v, want %v", c.name, got, c.want)
		}
	}
}

type dialErrorWrapper struct{ err error }

func (w *dialErrorWrapper) Error() string { return "Get \"https://vpn.mozilla.org\": " + w.err.Error() }
func (w *dialErrorWrapper) Unwrap() error { return w.err }
