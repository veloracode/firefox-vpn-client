package controlplane

import (
	"context"
	"errors"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"net/http/httptrace"
	"strings"
	"testing"
)

type renewalRoundTrip func(*http.Request) (*http.Response, error)

func (f renewalRoundTrip) RoundTrip(r *http.Request) (*http.Response, error) { return f(r) }

func TestRenewalTunnelKeepsHTTPSVerification(t *testing.T) {
	server := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/token" {
			t.Errorf("wrong path: %s", r.URL.Path)
		}
		_, _ = io.WriteString(w, "token fixture")
	}))
	defer server.Close()

	dial := func(ctx context.Context, address string) (net.Conn, error) {
		return (&net.Dialer{}).DialContext(ctx, "tcp", address)
	}
	ctx, closeTunnel := WithRenewalTunnel(t.Context(), dial)
	defer closeTunnel()
	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, server.URL+"/token", nil)
	if resp, err, handled := TryRenewalTunnel(req); resp != nil || err != nil || handled {
		t.Fatal("an untrusted tunnel endpoint did not fall back")
	}

	ctx, closeTrustedTunnel := WithRenewalTunnel(t.Context(), dial)
	defer closeTrustedTunnel()
	tunnel := ctx.Value(tunnelClientKey{}).(*http.Client)
	tunnel.Transport.(*http.Transport).TLSClientConfig = server.Client().Transport.(*http.Transport).TLSClientConfig.Clone()
	req = req.WithContext(ctx)
	resp, err, handled := TryRenewalTunnel(req)
	if err != nil || !handled || resp == nil {
		t.Fatalf("tunnel request failed: %v", err)
	}
	defer resp.Body.Close()
	data, err := io.ReadAll(resp.Body)
	if err != nil || string(data) != "token fixture" {
		t.Fatalf("unexpected tunnel response: %q, %v", data, err)
	}
}

func TestRenewalTunnelFallsBackWithoutReplayingAnUncertainPost(t *testing.T) {
	streamErr := errors.New("stream failed")
	for _, tc := range []struct {
		name, method string
		connected    bool
		status       int
		handled      bool
	}{
		{"read stream failed", http.MethodGet, true, 0, false},
		{"refresh not connected", http.MethodPost, false, 0, false},
		{"refresh may have reached Mozilla", http.MethodPost, true, 0, true},
		{"refresh got HTTP 406", http.MethodPost, true, 406, false},
		{"refresh got HTTP 503", http.MethodPost, true, 503, true},
		{"Guardian rejected access token", http.MethodGet, true, 401, true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			tunnel := &http.Client{Transport: renewalRoundTrip(func(r *http.Request) (*http.Response, error) {
				if tc.connected {
					httptrace.ContextClientTrace(r.Context()).GotConn(httptrace.GotConnInfo{})
				}
				if r.Body != nil {
					_, _ = io.Copy(io.Discard, r.Body)
					r.Body.Close()
				}
				if tc.status == 0 {
					return nil, streamErr
				}
				return &http.Response{StatusCode: tc.status, Body: http.NoBody}, nil
			})}
			ctx := context.WithValue(t.Context(), tunnelClientKey{}, tunnel)
			req, _ := http.NewRequestWithContext(ctx, tc.method, "https://example.test/token", strings.NewReader("fixture"))
			resp, err, handled := TryRenewalTunnel(req)
			if resp != nil {
				resp.Body.Close()
			}
			if handled != tc.handled || (err != nil) != (tc.handled && tc.status == 0) {
				t.Fatalf("handled=%t err=%v", handled, err)
			}
			body, err := io.ReadAll(req.Body)
			defer req.Body.Close()
			if err != nil || string(body) != "fixture" {
				t.Fatalf("backup request body changed: %q, %v", body, err)
			}
		})
	}
}
