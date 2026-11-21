package guardian

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"sync"
	"sync/atomic"
	"time"

	"github.com/armanlife/arman-vpn-client/core/internal/logx"
	"github.com/armanlife/arman-vpn-client/core/internal/netstate"
	"github.com/armanlife/arman-vpn-client/core/internal/securefile"
)

const tokenRouteTTL = 30 * time.Minute

type savedTokenRoute struct {
	Network string    `json:"network"`
	Route   string    `json:"route"`
	Until   time.Time `json:"until"`
}

type tokenRouteCache struct {
	sync.Mutex
	path string
	last savedTokenRoute
}

var tokenRoutesCache atomic.Pointer[tokenRouteCache]

// LoadTokenRouteCache configures the data folder's remembered route.
func LoadTokenRouteCache(path string) {
	cache := &tokenRouteCache{path: path}
	if data, err := os.ReadFile(path); err == nil {
		var last savedTokenRoute
		if json.Unmarshal(data, &last) == nil {
			cache.last = last
		}
	}
	tokenRoutesCache.Store(cache)
}

// ClearTokenRouteCache drops a preference when routing settings change.
func ClearTokenRouteCache() {
	if cache := tokenRoutesCache.Load(); cache != nil {
		cache.Lock()
		defer cache.Unlock()
		if cache.last.Route != "" {
			cache.last = savedTokenRoute{}
			cache.save()
		}
		tokenRoutesCache.CompareAndSwap(cache, &tokenRouteCache{path: cache.path})
	}
}

func (c *tokenRouteCache) preferred(network string, now time.Time) savedTokenRoute {
	c.Lock()
	defer c.Unlock()
	if c.last.Network == network && now.Before(c.last.Until) && !c.last.Until.After(now.Add(tokenRouteTTL)) {
		return c.last
	}
	return savedTokenRoute{}
}

func (c *tokenRouteCache) forget(previous savedTokenRoute) {
	c.Lock()
	defer c.Unlock()
	if tokenRoutesCache.Load() == c && c.last == previous {
		c.last = savedTokenRoute{}
		c.save()
	}
}

func (c *tokenRouteCache) remember(network, route string, now time.Time) {
	c.Lock()
	defer c.Unlock()
	if tokenRoutesCache.Load() != c {
		return
	}
	if c.last.Network == network && c.last.Route == route && now.Before(c.last.Until) {
		return
	}
	c.last = savedTokenRoute{Network: network, Route: route, Until: now.Add(tokenRouteTTL)}
	c.save()
}

// save holds c.Mutex across the atomic replacement so concurrent requests
// cannot put an older preference back on disk.
func (c *tokenRouteCache) save() {
	data, err := json.Marshal(c.last)
	if err == nil {
		err = securefile.WritePrivate(c.path, data)
	}
	if err != nil {
		logx.Debug("saving Guardian route preference failed: %s", logx.Err(err))
	}
}

func tokenRouteNetwork() string {
	if key := netstate.RouteIdentity(); key != "" {
		return fmt.Sprintf("%x", sha256.Sum256([]byte(key)))
	}
	return ""
}

type acceptedTokenRouteKey struct{}

// Bind the preference update to a request. Only a request that yields a
// usable ProxyPass commits it.
func withTokenRoute(req *http.Request, accept *func(bool)) *http.Request {
	return req.WithContext(context.WithValue(req.Context(), acceptedTokenRouteKey{}, accept))
}

func recordTokenRoute(req *http.Request, cache *tokenRouteCache, network, route string) {
	if accept, ok := req.Context().Value(acceptedTokenRouteKey{}).(*func(bool)); ok && cache != nil && network != "" {
		previous := cache.preferred(network, time.Now())
		*accept = func(valid bool) {
			if tokenRoutesCache.Load() != cache {
				return
			}
			if valid && tokenRouteNetwork() == network {
				cache.remember(network, route, time.Now())
			} else if !valid && previous.Route == route && req.Context().Err() == nil {
				cache.forget(previous)
			}
		}
	}
}
