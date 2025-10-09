#!/bin/bash
# ============================================================================
# Health Check Script for Demo Application
# ============================================================================

# Exit codes
SUCCESS=0
FAILURE=1

# Configuration
MAX_RETRIES=3
RETRY_DELAY=2
HEALTH_ENDPOINT="http://localhost/health"

# Function to check health
check_health() {
    local retries=0
    
    while [ $retries -lt $MAX_RETRIES ]; do
        if curl -f -s --max-time 3 "${HEALTH_ENDPOINT}" > /dev/null 2>&1; then
            echo "Health check passed"
            return $SUCCESS
        fi
        
        retries=$((retries + 1))
        if [ $retries -lt $MAX_RETRIES ]; then
            echo "Health check failed, retry $retries/$MAX_RETRIES..."
            sleep $RETRY_DELAY
        fi
    done
    
    echo "Health check failed after $MAX_RETRIES attempts"
    return $FAILURE
}

# Run health check
check_health
exit $?
