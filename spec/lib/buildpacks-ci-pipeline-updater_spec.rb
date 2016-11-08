# encoding: utf-8
require 'yaml'
require 'json'
require 'spec_helper'
require_relative '../../lib/buildpacks-ci-pipeline-updater'
require_relative '../../lib/buildpacks-ci-pipeline-update-command'

describe BuildpacksCIPipelineUpdater do
  let (:buildpacks_ci_configuration) { BuildpacksCIConfiguration.new }

  before do
    allow(BuildpacksCIConfiguration).to receive(:new).and_return(buildpacks_ci_configuration)
  end

  describe '#parse_args' do

    subject { described_class.new.parse_args(args) }

    context 'with --include specified' do
      let(:args) { %w(--include target_string) }

      it 'sets the include option correctly' do
        expect(subject[:include]).to eq('target_string')
      end
    end

    context 'with --exclude specified' do
      let(:args) { %w(--exclude bad_string) }

      it 'sets the exclude option correctly' do
        expect(subject[:exclude]).to eq('bad_string')
      end
    end

    context 'with --template specified' do
      let(:args) { %w(--template template_name) }
      let(:cmd)  { "" }

      it 'sets the template option correctly' do
        expect(subject[:template]).to eq('template_name')
      end
    end
  end

  describe '#update_standard_pipelines' do
    let(:buildpacks_ci_pipeline_updater) { described_class.new }
    let(:buildpacks_ci_pipeline_update_command) { BuildpacksCIPipelineUpdateCommand.new }
    let(:target_name)                    { 'concourse-target' }
    let(:options)                        { { key: 'value' } }

    subject { buildpacks_ci_pipeline_updater.update_standard_pipelines(target_name: target_name, options: options) }

    before do
      allow_any_instance_of(BuildpacksCIPipelineUpdateCommand).to receive(:run!).with(anything).and_return(true)

      allow(Dir).to receive(:[]).with('pipelines/*.yml').and_return(%w(first.yml))
      allow(BuildpacksCIPipelineUpdateCommand).to receive(:new).and_return(buildpacks_ci_pipeline_update_command)

    end

    it 'prints a header' do
      expect(buildpacks_ci_pipeline_updater).to receive(:header).with('For standard pipelines')

      subject
    end

    it 'looks for yaml files in the pipelines/ directory' do
      expect(Dir).to receive(:[]).with('pipelines/*.yml').and_return([])

      subject
    end

    it 'iterates over pipeline names' do
      allow(Dir).to receive(:[]).with('pipelines/*.yml').and_return(%w(first.yml second.yml))

      expect(buildpacks_ci_pipeline_update_command).to receive(:run!).with(anything).twice

      subject
    end

    it 'calls BuildpacksCIPipelineUpdateCommand#run! with a target name' do
      expect(buildpacks_ci_pipeline_update_command).to receive(:run!).
        with(target_name: target_name,
             name: anything, cmd: anything, options: anything)

      subject
    end

    it 'calls BuildpacksCIPipelineUpdateCommand#run! with a pipeline name' do
      expect(buildpacks_ci_pipeline_update_command).to receive(:run!).
        with(name: 'first',
             target_name: anything, cmd: anything, options: anything)

      subject
    end

    it 'calls BuildpacksCIPipelineUpdateCommand#run! with command line options' do
      expect(buildpacks_ci_pipeline_update_command).to receive(:run!).
        with(options: {key: 'value'},
             target_name: anything, name: anything, cmd: anything)

      subject
    end

    describe 'erb command passed to BuildpacksCIPipelineUpdateCommand#run!' do
      before do
        allow(buildpacks_ci_configuration).to receive(:organization).and_return('buildpacks-github-org')
        allow(buildpacks_ci_configuration).to receive(:run_oracle_php_tests?).and_return(false)
      end

      it 'includes `erb`' do
        expect(buildpacks_ci_pipeline_update_command).to receive(:run!).
          with(cmd: /^erb/,
               target_name: anything, name: anything, options: anything)

        subject
      end

      it 'sets an organization variable' do
        expect(buildpacks_ci_pipeline_update_command).to receive(:run!).
          with(cmd: /organization=buildpacks-github-org/,
               target_name: anything, name: anything, options: anything)

        subject
      end

      it 'sets a run_oracle_php_tests variable' do
        expect(buildpacks_ci_pipeline_update_command).to receive(:run!).
          with(cmd: /run_oracle_php_tests=false/,
               target_name: anything, name: anything, options: anything)

        subject
      end

      it 'passes in a pipeline filename' do
        expect(buildpacks_ci_pipeline_update_command).to receive(:run!).
          with(cmd: /first\.yml/,
               target_name: anything, name: anything, options: anything)

        subject
      end
    end

    describe 'asking BuildpackCIConfiguration for metadata' do
      it 'asks BuildpackCIConfiguration for the organization' do
        expect(buildpacks_ci_configuration).to receive(:organization)

        subject
      end

      it 'asks BuildpackCIConfiguration whether PHP oracle tests should be run' do
        expect(buildpacks_ci_configuration).to receive(:run_oracle_php_tests?)

        subject
      end
    end
  end
  
  describe '#update_bosh_lite_pipelines' do
    let(:target_name)                    { 'concourse-target' }
    let(:options)                        { { key: 'value' } }
    let(:buildpacks_ci_pipeline_updater) { described_class.new }
    let(:buildpacks_ci_pipeline_update_command) { BuildpacksCIPipelineUpdateCommand.new }

    subject { buildpacks_ci_pipeline_updater.update_bosh_lite_pipelines(target_name, options) }

    before do
      allow(buildpacks_ci_configuration).to receive(:domain_name).and_return('domain.name')
      allow_any_instance_of(BuildpacksCIPipelineUpdateCommand).to receive(:run!).with(anything).and_return(true)

      allow(YAML).to receive(:load_file).with('edge-99.yml').and_return({})
      allow(YAML).to receive(:load_file).with('lts-11.yml').and_return({})

      allow(Dir).to receive(:[]).with('config/bosh-lite/*.yml').and_return(%w(edge-99.yml))
      allow(BuildpacksCIPipelineUpdateCommand).to receive(:new).and_return(buildpacks_ci_pipeline_update_command)
    end

    it 'prints a header' do
      expect(buildpacks_ci_pipeline_updater).to receive(:header).with('For bosh-lite pipelines')

      subject
    end

    it 'looks for yaml files in config/bosh-lite' do
      expect(Dir).to receive(:[]).with('config/bosh-lite/*.yml').and_return([])

      subject
    end

    it 'gets full deployment names from yaml files' do
      expect(YAML).to receive(:load_file).with('edge-99.yml')

      subject
    end

    context 'when user has supplied a template option' do
      before do
        allow(Dir).to receive(:[]).with('config/bosh-lite/*.yml').and_return(%w(edge-99.yml lts-11.yml))
      end

      context 'and the template name is a bosh-lite template' do
        let(:options) { { template: 'lts' } }

        it 'runs when the pipeline name matches the template name' do
          expect(buildpacks_ci_pipeline_update_command).to receive(:run!).with(anything)

          subject
        end
      end

      context 'and the template name is not a bosh-lite template' do
        let(:options) { { template: 'not-a-bosh-lite' } }

        subject { buildpacks_ci_pipeline_updater.update_bosh_lite_pipelines(target_name, options) }

        it 'skips when the pipeline name does not match the template name' do
          expect(buildpacks_ci_pipeline_update_command).not_to receive(:run!)

          subject
        end
      end
    end

    it 'iterates over deployment names' do
      allow(Dir).to receive(:[]).with('config/bosh-lite/*.yml').and_return(%w(edge-99.yml lts-11.yml))

      expect(buildpacks_ci_pipeline_update_command).to receive(:run!).with(anything).twice

      subject
    end

    it 'calls BuildpacksCIPipelineUpdateCommand#run! with target name' do
      expect(buildpacks_ci_pipeline_update_command).to receive(:run!).
        with(target_name: 'concourse-target',
             name: anything, cmd: anything, options: anything, pipeline_variable_filename: anything)

      subject
    end

    it 'calls BuildpacksCIPipelineUpdateCommand#run! with deployment name' do
      expect(buildpacks_ci_pipeline_update_command).to receive(:run!).
        with(name: 'edge-99',
             target_name: anything, cmd: anything, options: anything, pipeline_variable_filename: anything)

      subject
    end

    it 'calls BuildpacksCIPipelineUpdateCommand#run! with pipeline_variable_file' do
      expect(buildpacks_ci_pipeline_update_command).to receive(:run!).
        with(pipeline_variable_filename: 'edge-99.yml',
          name: anything, target_name: anything, cmd: anything, options: anything)

      subject
    end

    it 'calls BuildpacksCIPipelineUpdateCommand#run! with options' do
      expect(buildpacks_ci_pipeline_update_command).to receive(:run!).
        with(options: {key: 'value'},
             name: anything, target_name: anything, cmd: anything, pipeline_variable_filename: anything)

      subject
    end

    describe 'erb command passed to BuildpacksCIPipelineUpdateCommand#run!' do
      before do
        allow(buildpacks_ci_configuration).to receive(:domain_name).and_return('domain.name')
        allow(YAML).to receive(:load_file).with('edge-99.yml').and_return({'deployment-name' => 'full-deployment-name'})
      end

      it 'includes `erb`' do
        expect(buildpacks_ci_pipeline_update_command).to receive(:run!).
          with(cmd: /^erb/,
               target_name: anything, name: anything, options: anything, pipeline_variable_filename: anything)

        subject
      end

      it 'sets a domain_name variable' do
        expect(buildpacks_ci_pipeline_update_command).to receive(:run!).
          with(cmd: /domain_name='domain\.name'/,
               target_name: anything, name: anything, options: anything, pipeline_variable_filename: anything)

        subject
      end

      it 'sets a deployment_name variable' do
        expect(buildpacks_ci_pipeline_update_command).to receive(:run!).
          with(cmd: /deployment_name=edge-99/,
               target_name: anything, name: anything, options: anything, pipeline_variable_filename: anything)

        subject
      end

      it 'sets a full_deployment_name variable' do
        expect(buildpacks_ci_pipeline_update_command).to receive(:run!).
          with(cmd: /full_deployment_name=full-deployment-name/,
               target_name: anything, name: anything, options: anything, pipeline_variable_filename: anything)

        subject
      end

      it 'passes in a pipeline filename based on the CF version' do
        expect(buildpacks_ci_pipeline_update_command).to receive(:run!).
          with(cmd: /pipelines\/templates\/bosh-lite-cf-edge/,
               target_name: anything, name: anything, options: anything, pipeline_variable_filename: anything)

        subject
      end
    end

    describe 'asking BuildpackCIConfiguration for metadata' do
      it 'asks BuildpacksCIConfiguration for domain name' do
        expect(buildpacks_ci_configuration).to receive(:domain_name)

        subject
      end
    end
  end

  describe '#update_buildpack_pipelines' do
    let(:target_name)                    { 'concourse-target' }
    let(:options)                        { { key: 'value' } }
    let(:buildpacks_ci_pipeline_updater) { described_class.new }
    let(:buildpacks_ci_pipeline_update_command) { BuildpacksCIPipelineUpdateCommand.new }

    subject { buildpacks_ci_pipeline_updater.update_buildpack_pipelines(target_name, options) }

    before do
      allow_any_instance_of(BuildpacksCIPipelineUpdateCommand).to receive(:run!).with(anything).and_return(true)

      allow(Dir).to receive(:[]).with('config/buildpack/*.yml').and_return(%w(cobol.yml))
      allow(BuildpacksCIPipelineUpdateCommand).to receive(:new).and_return(buildpacks_ci_pipeline_update_command)
    end

    it 'prints a header' do
      expect(buildpacks_ci_pipeline_updater).to receive(:header).with('For buildpack pipelines')

      subject
    end

    it 'looks for yaml files in config/buildpack/' do
      expect(Dir).to receive(:[]).with('config/buildpack/*.yml').and_return([])

      subject
    end

    context 'when user has supplied a template option' do
      before do
        allow(Dir).to receive(:[]).with('config/buildpack/*.yml').and_return(%w(template-name.yml will-not-match.yml))
      end

      context 'and the template name is a buildpack template' do
        let(:options) { { template: 'template-name' } }

        it 'runs when the pipeline name matches the template name' do
          expect_any_instance_of(BuildpacksCIPipelineUpdateCommand).to receive(:run!).with(anything)

          subject
        end
      end

      context 'and the template name is not a buildpack template' do
        let(:options) { { template: 'not-a-buildpack' } }

        subject { buildpacks_ci_pipeline_updater.update_buildpack_pipelines(target_name, options) }

        it 'skips when the pipeline name does not match the template name' do
          expect_any_instance_of(BuildpacksCIPipelineUpdateCommand).not_to receive(:run!)

          subject
        end
      end
    end

    it 'iterates over buildpack names' do
      allow(Dir).to receive(:[]).with('config/buildpack/*.yml').and_return(%w(intercal.yml cobol.yml))

      expect(buildpacks_ci_pipeline_update_command).to receive(:run!).with(anything).twice

      subject
    end

    it 'calls BuildpacksCIPipelineUpdateCommand#run! with target name' do
      expect(buildpacks_ci_pipeline_update_command).to receive(:run!).
        with(target_name: 'concourse-target',
             name: anything, cmd: anything, options: anything, pipeline_variable_filename: anything)

      subject
    end

    it 'calls BuildpacksCIPipelineUpdateCommand#run! with buildpack name' do
      expect(buildpacks_ci_pipeline_update_command).to receive(:run!).
        with(name: 'cobol-buildpack',
             target_name: anything, cmd: anything, options: anything, pipeline_variable_filename: anything)

      subject
    end

    it 'calls BuildpacksCIPipelineUpdateCommand#run! with pipeline_variable_file' do
      expect(buildpacks_ci_pipeline_update_command).to receive(:run!).
        with(pipeline_variable_filename: 'cobol.yml',
             name: anything, target_name: anything, cmd: anything, options: anything)

      subject
    end

    it 'calls BuildpacksCIPipelineUpdateCommand#run! with options' do
      expect(buildpacks_ci_pipeline_update_command).to receive(:run!).
        with(options: {key: 'value'},
             name: anything, target_name: anything, cmd: anything, pipeline_variable_filename: anything)

      subject
    end

    describe 'erb command passed to BuildpacksCIPipelineUpdateCommand#run!' do
      before do
        allow(buildpacks_ci_configuration).to receive(:organization).and_return('buildpacks-github-org')
      end

      it 'includes `erb`' do
        expect(buildpacks_ci_pipeline_update_command).to receive(:run!).
          with(cmd: /^erb/,
               target_name: anything, name: anything, options: anything, pipeline_variable_filename: anything)

        subject
      end

      it 'sets a language variable' do
        expect(buildpacks_ci_pipeline_update_command).to receive(:run!).
          with(cmd: /language=cobol/,
               target_name: anything, name: anything, options: anything, pipeline_variable_filename: anything)

        subject
      end

      it 'sets an organization variable' do
        expect(buildpacks_ci_pipeline_update_command).to receive(:run!).
          with(cmd: /organization=buildpacks-github-org/,
               target_name: anything, name: anything, options: anything, pipeline_variable_filename: anything)

        subject
      end
    end

    describe 'asking BuildpackCIConfiguration for metadata' do
      it 'asks BuildpackCIConfiguration for the organization' do
        expect(buildpacks_ci_configuration).to receive(:organization)

        subject
      end
    end
  end

  # describe '#get_cf_version_from_deployment_name'
  # describe '#run!'
end