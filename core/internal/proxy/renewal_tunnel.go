package proxy

import (
	"context"
	"net"
	"time"

	"github.com/armanlife/arman-vpn-client/core/internal/controlplane"
)

func (c *Controller) withRenewalTunnel(ctx context.Context) (context.Context, func()) {
	if !c.hasUsableSessionOtherThan(nil, time.Now()) {
		return ctx, func() {}
	}
	return controlplane.WithRenewalTunnel(ctx, func(ctx context.Context, address string) (net.Conn, error) {
		return openTunnelContext(ctx, existingSessionOpener{c}, address)
	})
}

type existingSessionOpener struct{ controller *Controller }

// OpenTunnel borrows the current session without attempting a rebuild. A
// rebuild may require the renewal that already holds the controller's lock.
func (o existingSessionOpener) OpenTunnel(address string) (net.Conn, error) {
	_, session, release, err := o.controller.acquireSession()
	if err != nil {
		return nil, err
	}
	if !isSessionAlive(session) {
		release()
		return nil, errProxySessionUnhealthy
	}
	conn, err := session.OpenTunnel(address)
	if err != nil {
		release()
		return nil, err
	}
	return &managedTunnelConn{Conn: conn, release: release}, nil
}
