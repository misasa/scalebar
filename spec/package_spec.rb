require 'spec_helper'

RSpec.describe 'gem metadata' do
  subject(:specification) { Gem::Specification.load(File.expand_path('../scalebar.gemspec', __dir__)) }

  {
    '2.5.9' => false,
    '2.6.0' => true,
    '2.6.1' => true,
    '2.6.6' => true,
    '2.6.10' => true,
    '4.0.7' => true
  }.each do |version, allowed|
    it "#{allowed ? 'allows' : 'excludes'} installation on Ruby #{version}" do
      requirement = specification.required_ruby_version
      expect(requirement.satisfied_by?(Gem::Version.new(version))).to be(allowed)
    end
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
