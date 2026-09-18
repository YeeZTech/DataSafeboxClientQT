# Client critical alerts

`critical-client-rule.json` is the update payload for legacy issue rule **4** in
`sentry/datasafebox-client-qt`. It preserves the existing owner/fallback email
recipients, includes all environments, and limits notifications to new, regressed,
or escalating critical issues. The 60 minute interval is an action throttle, not
a timer that emails every hour. With no environment restriction, first-seen means
the issue is new across the project, not new independently in each environment.

Run the offline checks from the repository root:

```powershell
node --test tools/sentry/critical-client-rule.test.cjs
```

These checks exercise the configured matching policy without creating events or
sending email. They model the specific upstream Sentry [event attributes](https://github.com/getsentry/sentry/blob/master/src/sentry/rules/conditions/event_attribute.py),
[tags](https://github.com/getsentry/sentry/blob/master/src/sentry/rules/conditions/tagged_event.py),
[levels](https://github.com/getsentry/sentry/blob/master/src/sentry/rules/conditions/level.py),
and first-seen/regression/escalation conditions; they do not execute the server's
notification delivery or throttle implementation. `error.unhandled` is derived
from exception mechanisms with `handled: false`; missing mechanisms do not match.
Its comparison value in the API payload is the string `"true"`.

Before applying, save a fresh GET response from
`sentry.cmd api /projects/sentry/datasafebox-client-qt/rules/4/ --json` outside tracked
source (for example `.omc/`). Apply the reviewed payload with:

```powershell
sentry.cmd api /projects/sentry/datasafebox-client-qt/rules/4/ --method PUT --input tools/sentry/critical-client-rule.json
```

Read rule 4 back and compare its editable fields with the payload, allowing the
server's added action `uuid` and display `name` fields. For the unused
`IssueOwners` action's `targetIdentifier` only, treat `null` and `""` as equivalent;
the server normalizes this field to an empty string. To roll back, extract `name`, `environment`,
`actionMatch`, `filterMatch`, `frequency`, `conditions`, `filters`, and `actions`
from the saved GET response and PUT that payload to the same endpoint. Keep the
backup and verified response for the deployment record. This change does not
delete or resolve historical issues or change personal notification settings.
