# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe 'issue API views' do
  let(:index_view) { File.read(File.expand_path('../../app/views/issues/index.api.rsb', __dir__)) }
  let(:show_view) { File.read(File.expand_path('../../app/views/issues/show.api.rsb', __dir__)) }

  it 'exposes impact and urgency in index API view' do
    expect(index_view).to include('api.impact_id issue.impact_id')
    expect(index_view).to include('api.urgency_id issue.urgency_id')
  end

  it 'exposes impact and urgency in show API view' do
    expect(show_view).to include('api.impact_id @issue.impact_id')
    expect(show_view).to include('api.urgency_id @issue.urgency_id')
  end
end
