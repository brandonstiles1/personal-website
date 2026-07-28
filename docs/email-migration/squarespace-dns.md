# Squarespace DNS checklist

Squarespace has no practical API for DNS record management, so this is a manual checklist. Go to: **Squarespace → Domains → brandonstiles.com → DNS Settings**.

## Do not touch — existing records to leave exactly as-is

| Record | Why |
|---|---|
| `A` records for `brandonstiles.com` → `185.199.108.153` / `.109.153` / `.110.153` / `.111.153` | These point the site at GitHub Pages. Not AWS, not part of this migration. |
| `CNAME` for `www.brandonstiles.com` → `brandonstiles.com` | Same — website routing. |
| `TXT` for `brandonstiles.com` → `v=spf1 include:mailgun.org ~all` | Root domain SPF, presumably covering the site's contact form or another Mailgun use. Not modified by this plan — SES uses its own SPF record on the `mail.brandonstiles.com` subdomain instead. |
| `MX` records → `mxa.mailgun.org` / `mxb.mailgun.org` | Current live inbound mail. Stays until Squarespace forwarding + SES sending are fully tested (see `testing-checklist.md`). Only removed during the deliberate cutover step in `rollback.md`'s companion, the final cutover checklist. |

## Group 1 — safe to add now, no effect on current mail

These are new records on names nothing currently uses (`_domainkey.brandonstiles.com`, `mail.brandonstiles.com`, and the DKIM subdomains). Adding them does not change how mail is currently routed or authenticated — SES simply isn't live yet.

### DKIM (3 CNAME records — also verifies domain ownership)

| Type | Host | Value | TTL |
|---|---|---|---|
| CNAME | `fgy6qsehlypbuzgyvgc6t7xh7taeu2mn._domainkey` | `fgy6qsehlypbuzgyvgc6t7xh7taeu2mn.dkim.amazonses.com` | 3600 (1 hr) |
| CNAME | `fask7j2govncttr3p6rmgi5xcqsqdwy4._domainkey` | `fask7j2govncttr3p6rmgi5xcqsqdwy4.dkim.amazonses.com` | 3600 (1 hr) |
| CNAME | `x4s2wwatc4i2ypn5rjtlmrc723hnfg2v._domainkey` | `x4s2wwatc4i2ypn5rjtlmrc723hnfg2v.dkim.amazonses.com` | 3600 (1 hr) |

Squarespace usually only wants the host portion (without `.brandonstiles.com` — it appends the zone automatically). If it asks for a fully-qualified host, use e.g. `fgy6qsehlypbuzgyvgc6t7xh7taeu2mn._domainkey.brandonstiles.com`.

These tokens are specific to this SES identity — don't reuse tokens from any example or another domain. Re-confirm current values with:
```
aws sesv2 get-email-identity --email-identity brandonstiles.com --region us-east-1 --query DkimAttributes.Tokens
```

### Custom MAIL FROM (`mail.brandonstiles.com`)

| Type | Host | Value | Priority | TTL |
|---|---|---|---|---|
| MX | `mail` | `feedback-smtp.us-east-1.amazonses.com` | 10 | 3600 |
| TXT | `mail` | `v=spf1 include:amazonses.com ~all` | — | 3600 |

Purpose: this is the domain SES stamps as the envelope-sender (`Return-Path`) on outgoing mail. The MX record lets SES receive bounce/complaint notifications sent to this subdomain; the TXT record is the SPF policy that authorizes SES to send as `mail.brandonstiles.com`. Because `mail.brandonstiles.com` is a subdomain of `brandonstiles.com`, DMARC's default "relaxed alignment" treats mail sent from it as aligned with the root domain — no root-domain SPF change needed.

## Group 2 — edit an existing record (DMARC)

The current DMARC record already exists at `_dmarc.brandonstiles.com`. Don't add a second TXT record at this name — DNS allows it, but mail clients that only read the first `_dmarc` TXT they find can end up ignoring one of them, which defeats the point. Edit the existing record in place.

**Current value:**
```
v=DMARC1; p=none; pct=100; fo=1; ri=3600; rua=mailto:32a1088@dmarc.mailgun.org,mailto:7a82e45f@inbox.ondmarc.com; ruf=mailto:32a1088@dmarc.mailgun.org,mailto:7a82e45f@inbox.ondmarc.com;
```

**New value** (adds `brandon@brandonstiles.com` to the `rua` aggregate-report recipients; everything else — including Mailgun/OnDMARC's existing monitoring — is preserved):
```
v=DMARC1; p=none; pct=100; fo=1; ri=3600; rua=mailto:32a1088@dmarc.mailgun.org,mailto:7a82e45f@inbox.ondmarc.com,mailto:brandon@brandonstiles.com; ruf=mailto:32a1088@dmarc.mailgun.org,mailto:7a82e45f@inbox.ondmarc.com;
```

| Type | Host | Value | TTL |
|---|---|---|---|
| TXT | `_dmarc` | (new value above) | 3600 |

`p=none` means DMARC is monitor-only right now — nothing gets rejected or quarantined based on it, so this edit carries no delivery risk. It's purely "also send me the aggregate reports."

## Group 3 — cutover only, requires explicit go-ahead

**Do not do this until Gmail send-as, SES sending, and Squarespace forwarding have all been tested per `testing-checklist.md`.**

Replacing the MX records is what actually switches inbound mail from Mailgun to your forwarding setup. In Squarespace, this typically isn't done by hand-entering MX records — the **Email Forwarding** panel (Squarespace → Domains → brandonstiles.com → Email Forwarding) manages the MX records for you when you add a forwarding address. Check that panel first; only fall back to manual MX entry if Squarespace's UI doesn't offer forwarding for this domain.

Either way, this step **removes the Mailgun MX records** in the process. See `rollback.md` for exactly how to restore them if inbound mail breaks after cutover.

## Quick propagation check

```
dig +short brandonstiles.com TXT
dig +short _dmarc.brandonstiles.com TXT
dig +short mail.brandonstiles.com MX
dig +short mail.brandonstiles.com TXT
dig +short fgy6qsehlypbuzgyvgc6t7xh7taeu2mn._domainkey.brandonstiles.com CNAME
```
