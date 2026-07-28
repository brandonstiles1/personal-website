# Gmail: send mail as brandon@brandonstiles.com

Do this after the DNS records in `squarespace-dns.md` (Groups 1–2) are published and SES identity verification shows `SUCCESS` (see `aws-ses-setup.md`). SES production access should also be approved by this point, or test sends will fail for any recipient not pre-verified in the sandbox.

## Steps

1. In `brandonstiles@gmail.com`, go to **Settings → See all settings → Accounts and Import → Send mail as → Add another email address**.
2. Fill in:
   - **Name:** `Brandon Stiles`
   - **Email address:** `brandon@brandonstiles.com`
   - **Treat as an alias:** leave checked (recommended). This tells Gmail your Gmail inbox and `brandon@brandonstiles.com` are the same identity, which keeps "Reply" defaulting sensibly and keeps this address grouped with your other Gmail identities instead of treated as a fully separate account.
3. Click **Next Step**. Gmail asks for SMTP server details — this is where SES comes in:
   - **SMTP Server:** `email-smtp.us-east-1.amazonaws.com`
   - **Port:** `587`
   - **Username:** the SMTP username from `~/.secrets/ses-brandonstiles/smtp-credentials.txt`
   - **Password:** the SMTP password from the same file
   - **Secured connection:** select **TLS** (this corresponds to STARTTLS on port 587 — Gmail's UI just calls it "TLS")
4. Click **Add Account**. Gmail sends a verification email to `brandon@brandonstiles.com` to prove you control it.
5. That verification email lands wherever inbound mail currently goes — **Mailgun**, until forwarding is cut over (see `squarespace-dns.md` Group 3 and `testing-checklist.md`). If forwarding isn't live yet, you won't see this email in Gmail automatically. Options:
   - Wait until after cutover to do this step, or
   - Retrieve the verification email/link through whatever currently receives `brandon@brandonstiles.com` mail (check where Mailgun is currently routing it), or
   - Gmail also shows the same verification as a clickable link/code directly in the "Send mail as" setup screen after step 4 — you can confirm from there without needing the email at all.
6. Once verified, back in **Accounts and Import → Send mail as**, click **make default** next to `brandon@brandonstiles.com` if you want new outgoing mail (not replies) to use this address by default.
7. Still under **Send mail as**, also check **Settings → General → "When replying to a message"** if present, or confirm on the send-as row itself: enable **"Reply from the same address the message was sent to"**. This makes Gmail auto-pick `brandon@brandonstiles.com` as the From address when you reply to mail that arrived at that address (i.e., forwarded mail), instead of always defaulting to your Gmail address.

## What recipients will see

- **From:** `Brandon Stiles <brandon@brandonstiles.com>`
- **Reply-To / Return-Path:** handled by SES's MAIL FROM domain (`mail.brandonstiles.com`) under the hood — invisible to the recipient in normal mail clients, but this is what makes SPF/DKIM/DMARC pass.

## Known Gmail UI quirks

- Gmail may show a small "via brandonstiles.com" or similar note next to the sender name in some clients if DKIM/SPF don't fully align. This should not happen once DKIM (`aws-ses-setup.md` step 1) is `SUCCESS` and MAIL FROM (`mail.brandonstiles.com`) SPF is correctly aligned — check `testing-checklist.md`'s header inspection step if you see this.
- Gmail limits you to 5 "send mail as" addresses on a free account — not a concern here since you're only adding one.
- If SES sandbox mode is still active, sends to unverified recipients will bounce with an SES-specific error — this is expected until production access is approved, not a Gmail misconfiguration.
