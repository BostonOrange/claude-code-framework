#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

pause_on_error() {
  local exit_code=$?
  if [ "$exit_code" -ne 0 ]; then
    echo
    echo "Something stopped the local startup."
    echo "Read the message above, fix the missing item, then run this file again."
    echo
    read -r -p "Press Enter to close this window..."
  fi
  exit "$exit_code"
}
trap pause_on_error EXIT

echo
echo "Internal tools starter"
echo "========================"
echo

if ! command -v node >/dev/null 2>&1; then
  echo "Node.js is missing. Install Node.js 22 or newer, then run this file again."
  echo "Download: https://nodejs.org/"
  exit 1
fi

if ! command -v npm >/dev/null 2>&1; then
  echo "npm is missing. Reinstall Node.js 22 or newer, then run this file again."
  exit 1
fi

npm run start-here

echo
echo "Checking your laptop..."
npm run doctor

echo
echo "Installing project packages. This can take a few minutes the first time."
npm install

echo
echo "Starting the local app. Keep this window open while you use it."
echo "Open http://localhost:3000 when the app says it is ready."
echo
npm run dev
