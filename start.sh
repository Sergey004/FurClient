#!/bin/bash

# FA Nexus - Quick Start Script (Cross-Platform)

set -e

echo ""
echo "🚀 FA Nexus - Fur Affinity Client"
echo "=================================="
echo "Platform: $(uname -s)"
echo ""

# Check if node_modules exists
if [ ! -d "node_modules" ]; then
    echo "📦 Installing dependencies..."
    npm install
    echo ""
fi

# Check if .env exists
if [ ! -f ".env" ]; then
    echo "⚙️  Creating .env file..."
    cat > .env << EOF
PORT=3001
CLIENT_URL=http://localhost:3000
NODE_ENV=development
REACT_APP_API_URL=http://localhost:3001/api
EOF
    echo "✅ .env file created"
    echo ""
fi

# Check if .env.local exists (for local overrides)
if [ ! -f ".env.local" ]; then
    echo "💡 Tip: Create .env.local to override environment variables locally"
    echo ""
fi

# TypeScript check
echo "🔍 Running TypeScript check..."
npm run lint
if [ $? -ne 0 ]; then
    echo "❌ TypeScript errors found!"
    exit 1
fi
echo "✅ TypeScript OK"
echo ""

# Start dev servers
echo "🟢 Starting dev servers..."
echo "   Frontend: http://localhost:3000"
echo "   Backend:  http://localhost:3001/api"
echo ""
echo "Press Ctrl+C to stop"
echo ""

npm run dev
