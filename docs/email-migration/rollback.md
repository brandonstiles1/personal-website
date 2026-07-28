# Final cutover checklist and rollback

## Final cutover checklist (in order)

1. **Back up current mail.** If there's anything in the Google Workspace mailbox worth keeping, run Google Takeout first (`testing-checklist.md` step 13). This is the one step that's awkward to redo later.
2. **Verify SES.** `./verify.sh` shows `Verified/DKIM/MailFrom` all green. Don't proceed until this is true.
3. **Confirm DKIM/SPF/DMARC records are live** — Group 1 and Group 2 in `squarespace-dns.md` are published and have propagated (`./verify.sh` output matches expected values).
4. **Configure Gmail Send mail as** per `gmail-send-as.md`, verified.
5. **Configure Squarespace Email Forwarding** (`brandon@brandonstiles.com → brandonstiles@gmail.com`) — this is the step that changes the MX records (Group 3 in `squarespace-dns.md`).
6. **Replace the MX records** — this happens automatically when step 5's forwarding is enabled through Squarespace's panel. Note the exact timestamp you do this; you'll want it if you need to check propagation timing later.
7. **Test incoming and outgoing mail** — full run of `testing-checklist.md` steps 7–12.
8. **Keep Google Workspace active** for a validation window (a few days to a week — `testing-checklist.md` step 15) even though its MX is no longer live. This costs nothing extra beyond the subscription itself and gives you a fallback inbox to check against if anything about the new setup looks wrong.
9. **Cancel Google Workspace** only after every test in `testing-checklist.md` has passed and the validation window has elapsed with no issues.

## Rollback: restoring Mailgun MX if inbound mail breaks

If, after step 6, mail to `brandon@brandonstiles.com` stops arriving anywhere (not in Gmail via forwarding, and no longer reachable via whatever previously used Mailgun), restore the previous MX records:

1. In Squarespace DNS settings, either disable the Email Forwarding feature (if that's what changed the MX records) or manually re-add:

   | Type | Host | Value | Priority | TTL |
   |---|---|---|---|---|
   | MX | `@` | `mxa.mailgun.org` | 10 | 3600 |
   | MX | `@` | `mxb.mailgun.org` | 10 | 3600 |

2. Confirm restoration: `dig +short brandonstiles.com MX` should show both `mxa.mailgun.org` and `mxb.mailgun.org` again.
3. Allow DNS propagation (minutes to a few hours depending on your resolver's cache and the record's prior TTL).
4. Re-test inbound delivery to whatever received mail via Mailgun before this migration started (confirm what that destination actually was — the sandbox inspection couldn't determine what consumes Mailgun-routed mail today; check Mailgun's dashboard at mailgun.com if unsure).
5. Once inbound is confirmed working again, diagnose the forwarding issue (common causes: Squarespace forwarding not fully propagated yet, a typo in the forwarding destination address, or Gmail's spam filter silently dropping the forwarded test message — check Gmail spam folder before assuming total failure) before attempting cutover again.

## What's safe to roll back at every stage

- **SES identity, DKIM, MAIL FROM (`squarespace-dns.md` Group 1):** deleting these DNS records or the SES identity itself has zero effect on current mail flow — Mailgun keeps working regardless, since nothing about Group 1 touches MX or the root SPF record.
- **DMARC edit (`squarespace-dns.md` Group 2):** reverting to the original `_dmarc` TXT value (drop the added `brandon@brandonstiles.com` from `rua`) has zero effect on mail delivery — DMARC reporting addresses don't affect whether mail is delivered, only who gets copied on aggregate reports.
- **MX replacement (Group 3):** this is the only step with real inbound-mail risk, and it's exactly the step this rollback section covers.
- **Google Workspace cancellation:** irreversible in the sense that you'd need to re-subscribe and reconfigure from scratch — this is why step 9 above says to cancel last, after a validation window, not as part of testing.
