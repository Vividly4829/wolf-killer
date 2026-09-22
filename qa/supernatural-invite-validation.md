# Supernatural / internet-invite update validation

## Automated gameplay checks

Godot 4.6.2 Windows headless tests passed with exit code 0:
- test_supernatural_update: repeated bonuses, lycanthropy transition, fallen goose ray hit and ground clearance, devil surviving a brain hit, soul cost / three boons / duplicate prevention, fifth-sacrifice angels, kill reward deduplication, finite heart damage, relative accuracy and visible counts.
- test_dark_ritual: sacrifice eligibility, interruption, line of sight, mission rewards and revised permanent stack math.
- test_affliction_flame: revised temporary blur, permanent later health, psychedelics, continuous flame and wall blocking.
- test_gameplay_expansion: existing travel, moose, struggle and ritual behavior.
- test_split_session: separate controls, shared state and rewards, rituals, moose death replication and struggle damage.
- test_weapon_balance: catalog, price / inventory / explosive replenishment behavior.

## Internet integration

`python tools/run_internet_test.py` completed with process exits [0, 0, 0, 0]. A real public Cloudflare Quick Tunnel carried TLS WebSocket traffic between the host and three clients. All three clients spawned, received two ritual stacks, observed an angel's 321 HP state and observed its death. No router settings or port forwarding were changed. These were four processes on the same Windows PC, not independent household connections. The test found and fixed an ENet-only peer enumeration check and a pre-authentication pose-send timing issue.

The helper is downloaded from Cloudflare's official 2026.9.1 GitHub release only on first hosting, checked against its published SHA-256, and run without a visible console. The local server binds 127.0.0.1. An invite includes a random 192-bit token, validated before Godot gameplay RPC admission. Host plus three guests is the hard cap. Leaving the session stops the owned helper process. TLS verification remains enabled.

Cloudflare documents Quick Tunnels as development/testing infrastructure without an SLA: https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/do-more-with-tunnels/trycloudflare/ . The menu and release instructions label this experimental. A long-term production relay would need a managed account/deployment; no such account was silently created.

## Visual checks

Native OpenGL captures checked the paginated armory with pictures and accuracy, and the distinct feathered angel / red tweed-suit devil models. All 36 weapon thumbnails were rendered from game models. Captures remain local under qa. The editor import reports no script errors.

Animal pain foley is original synthesis except the wolf's short excerpt of the existing attributed public-domain NPS recording. Historical sources support relative accuracy ordering; exact spread values remain gameplay tuning (accuracy-notes.md).

Release verification: the exported embedded-PCK Windows executable passed its isolated headless --qa smoke run with VISUAL_QA_COMPLETE and no script/engine errors. The six gameplay suites passed 310 checks in total.
