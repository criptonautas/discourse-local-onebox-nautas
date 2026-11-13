# frozen_string_literal: true

# README screenshots. Run by the "Screenshots" workflow, which commits the PNGs
# to docs/screenshots/. Skipped in regular CI.
RSpec.describe "Screenshots" do
  fab!(:author) { Fabricate(:user, username: "satoshi") }
  fab!(:target) { Fabricate(:topic_with_op, title: "Running your own Bitcoin node", user: author) }
  fab!(:topic) do
    Fabricate(:topic_with_op, title: "Where to start with self-custody", user: author)
  end

  before do
    skip "set SCREENSHOTS=1 to take screenshots" unless ENV["SCREENSHOTS"]

    upload_theme_or_component
    target.update_columns(
      excerpt: "What a home node needs, what it costs to run and what it verifies for you.",
      image_upload_id: cover.id,
    )
    # Baked by hand: post-processing would resolve the link over HTTP, which specs block.
    topic.first_post.update_columns(cooked: <<~HTML)
      <p>Before buying hardware, read this one:</p>
      <aside class="quote" data-post="1" data-topic="#{target.id}">
        <div class="title">
          <div class="quote-controls"></div>
          <div class="quote-title__text-content"><a href="#{target.relative_url}">#{target.title}</a></div>
        </div>
        <blockquote>Start of the first post</blockquote>
      </aside>
    HTML
  end

  def cover
    file = File.open(File.expand_path("../fixtures/cover.jpg", __dir__))
    UploadCreator.new(file, "cover.jpg").create_for(author.id)
  end

  def save(name)
    path = Rails.root.join("tmp/capybara/screenshots/#{name}.png")
    FileUtils.mkdir_p(path.dirname)
    page.driver.with_playwright_page { |pw| pw.screenshot(path: path.to_s) }
  end

  it "shows the gist or excerpt and the cover" do
    resize_window(width: 1100, height: 700) do
      visit topic.relative_url
      expect(page).to have_css("aside.local-onebox img.local-onebox__cover")
      save("local-onebox")
    end
  end
end
