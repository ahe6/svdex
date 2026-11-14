# Third-party notices

## Discourse

SVDEX integrates with [Discourse](https://github.com/discourse/discourse), licensed
under GPL v2 or later. Discourse's own copyright notices and license apply to
upstream code. This repository does not replace or relicense those notices.

`frontend/discourse-interface/javascripts/discourse/templates/svdex-chat.gjs`
adapts Discourse's native Chat template. Its source is
`plugins/chat/assets/javascripts/discourse/templates/chat.gjs` at the reviewed
revision in `deploy/discourse/upstream-contracts.json`; the SVDEX changes insert
Discussions navigation. Other Interface components compose native Discourse
components; the upstream installation retains their notices and assets.

Discourse Docker is obtained separately from its upstream repository at the
revision recorded by `scripts/discourse-local.sh`. Its own license applies.

## Dependencies and archived materials

Container images and other third-party components retain their own licenses.
Docker setup records the images it uses. Discourse obtains its dependencies from
its pinned upstream source; their notices remain part of that installation.

The software license is not a claim of authorship or redistribution permission
for external policies, questionnaires, research or linked documents. Historical
signup captures and the retired standalone application are not included.
