#!/usr/bin/env bash
set -e

# Ajuste estes valores se necessário
GITHUB_USER="Kaua-Navarro"
REPO_NAME="Desafio-CampoMinado"
VISIBILITY="public" # public ou private
PROJECT_DIR="$REPO_NAME"

echo "Criando pasta do projeto: $PROJECT_DIR"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

echo "Escrevendo arquivos do projeto..."

cat > package.json <<'EOF'
{
  "name": "campo-minado-react",
  "version": "1.0.0",
  "private": true,
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-router-dom": "^6.14.1"
  },
  "scripts": {
    "dev": "vite",
    "start": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "devDependencies": {
    "vite": "^5.0.0",
    "@vitejs/plugin-react": "^4.0.0"
  }
}
EOF

cat > index.html <<'EOF'
<!doctype html>
<html>
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Campo Minado</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
  </body>
</html>
EOF

mkdir -p src/components src/pages

cat > src/main.jsx <<'EOF'
import React from "react";
import { createRoot } from "react-dom/client";
import { BrowserRouter } from "react-router-dom";
import App from "./App";
import "./styles.css";

createRoot(document.getElementById("root")).render(
  <React.StrictMode>
    <BrowserRouter>
      <App />
    </BrowserRouter>
  </React.StrictMode>
);
EOF

cat > src/App.jsx <<'EOF'
import React, { useEffect, useState } from "react";
import { Routes, Route, useNavigate } from "react-router-dom";
import Config from "./pages/Config";
import Game from "./pages/Game";
import Dashboard from "./pages/Dashboard";

const STORAGE_KEY = "minesweeper_stats_v1";

function loadStats() {
  const raw = localStorage.getItem(STORAGE_KEY);
  if (!raw) {
    const init = { totalGames: 0, wins: 0, maxStreak: 0, points: 10 };
    localStorage.setItem(STORAGE_KEY, JSON.stringify(init));
    return init;
  }
  return JSON.parse(raw);
}

function saveStats(stats) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(stats));
}

export default function App() {
  const [stats, setStats] = useState(loadStats);
  const navigate = useNavigate();

  useEffect(() => {
    saveStats(stats);
  }, [stats]);

  const updatePoints = (newPoints) => {
    setStats((s) => {
      const next = { ...s, points: newPoints };
      saveStats(next);
      return next;
    });
  };

  const incrementTotalGames = () => {
    setStats((s) => ({ ...s, totalGames: s.totalGames + 1 }));
  };

  const incrementWins = () => {
    setStats((s) => ({ ...s, wins: s.wins + 1 }));
  };

  const updateMaxStreak = (streak) => {
    setStats((s) => ({ ...s, maxStreak: Math.max(s.maxStreak, streak) }));
  };

  useEffect(() => {
    if (stats.points <= 0) {
      alert("Seus pontos chegaram a 0. Fim de jogo! Você será levado ao Dashboard.");
      navigate("/dashboard");
    }
  }, [stats.points, navigate]);

  return (
    <Routes>
      <Route
        path="/"
        element={<Config points={stats.points} updatePoints={updatePoints} />}
      />
      <Route
        path="/game"
        element={
          <Game
            points={stats.points}
            updatePoints={updatePoints}
            incrementTotalGames={incrementTotalGames}
            incrementWins={incrementWins}
            updateMaxStreak={updateMaxStreak}
          />
        }
      />
      <Route
        path="/dashboard"
        element={
          <Dashboard
            stats={stats}
            reset={() => {
              const resetStats = { totalGames: 0, wins: 0, maxStreak: 0, points: 10 };
              setStats(resetStats);
              saveStats(resetStats);
              navigate("/");
            }}
          />
        }
      />
    </Routes>
  );
}
EOF

cat > src/pages/Config.jsx <<'EOF'
import React, { useState } from "react";
import { useNavigate } from "react-router-dom";

export default function Config({ points }) {
  const [size, setSize] = useState(4);
  const [bombs, setBombs] = useState(3);
  const navigate = useNavigate();

  const handleStart = () => {
    const total = size * size;
    if (bombs >= total) {
      alert("Quantidade de bombas deve ser menor que o total de células (deixe ao menos 1 célula sem bomba).");
      return;
    }
    navigate("/game", { state: { size, bombs } });
  };

  return (
    <div className="container">
      <h1>Campo Minado</h1>
      <div className="card config">
        <label>
          Tamanho do tabuleiro (N x N):
          <select value={size} onChange={(e) => setSize(Number(e.target.value))}>
            {[3,4,5,6,7,8].map(n => <option key={n} value={n}>{n}×{n}</option>)}
          </select>
        </label>

        <label>
          Número de bombas:
          <input
            type="number"
            min="1"
            value={bombs}
            onChange={(e) => setBombs(Number(e.target.value))}
          />
        </label>

        <div className="row">
          <button onClick={handleStart}>Iniciar Partida</button>
        </div>

        <div className="info">
          <p>Pontos atuais: <strong>{points}</strong></p>
        </div>
      </div>
    </div>
  );
}
EOF

cat > src/pages/Game.jsx <<'EOF'
import React, { useEffect, useState } from "react";
import { useLocation, useNavigate } from "react-router-dom";
import Card from "../components/Card";

function shuffleArray(arr) {
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
}

export default function Game({ points, updatePoints, incrementTotalGames, incrementWins, updateMaxStreak }) {
  const location = useLocation();
  const navigate = useNavigate();
  const { size = 4, bombs = 3 } = location.state || {};
  const totalCells = size * size;

  useEffect(() => {
    if (!location.state) {
      navigate("/");
    }
  }, [location.state, navigate]);

  const [board, setBoard] = useState([]);
  const [safeRevealed, setSafeRevealed] = useState(0);
  const [currentStreak, setCurrentStreak] = useState(0);

  useEffect(() => {
    const indices = Array.from({ length: totalCells }, (_, i) => i);
    shuffleArray(indices);
    const bombSet = new Set(indices.slice(0, bombs));
    const newBoard = Array.from({ length: totalCells }, (_, i) => ({
      id: i,
      isBomb: bombSet.has(i),
      revealed: false
    }));
    setBoard(newBoard);
    setSafeRevealed(0);
    setCurrentStreak(0);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const handleReveal = (idx) => {
    if (board[idx].revealed) return;

    setBoard((prev) => {
      const copy = prev.map((c) => ({ ...c }));
      copy[idx].revealed = true;
      return copy;
    });

    if (board[idx].isBomb) {
      const newPoints = Math.max(0, points - 1);
      updatePoints(newPoints);
      setCurrentStreak(0);

      if (newPoints <= 0) {
        incrementTotalGames();
        return;
      }
      return;
    } else {
      setSafeRevealed((prev) => {
        const nextSafe = prev + 1;
        const newStreak = currentStreak + 1;
        setCurrentStreak(newStreak);
        updateMaxStreak(newStreak);
        if (nextSafe === totalCells - bombs) {
          incrementWins();
          incrementTotalGames();
          alert("Vitória! Você revelou todas as células seguras. Voltando à tela de configuração.");
          navigate("/");
        }
        return nextSafe;
      });
    }
  };

  const gridStyle = {
    gridTemplateColumns: `repeat(${size}, 1fr)`
  };

  return (
    <div className="container">
      <h2>Partida: {size}×{size} - Bombas: {bombs}</h2>
      <div className="info">
        <p>Pontos: <strong>{points}</strong></p>
        <p>Sequência atual (streak): <strong>{currentStreak}</strong></p>
        <p>Células seguras reveladas: <strong>{safeRevealed}/{totalCells - bombs}</strong></p>
      </div>

      <div className="board" style={gridStyle}>
        {board.map((cell) => (
          <Card
            key={cell.id}
            revealed={cell.revealed}
            isBomb={cell.isBomb}
            onReveal={() => handleReveal(cell.id)}
          />
        ))}
      </div>

      <div className="row">
        <button onClick={() => navigate("/")}>Voltar à Configuração</button>
        <button onClick={() => navigate("/")}>Abandonar Partida</button>
      </div>
    </div>
  );
}
EOF

cat > src/components/Card.jsx <<'EOF'
import React from "react";

export default function Card({ revealed, isBomb, onReveal }) {
  const handleClick = () => {
    if (!revealed) onReveal();
  };

  return (
    <div className={`card cell ${revealed ? "revealed" : ""}`} onClick={handleClick}>
      {!revealed && <span className="emoji">⬜</span>}
      {revealed && isBomb && <span className="emoji">💣</span>}
      {revealed && !isBomb && <span className="emoji">✅</span>}
    </div>
  );
}
EOF

cat > src/pages/Dashboard.jsx <<'EOF'
import React from "react";

export default function Dashboard({ stats, reset }) {
  return (
    <div className="container">
      <h1>Dashboard</h1>
      <div className="card">
        <p>Total de partidas jogadas até zerar os pontos: <strong>{stats.totalGames}</strong></p>
        <p>Quantidade de vitórias (completa um mapa): <strong>{stats.wins}</strong></p>
        <p>Maior sequência de cliques seguros consecutivos (streak): <strong>{stats.maxStreak}</strong></p>
        <p>Pontos atuais: <strong>{stats.points}</strong></p>
        <div className="row">
          <button onClick={reset}>Reiniciar Jogo (limpar estatísticas)</button>
        </div>
      </div>
    </div>
  );
}
EOF

cat > src/styles.css <<'EOF'
:root{
  --bg:#f3f4f6;
  --card:#fff;
  --accent:#0ea5a4;
}

body{
  font-family: system-ui, Arial, sans-serif;
  margin:0;
  background:var(--bg);
  color:#0f172a;
}

.container{
  max-width:900px;
  margin:24px auto;
  padding:12px;
}

.card{
  background:var(--card);
  padding:16px;
  border-radius:8px;
  box-shadow:0 4px 12px rgba(2,6,23,0.06);
}

.config label{
  display:block;
  margin:10px 0;
}

.row{
  margin-top:12px;
  display:flex;
  gap:8px;
}

button{
  background:var(--accent);
  color:white;
  border:none;
  padding:8px 12px;
  border-radius:6px;
  cursor:pointer;
}

.board{
  display:grid;
  gap:8px;
  margin-top:16px;
}

.cell{
  background:#e6eef0;
  aspect-ratio:1/1;
  display:flex;
  align-items:center;
  justify-content:center;
  font-size:20px;
  cursor:pointer;
  border-radius:6px;
  user-select:none;
}

.cell.revealed{
  background:#f8fafb;
  cursor:default;
}

.emoji{ font-size:22px; }

.info p{ margin:6px 0; }
EOF

cat > .gitignore <<'EOF'
/node_modules
/dist
/.env
.DS_Store
.vscode
EOF

cat > README.md <<'EOF'
# Desafio - Campo Minado (React)

Projeto criado automaticamente pelo script.

Como rodar:
1. Instale dependências:
   npm install
2. Rode em modo desenvolvedor:
   npm run dev
3. Abra http://localhost:5173

Repositório remoto será criado com o nome: '$GITHUB_USER/$REPO_NAME' (se você estiver autenticado com 'gh').
EOF

echo "Instalando dependências (npm install)..."
npm install

echo "Inicializando git e criando commit..."
git init
git add .
git commit -m "Initial commit - Campo Minado"

# Check gh CLI
if command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI detectado."
  if gh auth status >/dev/null 2>&1; then
    echo "Você está autenticado no gh. Criando repositório remoto e fazendo push..."
    gh repo create "$GITHUB_USER/$REPO_NAME" --"$VISIBILITY" --source=. --remote=origin --push
    echo "Repositório criado e push realizado: https://github.com/$GITHUB_USER/$REPO_NAME"
  else
    echo "GitHub CLI encontrado, mas você não está autenticado."
    echo "Execute: gh auth login"
    echo "Após autenticar, rode:"
    echo "  gh repo create $GITHUB_USER/$REPO_NAME --$VISIBILITY --source=. --remote=origin --push"
  fi
else
  echo "GitHub CLI (gh) não encontrado."
  echo "Crie o repositório manualmente no GitHub (https://github.com/new) com o nome: $REPO_NAME (visibilidade: $VISIBILITY)"
  echo "Depois rode os comandos abaixo para conectar e enviar o código:"
  echo "  git branch -M main"
  echo "  git remote add origin https://github.com/$GITHUB_USER/$REPO_NAME.git"
  echo "  git push -u origin main"
fi

echo "Pronto. Se precisar que eu ajuste algo no conteúdo, me avise."