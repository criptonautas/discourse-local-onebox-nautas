import { ajax } from "discourse/lib/ajax";
import { apiInitializer } from "discourse/lib/api";
import discourseDebounce from "discourse/lib/debounce";

// An internal topic onebox. A real quote carries data-username; a onebox to a
// single reply has another data-post and its text is that reply's, so skip both.
const ONEBOX = 'aside.quote[data-topic][data-post="1"]:not([data-username])';
// The topic list's page size: more ids than this would be paginated away.
const PAGE = 30;

// Topic id → list item. null means asked and not returned (or still in flight).
const topics = new Map();
// Oneboxes rendered before their topic arrived.
const waiting = new Set();

function enhance(aside) {
  const topic = topics.get(aside.dataset.topic);
  if (!topic || aside.classList.contains("local-onebox")) {
    return;
  }
  aside.classList.add("local-onebox");

  const quote = aside.querySelector("blockquote");
  if (!quote) {
    return;
  }

  // The gist is plain LLM text. The excerpt is HTML with entities, so it is
  // parsed in an inert document and only its text is kept. Neither is ever
  // inserted as HTML.
  // Callout markers ([!note], [!tldr]-) survive into the excerpt as text.
  const text = (
    topic.ai_topic_gist ||
    new DOMParser().parseFromString(topic.excerpt || "", "text/html").body
      .textContent
  )
    .replace(/\[![^\]\s]+\][+-]?\s*/g, "")
    .trim();
  if (text) {
    quote.textContent = text;
  }

  const thumbnail = (topic.thumbnails || [])
    .filter((t) => t.url && t.width >= 400)
    .sort((a, b) => a.width - b.width)[0];
  const src = thumbnail?.url || topic.image_url;
  if (src) {
    const img = document.createElement("img");
    img.className = "local-onebox__cover";
    img.alt = "";
    img.loading = "lazy";
    if (thumbnail) {
      img.width = thumbnail.width;
      img.height = thumbnail.height;
    }
    img.src = src;
    quote.prepend(img);
  }
}

function settle(ids) {
  for (const aside of waiting) {
    if (ids.includes(aside.dataset.topic)) {
      enhance(aside);
      waiting.delete(aside);
    }
  }
}

function flush() {
  const ids = [...new Set([...waiting].map((aside) => aside.dataset.topic))]
    // Only ids never asked for: the rest are cached or already in flight.
    .filter((id) => !topics.has(id));
  ids.forEach((id) => topics.set(id, null));

  for (let i = 0; i < ids.length; i += PAGE) {
    const chunk = ids.slice(i, i + PAGE);
    ajax("/latest.json", { data: { topic_ids: chunk.join(",") } })
      .then((result) => {
        result.topic_list.topics.forEach((topic) =>
          topics.set(String(topic.id), topic)
        );
      })
      // Forget a failed chunk so a later render retries it; the oneboxes
      // meanwhile stay as core rendered them.
      .catch(() => chunk.forEach((id) => topics.delete(id)))
      .finally(() => settle(chunk));
  }
}

export default apiInitializer((api) => {
  api.decorateCookedElement(
    (element) => {
      element.querySelectorAll(ONEBOX).forEach((aside) => {
        if (topics.get(aside.dataset.topic)) {
          enhance(aside);
        } else {
          waiting.add(aside);
        }
      });
      if (waiting.size) {
        discourseDebounce(flush, 100);
      }
    },
    // Not the composer preview: it would ask on every pasted link.
    { onlyStream: true }
  );
});
