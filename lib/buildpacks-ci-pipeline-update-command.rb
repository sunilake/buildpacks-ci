require_relative 'buildpacks-ci-configuration'

class BuildpacksCIPipelineUpdateCommand
  def run!(target_name:, name:, cmd:, pipeline_variable_filename: "", options:)

    buildpacks_configuration = BuildpacksCIConfiguration.new

    pipeline_prefix = ENV['PIPELINE_PREFIX'] || ''

    text_to_include = options[:include]
    text_to_exclude = options[:exclude]
    return if options.has_key?(:include) && !name.include?(text_to_include)
    return if options.has_key?(:exclude) && name.include?(text_to_exclude)

    puts "   #{name} pipeline"

    pipeline_specific_config = ""
    pipeline_specific_config ="--load-vars-from=#{pipeline_variable_filename}" unless pipeline_variable_filename.empty?
    fly_cmd = %{bash -c "fly \
      --target=#{target_name} \
      set-pipeline \
      --pipeline=#{pipeline_prefix}#{name} \
      --config=<(#{cmd}) \
      --load-vars-from=<(lpass show #{buildpacks_configuration.concourse_private_filename} --notes && lpass show #{buildpacks_configuration.deployments_buildpacks_filename} --notes && lpass show #{buildpacks_configuration.repos_private_keys_filename} --notes && lpass show #{buildpacks_configuration.bosh_release_private_keys_filename}) \
      --load-vars-from=public-config.yml \
    #{pipeline_specific_config}
    "}

    system "#{fly_cmd}"
  end
end