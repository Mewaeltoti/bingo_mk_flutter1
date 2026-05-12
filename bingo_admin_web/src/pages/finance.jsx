import { useState, useEffect } from 'react';
import { db } from '../firebase/config';
import { doc, onSnapshot } from 'firebase/firestore';

function Finance() {
  const [gameState, setGameState] = useState(null);

  useEffect(() => {
    const unsub = onSnapshot(doc(db, 'games', 'live'), (doc) => {
      setGameState(doc.data());
    });
    return () => unsub();
  }, []);

  const cardsSold = gameState?.cardsSold || 0;
  const cardPrice = 10; // Default price, could be made dynamic
  const totalRevenue = cardsSold * cardPrice;
  const prizePool = gameState?.prizePool || 0;

  return (
    <div>
      <h2 style={{ color: '#333' }}>Finance & Prize Pool</h2>
      
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '20px', marginTop: '20px' }}>
        <div style={cardStyle}>
          <h4 style={{ margin: '0 0 10px 0', color: '#666' }}>Cards Sold</h4>
          <div style={{ fontSize: '36px', fontWeight: 'bold', color: '#17a2b8' }}>{cardsSold}</div>
        </div>

        <div style={cardStyle}>
          <h4 style={{ margin: '0 0 10px 0', color: '#666' }}>Total Revenue</h4>
          <div style={{ fontSize: '36px', fontWeight: 'bold', color: '#28a745' }}>${totalRevenue.toFixed(2)}</div>
        </div>

        <div style={cardStyle}>
          <h4 style={{ margin: '0 0 10px 0', color: '#666' }}>Current Prize Pool</h4>
          <div style={{ fontSize: '36px', fontWeight: 'bold', color: '#ffc107' }}>${prizePool.toFixed(2)}</div>
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
};

export default Finance;

