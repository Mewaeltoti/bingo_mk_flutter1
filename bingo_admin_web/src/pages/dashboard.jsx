import { useState, useEffect } from 'react';
import { db } from '../firebase/config';
import { doc, onSnapshot } from 'firebase/firestore';

function Dashboard() {
  const [gameState, setGameState] = useState(null);

  useEffect(() => {
    const unsub = onSnapshot(doc(db, 'games', 'live'), (doc) => {
      setGameState(doc.data());
    });
    return () => unsub();
  }, []);

  return (
    <div>
      <h1 style={{ color: '#333' }}>Live Monitor</h1>
      <p style={{ color: '#666', fontSize: '18px' }}>
        Status: <strong style={{ color: '#007bff', textTransform: 'uppercase' }}>{gameState?.status || 'Waiting'}</strong>
      </p>

      <div style={{ display: 'flex', gap: '20px', marginTop: '20px' }}>
        <div style={cardStyle}>
          <h3>Current Number</h3>
          <div style={{ fontSize: '48px', fontWeight: 'bold', color: '#dc3545', display: 'flex', justifyContent: 'center', alignItems: 'center', height: '100px' }}>
            {gameState?.drawnNumbers?.length > 0 ? gameState.drawnNumbers[gameState.drawnNumbers.length - 1] : '--'}
          </div>
        </div>

        <div style={{ ...cardStyle, flex: 2 }}>
          <h3>Recently Drawn</h3>
          <div style={{ display: 'flex', gap: '10px', overflowX: 'auto', padding: '10px 0' }}>
            {gameState?.drawnNumbers?.slice().reverse().map((num, i) => (
              <div key={i} style={ballStyle}>
                {num}
              </div>
            ))}
            {(!gameState?.drawnNumbers || gameState.drawnNumbers.length === 0) && (
              <p style={{ color: '#999' }}>No numbers drawn yet.</p>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

const cardStyle = {
  backgroundColor: 'white',
  padding: '20px',
  borderRadius: '8px',
  boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
  flex: 1
};

const ballStyle = {
  minWidth: '50px',
  height: '50px',
  borderRadius: '50%',
  backgroundColor: '#f8f9fa',
  border: '2px solid #dee2e6',
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'center',
  fontSize: '20px',
  fontWeight: 'bold',
  color: '#495057'
};

export default Dashboard;

