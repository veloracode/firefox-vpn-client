package service

import (
	"context"
	"testing"
	"time"

	"github.com/armanlife/arman-vpn-client/core/internal/proxy"
	"github.com/armanlife/arman-vpn-client/core/internal/serverlist"
)

func pingCountry(code string) serverlist.Country {
	return serverlist.Country{Name: code, Code: code, Cities: []serverlist.City{{
		Name: code, Code: code, Servers: []serverlist.Server{{Hostname: code + ".example", Port: 443}},
	}}}
}

// A location that came out slow, or did not answer, is left out of the next
// measurements for a while, keeps its last figure on the list, and is
// measured again on another network.
func TestSlowLocationsAreSkippedForAWhile(t *testing.T) {
	network := "home"
	oldNetwork, oldPing := networkNow, pingLocations
	t.Cleanup(func() { networkNow, pingLocations = oldNetwork, oldPing })
	networkNow = func() (string, bool) { return network, true }

	figures := map[string]int64{"NL": 80, "US": 300, "JP": 0} // JP answers nothing
	var measured []string
	pingLocations = func(_ context.Context, targets []proxy.Candidate, _ string) []proxy.LocationPing {
		measured = measured[:0]
		var out []proxy.LocationPing
		for _, c := range targets {
			measured = append(measured, c.CountryCode)
			p := proxy.LocationPing{Code: c.CountryCode, Name: c.CountryName}
			if ms := figures[c.CountryCode]; ms > 0 {
				p.PingMS = ms
			} else {
				p.Error = "timeout"
			}
			out = append(out, p)
		}
		return out
	}

	d := &Daemon{countries: []serverlist.Country{pingCountry("NL"), pingCountry("US"), pingCountry("JP")}}
	ctx := context.Background()

	if _, _ = d.measureLocations(ctx, "token", nil, false); len(measured) != 3 {
		t.Fatalf("first measurement covered %v; want all three", measured)
	}

	results, _ := d.measureLocations(ctx, "token", nil, false)
	if len(measured) != 1 || measured[0] != "NL" {
		t.Fatalf("second measurement covered %v; want only the quick NL", measured)
	}
	if len(results) != 3 {
		t.Fatalf("the answer lists %d locations; want all three, the skipped with their last figure", len(results))
	}
	for _, r := range results {
		if r.Code == "US" && (r.PingMS != 300 || !r.Cached) {
			t.Fatalf("US: %d ms cached=%v; want its last figure, 300, marked cached", r.PingMS, r.Cached)
		}
		if r.Code == "NL" && r.Cached {
			t.Fatal("NL was measured now but is marked cached")
		}
	}

	// A person pressing the button gets every location measured.
	if _, _ = d.measureLocations(ctx, "token", nil, true); len(measured) != 3 {
		t.Fatalf("a fresh measurement covered %v; want all three", measured)
	}

	// The skip runs out.
	for code := range d.pingSkip {
		d.pingSkip[code] = time.Now().Add(-time.Second)
	}
	if _, _ = d.measureLocations(ctx, "token", nil, false); len(measured) != 3 {
		t.Fatalf("after the skip ran out, measured %v; want all three", measured)
	}

	// Another network measures everything again at once.
	_, _ = d.measureLocations(ctx, "token", nil, false) // US and JP skipped again
	network = "office"
	if _, _ = d.measureLocations(ctx, "token", nil, false); len(measured) != 3 {
		t.Fatalf("on another network, measured %v; want all three", measured)
	}
}
