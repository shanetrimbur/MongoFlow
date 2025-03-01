#!/bin/bash

# MongoFlow Local Development Script
echo "Starting MongoFlow local development environment..."

# Check if running services are specified
if [ $# -eq 0 ]; then
  echo "Usage: $0 [all|frontend|python|go]"
  echo "  all      - Start all services"
  echo "  frontend - Start only the frontend"
  echo "  python   - Start only the Python service"
  echo "  go       - Start only the Go service"
  exit 1
fi

# Source environment variables if .env exists
if [ -f .env ]; then
  echo "Loading environment variables..."
  export $(grep -v '^#' .env | xargs)
fi

# Function to start the Python service
start_python() {
  echo "Starting Python service..."
  cd services/python-service
  pip install -r requirements.txt > /dev/null
  uvicorn app:app --reload --port 8000 &
  PYTHON_PID=$!
  cd ../..
  echo "Python service started on http://localhost:8000"
}

# Function to start the Go service
start_go() {
  echo "Starting Go service..."
  cd services/go-service
  go run main.go &
  GO_PID=$!
  cd ../..
  echo "Go service started on http://localhost:8080"
}

# Function to start the frontend
start_frontend() {
  echo "Starting React frontend..."
  cd frontend
  npm install > /dev/null
  npm start &
  FRONTEND_PID=$!
  cd ..
  echo "Frontend started on http://localhost:3000"
}

# Start services based on command line argument
case "$1" in
  all)
    start_python
    start_go
    start_frontend
    ;;
  python)
    start_python
    ;;
  go)
    start_go
    ;;
  frontend)
    start_frontend
    ;;
  *)
    echo "Unknown service: $1"
    exit 1
    ;;
esac

# Trap SIGINT to kill all background processes
trap "kill $PYTHON_PID $GO_PID $FRONTEND_PID 2>/dev/null" SIGINT

echo "Press Ctrl+C to stop all services"
wait
