// Package evasion holds the client's connection profile: the knobs the
// transport layer consults when a network refuses ordinary traffic. The
// built-in profile is the default and is what this repository builds and
// ships from source. A build may register a different profile at startup
// (Register) when it is put together with its own tuning, which keeps
// profile choices out of the transport code and out of user settings.
package evasion

import "net/url"

// Profile is the active connection profile. It is deliberately narrow, and
// its methods say what is needed rather than how it is produced.
type Profile interface {
	// Name identifies the active profile. The daemon logs it at startup so
	// a build plainly reports which profile it is running.
	Name() string

	// Authorize returns the query parameters that let a shared endpoint
	// accept one request for method and target, or nil when this build has
	// nothing to offer. A build assembled from this repository alone
	// returns nil, so it simply does not use shared endpoints.
	Authorize(method, target string) url.Values
}

// builtin is the profile compiled from this repository.
type builtin struct{}

func (builtin) Name() string { return "base" }

func (builtin) Authorize(string, string) url.Values { return nil }

var active Profile = builtin{}

// Register installs a profile in place of the built-in one, or restores the
// built-in one when given nil. It is called from an init during startup,
// before any connection is made.
func Register(p Profile) {
	if p == nil {
		active = builtin{}
		return
	}
	active = p
}

// Active returns the profile in force.
func Active() Profile { return active }

// Name is the active profile's identifier.
func Name() string { return active.Name() }

// Authorize asks the active profile to authorize one request for a shared
// endpoint. A nil result means this build does not use them.
func Authorize(method, target string) url.Values { return active.Authorize(method, target) }

// GuardianAlternateAddress returns an optional TCP address for Guardian.
func GuardianAlternateAddress() string {
	if profile, ok := active.(interface{ GuardianAlternateAddress() string }); ok {
		return profile.GuardianAlternateAddress()
	}
	return ""
}
