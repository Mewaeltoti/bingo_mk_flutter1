import { useState, useEffect } from 'react';
import { db, functions } from '../firebase/config';
import { doc, getDoc, setDoc, updateDoc, onSnapshot } from 'firebase/firestore';
import { httpsCallable } from 'firebase/functions';

function GameControl() {
  const [gameState, setGameState] = useState(null);

  const [settings, setSettings] = useState({
    prizePool: 100,
    cardPrice: 10,
    gamePattern: 'full_house',
    sessionId: 1001,
    broadcastMessage: ''
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
    setSettings(prev => ({ ...prev, [name]: (name === 'gamePattern' || name === 'broadcastMessage') ? value : Number(value) }));
  };


  const cancelGameAction = async () => {
    if (!window.confirm("ARE YOU SURE? This will cancel the current game, save it to history as 'cancelled', and reset everything. This action cannot be undone.")) return;
    
    try {
      const cancelFunc = httpsCallable(functions, 'cancelGame');
      await cancelFunc();
      alert("Game cancelled successfully.");
    } catch (error) {
      console.error(error);
      alert("Error cancelling game: " + error.message);
    }
  };

  const startBuyingPhase = async () => {
    try {
      const startFunc = httpsCallable(functions, 'startNewGame');
      await startFunc(settings);
    } catch (error) {
      console.error(error);
      alert("Error starting game: " + error.message);
    }
  };
  const startGame = () => updateStatus('active');
  const pauseGame = () => updateStatus('paused', { isPaused: true });
  const resumeGame = () => updateStatus('active', { isPaused: false });
  const sendBroadcast = () => {
    if (!settings.broadcastMessage) return;
    updateStatus(gameState?.status || 'waiting', { broadcastMessage: settings.broadcastMessage });
    alert("Broadcast message sent!");
  };

  const clearBroadcast = () => {
    updateStatus(gameState?.status || 'waiting', { broadcastMessage: null });
    setSettings(prev => ({ ...prev, broadcastMessage: '' }));
  };

  const resetGame = () => updateStatus('waiting', { 
    drawnNumbers: [], 
    winners: [], 
    isPaused: false, 
    cardsSold: 0, 
    playersCount: 0,
    currentNumber: null,
    lastDrawTime: null,
    winningCardNo: null,
    winningCardNumbers: null,
    startTime: null,
    endTime: null
  });

  return (
    <div>
      <h2 style={{ color: '#333' }}>Live Game Control</h2>
      
      <div style={{ backgroundColor: 'white', padding: '20px', borderRadius: '8px', boxShadow: '0 2px 4px rgba(0,0,0,0.1)', marginBottom: '20px' }}>
        <h3>Current Status: <span style={{ color: '#007bff', textTransform: 'uppercase' }}>{gameState?.status || 'UNKNOWN'}</span></h3>
        <p><strong>Session ID:</strong> #{gameState?.sessionId || 'N/A'} | <strong>Players:</strong> {gameState?.playersCount || 0}</p>
        <p><strong>Prize:</strong> {gameState?.prizePool} ETB | <strong>Price:</strong> {gameState?.cardPrice} ETB | <strong>Cards Sold:</strong> {gameState?.cardsSold || 0}</p>
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
            <option value="two_lines">Two Lines</option>
            <option value="x_shape">X Shape</option>
            <option value="t_shape">T Shape</option>
            <option value="l_shape">L Shape</option>
            <option value="cross">Cross</option>
            <option value="frame">Frame</option>
            <option value="postage_stamp">Postage Stamp</option>
            <option value="small_diamond">Small Diamond</option>
            <option value="arrow_up">Arrow Up</option>
            <option value="pyramid">Pyramid</option>
            <option value="u_shape">U Shape</option>
          </select>
        </div>
      </div>

      <div style={{ backgroundColor: '#fff3cd', padding: '20px', borderRadius: '8px', marginBottom: '20px' }}>
        <h3>Broadcast Message</h3>
        <div style={{ display: 'flex', gap: '10px' }}>
          <input 
            name="broadcastMessage" 
            placeholder="Type a message to all players..." 
            value={settings.broadcastMessage} 
            onChange={handleSettingChange} 
            style={{ ...inputStyle, flex: 1 }} 
          />
          <button onClick={sendBroadcast} style={btnStyle('#ffc107', 'black')}>Send</button>
          <button onClick={clearBroadcast} style={btnStyle('#6c757d', 'white')}>Clear</button>
        </div>
      </div>

      <div style={{ display: 'flex', gap: '10px', flexWrap: 'wrap', marginBottom: '10px' }}>
        <button onClick={startBuyingPhase} style={btnStyle('#ffc107', 'black')}>Start Buying Phase</button>
        <button onClick={startGame} style={btnStyle('#28a745', 'white')}>Start Game (Draw Loop)</button>
        <button onClick={pauseGame} style={btnStyle('#dc3545', 'white')}>Pause Game</button>
        <button onClick={resumeGame} style={btnStyle('#17a2b8', 'white')}>Resume Game</button>
        <button onClick={cancelGameAction} style={btnStyle('#000000', 'white')}>Cancel & Reset Game</button>
        <button onClick={resetGame} style={btnStyle('#6c757d', 'white')}>Simple Reset</button>
      </div>

      <div style={{ backgroundColor: '#e2e3e5', padding: '20px', borderRadius: '8px', marginBottom: '20px' }}>
        <h3>Pending Bingo Claims</h3>
        {gameState?.pendingClaims?.length > 0 ? (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
            {gameState.pendingClaims.map((claim) => (
              <div key={claim.cardId} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', backgroundColor: 'white', padding: '10px', borderRadius: '4px' }}>
                <span>Card #{claim.cardNo} (User: {claim.userId.substring(0, 5)}...)</span>
                <div style={{ display: 'flex', gap: '5px' }}>
                  <button onClick={() => httpsCallable(functions, 'confirmBingoClaim')({ cardId: claim.cardId })} style={btnStyle('#28a745', 'white', '8px 16px', '12px')}>Approve</button>
                  <button onClick={() => httpsCallable(functions, 'rejectBingoClaim')({ cardId: claim.cardId, userId: claim.userId })} style={btnStyle('#dc3545', 'white', '8px 16px', '12px')}>Reject</button>
                </div>
              </div>
            ))}
          </div>
        ) : <p>No pending claims.</p>}
      </div>

      <div style={{ backgroundColor: '#d1ecf1', padding: '20px', borderRadius: '8px', marginBottom: '20px' }}>
        <h3>Confirmed Winners ({gameState?.confirmedWinners?.length || 0})</h3>
        {gameState?.confirmedWinners?.length > 0 ? (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
            {gameState.confirmedWinners.map((winner) => (
              <div key={winner.cardId} style={{ backgroundColor: 'white', padding: '10px', borderRadius: '4px' }}>
                Card #{winner.cardNo} (User: {winner.userId.substring(0, 5)}...)
              </div>
            ))}
            <button 
                onClick={() => {
                    if (window.confirm("Finalize game and split prize equally?")) {
                        httpsCallable(functions, 'finalizeGameAndPayout')();
                    }
                }} 
                style={btnStyle('#17a2b8', 'white')}
            >
                Finalize Game & Payout
            </button>
          </div>
        ) : <p>No confirmed winners yet.</p>}
      </div>

      <div style={{ fontSize: '12px', color: '#666', marginTop: '20px', borderTop: '1px solid #ddd', paddingTop: '10px' }}>
        <p><strong>Note:</strong> If you accidentally deleted the 'games/live' document, clicking <strong>"Start Buying Phase"</strong> or <strong>"Cancel & Reset Game"</strong> will automatically recreate it.</p>
      </div>

    </div>
  );
}

const btnStyle = (bg, color, padding = '12px 24px', fontSize = '16px') => ({
  padding: padding,
  backgroundColor: bg,
  color: color,
  border: 'none',
  borderRadius: '4px',
  cursor: 'pointer',
  fontSize: fontSize,
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

