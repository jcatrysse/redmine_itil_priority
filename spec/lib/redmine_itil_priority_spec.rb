# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe RedmineItilPriority do
  # ActiveRecord::Associations::Preloader as Rails 6.1 (Redmine 5.1) has it...
  Rails61Preloader = Class.new do
    def self.calls
      @calls ||= []
    end

    def initialize(associate_by_default: true); end

    def preload(records, associations)
      self.class.calls << [records, associations]
    end
  end

  # ...and as Rails 7.2 and 8.1 (Redmine 6.0 and later) have it.
  Rails7Preloader = Class.new do
    def self.calls
      @calls ||= []
    end

    def initialize(records:, associations:, scope: nil, available_records: [], associate_by_default: true)
      @args = [records, associations]
    end

    def call
      self.class.calls << @args
    end
  end

  before do
    Rails61Preloader.calls.clear
    Rails7Preloader.calls.clear
    Setting.values = {
      'plugin_redmine_itil_priority' => {
        'label_urgency_1' => 'Not urgent',
        'label_urgency_2' => 'Normal',
        'label_urgency_3' => 'Urgent',
        'label_impact_1' => 'Low impact',
        'label_impact_2' => 'Medium impact',
        'label_impact_3' => 'Important impact'
      }
    }
  end

  describe '.urgency_options' do
    it 'returns localized urgency labels' do
      expect(described_class.urgency_options).to eq([
        ['Not urgent', '1'],
        ['Normal', '2'],
        ['Urgent', '3']
      ])
    end
  end

  describe '.impact_options' do
    it 'returns localized impact labels' do
      expect(described_class.impact_options).to eq([
        ['Low impact', '1'],
        ['Medium impact', '2'],
        ['Important impact', '3']
      ])
    end
  end

  context 'with project hierarchy and mixed tracker modes' do
    LibProject = Struct.new(:id, :identifier, :trackers, :children) do
      def module_enabled?(_)
        true
      end

      def self_and_descendants
        FakeRelation.new([self] + children.flat_map(&:self_and_descendants))
      end
    end
    LibTracker = Struct.new(:id)

    let(:tracker1) { LibTracker.new(1) }
    let(:tracker2) { LibTracker.new(2) }

    let(:child) { LibProject.new(2, 'child', FakeRelation.new([tracker1, tracker2]), []) }
    let(:project) { LibProject.new(1, 'root', FakeRelation.new([tracker1, tracker2]), [child]) }

    before do
      Setting.values = {
        'plugin_redmine_itil_priority' => {
          'label_urgency_1' => 'U1',
          'label_urgency_2' => 'U2',
          'label_urgency_3' => 'U3',
          'label_impact_1' => 'G1',
          'label_impact_2' => 'G2',
          'label_impact_3' => 'G3'
        },
        'plugin_redmine_itil_priority_project_1' => {
          'tracker_settings' => {
            '1' => { 'mode' => 'custom', 'label_impact_1' => 'Root-Imp1', 'label_urgency_1' => 'Root-Urg1' },
            '2' => { 'mode' => 'default' }
          }
        },
        'plugin_redmine_itil_priority_project_2' => {
          'tracker_settings' => {
            '1' => { 'mode' => 'custom', 'label_impact_2' => 'Child-Imp2', 'label_urgency_3' => 'Child-Urg3' },
            '2' => { 'mode' => 'inactive' }
          }
        }
      }
    end

    it 'collects labels across project tree for impact options' do
      expect(described_class.impact_options(project)).to eq([
        ['Root-Imp1', '1'],
        ['Child-Imp2', '2'],
        ['G3', '3']
      ])
    end

    it 'collects labels across project tree for urgency options' do
      expect(described_class.urgency_options(project)).to eq([
        ['Root-Urg1', '1'],
        ['U2', '2'],
        ['Child-Urg3', '3']
      ])
    end
  end

  context 'with multiple independent projects' do
    MultiProject = Struct.new(:id, :identifier, :trackers) do
      def module_enabled?(_)
        true
      end
    end
    MultiTracker = Struct.new(:id)

    let(:t1) { MultiTracker.new(1) }
    let(:t2) { MultiTracker.new(2) }
    let(:project1) { MultiProject.new(1, 'p1', FakeRelation.new([t1])) }
    let(:project2) { MultiProject.new(2, 'p2', FakeRelation.new([t2])) }

    before do
      Setting.values = {
        'plugin_redmine_itil_priority' => {
          'label_urgency_1' => 'U1',
          'label_urgency_2' => 'U2',
          'label_urgency_3' => 'U3',
          'label_impact_1' => 'G1',
          'label_impact_2' => 'G2',
          'label_impact_3' => 'G3'
        },
        'plugin_redmine_itil_priority_project_1' => {
          'tracker_settings' => {
            '1' => { 'mode' => 'custom', 'label_impact_2' => 'P1-Imp2', 'label_urgency_1' => 'P1-Urg1' }
          }
        },
        'plugin_redmine_itil_priority_project_2' => {
          'tracker_settings' => {
            '2' => { 'mode' => 'custom', 'label_impact_3' => 'P2-Imp3', 'label_urgency_2' => 'P2-Urg2' }
          }
        }
      }
    end

    # The context menu passes the projects of the selected issues as an array.
    # Rails 7 made the Preloader take keywords, which crashed the menu on
    # Redmine 6.
    { 'Rails 6.1' => Rails61Preloader, 'Rails 7 and later' => Rails7Preloader }.each do |rails, preloader|
      it "preloads the trackers of the projects with the Preloader of #{rails}" do
        stub_const('ActiveRecord::Associations::Preloader', preloader)

        expect(described_class.urgency_options([project1, project2])).to eq([['P1-Urg1', '1'], ['P2-Urg2', '2'], ['U3', '3']])
        expect(preloader.calls).to eq([[[project1, project2], :trackers]])
      end
    end

    it 'merges labels across given projects for impact and urgency' do
      expect(described_class.impact_options([project1, project2])).to eq([
        ['G1', '1'],
        ['P1-Imp2', '2'],
        ['P2-Imp3', '3']
      ])
      expect(described_class.urgency_options([project1, project2])).to eq([
        ['P1-Urg1', '1'],
        ['P2-Urg2', '2'],
        ['U3', '3']
      ])
    end
  end

  context 'with trackers defining different labels for same level' do
    LblProject = Struct.new(:id, :identifier, :trackers) do
      undef_method :each

      def module_enabled?(_)
        true
      end
    end
    LblTracker = Struct.new(:id)

    let(:t1) { LblTracker.new(1) }
    let(:t2) { LblTracker.new(2) }
    let(:project) { LblProject.new(1, 'p', FakeRelation.new([t1, t2])) }

    before do
      Setting.values = {
        'plugin_redmine_itil_priority' => {
          'label_urgency_1' => 'U1',
          'label_urgency_2' => 'U2',
          'label_urgency_3' => 'U3',
          'label_impact_1' => 'I1',
          'label_impact_2' => 'I2',
          'label_impact_3' => 'I3'
        },
        'plugin_redmine_itil_priority_project_1' => {
          'tracker_settings' => {
            '1' => { 'mode' => 'custom', 'label_urgency_1' => 'T1-Urg1', 'label_impact_1' => 'T1-Imp1' },
            '2' => { 'mode' => 'custom', 'label_urgency_1' => 'T2-Urg1', 'label_impact_1' => 'T2-Imp1' }
          }
        }
      }
    end

    it 'lists all unique labels for shared ids' do
      expect(described_class.urgency_options(project)).to eq([
        ['T1-Urg1', '1'],
        ['T2-Urg1', '1'],
        ['U2', '2'],
        ['U3', '3']
      ])
      expect(described_class.impact_options(project)).to eq([
        ['T1-Imp1', '1'],
        ['T2-Imp1', '1'],
        ['I2', '2'],
        ['I3', '3']
      ])
    end
  end


  it 'keeps one help text per level in the filtered settings and drops unknown keys' do
    filtered = described_class.filter_settings('help_impact_1' => 'x', 'help_urgency_3' => 'y',
                                               'help_impact' => 'old', 'help_impact_4' => 'no', 'help_other_1' => 'z')
    expect(filtered).to eq('help_impact_1' => 'x', 'help_urgency_3' => 'y')
  end

  it 'returns the help texts per level, without the empty ones' do
    settings = { 'help_impact_1' => 'one user', 'help_impact_2' => '', 'help_impact_3' => 'everyone', 'help_urgency_1' => 'x' }
    expect(described_class.help_texts(settings, 'impact')).to eq(1 => 'one user', 3 => 'everyone')
    expect(described_class.help_texts(nil, 'impact')).to eq({})
  end
end
