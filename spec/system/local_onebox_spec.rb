# frozen_string_literal: true

RSpec.describe "Local onebox" do
  fab!(:user)
  fab!(:target, :topic_with_op)
  fab!(:post)

  # Baked by hand, like core's localized_internal_oneboxes_spec: post-processing
  # would resolve the link over HTTP, which specs block.
  def onebox
    <<~HTML
      <aside class="quote" data-post="1" data-topic="#{target.id}">
        <div class="title">
          <div class="quote-controls"></div>
          <div class="quote-title__text-content"><a href="#{target.relative_url}">#{target.title}</a></div>
        </div>
        <blockquote>Comienzo del primer post</blockquote>
      </aside>
    HTML
  end

  before do
    upload_theme_or_component
    target.update_columns(
      excerpt: "[!tldr] Extracto &amp; <b>resumen</b> del topic",
      image_upload_id: Fabricate(:image_upload).id,
    )
    post.update_columns(cooked: <<~HTML)
      #{onebox}
      <p>entre medio</p>
      #{onebox}
      <aside class="quote" data-username="#{user.username}" data-post="1" data-topic="#{target.id}">
        <div class="title"><div class="quote-controls"></div>#{user.username}:</div>
        <blockquote><p>una cita normal</p></blockquote>
      </aside>
    HTML
  end

  it "swaps text and adds the cover with a single request" do
    visit post.url

    expect(page).to have_css("aside.local-onebox", count: 2)
    expect(page).to have_css(
      "aside.local-onebox blockquote",
      exact_text: "Extracto & resumen del topic",
      count: 2,
    )
    expect(page).to have_css("aside.local-onebox img.local-onebox__cover", count: 2)
    expect(page).to have_no_css("aside.local-onebox .quote-toggle", visible: :visible)

    expect(page).to have_css("aside.quote[data-username] blockquote", text: "una cita normal")
    expect(page).to have_no_css("aside.quote[data-username].local-onebox")

    requests =
      page.evaluate_script(
        "performance.getEntriesByType('resource').filter((e) => e.name.includes('/latest.json?topic_ids')).length",
      )
    expect(requests).to eq(1)
  end
end
