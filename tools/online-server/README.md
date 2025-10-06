Local WebSocket relay server for two-player demo

Requirements:
- Node.js v14+

Run:

```bash
cd tools/online-server
node server.js
```

This server allocates a room for every two connected clients and simply relays JSON messages between peers.

Protocol (JSON):
- Client -> Server:
  - { "type": "join", "payload": { "team": "r" } }
  - { "type": "move", "payload": { "move": "a3a4" } }
  - { "type": "rq_retract", "payload": {} }
  - { "type": "rq_draw", "payload": {} }
  - { "type": "resign", "payload": {} }

- Server -> Client: forwards the same JSON to peer
- Server also replies with: { "type": "joined", "payload": { "roomId": "abc123" }} when client joins
- When the room has 2 clients, server broadcasts { "type": "ready" } to both clients

Notes:
- This is a minimal demo server for local testing only. Do not expose it on the public internet without additional security.
