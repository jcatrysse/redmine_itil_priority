# frozen_string_literal: true

require_relative '../spec_helper'
require 'yaml'

RSpec.describe 'shipped locales' do
  files = Dir[File.expand_path('../../config/locales/*.yml', __dir__)].sort
  keys = files.to_h { |f| [File.basename(f), YAML.load_file(f).values.first.keys.sort] }

  it 'all have the keys of en.yml' do
    keys.each do |file, file_keys|
      expect(file_keys).to eq(keys.fetch('en.yml')), "#{file} differs from en.yml"
    end
  end
end
