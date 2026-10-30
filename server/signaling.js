
const WebSocket = require('ws');

const wss = new WebSocket.Server({ port: 3001 });

const rooms = new Map();

wss.on('connection', (ws) => {
  let currentRoom = null;

  ws.on('message', (message) => {
    try {
      const data = JSON.parse(message.toString());

      // Client bergabung ke room
      if (data.type === 'join') {
        currentRoom = data.room;

        if (!rooms.has(currentRoom)) {
          rooms.set(currentRoom, new Set());
        }

        const room = rooms.get(currentRoom);

        // Beri tahu client lama bahwa ada client baru
        room.forEach((client) => {
          if (client.readyState === WebSocket.OPEN) {
            client.send(JSON.stringify({
              type: 'peer-joined',
            }));
          }
        });

        room.add(ws);

        ws.send(JSON.stringify({
          type: 'joined',
          room: currentRoom,
        }));

        console.log(`Client bergabung ke room: ${currentRoom}`);
        return;
      }

      // Teruskan offer, answer, dan ICE candidate
      if (currentRoom && rooms.has(currentRoom)) {
        const room = rooms.get(currentRoom);

        room.forEach((client) => {
          if (client !== ws &&
              client.readyState === WebSocket.OPEN) {
            client.send(JSON.stringify(data));
          }
        });
      }
    } catch (error) {
      console.error('Pesan signaling tidak valid:', error);
    }
  });

  ws.on('close', () => {
    if (currentRoom && rooms.has(currentRoom)) {
      const room = rooms.get(currentRoom);
      room.delete(ws);

      room.forEach((client) => {
        if (client.readyState === WebSocket.OPEN) {
          client.send(JSON.stringify({
            type: 'peer-left',
          }));
        }
      });

      if (room.size === 0) {
        rooms.delete(currentRoom);
      }

      console.log('Client keluar dari room');
    }
  });
});

console.log('Signaling server berjalan pada port 3001');
