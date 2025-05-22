#!/bin/bash

# =====================
# CONFIGURATION
# =====================
CERT="$1"
TMP_PEM="converted_temp_cert.pem"

if [[ -z "$CERT" || ! -f "$CERT" ]]; then
  echo "❌ Please provide a valid certificate file as an argument."
  echo "Usage: $0 <certificate_file>"
  exit 1
fi

echo "🔍 Checking certificate file: $CERT"

# =====================
# STEP 1: Detect Format
# =====================
if grep -q "BEGIN CERTIFICATE" "$CERT"; then
  echo "✅ Detected PEM format."
  PEM_FILE="$CERT"
else
  echo "ℹ Detected non-PEM format. Converting to PEM..."
  openssl x509 -in "$CERT" -inform DER -out "$TMP_PEM" -outform PEM 2>/dev/null
  if [[ $? -ne 0 ]]; then
    echo "❌ Conversion failed. Invalid certificate format."
    exit 1
  fi
  PEM_FILE="$TMP_PEM"
  echo "✅ Successfully converted to PEM format."
fi

# =====================
# STEP 2: Check Bangladeshi CA
# =====================
ISSUER=$(openssl x509 -in "$PEM_FILE" -noout -issuer)
SUBJECT=$(openssl x509 -in "$PEM_FILE" -noout -subject)

echo "📜 Issuer: $ISSUER"
echo "📜 Subject: $SUBJECT"

ISSUER_LOWER=$(echo "$ISSUER" | tr '[:upper:]' '[:lower:]')
if [[ "$ISSUER_LOWER" == *"c=bd"* || "$ISSUER_LOWER" == *"bangladesh"* ]]; then
  echo "✅ Issuer is a Bangladeshi CA."
else
  echo "❌ Issuer is NOT a Bangladeshi CA. Skipping further checks."
  [[ "$PEM_FILE" == "$TMP_PEM" ]] && rm -f "$TMP_PEM"
  exit 1
fi

# =====================
# STEP 3: Run ZLint
# =====================
echo "🧪 Running zlint..."
ZLINT_OUTPUT=$(zlint -pretty "$PEM_FILE" 2>/dev/null)

if [[ -z "$ZLINT_OUTPUT" ]]; then
  echo "❌ zlint failed to parse the certificate."
  [[ "$PEM_FILE" == "$TMP_PEM" ]] && rm -f "$TMP_PEM"
  exit 1
fi

# =====================
# STEP 4: Count and Display Errors
# =====================
ERRORS=$(echo "$ZLINT_OUTPUT" | grep -i '"result": "error"' | wc -l)
FATALS=$(echo "$ZLINT_OUTPUT" | grep -i '"result": "fatal"' | wc -l)

if [[ $ERRORS -eq 0 && $FATALS -eq 0 ]]; then
  echo "✅ Certificate is structurally VALID according to PKI linting rules."
else
  echo "❌ Certificate is INVALID:"
  echo "  • ERROR count: $ERRORS"
  echo "  • FATAL count: $FATALS"
  echo ""
  echo "🔎 Listing failed lints:"
  echo "$ZLINT_OUTPUT" | jq -r 'to_entries[] | select(.value.result == "error" or .value.result == "fatal") | "- \(.key): \(.value.result | ascii_upcase) — \(.value.description)"'
fi

# =====================
# Cleanup
# =====================
[[ "$PEM_FILE" == "$TMP_PEM" ]] && rm -f "$TMP_PEM"
