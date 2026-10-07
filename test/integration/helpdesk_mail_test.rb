# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

# A real helpdesk mail through RedmineUP's helpdesk, when it is installed
# (the GEOxyz installation). Skipped where it is not.
class ItilHelpdeskMailTest < ActiveSupport::TestCase
  include RedmineItilPriority::TestHelper
  fixtures(*FIXTURES)

  def setup
    skip 'RedmineUP helpdesk not installed' unless Redmine::Plugin.installed?(:redmine_contacts_helpdesk)
    @project = Project.find(2) # private
    itil_setup(@project)
    @project.enable_module!(:contacts)
    @project.enable_module!(:contacts_helpdesk)
    ContactsSetting['helpdesk_issue_priority', @project.id] = '7'
  end

  def test_mail_ticket_keeps_the_helpdesk_priority_when_anonymous_may_override
    Role.anonymous.add_permission!(:override_itil_priority)
    assert_equal 'Urgent', receive_helpdesk_mail.priority.name
  end

  def test_mail_ticket_gets_the_default_priority_otherwise
    Role.anonymous.remove_permission!(:override_itil_priority)
    assert_equal IssuePriority.default, receive_helpdesk_mail.priority
  end

  private

  def receive_helpdesk_mail
    User.current = nil
    subject = "Helpdesk #{SecureRandom.hex(4)}"
    raw = "From: customer.#{SecureRandom.hex(3)}@example.org\r\nTo: support@example.net\r\nSubject: #{subject}\r\n" \
          "Message-ID: <#{SecureRandom.hex(8)}@example.org>\r\nDate: #{Time.now.rfc2822}\r\n" \
          "Content-Type: text/plain; charset=utf-8\r\n\r\nHelp please.\r\n"
    options = HelpdeskMailSupport.issue_options({ issue: { project: @project.identifier } }, @project.id)
    assert HelpdeskMailer.receive(raw, options), 'mail received'
    Issue.find_by!(subject: subject)
  end
end
