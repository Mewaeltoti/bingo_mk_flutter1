import React, { useState, useEffect } from 'react';
import { db, functions } from '../firebase/config';
import { doc, getDoc, setDoc, updateDoc, onSnapshot } from 'firebase/firestore';
import { httpsCallable } from 'firebase/functions';

function GameControl() {
  const [gameState, setGameState] = useState(null);
  const [isSeeding, setIsSeeding] = useState(false);
  const [settings, setSettings] = useState({
    prizePool: 100,
    cardPrice: 10,
    gamePattern: 'full_house',
    sessionId: 1001
  });

  useEffect(() => {
    const unsub = onSnapshot(doc(db, 'games', 'live'), (doc) => {
      const data = doc.data();
      setGameState(data);
      if (data) {
        setSettings({
          prizePool: data.prizePool || 100,
          cardPrice: data.cardPrice || 10,
          gamePattern: data.gamePattern || 'full_house',
          sessionId: data.sessionId || 1001
        });
      }
    });
    return () => unsub();
  }, []);

  const updateStatus = async (status, overrides = {}) => {
    const ref = doc(db, 'games', 'live');
    const snap = await getDoc(ref);
    const finalData = { 
      status, 
      ...settings,
      ...overrides 
    };
    
    if (!snap.exists()) {
      await setDoc(ref, finalData);
    } else {
      await updateDoc(ref, finalData);
    }
  };

  const handleSettingChange = (e) => {
    const { name, value } = e.target;
    setSettings(prev => ({ ...prev, [name]: name === 'gamePattern' ? value : Number(value) }));
  };


  const cancelGameAction = async () => {
    if (!window.confirm("ARE YOU SURE? This will cancel the current game, save it to history as 'cancelled', and reset everything. This action cannot be undone.")) return;
    
    setIsSeeding(true);
    try {
      const cancelFunc = httpsCallable(functions, 'cancelGame');
      await cancelFunc();
      alert("Game cancelled successfully.");
    } catch (error) {
      console.error(error);
      alert("Error cancelling game: " + error.message);
    } finally {
      setIsSeeding(false);
    }
  };

  const startBuyingPhase = async () => {
    setIsSeeding(true);
    try {
      const startFunc = httpsCallable(functions, 'startNewGame');
      await startFunc();
    } catch (error) {
      console.error(error);
      alert("Error starting game: " + error.message);
    } finally {
      setIsSeeding(false);
    }
  };
  const startGame = () => updateStatus('active');
  const pauseGame = () => updateStatus('paused', { isPaused: true });
  const resumeGame = () => updateStatus('active', { isPaused: false });
  const resetGame = () => updateStatus('waiting', { drawnNumbers: [], winners: [], isPaused: false, cardsSold: 0, playersCount: 0 });

  return (
    <div>
      <h2 style={{ color: '#333' }}>Live Game Control</h2>
      
      <div style={{ backgroundColor: 'white', padding: '20px', borderRadius: '8px', boxShadow: '0 2px 4px rgba(0,0,0,0.1)', marginBottom: '20px' }}>
        <h3>Current Status: <span style={{ color: '#007bff', textTransform: 'uppercase' }}>{gameState?.status || 'UNKNOWN'}</span></h3>
        <p><strong>Session ID:</strong> #{gameState?.sessionId || 'N/A'}</p>
        <p><strong>Prize:</strong> {gameState?.prizePool} ETB | <strong>Price:</strong> {gameState?.cardPrice} ETB</p>
        <p><strong>Pattern:</strong> {gameState?.gamePattern}</p>
      </div>

      <div style={{ backgroundColor: '#f8f9fa', padding: '20px', borderRadius: '8px', marginBottom: '20px', display: 'flex', gap: '15px', flexWrap: 'wrap' }}>
        <div style={inputGroup}>
          <label>Prize Pool (ETB)</label>
          <input name="prizePool" type="number" value={settings.prizePool} onChange={handleSettingChange} style={inputStyle} />
        </div>
        <div style={inputGroup}>
          <label>Card Price (ETB)</label>
          <input name="cardPrice" type="number" value={settings.cardPrice} onChange={handleSettingChange} style={inputStyle} />
        </div>
        <div style={inputGroup}>
          <label>Game Pattern</label>
          <select name="gamePattern" value={settings.gamePattern} onChange={handleSettingChange} style={inputStyle}>
            <option value="full_house">Full House</option>
            <option value="single_line">Single Line</option>
            <option value="four_corners">Four Corners</option>
          </select>
        </div>
      </div>

      <div style={{ display: 'flex', gap: '10px', flexWrap: 'wrap', marginBottom: '30px' }}>
        <button onClick={startBuyingPhase} style={btnStyle('#ffc107', 'black')}>Start Buying Phase</button>
        <button onClick={startGame} style={btnStyle('#28a745', 'white')}>Start Game (Draw Loop)</button>
        <button onClick={pauseGame} style={btnStyle('#dc3545', 'white')}>Pause Game</button>
        <button onClick={resumeGame} style={btnStyle('#17a2b8', 'white')}>Resume Game</button>
        <button onClick={cancelGameAction} style={btnStyle('#000000', 'white')}>Cancel & Reset Game</button>
        <button onClick={resetGame} style={btnStyle('#6c757d', 'white')}>Simple Reset</button>
      </div>

    </div>
  );
}

const btnStyle = (bg, color) => ({
  padding: '12px 24px',
  backgroundColor: bg,
  color: color,
  border: 'none',
  borderRadius: '4px',
  cursor: 'pointer',
  fontSize: '16px',
  fontWeight: 'bold'
});

const inputGroup = {
  display: 'flex',
  flexDirection: 'column',
  gap: '5px'
};

const inputStyle = {
  padding: '8px',
  borderRadius: '4px',
  border: '1px solid #ccc',
  fontSize: '14px'
};

export default GameControl;

