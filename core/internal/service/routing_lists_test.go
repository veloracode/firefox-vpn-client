package service

import (
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/armanlife/arman-vpn-client/core/internal/config"
	"github.com/armanlife/arman-vpn-client/core/internal/routing"
	"github.com/armanlife/arman-vpn-client/core/internal/securefile"
)

// writeTestGeoSite writes a geosite.dat holding only the given tags (the
// v2ray layout: GeoSiteList -> GeoSite{country_code, domain{type, value}}).
func writeTestGeoSite(t *testing.T, dir string, tags map[string][]string) {
	t.Helper()
	field := func(b []byte, num int, data []byte) []byte {
		b = binaryUvarint(b, uint64(num)<<3|2)
		b = binaryUvarint(b, uint64(len(data)))
		return append(b, data...)
	}
	var list []byte
	for tag, domains := range tags {
		entry := field(nil, 1, []byte(tag))
		for _, name := range domains {
			// Domain{type: 2 (domain), value}
			domain := binaryUvarint(binaryUvarint(nil, 1<<3), 2)
			domain = field(domain, 2, []byte(name))
			entry = field(entry, 2, domain)
		}
		list = field(list, 1, entry)
	}
	if err := securefile.EnsurePrivateDir(dir); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, routing.GeoSiteFile), list, 0o600); err != nil {
		t.Fatal(err)
	}
}

// Lists that are present and current but miss a tag a rule needs are the
// wrong lists, whatever put them there. Neither the staleness check nor the
// source check notices, because a missing source record is taken to mean
// the files came from the default source. Without a forced refetch routing
// would stay broken until the files simply aged out, which is what users on
// region "ir" with another source's list hit (their logs, 2026-11-15:
// `geosite.dat has no tag "ir"`).
func TestRoutingAsksForAFreshListWhenATagIsMissing(t *testing.T) {
	d := newTestDaemon(t)
	dir := d.paths.RoutingDir

	// The other source's domain list: it has category-ir, not ir.
	writeTestGeoSite(t, dir, map[string][]string{"category-ir": {"example.ir"}})
	writeTestGeoIP(t, d, map[string][]string{"ir": {"2.144.0.0/14"}})

	// Both files are fresh and the configured URLs are the defaults, with no
	// source record, so neither existing check asks for a download.
	if routing.Due(dir, time.Hour, nil) {
		t.Fatal("the fixture's lists should look current")
	}
	if routing.SourceChanged(dir, routing.DefaultGeoSiteURL, routing.DefaultGeoIPURL) {
		t.Fatal("the fixture should look like it came from the default source")
	}

	cfg := config.Routing{
		Enabled:    true,
		Region:     "ir",
		Direct:     []string{"geosite:ir"},
		GeoSiteURL: routing.DefaultGeoSiteURL,
		GeoIPURL:   routing.DefaultGeoIPURL,
	}
	d.applyRouting(cfg)

	d.routing.mu.Lock()
	problem, router, refetch := d.routing.err, d.routing.router, d.routing.refetch
	d.routing.mu.Unlock()

	if router != nil || problem == "" {
		t.Fatal("a rule whose tag is absent must leave routing unbuilt and say so")
	}
	if !refetch {
		t.Fatal("unusable lists must ask for one download, or routing stays broken")
	}
	select {
	case <-d.routing.wake:
	default:
		t.Fatal("the update loop was not woken")
	}

	// The ask is consumed once, so a failing download cannot spin.
	d.routing.mu.Lock()
	d.routing.refetch = false
	d.routing.mu.Unlock()

	// With the right list the router builds and asks for nothing.
	writeTestGeoSite(t, dir, map[string][]string{"ir": {"example.ir"}})
	d.applyRouting(cfg)
	d.routing.mu.Lock()
	problem, router, refetch = d.routing.err, d.routing.router, d.routing.refetch
	d.routing.mu.Unlock()
	if router == nil || problem != "" {
		t.Fatalf("the router should build from a list that has the tag: %s", problem)
	}
	if refetch {
		t.Fatal("a working list must not ask for a download")
	}
}
