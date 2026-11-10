# frozen_string_literal: true

RSpec.describe "Local onebox" do
  fab!(:user)
  fab!(:target) { Fabricate(:topic_with_op) }
  fab!(:post) do
    url = "#{Discourse.base_url}/t/#{target.slug}/#{target.id}"
    quote = "[quote=\"#{user.username}, post:1, topic:#{target.id}\"]\nuna cita normal\n[/quote]"
    Fabricate(:post, raw: "#{url}\n\nentre medio\n\n#{url}\n\n#{quote}")
  end

  before do
    upload_theme_or_component
    target.update_columns(
      excerpt: "[!tldr] Extracto &amp; <b>resumen</b> del topic",
      image_upload_id: Fabricate(:image_upload).id,
    )
    # Oneboxes are added in post-processing, which fabrication does not run.
    cpp = CookedPostProcessor.new(post, invalidate_oneboxes: true)
    cpp.post_process
    post.update_columns(cooked: cpp.html)
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
