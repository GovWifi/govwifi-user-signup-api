# GovWifi User Signup API

This handles incoming sign-up texts and e-mails.

The private GovWifi [build repository][build-repo] contains instructions on how to build GovWifi end-to-end - the sites, services and infrastructure.

## Overview

### Journeys

With each journey, we generate a unique username and password for GovWifi.
These get stored and sent to the user.

- SMS signup - Users text a phone number and get a set of credentials.
- SMS help routes - Users can also ask for help from the same phone number and
  are sent some guides based on their selected operating system.
- Email signup - Users with a government domain email send a blank email to
  signup@wifi.service.gov.uk.
- Sponsor signup - Users with a government domain email address send through a
  list of email addresses and/or phone numbers to sponsor@wifi.service.gov.uk.

### Sinatra routes

- `GET /healthcheck` - AWS ELB target group health checking
- `POST /user-signup/email-notification` - AWS SES incoming email notifications
- `POST /user-signup/sms-notification/notify` - Notify incoming SMS notifications

## Performance Platform

This application used to send statistics to the [Performance Platform][performance-platform] for volumetrics and completion rates via a Rake task. This is no longer the case because the Performance Platform has been archived and the relevant code in this application has been removed. The archived data is still available via the above link.

## GDPR

### Policies

- **Sponsored users username/password reminder:** Not allowed after 90 days from initial registration/usage. Reminders are only available within the first 90 days.
- **Sponsored users/accounts:** Deleted after 90 days of inactivity (see Inactive User Deletion below).

### Inactive User Deletion

Any user who has not logged into GovWifi for more than 12 months is considered inactive.

Sponsored users/accounts are deleted after 90 days of inactivity.

We have a Rake task that runs daily with ECS Scheduled tasks to ensure this happens.

```shell
bundle exec rake delete_inactive_users
```

### Dependencies

- [GOV.UK Notify][notify] - used to send outgoing emails and SMS replies
- MySQL database - used to store generated credentials

## Developing

### Running the tests

```shell
make test
```

### Using the linter

```shell
make lint
```

### Serving the app locally

```shell
make serve
```

Then access the site at <http://localhost:8080/healthcheck>

### Deploying changes

You can find in depth instructions on using our deploy process [here](https://docs.google.com/document/d/1ORrF2HwrqUu3tPswSlB0Duvbi3YHzvESwOqEY9-w6IQ/) (you must be member of the GovWifi Team to access this document).

### Testing in staging

Use staging addresses and integrations when validating changes after deployment.

- Staging sponsor email: `sponsor@staging.wifi.service.gov.uk`
- Production sponsor email: `sponsor@wifi.service.gov.uk`

If the ECS service does not reach steady state after a deploy, check service events and logs for `/healthcheck`. Healthcheck verifies Notify templates and will fail if required templates are missing.

### Staging user journey walkthrough

#### Sponsor journey

1. Send an email from a valid government sponsor account to `sponsor@staging.wifi.service.gov.uk`.
2. Put sponsored email addresses and/or phone numbers in the body, one per line.
3. Confirm each sponsored user receives credentials (email for email contacts, SMS for mobile contacts).
4. Confirm sponsor confirmation email is received.
5. Validate records in staging DB (`userdetails`) using `contact` and `sponsor` values.

#### Email signup and rejection journey

1. Send a blank email to `signup@wifi.service.gov.uk` in the environment under test.
2. Government domain sender:
   - receives credentials using `self_signup_credentials_email`.
3. Non government sender:
   - if no existing user exists, receives `rejected_email_address_email`;
   - if an existing sponsored user exists and is active in the reminder window, receives credentials;
   - if an existing sponsored user exists but is outside the reminder window, receives `sponsor_credentials_expired_notification_email`.

## Licence

This codebase is released under [the MIT License][mit].

[mit]: LICENCE
[performance-platform]: https://www.gov.uk/performance/govwifi
[notify]: https://www.notifications.service.gov.uk/
[build-repo]: https://github.com/GovWifi/govwifi-build
