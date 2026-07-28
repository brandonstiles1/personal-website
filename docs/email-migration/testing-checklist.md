# Testing checklist

Run through this before touching MX records (cutover), and again after cutover before cancelling Google Workspace. Nothing here is destructive — it's all sending/receiving test messages and reading headers.

Run `./verify.sh` (in this folder) at any point for a read-only snapshot of DNS + SES status. It prints no secrets.

## Before cutover (Mailgun MX still live)

1. **SES identity fully verified.** `./verify.sh` → `Verified/DKIM/MailFrom` should all show `true`/`SUCCESS`/`SUCCESS`. If any are `PENDING` after a few hours, double check the DNS records in `squarespace-dns.md` were entered exactly as shown (typos in DKIM tokens are the most common cause).
2. **SES production access approved.** `./verify.sh` → `ProductionAccessEnabled: true`. Until this is true, sends to unverified addresses will bounce — expected, not a bug.
3. **Gmail send-as configured and verified** per `gmail-send-as.md`.
4. **Send a test message from Gmail as `brandon@brandonstiles.com`** to an account you control at another provider (e.g. Outlook, or a second personal Gmail). Confirm:
   - Visible **From** is `brandon@brandonstiles.com`, not your `@gmail.com` address.
   - Open the message's full headers (Outlook: "View message source"; Gmail: "Show original"). Confirm:
     - `SPF: PASS`
     - `DKIM: PASS` (signed by `d=brandonstiles.com`)
     - `DMARC: PASS`
   - Check spam placement — it should land in the inbox, not spam, given `p=none` and passing alignment.
5. **Reply test.** From that external account, reply to the test message. Confirm the reply is addressed to `brandon@brandonstiles.com` (proves the Return-Path/Reply-To chain is correct) — but don't expect it to arrive in Gmail yet, since inbound still goes to Mailgun at this point. This step is just confirming what address external mail clients resolve for replies.

## Cutover (see `rollback.md`'s companion checklist for the exact MX-swap sequence)

6. **Squarespace Email Forwarding configured**, `brandon@brandonstiles.com → brandonstiles@gmail.com`, per the Group 3 section of `squarespace-dns.md`.
7. **Send a fresh test message** (new message, not a reply — avoid caching/threading quirks) from an unrelated external account to `brandon@brandonstiles.com`.
8. **Confirm it arrives in `brandonstiles@gmail.com`**, and check delivery time — should be near-instant once MX has propagated, but allow up to ~30–60 minutes for the first message after a DNS change.
9. **Reply from within Gmail** to that forwarded message. Confirm:
   - "Reply from the same address the message was sent to" kicked in — outgoing reply shows **From: brandon@brandonstiles.com**, not your personal Gmail address.
   - The original external sender receives the reply and it again shows headers `SPF/DKIM/DMARC: PASS`.
10. **Repeat steps 7–9 from at least 2 more providers** (e.g. Gmail-to-Gmail if you have a second account, plus Outlook/Yahoo) — deliverability behavior varies by provider, especially spam placement.
11. **Check spam placement on each.** A `p=none` DMARC policy plus passing SPF/DKIM should be enough for direct sends, but forwarded mail (external sender → Squarespace forwarding → Gmail) is more spam-prone because the forwarding step can break the sending server's own SPF alignment for the *original* sender. This doesn't affect your outbound mail (which goes through SES directly, not through forwarding) — it's specifically a risk for inbound forwarded mail. If test messages land in spam, it's an inbound-forwarding limitation, not something wrong with the SES/SPF/DKIM/DMARC setup.
12. **Test the website's contact form / any automated site email.** This should be entirely unaffected — it doesn't touch MX or the root SPF record — but confirm it still delivers, since this is the one place Mailgun's root-domain SPF record matters and it's easy to accidentally break by fat-fingering the wrong TXT record during this migration.

## Before cancelling Google Workspace

13. **Google Takeout.** Export Gmail, Contacts, and Calendar from the Workspace account at [takeout.google.com](https://takeout.google.com) (only relevant if the Workspace account itself — as opposed to `brandonstiles@gmail.com` — has mail/contacts/calendar history worth keeping).
14. **Re-run steps 7–11** one more time after Workspace's MX involvement (if any remained) is fully gone, to catch any regression introduced by the final DNS state.
15. **Let it run for a validation window** (a few days to a week) before cancelling — catches low-frequency senders (e.g. monthly billing emails) that a short test window would miss.

## DNS inspection commands

```
dig +short brandonstiles.com MX
dig +short brandonstiles.com TXT
dig +short _dmarc.brandonstiles.com TXT
nslookup -type=MX brandonstiles.com
```

## AWS inspection commands

```
aws sesv2 get-email-identity --email-identity brandonstiles.com --region us-east-1
aws sesv2 get-account --region us-east-1
aws ses get-send-statistics --region us-east-1
```

`get-send-statistics` shows recent send/bounce/complaint counts — useful for spotting a bounce spike if something's misconfigured.
