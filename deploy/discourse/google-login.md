# Google sign-in

Discourse's built-in Google OAuth authenticator supports this installation.
Configure the client ID/secret in private native site settings; do not commit them
or copy production credentials into contributor development environments.

For a site at `https://svdex.com`, the authorized JavaScript origin is that exact
origin and the callback is `https://svdex.com/auth/google_oauth2/callback`.
For a local test client, use the callback matching the loopback site URL and
Discourse port. Prefer separate local and production credentials, and preserve
ordinary local/email login while validating OAuth.

Request only basic identity, email and profile scopes. The application does not
need Gmail, Drive or Calendar permissions to authenticate members. Keep the
Google branding home/privacy/terms links aligned with the published site.

Test normal members as well as the owner, account-link behavior, cancelled login,
logout/re-login and the current OAuth audience restrictions before onboarding.
A successful owner sign-in alone does not prove access for other Google users.
Google Cloud ownership, app audience, credential rotation and any verification
requirements must be managed in the owner's account; they are not supplied by
this source repository.
