# Local onebox — agent guide

Rules for anyone changing this repo, people and AI agents alike. Org-wide
conventions (README, licenses, commits) are in the [contributing guide](https://github.com/criptonautas/.github/blob/main/CONTRIBUTING.md).

## Checks

```bash
pnpm install && pnpm lint
discourse_theme rspec .
```

CI runs both. Screenshots in `docs/screenshots/` come from
`spec/system/screenshots_spec.rb` via Actions → Screenshots.

## Things that are easy to get wrong

- One request per render, for every onebox on the page: `/latest.json?topic_ids=…`.
  Never one request per onebox, and never `/t/:id.json` (it carries the whole post stream).
- The gist is LLM output and the excerpt is HTML: both go in through `textContent`.
- Only oneboxes to a whole topic (`data-post="1"`, no `data-username`). Quotes and
  oneboxes to a single reply are left alone.
- `ai_topic_gist` is only in the payload for viewers allowed by Discourse AI's gist
  settings. Without it the list excerpt is used; that is not a bug here.
- On failure the onebox stays as core rendered it. No error, nothing hidden.
