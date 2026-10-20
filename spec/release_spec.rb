require 'spec_helper'
require 'json'
require 'yaml'
require 'digest'

RSpec.describe 'release preflight' do
  let(:script) { File.expand_path('../script/verify_release.rb', __dir__) }

  def git(*args)
    out, err, status = Open3.capture3('git', *args, chdir: @work_dir)
    raise err unless status.success?
    out.strip
  end

  before do
    git('init', '-q', '-b', 'master')
    git('config', 'user.name', 'Release test')
    git('config', 'user.email', 'release-test@example.invalid')
    File.write(File.join(@work_dir, 'scalebar.gemspec'), <<~RUBY)
      Gem::Specification.new do |s|
        s.name = 'scalebar'
        s.version = '1.1.1'
      end
    RUBY
    git('add', '.')
    git('commit', '-qm', 'Fixture')
    @sha = git('rev-parse', 'HEAD')
    git('update-ref', 'refs/remotes/origin/master', @sha)
    git('tag', '-a', 'v1.1.1', '-m', 'Fixture tag')
    @releases = File.join(@work_dir, 'releases.json')
    File.write(@releases, '[[]]')
  end

  def verify(tag = 'v1.1.1', sha = @sha)
    Open3.capture3(RbConfig.ruby, script, tag, sha, @releases, chdir: @work_dir)
  end

  it 'accepts an annotated tag on master with matching version and filename' do
    stdout, stderr, status = verify
    expect(status.success?).to be(true), stderr
    expect(stdout.strip).to eq('scalebar-1.1.1.gem')
  end

  it 'rejects a tag that differs from the gemspec version' do
    _, stderr, status = verify('v1.1.2')
    expect(status.success?).to be(false)
    expect(stderr).to match(/version/i)
  end

  it 'rejects a commit outside master' do
    git('checkout', '-qb', 'topic')
    File.write(File.join(@work_dir, 'extra'), 'topic only')
    git('add', '.')
    git('commit', '-qm', 'Topic')
    @sha = git('rev-parse', 'HEAD')
    git('tag', '-f', 'v1.1.1')
    _, stderr, status = verify
    expect(status.success?).to be(false)
    expect(stderr).to match(/master/)
  end

  it 'rejects a moved tag or mismatched checkout' do
    _, stderr, status = verify('v1.1.1', '0' * 40)
    expect(status.success?).to be(false)
    expect(stderr).to match(/commit/i)
  end

  it 'rejects an old unprefixed tag for the same version' do
    git('tag', '1.1.1')
    _, stderr, status = verify
    expect(status.success?).to be(false)
    expect(stderr).to match(/tag.*exists/i)
  end

  it 'rejects published or draft releases for the same version on any page' do
    [true, false].each do |draft|
      File.write(@releases, JSON.generate([[], [{'tag_name' => 'v1.1.1', 'draft' => draft, 'assets' => []}]]))
      _, stderr, status = verify
      expect(status.success?).to be(false)
      expect(stderr).to match(/Release.*exists/i)
    end
  end

  it 'rejects the same gem asset attached to a differently named release' do
    File.write(@releases, JSON.generate([[{
      'tag_name' => 'legacy', 'assets' => [{'name' => 'scalebar-1.1.1.gem'}]
    }]]))
    _, _, status = verify
    expect(status.success?).to be(false)
  end

  it 'fails closed on malformed release API data' do
    File.write(@releases, '{"message":"API failed"}')
    _, _, status = verify
    expect(status.success?).to be(false)
  end

  context 'upload and publish step' do
    before do
      root = File.expand_path('..', __dir__)
      @workflow = YAML.load_file(File.join(root, '.github/workflows/ruby.yml'))
      @publish_step = @workflow.fetch('jobs').fetch('release').fetch('steps').last.fetch('run')
      FileUtils.mkdir_p(%w[script pkg tools runner uploaded].map { |name| File.join(@work_dir, name) })
      FileUtils.cp(script, File.join(@work_dir, 'script'))
      @gemfile = 'scalebar-1.1.1.gem'
      File.write(File.join(@work_dir, 'pkg', @gemfile), 'verified archive')
      digest = Digest::SHA256.hexdigest('verified archive')
      File.write(File.join(@work_dir, 'pkg', "#{@gemfile}.sha256"), "#{digest}  #{@gemfile}\n")
      File.symlink(RbConfig.ruby, File.join(@work_dir, 'tools/ruby'))
      File.write(File.join(@work_dir, 'tools/gh'), <<~'SH')
        #!/bin/bash
        set -eu
        if [ "$1" = api ]; then
          [ "${FAIL_API:-0}" = 0 ] || exit 1
          cat "$FIXTURE_DIR/releases.json"
          exit
        fi
        [ "$1" = release ]
        case "$2" in
          create)
            touch "$FIXTURE_DIR/created"
            [ "${FAIL_UPLOAD:-0}" = 0 ] || exit 1
            cp "$4" "$5" "$FIXTURE_DIR/uploaded/" ;;
          download)
            cp "$FIXTURE_DIR/uploaded/"* "$5/"
            if [ "${CORRUPT_UPLOAD:-0}" = 1 ]; then
              printf corrupt > "$5/$GEM_FILENAME"
            fi ;;
          edit)
            touch "$FIXTURE_DIR/published" ;;
          *) exit 95 ;;
        esac
      SH
      File.write(File.join(@work_dir, 'tools/sha256sum'), "#!/bin/sh\nexec shasum -a 256 \"$@\"\n")
      FileUtils.chmod(0755, %w[gh sha256sum].map { |name| File.join(@work_dir, 'tools', name) })
    end

    def publish(env = {})
      Open3.capture3({
        'PATH' => "#{@work_dir}/tools:#{ENV.fetch('PATH')}",
        'FIXTURE_DIR' => @work_dir, 'RUNNER_TEMP' => "#{@work_dir}/runner",
        'GITHUB_STEP_SUMMARY' => "#{@work_dir}/summary", 'GH_REPO' => 'misasa/scalebar',
        'RELEASE_TAG' => 'v1.1.1', 'GITHUB_SHA' => @sha, 'GEM_FILENAME' => @gemfile,
        'TMPDIR' => "#{@work_dir}/runner"
      }.merge(env), '/bin/bash', '-c', @publish_step, chdir: @work_dir)
    end

    it 'publishes after downloaded assets match the verified local bytes' do
      _, stderr, status = publish
      expect(status.success?).to be(true), stderr
      expect(File.exist?(File.join(@work_dir, 'published'))).to be(true)
    end

    %w[FAIL_API FAIL_UPLOAD CORRUPT_UPLOAD].each do |failure|
      it "does not publish on #{failure}" do
        _, _, status = publish(failure => '1')
        expect(status.success?).to be(false)
        expect(File.exist?(File.join(@work_dir, 'published'))).to be(false)
        if failure == 'FAIL_API'
          expect(File.exist?(File.join(@work_dir, 'created'))).to be(false)
        end
      end
    end

    it 'never modifies an existing release' do
      File.write(@releases, '[[{"tag_name":"v1.1.1","assets":[]}]]')
      _, _, status = publish
      expect(status.success?).to be(false)
      expect(File.exist?(File.join(@work_dir, 'created'))).to be(false)
      expect(File.exist?(File.join(@work_dir, 'published'))).to be(false)
    end
  end
end
