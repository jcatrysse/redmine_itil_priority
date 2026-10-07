# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

# Production eager-loads with Zeitwerk, the test environment does not: a file
# under lib/ whose constant does not match its name only fails in production
# (it did, for patches/helpdesk_patch.rb).
class ItilEagerLoadTest < ActiveSupport::TestCase
  def test_the_application_eager_loads
    assert_nothing_raised { Zeitwerk::Loader.eager_load_all }
  end
end
