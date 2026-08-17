# Project Sunrise

Project Sunrise makes an old Destiny 2 build available for local, offline exploration.

## Language

**Client**:
The old Destiny 2 build that runs through Sunrise.
_Avoid_: Live client

**Server**:
Sunrise's local service layer that answers Client requests.
_Avoid_: Bungie server, custom server

**Activity Session**:
A local play session with one Destination Selection, membership state, and authority state.

**Destination Selection**:
The destination and arrival data chosen for an Activity Session.
_Avoid_: Map

**Forced Destination**:
A temporary operator choice that replaces the Client's Destination Selection. Sunrise never saves it.

**Activity Defaults**:
Fixed fallback data used when no complete Destination Selection exists.
