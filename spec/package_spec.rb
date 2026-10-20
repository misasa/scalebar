require 'spec_helper'

RSpec.describe 'gem metadata' do
  subject(:specification) { Gem::Specification.load(File.expand_path('../scalebar.gemspec', __dir__)) }

  it 'declares the verified Ruby floor while admitting both compatibility targets' do
    requirement = specification.required_ruby_version
    expect(requirement.satisfied_by?(Gem::Version.new('2.6.10'))).to be(true)
    expect(requirement.satisfied_by?(Gem::Version.new('4.0.7'))).to be(true)
    expect(requirement.satisfied_by?(Gem::Version.new('2.5.9'))).to be(false)
  end

  it 'identifies the source repository and the existing GPL license' do
    expect(specification.homepage).to eq('https://github.com/misasa/scalebar')
    expect(specification.licenses).to eq(['GPL-3.0-or-later'])
  end

  it 'packages only runtime code and user-facing documentation' do
    expect(specification.files.sort).to eq(%w[
      LICENSE.txt README.md bin/image-scalebar lib/scalebar.rb
      lib/scalebar/scalebar.rb lib/scalebar/version.rb
    ])
  end
end
