Start-Service -Name "Sunshine"

# Navigate to project
cd C:\CloudGaming

# Create logs folder
mkdir logs

# Build and launch all containers
docker-compose up --build

# Verify all containers are healthy
docker ps

# Test the session manager
curl http://localhost:3000/health

# Start a gaming session via the API
curl -X POST http://localhost:3000/session/start `
     -H "Content-Type: application/json" `
     -d '{"game": "mario-kart"}'