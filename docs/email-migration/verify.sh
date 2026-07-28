#!/usr/bin/env bash
# Read-only DNS + SES status check for the brandonstiles.com email migration.
# Prints no secrets. Safe to run at any point in the migration.
set -euo pipefail

DOMAIN="brandonstiles.com"
REGION="us-east-1"

echo "== DNS: website (must stay GitHub Pages) =="
dig +short "$DOMAIN" A

echo
echo "== DNS: current MX =="
dig +short "$DOMAIN" MX

echo
echo "== DNS: root SPF (should still say include:mailgun.org) =="
dig +short "$DOMAIN" TXT

echo
echo "== DNS: DMARC =="
dig +short "_dmarc.$DOMAIN" TXT

echo
echo "== DNS: SES MAIL FROM (MX + SPF) =="
dig +short "mail.$DOMAIN" MX
dig +short "mail.$DOMAIN" TXT

echo
echo "== DNS: DKIM CNAMEs =="
for token in $(aws sesv2 get-email-identity --email-identity "$DOMAIN" --region "$REGION" --query "DkimAttributes.Tokens" --output text); do
  echo "-- $token --"
  dig +short "${token}._domainkey.${DOMAIN}" CNAME
done

echo
echo "== SES identity status =="
aws sesv2 get-email-identity --email-identity "$DOMAIN" --region "$REGION" \
  --query "{Verified:VerifiedForSendingStatus,DKIM:DkimAttributes.Status,MailFrom:MailFromAttributes.MailFromDomainStatus}"

echo
echo "== SES account sandbox status =="
aws sesv2 get-account --region "$REGION" \
  --query "{ProductionAccessEnabled:ProductionAccessEnabled,Max24Hour:SendQuota.Max24HourSend,SentLast24Hours:SendQuota.SentLast24Hours}"
