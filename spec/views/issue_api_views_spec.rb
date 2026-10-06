# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe 'issue API views' do
  let(:index_view) { File.read(File.expand_path('../../app/views/issues/index.api.rsb', __dir__)) }
  let(:show_view) { File.read(File.expand_path('../../app/views/issues/show.api.rsb', __dir__)) }

  it 'exposes impact and urgency in index API view' do
    expect(index_view).to include('api.impact_id issue.impact_id')
    expect(index_view).to include('api.urgency_id issue.urgency_id')
  end

  # The plugin replaces core's templates whole, so they have to stay core's
  # template of the Redmine they run in, plus the ITIL lines. Redmine 6.0 added
  # updated_on and updated_by to the journals, which the copy lacked.
  %w[index show].each do |name|
    it "keeps every line of core's #{name}.api.rsb, in order" do
      core_file = File.expand_path("../../../../app/views/issues/#{name}.api.rsb", __dir__)
      skip 'not inside a Redmine checkout' unless File.exist?(core_file)

      core = File.readlines(core_file).map(&:strip).reject(&:empty?)
      extra = []
      File.readlines(File.expand_path("../../app/views/issues/#{name}.api.rsb", __dir__)).map(&:strip).reject(&:empty?).each do |line|
        core.first == line ? core.shift : extra << line
      end

      expect(core).to eq([])
      # Besides the ITIL lines, only the 6.0 journal fields, which 5.1 leaves out.
      allowed = /\A(api\.(impact|urgency)_id |api\.itil_priority_linked |api\.updated_on journal\.|api\.updated_by\(:id => journal\.|if Redmine::VERSION::MAJOR >= 6\z|end\z)/
      expect(extra.grep_v(allowed)).to eq([])
    end
  end

  it 'exposes whether the priority is linked in both API views' do
    expect(index_view).to include('api.itil_priority_linked issue.itil_priority_active?')
    expect(show_view).to include('api.itil_priority_linked @issue.itil_priority_active?')
  end

  it 'exposes impact and urgency in show API view' do
    expect(show_view).to include('api.impact_id @issue.impact_id')
    expect(show_view).to include('api.urgency_id @issue.urgency_id')
  end
end
