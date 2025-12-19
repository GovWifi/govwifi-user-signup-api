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

### Inactive User Deletion

Any user who has not logged into GovWifi for more than 12 months is considered inactive.

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

For local development you can publish the app port to your host with:

```shell
make servelocal
```

`make servelocal` also sets `TEST_LOCAL=1` inside the container which disables Notify template verification for local testing (so `GET /healthcheck` won't fail because of a dummy NOTIFY_API_KEY). Then access the site at <http://localhost:8080/healthcheck>

### Deploying changes

You can find in depth instructions on using our deploy process [here](https://docs.google.com/document/d/1ORrF2HwrqUu3tPswSlB0Duvbi3YHzvESwOqEY9-w6IQ/) (you must be member of the GovWifi Team to access this document).

## Licence

This codebase is released under [the MIT License][mit].

[mit]: LICENCE
[performance-platform]: https://www.gov.uk/performance/govwifi
[notify]: https://www.notifications.service.gov.uk/
[build-repo]: https://github.com/GovWifi/govwifi-build
