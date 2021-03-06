require "rails_helper"

RSpec.describe LiveContentItem do
  subject { FactoryGirl.build(:live_content_item) }

  def set_new_attributes(item)
    item.title = "New title"
  end

  def verify_new_attributes_set
    expect(described_class.last.title).to eq("New title")
  end

  describe ".renderable_content" do
    let!(:guide) { FactoryGirl.create(:live_content_item, format: "guide", base_path: "/foo") }
    let!(:redirect) { FactoryGirl.create(:redirect_live_content_item, base_path: "/bar") }
    let!(:gone) { FactoryGirl.create(:gone_live_content_item, base_path: "/baz") }

    it "returns content items that do not have a format of 'redirect' or 'gone'" do
      expect(described_class.renderable_content).to eq [guide]
    end
  end

  describe "validations" do
    it "is valid for the default factory" do
      expect(subject).to be_valid
    end

    it "requires a content_id" do
      subject.content_id = nil
      expect(subject).to be_invalid
    end

    it "requires that the content_ids match" do
      subject.content_id = "something else"
      expect(subject).to be_invalid
    end

    it "requires a format" do
      subject.format = ""
      expect(subject).to be_invalid
    end

    it "requires a publishing_app" do
      subject.publishing_app = ""
      expect(subject).to be_invalid
    end

    context "when the content item is 'renderable'" do
      before do
        subject.format = "guide"
      end

      it "requires a title" do
        subject.title = ""
        expect(subject).to be_invalid
      end

      it "requires a rendering_app" do
        subject.rendering_app = ""
        expect(subject).to be_invalid
      end

      it "requires that the rendering_app is a valid DNS hostname" do
        %w(word alpha12numeric dashed-item).each do |value|
          subject.rendering_app = value
          expect(subject).to be_valid
        end

        ['no spaces', 'puncutation!', 'mixedCASE'].each do |value|
          subject.rendering_app = value
          expect(subject).to be_invalid
          expect(subject.errors[:rendering_app].size).to eq(1)
        end
      end

      it "requires a public_updated_at" do
        subject.public_updated_at = nil
        expect(subject).to be_invalid
      end
    end

    context "when the content item is not 'renderable'" do
      subject { FactoryGirl.build(:redirect_live_content_item) }

      it "does not require a title" do
        subject.title = ""
        expect(subject).to be_valid
      end

      it "does not require a rendering_app" do
        subject.rendering_app = ""
        expect(subject).to be_valid
      end

      it "does not require a public_updated_at" do
        subject.public_updated_at = nil
        expect(subject).to be_valid
      end
    end

    context "#base_path" do
      it "should be required" do
        subject.base_path = nil
        expect(subject).not_to be_valid
        expect(subject.errors[:base_path].size).to eq(2)

        subject.base_path = ''
        expect(subject).not_to be_valid
        expect(subject.errors[:base_path].size).to eq(2)
      end

      it "should be an absolute path" do
        subject.base_path = 'invalid//absolute/path/'
        expect(subject).to_not be_valid
        expect(subject.errors[:base_path].size).to eq(1)
      end

      it "should have a db level uniqueness constraint" do
        FactoryGirl.create(:live_content_item, base_path: "/foo")
        subject = FactoryGirl.build(:redirect_live_content_item, base_path: "/foo")

        expect {
          subject.save!
        }.to raise_error(ActiveRecord::RecordNotUnique)
      end
    end

    context 'content_id' do
      it "accepts a UUID" do
        content_id = "a7c48dac-f1c6-45a8-b5c1-5c407d45826f"
        subject.content_id = content_id
        expect(subject).to be_valid
      end

      it "does not accept an arbitrary string" do
        subject.content_id = "bacon"
        expect(subject).not_to be_valid
      end

      it "does not accept an empty string" do
        subject.content_id = ""
        expect(subject).not_to be_valid
      end
    end

    context "locale" do
      it "defaults to the default I18n locale" do
        expect(described_class.new.locale).to eq(I18n.default_locale.to_s)
      end

      it "can be set as a supported I18n locale" do
        subject.locale = 'fr'
        expect(subject).to be_valid
        expect(subject.locale).to eq('fr')
      end

      it "rejects non-supported locales" do
        subject.locale = 'xyz'
        expect(subject).to_not be_valid
        expect(subject.errors[:locale].first).to eq('must be a supported locale')
      end
    end

    context 'phase' do
      it 'defaults to live' do
        expect(described_class.new.phase).to eq('live')
      end

      %w(alpha beta live).each do |phase|
        it "is valid with #{phase} phase" do
          subject.phase = phase
          expect(subject).to be_valid
        end
      end

      it 'is invalid without a phase' do
        subject.phase = nil
        expect(subject).not_to be_valid
        expect(subject.errors[:phase].size).to eq(1)
      end

      it 'is invalid with any other phase' do
        subject.phase = 'not-a-correct-phase'
        expect(subject).to_not be_valid
      end
    end
  end

  context "replaceable" do
    let!(:existing) { FactoryGirl.create(:live_content_item) }

    let(:draft) { existing.draft_content_item }
    let(:content_id) { existing.content_id }
    let(:payload) do
      FactoryGirl.build(:live_content_item)
      .as_json
      .symbolize_keys
      .merge(
        content_id: content_id,
        title: "New title",
        draft_content_item: draft
      )
    end

    let(:another_draft) do
      FactoryGirl.create(
        :draft_content_item,
        base_path: "/another_base_path",
        routes: [{ path: "/another_base_path", type: "exact" }],
      )
    end

    let(:another_content_id) { another_draft.content_id }
    let(:another_payload) do
      FactoryGirl.build(:live_content_item)
      .as_json
      .symbolize_keys
      .merge(
        content_id: another_content_id,
        title: "New title",
        base_path: another_draft.base_path,
        routes: another_draft.routes,
        draft_content_item: another_draft
      )
    end

    it_behaves_like Replaceable
  end

  it_behaves_like DefaultAttributes
  it_behaves_like ImmutableBasePath
  it_behaves_like RoutesAndRedirectsValidator
end
