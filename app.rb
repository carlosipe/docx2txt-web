require "cuba"
require "mote"
require "mote/render"
require 'zip'
require 'pathname'
Cuba.plugin(Mote::Render)

class Antiword
  def initialize(filename)
    @filename = filename
  end

  def perl_path
    ENV.fetch('PERL_PATH') { '/usr/bin/perl' }
  end

  def to_s
    docx2txt_path = Pathname(__FILE__).dirname + "bin/docx2txt"
    env         = {}
    args        = [@filename.to_s,'-']
    IO.popen([env, perl_path, docx2txt_path.to_s, *args], 'r') {|p| p.read}
  end
end

class Zipper
  attr_reader :texts
  def initialize(texts)
    @texts = texts
  end

  def sanitize_name(filename)
    @used_names ||=[]
    filename = File.basename(filename, ".*")
    filename.gsub!(/[^0-9A-Za-z.\-]/, '_')
    filename = "#{filename}_" if @used_names.include?(filename)
    @used_names << filename 

    "#{filename}.txt"
  end

  def zip
    stringio = Zip::OutputStream.write_buffer do |zio|
      texts.each do |text|
        zio.put_next_entry ( sanitize_name text.fetch("title") )
        zio.write text.fetch("text")
      end
    end
    stringio.rewind
    
    stringio.sysread
  end
end

Cuba.define do
  on root do
    on get do
      render 'form'
    end

    on post, param('filesToUpload') do |files|
      results = files.map do |file|
        tmpfile = file.fetch(:tempfile){}.path
        filename = file.fetch(:filename) {}
        {title: filename, text: Antiword.new(tmpfile).to_s }
      end

      render 'result', results: results
    end

    on post do
      res.write 'No files'
    end
  end

  on post,'zip', param('texts') do |texts|
    res.headers["Content-Type"] = 'application/octet-stream'
    res.headers["Content-Disposition"] = 'inline; filename="output.zip"'
    res.write Zipper.new(texts.values).zip
  end
end