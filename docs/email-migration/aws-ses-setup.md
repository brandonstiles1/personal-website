# AWS SES setup

Account: `570851832299` · Region: `us-east-1`

## 1. Domain identity + Easy DKIM

```
aws sesv2 create-email-identity --email-identity brandonstiles.com --region us-east-1
```

This creates the identity and enables Easy DKIM by default (`SigningEnabled: true`), generating 3 DKIM tokens. The 3 resulting CNAME records serve double duty: publishing them both proves domain ownership to SES *and* turns on DKIM signing — no separate verification TXT record is needed.

Check status any time with:

```
aws sesv2 get-email-identity --email-identity brandonstiles.com --region us-east-1
```

Look for `"VerificationStatus": "SUCCESS"` and `"DkimAttributes.Status": "SUCCESS"`. Both are `PENDING` until the DNS records in `squarespace-dns.md` are published and propagate (typically minutes to a few hours).

## 2. Custom MAIL FROM domain

```
aws sesv2 put-email-identity-mail-from-attributes \
  --email-identity brandonstiles.com \
  --mail-from-domain mail.brandonstiles.com \
  --behavior-on-mx-failure USE_DEFAULT_VALUE \
  --region us-east-1
```

`USE_DEFAULT_VALUE` means if the MAIL FROM MX record is ever unreachable, SES falls back to sending from `amazonses.com` instead of hard-failing the send — the safer choice for a low-traffic personal domain.

This requires two new DNS records under `mail.brandonstiles.com` (see `squarespace-dns.md`). This subdomain is currently unused, so these are brand-new records with nothing to merge.

## 3. IAM user for SMTP sending

A dedicated, least-privilege IAM user was created — it can only call `ses:SendEmail` / `ses:SendRawEmail`, and only against this one SES identity. It cannot read anything, manage IAM, or touch any other AWS resource.

```
aws iam create-user --user-name ses-smtp-brandonstiles
```

Policy attached (inline, `SesSmtpSendOnly`):

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "SesSmtpSendOnly",
            "Effect": "Allow",
            "Action": [
                "ses:SendRawEmail",
                "ses:SendEmail"
            ],
            "Resource": "arn:aws:ses:us-east-1:570851832299:identity/brandonstiles.com"
        }
    ]
}
```

## 4. SMTP credentials

An IAM access key was created for `ses-smtp-brandonstiles`, and the SES SMTP password was derived from it locally (SES SMTP passwords are not returned by any API — they're a deterministic transform of the IAM secret access key, computed with HMAC-SHA256, per AWS's documented algorithm). Nothing was transmitted anywhere for this step; it ran entirely on your machine.

Credentials are saved at:

```
~/.secrets/ses-brandonstiles/smtp-credentials.txt
~/.secrets/ses-brandonstiles/iam-access-key.json
```

Both files are `chmod 600`, owned by you, and live outside any git repository — there's nothing to gitignore because they were never placed in a repo. Do not copy them into `personal-website` or any other tracked project.

To view them: `cat ~/.secrets/ses-brandonstiles/smtp-credentials.txt`

**SMTP connection details** (same for all recipients of these credentials):
- Host: `email-smtp.us-east-1.amazonaws.com`
- Port: `587` (STARTTLS) — Gmail's "Send mail as" UI expects this
- Username: the `AccessKeyId` value in the credentials file
- Password: the derived SMTP password in the credentials file

## 5. SES sandbox status

The account is **in the SES sandbox** in `us-east-1`:

```
"ProductionAccessEnabled": false,
"SendQuota": { "Max24HourSend": 200.0, "MaxSendRate": 1.0 }
```

In sandbox mode, SES will only deliver to **verified** recipient addresses/domains, capped at 200 messages/24h. That's enough for testing but not for real use — production access must be requested before this is usable as your everyday outgoing mail path.

### Requesting production access

This submits a request to AWS's SES review team and is visible outside your account, so it wasn't run automatically — run it yourself when ready:

```
aws sesv2 put-account-details \
  --mail-type TRANSACTIONAL \
  --website-url https://brandonstiles.com \
  --use-case-description "Personal domain email. Sending low-volume (a handful of messages per day) person-to-person correspondence from brandon@brandonstiles.com, relayed through SES SMTP from a personal Gmail account's Send-mail-as feature. No bulk mail, no marketing, no automated campaigns." \
  --additional-contact-email-addresses brandonstiles@gmail.com \
  --production-access-enabled \
  --region us-east-1
```

Approval is typically automated or same-day for a use case this small and clearly non-bulk. Check status with:

```
aws sesv2 get-account --region us-east-1 --query ProductionAccessEnabled
```

You can request production access at any point in this process — it doesn't require DNS to be live first, but nothing will actually send outside the sandbox until it's approved.

## Verifying identity status from the CLI

```
aws sesv2 get-email-identity --email-identity brandonstiles.com --region us-east-1 \
  --query "{Verified:VerifiedForSendingStatus,DKIM:DkimAttributes.Status,MailFrom:MailFromAttributes.MailFromDomainStatus}"
```

All three should read `true` / `SUCCESS` / `SUCCESS` before moving on to the Gmail and cutover steps.
