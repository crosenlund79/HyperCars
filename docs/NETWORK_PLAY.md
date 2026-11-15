# Playing HyperCars over the network (two players)

HyperCars connects two computers directly over **UDP port 24680** (Godot ENet). One player **hosts**, the other **joins** with the host's IPv4 address. There are no servers, accounts, relays or automatic router setup: for internet play the **host** must make port 24680 reachable.

## Quick start
1. Both players run the same HyperCars build (the game refuses a different version).
2. Host: Title → RACE → TWO PLAYERS: LAN / ONLINE → **HOST GAME**. The panel shows the local network address and waits.
3. Joiner: same menu, type the host's address → **JOIN GAME**.
   - Same house / local network: the host's local address, e.g. `192.168.1.20`.
   - Over the internet: the host's **public** IPv4 address, e.g. `203.0.113.7` (the host finds it by searching "what is my IP" in a browser).
   - A different port: `203.0.113.7:30000` (the host must then also use that port — the default 24680 is recommended).
4. Both land on the grid panel. The joiner presses **Fire** to be ready, the host presses **Fire** to start.

## What the host must set up for internet play
### 1. Windows Firewall (host, and usually the joiner too)
The first time HyperCars hosts, Windows asks whether to allow it on networks: tick **Private** (and **Public** only if needed) and choose **Allow**. If you missed the prompt, add a rule (Administrator command prompt):

```
netsh advfirewall firewall add rule name="HyperCars UDP 24680" dir=in action=allow protocol=UDP localport=24680
```

To remove it later: `netsh advfirewall firewall delete rule name="HyperCars UDP 24680"`. Third-party antivirus firewalls need an equivalent UDP rule.

### 2. Port forwarding on the host's router
In the router's web page (often `192.168.1.1` or `192.168.0.1`; look for *Port forwarding*, *Virtual server* or *NAT*):
- Protocol **UDP**, external port **24680**, internal port **24680**,
- internal IP = the host computer's local address (shown on the HOST panel, e.g. `192.168.1.20`).
- Give the host computer a fixed local address (DHCP reservation) so the rule keeps working.

The joiner does **not** need port forwarding.

### 3. Check for CGNAT (carrier-grade NAT)
Port forwarding cannot work if the internet provider shares one public address between customers (common on mobile / 4G / 5G, some fibre and cable providers):
- Compare the **WAN / Internet IP** shown in the router with the address from "what is my IP". If they differ, or the router's WAN IP starts with `100.64.`–`100.127.`, `10.`, `172.16.`–`172.31.` or `192.168.`, you are behind CGNAT.
- Options: ask the provider for a public IPv4 address (sometimes free, sometimes paid), let the other player host instead, or use a VPN-style virtual LAN tool that both players install (outside HyperCars; then join with the virtual-LAN address).

## Common connection failures
| Message / symptom | Likely cause | What to try |
|---|---|---|
| "Could not connect to … " after ~10 s | Wrong address, host not hosting, port not forwarded, firewall, CGNAT | Check the address and port; host waits on the HOST panel; check the firewall rule, port forwarding and CGNAT above; try on the same LAN first. |
| "Please type the host's IPv4 address…" | Not an IPv4 address (names and IPv6 are not supported) | Type digits like `203.0.113.7` or `203.0.113.7:24680`. |
| "Could not host on port 24680" | Another program (or another HyperCars) already uses the port | Close it, or restart the computer. |
| "The host runs a different version of HyperCars" | Different builds | Both players install the same build. |
| "The host is already racing" | A race is in progress on the host | Wait until the host returns to the menu and hosts again. |
| "CONNECTION LOST" during a race | One computer closed the game or the connection dropped for ~10 s | Both return to the menu (Fire / Esc) and start a new session. There is no reconnect. |
| High ping / "connection problems" indicator | Busy or Wi-Fi network, long distance | Prefer cable, close downloads / streams. Above ~150 ms ping the game remains playable but bumps and hits react later. |

## Testing at home
- **One computer, two copies:** host in one window, join `127.0.0.1` in the other (in the editor: Debug → Customize Run Instances → 2).
- **Two computers, same network:** join the host's local address (no forwarding needed).
- **Over the internet:** only after port forwarding; if it fails, test the forwarding with a friend first on LAN, then from outside.
