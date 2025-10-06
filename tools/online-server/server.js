// Simple WebSocket relay server for local two-player demo
// Run: node server.js

const WebSocket = require('ws');
const wss = new WebSocket.Server({ port: 8080 });

// Rooms: roomId -> [ws1, ws2]
const rooms = new Map();

wss.on('connection', function connection(ws) {
  ws.roomId = null;
  ws.on('message', function incoming(message) {
    try {
      const m = JSON.parse(message.toString());
      const type = m.type;
      const payload = m.payload || {};

      if (type === 'join') {
        // find or create an available room
        let room = null;
        for (const [id, arr] of rooms.entries()) {
          if (arr.length < 2) {
            room = id;
            break;
          }
        }
        if (!room) {
          room = Math.random().toString(36).substring(2, 8);
          rooms.set(room, []);
        }
        const arr = rooms.get(room);
        arr.push(ws);
        ws.roomId = room;
        // reply with joined and roomId
        ws.send(JSON.stringify({ type: 'joined', payload: { roomId: room } }));
        if (arr.length === 2) {
          // notify both players ready
          arr.forEach(s => s.send(JSON.stringify({ type: 'ready' })));
        }
        return;
      }

      // forward other messages to peer in the same room
      const roomId = ws.roomId;
      if (!roomId) return;
      const peers = rooms.get(roomId) || [];
      for (const peer of peers) {
        if (peer !== ws && peer.readyState === WebSocket.OPEN) {
          peer.send(JSON.stringify(m));
        }
      }
    } catch (e) {
      // ignore
    }
  });

  ws.on('close', function() {
    if (ws.roomId) {
      const arr = rooms.get(ws.roomId) || [];
      const idx = arr.indexOf(ws);
      if (idx >= 0) arr.splice(idx, 1);
      if (arr.length === 0) rooms.delete(ws.roomId);
    }
  });
});

console.log('WebSocket relay server started on ws://127.0.0.1:8080');
