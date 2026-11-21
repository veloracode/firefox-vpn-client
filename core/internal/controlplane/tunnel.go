package controlplane

import (
	"bytes"
	"context"
	"crypto/tls"
	"io"
	"net"
	"net/http"
	"net/http/httptrace"
	"sync/atomic"
	"time"

	"github.com/armanlife/arman-vpn-client/core/internal/logx"
)

// The handshake is kept short and the request is not: a tunnel that is gone
// fails within the handshake, where nothing has been sent yet and the caller
// can still take its usual route. Once the handshake is through, the request
// may have arrived, so a POST is never replayed and this is its only route;
// five seconds for the whole of it failed renewals outright on a slow link,
// for a tunnel that was working.
const (
	renewalTunnelHandshake = 5 * time.Second
	renewalTunnelTimeout   = 15 * time.Second
)

type tunnelClientKey struct{}

// WithRenewalTunnel supplies an HTTPS client for this renewal only. The dialer
// opens a stream in a session the caller already has.
func WithRenewalTunnel(ctx context.Context, dial func(context.Context, string) (net.Conn, error)) (context.Context, func()) {
	if ctx.Value(tunnelClientKey{}) != nil {
		return ctx, func() {}
	}
	transport := &http.Transport{
		ForceAttemptHTTP2:   true,
		TLSHandshakeTimeout: renewalTunnelHandshake,
		TLSClientConfig:     &tls.Config{MinVersion: tls.VersionTLS12},
		DialContext: func(ctx context.Context, _, address string) (net.Conn, error) {
			return dial(ctx, address)
		},
	}
	tunnel := &http.Client{
		Transport:     transport,
		Jar:           client.Jar,
		Timeout:       renewalTunnelTimeout,
		CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse },
	}
	return context.WithValue(ctx, tunnelClientKey{}, tunnel), transport.CloseIdleConnections
}

// TryRenewalTunnel returns handled=false when the caller should use its normal
// routes. A write that may have reached the destination is not sent twice.
func TryRenewalTunnel(req *http.Request) (resp *http.Response, err error, handled bool) {
	tunnel, _ := req.Context().Value(tunnelClientKey{}).(*http.Client)
	if tunnel == nil || req.URL.Scheme != "https" {
		return nil, nil, false
	}
	if route, ok := Transport().(interface{ AllowsRenewalTunnel() bool }); !UsesDefaultTransport() &&
		(!ok || !route.AllowsRenewalTunnel()) {
		return nil, nil, false
	}

	var connected atomic.Bool
	ctx := httptrace.WithClientTrace(req.Context(), &httptrace.ClientTrace{
		GotConn: func(httptrace.GotConnInfo) { connected.Store(true) },
	})
	out := req.Clone(ctx)
	if req.Body != nil && req.Body != http.NoBody {
		if req.GetBody == nil {
			return nil, nil, false
		}
		out.Body, err = req.GetBody()
		if err != nil {
			return nil, err, true
		}
	}

	resp, err = tunnel.Do(out)
	readOnly := req.Method == http.MethodGet || req.Method == http.MethodHead
	if err != nil {
		if req.Context().Err() == nil && (readOnly || !connected.Load()) {
			logx.Debug("control plane tunnel unavailable host=%s", req.URL.Hostname())
			return nil, nil, false
		}
		return resp, err, true
	}
	switch {
	case resp.StatusCode == http.StatusNotAcceptable,
		resp.StatusCode == http.StatusMisdirectedRequest,
		resp.StatusCode == http.StatusUnavailableForLegalReasons,
		readOnly && resp.StatusCode >= 500:
		resp.Body.Close()
		return nil, nil, false
	}
	if readOnly && resp.StatusCode == http.StatusOK {
		body, readErr := io.ReadAll(resp.Body)
		resp.Body.Close()
		if readErr != nil {
			if req.Context().Err() != nil {
				return nil, req.Context().Err(), true
			}
			return nil, nil, false
		}
		resp.Body = io.NopCloser(bytes.NewReader(body))
	}
	logx.Debug("control plane answered through current tunnel host=%s http=%d", req.URL.Hostname(), resp.StatusCode)
	return resp, nil, true
}
