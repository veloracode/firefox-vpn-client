File: lib (settings row widgets) / _Row.build
Function: _Row (InkWell wrapper)
Failure scenario: Tapping label/icon region of a boolRow (Switch trailing only, row onTap == null) does nothing; user perceives missed tap. Also, on rows with onTap, taps sometimes land during the ~2s VPN-core–triggered full-tree rebuild, canceling the ink/tap gesture.
Evidence: boolRow builds _Row with only trailing child and no onTap (InkWell onTap null); app root rebuilds whole tree every ~2 s; page widgets keep keys but row/InkWell subtree has no keys, so rebuild replaces gesture recognizers mid-gesture.

File: lib (settings row widgets) / _Row.build
Function: _Row (InkWell + Container margin/decoration, no Material ancestor guarantee)
Failure scenario: Tap registers (onTap fires) but no visible effect (no splash) because InkWell paints on nearest Material and the Container margin/decoration can occlude or offset the splash, or ListView clipping prevents splash.
Evidence: InkWell with default splashFactory inside ListView; child is Container with margin and conditional BoxDecoration border; no explicit Material/splashFactory customization.

File: lib (settings row widgets) / _Choice._open
Function: _Choice._open
Failure scenario: Repeated taps open the modal picker multiple times or the picker fails to appear because _open awaits a dialog while the surrounding tree rebuilds; tap appears to have no effect.
Evidence: _open is async and triggered from row onTap with no debounce/guard; tree rebuilds ~every 2 s; onChanged?.call after await.

File: lib (dock/tab) / GestureDetector(behavior: opaque)
Function: dock/tab item tap handlers
Failure scenario: Taps on dock/tab items swallowed or doubled when overlapping GestureDetectors (opaque behavior) or when the ~2 s rebuild replaces the detector mid-tap.
Evidence: GestureDetector with opaque behavior filling slots, no keys mentioned, whole tree rebuilt on poll.

File: lib (connect button) / GestureDetector over colored Container
Function: connect button
Failure scenario: Tap on connect button not registering during core-notification rebuild, or registering with no visible effect while connection state notification lags.
Evidence: GestureDetector wrapping plain Container (no Material/InkWell feedback), tree rebuilt ~every 2 s by VPN core notify.

File: lib (settings row widgets) / _Row under decoration
Function: _Row with under == true (BorderDirectional + margin)
Failure scenario: Start-edge hit area offset by margin/indent so taps near the icon edge fall outside the InkWell's paint/gesture region, perceived as missed tap.
Evidence: margin EdgeInsetsDirectional.only(start: under ? 10 : 0) plus padding start 28; InkWell wraps Container whose margin is inside the gesture area but decoration border added.

TOTAL FINDINGS: 6