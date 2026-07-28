# Email migration: Google Workspace → SES + Gmail

Goal: stop paying for Google Workspace on `brandonstiles.com` while keeping `brandon@brandonstiles.com` fully functional — receiving and sending — from a free personal Gmail account (`brandonstiles@gmail.com`).

## Important correction from the original plan

The original brief assumed Google Workspace is the current incoming-mail provider and that the website is hosted on AWS. Neither is true as of the 2026-07-28 inspection:

- **Website hosting:** GitHub Pages (confirmed by DNS: `A` records resolve to GitHub Pages IPs `185.199.108-111.153`, and `public/CNAME` = `brandonstiles.com`). Not AWS. There is nothing AWS-hosted to protect — the record to leave alone is whatever points `brandonstiles.com` at GitHub Pages.
- **Current mail:** Mailgun, not Google Workspace. MX records are `mxa.mailgun.org` / `mxb.mailgun.org`. There's an existing SPF record (`v=spf1 include:mailgun.org ~all`) and an existing DMARC record reporting to Mailgun and OnDMARC.

Everywhere the original plan says "Google Workspace MX," read "Mailgun MX" instead — same caution applies (don't touch it until the replacement is tested).

## Architecture

```
Sending (outbound)
  Gmail (brandonstiles@gmail.com)
    → "Send mail as brandon@brandonstiles.com" via SMTP relay
    → Amazon SES SMTP endpoint (email-smtp.us-east-1.amazonaws.com:587)
    → recipient sees From: brandon@brandonstiles.com

Receiving (inbound)
  Sender → MX records for brandonstiles.com
    → Squarespace Email Forwarding
    → brandonstiles@gmail.com (free Gmail inbox)
```

No mail server is run anywhere. SES is used purely as an authenticated SMTP relay for outbound mail (not for receiving — SES inbound receipt is not part of this design, and WorkMail is explicitly not used). Inbound relies on Squarespace's built-in domain email forwarding.

## Why SES needs its own subdomain

SES signs outgoing mail using a **custom MAIL FROM domain**: `mail.brandonstiles.com`. This is a new, currently-unused subdomain, so its SPF/MX records are brand new — they don't need to be merged with anything. The existing root-domain SPF record (`include:mailgun.org`, presumably serving something like the site's contact form) is untouched.

DKIM is added directly on `brandonstiles.com` via three CNAME records (Easy DKIM) and does not conflict with anything existing.

DMARC is the one place a shared record gets edited — see `squarespace-dns.md` for the exact before/after diff.

## Documents in this folder

- `aws-ses-setup.md` — what was configured in AWS (already done) and the commands used
- `squarespace-dns.md` — exact DNS records to add/edit by hand in Squarespace, in order, with a clear "safe to do now" vs. "cutover only" split
- `gmail-send-as.md` — configuring Gmail to send as `brandon@brandonstiles.com` via SES
- `testing-checklist.md` — how to verify everything before cancelling Workspace
- `rollback.md` — how to revert to Google Workspace if something goes wrong

## Status as of 2026-07-28

- [x] SES domain identity created for `brandonstiles.com` (`us-east-1`), Easy DKIM enabled
- [x] Custom MAIL FROM domain configured (`mail.brandonstiles.com`)
- [x] Dedicated IAM user `ses-smtp-brandonstiles` created, least-privilege send-only policy attached
- [x] SMTP credentials generated, stored locally outside any git repo at `~/.secrets/ses-brandonstiles/`
- [ ] SES production access requested (still in sandbox — command provided, not yet run)
- [ ] DNS records published in Squarespace
- [ ] DKIM/MAIL FROM verification status = SUCCESS
- [ ] Gmail send-as configured and verified
- [ ] Squarespace email forwarding configured
- [ ] Full send/receive/reply test passed
- [ ] Google Workspace cancelled

Nothing has been made externally visible yet — no DNS changes, no production access request. Everything so far is AWS-account-internal and reversible by deleting the IAM user and SES identity.
