#!/bin/bash
set -e

# Remove a potentially pre-existing server.pid for Rails
rm -f /myapp/tmp/pids/server.pid

# Optional: fix line endings (only when explicitly enabled)
if [ "${DOS2UNIX_ON_BOOT}" = "1" ]; then
  echo "Fixing line endings..."
  find /myapp \( -name "*.rb" -o -name "*.sh" \) -print0 | xargs -0 dos2unix 2>/dev/null || true
fi

# Execute the container's main process (rails server)
exec "$@"
