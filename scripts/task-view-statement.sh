#!/bin/bash

sync_folders() {
  #  link resources
  rm -rf tasks/.commons/statement-viewer/resources
  ln -s "$(realpath tasks/$1/statement/)" tasks/.commons/statement-viewer/resources
  #  link sample cases
  rm -rf tasks/.commons/statement-viewer/sample-cases
  ln -s "$(realpath tasks/$1/public/examples/)" tasks/.commons/statement-viewer/sample-cases
  #  link problem.json
  rm -rf tasks/.commons/statement-viewer/data/problem.json
  #  ln -s "$(realpath tasks/$1/problem.json)" tasks/.commons/statement-viewer/data
  #  rm -f tasks/.commons/statement-viewer/data/problem.json
  #  cd tasks/.commons/statement-viewer/data
  #  ln -s ../../../$1/problem.json problem.json
  #  cd ../../../../
  cp tasks/$1/problem.json tasks/.commons/statement-viewer/data/problem.json
}

kill_process_on_port() {
  local PORT_TO_KILL=$1 # El puerto se pasa como el primer argumento a la función

  if [ -z "$PORT_TO_KILL" ]; then
    echo "Error: Debes proporcionar un número de puerto."
    echo "Uso: kill_process_on_port <numero_de_puerto>"
    return 1
  fi

  echo "Intentando terminar el proceso en el puerto $PORT_TO_KILL..."

  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    echo "Sistema operativo: macOS."
    PROCESS_ID=$(lsof -ti :"$PORT_TO_KILL" 2>/dev/null)
    if [ -n "$PROCESS_ID" ]; then
      echo "Terminando proceso $PROCESS_ID en el puerto $PORT_TO_KILL..."
      kill -9 "$PROCESS_ID"
      echo "Proceso terminado exitosamente."
    else
      echo "No se encontró ningún proceso escuchando en el puerto $PORT_TO_KILL."
    fi
  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux
    echo "Sistema operativo: Linux."
    PROCESS_ID=$(lsof -ti :"$PORT_TO_KILL" 2>/dev/null)
    if [ -n "$PROCESS_ID" ]; then
      echo "Terminando proceso $PROCESS_ID en el puerto $PORT_TO_KILL..."
      kill -9 "$PROCESS_ID"
      echo "Proceso terminado exitosamente."
    else
      echo "No se encontró ningún proceso escuchando en el puerto $PORT_TO_KILL."
    fi
  elif [[ "$OSTYPE" == "cygwin"* || "$OSTYPE" == "msys"* ]]; then
    # Windows (Git Bash/Cygwin)
    echo "Sistema operativo: Windows (via Git Bash/Cygwin)."
    PROCESS_ID=$(netstat -ano | grep ":$PORT_TO_KILL" | grep "LISTENING" | awk '{print $5}' | head -n 1)
    if [ -n "$PROCESS_ID" ]; then
      echo "Terminando proceso $PROCESS_ID en el puerto $PORT_TO_KILL..."
      taskkill //PID "$PROCESS_ID" //F
      echo "Proceso terminado exitosamente."
    else
      echo "No se encontró ningún proceso escuchando en el puerto $PORT_TO_KILL."
    fi
  else
    echo "Sistema operativo no soportado: $OSTYPE"
    echo "Este script solo soporta macOS, Linux y Windows (via Git Bash/Cygwin)."
    return 1
  fi
}

open_url_in_browser() {
  local URL_TO_OPEN="$1" # La URL se pasa como el primer argumento a la función

  if [ -z "$URL_TO_OPEN" ]; then
    echo "Error: Debes proporcionar una URL."
    echo "Uso: open_url_in_browser <URL>"
    return 1 # Devuelve un código de error
  fi

  echo "Intentando abrir: $URL_TO_OPEN en el navegador..."

  if command -v xdg-open > /dev/null; then
    # Para sistemas basados en Linux (ej. Ubuntu, Fedora)
    xdg-open "$URL_TO_OPEN"
    echo "Abierto con xdg-open."
  elif command -v open > /dev/null; then
    # Para macOS
    open "$URL_TO_OPEN"
    echo "Abierto con open."
  elif command -v start > /dev/null; then
    # Para Windows (usando Git Bash/Cygwin)
    start "$URL_TO_OPEN"
    echo "Abierto con start."
  else
    echo "❌ No se pudo abrir el navegador automáticamente."
    echo "Por favor, abre manualmente la siguiente URL en tu navegador: $URL_TO_OPEN"
    return 1 # Devuelve un código de error si no se encuentra un comando adecuado
  fi
}

sync_folders $1
cd tasks/.commons
kill_process_on_port "1234"
serve -p 1234 statement-viewer &
if [ "$2" != "no-browser" ]; then
  open_url_in_browser "http://localhost:1234"
fi
