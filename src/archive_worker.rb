# Copyright (c) 2013 MaestroDev.  All rights reserved.
require 'maestro_plugin'
require 'archive/tar/minitar'
require 'zip/zip'
require 'zip/zipfilesystem'
require 'digest/md5'
require 'json'

module MaestroDev
  module Plugin
  
    class ArchiveWorker < Maestro::MaestroWorker
      include Archive::Tar
  
      def archive
        validate_parameters
  
        if @path.is_a?(Array)
          if @type == 'zip'
            write_output("\nCreating '#{@destination}/#{@filename}.zip", :buffer => true)
            dest = make_zip("#{@destination}/#{@filename}.zip",
                            @filename,
                            *@path)
          else
            write_output("\nCreating '#{@destination}/#{@filename}.tar.gz", :buffer => true)
            dest = make_tarball("#{@destination}/#{@filename}.tar.gz",
                                @filename,
                                *@path)
          end
        else
          if @type == 'zip'
            write_output("\nCreating '#{@destination}/#{@filename}.zip", :buffer => true)
            dest = make_zip("#{@destination}/#{@filename}.zip",
                            @filename,
                            @path)
          else
            write_output("\nCreating '#{@destination}/#{@filename}.tar.gz", :buffer => true)
            dest = make_tarball("#{@destination}/#{@filename}.tar.gz",
                                @filename,
                                @path)
          end
        end
  
        md5 = calculate_md5(dest)
        write_output("\nSuccessfully Created Archive\n  name: #{dest}\n  md5:  #{md5}")
          
        save_output_value('archive', dest)
        save_output_value('md5', md5)
    
        set_field('archive', {'archiveFile' => dest, 'archiveMD5' => md5}.to_json)
      end
  
      def on_output(text)
        write_output(text, :buffer => true)
      end
  
      private
  
      def valid_file?(path)
        File.exists?(path)
      end
  
      def valid_directory?(path)
        File.exists?(path) and File.directory?(path)
      end
  
      def booleanify(value)
        res = false
  
        if value
          if value.is_a?(TrueClass) || value.is_a?(FalseClass)
            res = value
          elsif value.is_a?(Fixnum)
            res = value != 0
          elsif value.respond_to?(:to_s)
            value = value.to_s.downcase
  
            res = (value == 't' || value == 'true')
          end
        end
  
        res
      end
  
      def validate_parameters
        errors = []
  
        @path = get_field('path', '')
        @destination = get_field('destination', '')
        @filename = get_field('filename', '')
        @type = get_field('type', 'targz').downcase
  
        begin
          @path = JSON.parse(@path) if @path.is_a? String
        rescue
          # not json
        end
  
        if @path.is_a?(Array)
          @path.each { |p|
            errors << "path[] '#{p}' No such file or directory" unless valid_file?(p)
          }
        else
          errors << "path '#{@path}' No such file or directory" if @path && !valid_file?(@path)
        end
  
        errors << 'path must be a single file/dir or a list of files/dirs' if @path.empty?
        errors << "destination: '#{@destination}' No such directory" unless valid_directory?(@destination)
        errors << 'filename not specified' if @filename.empty?
        errors << "type '@type' not one of zip or targz" unless @type == 'zip' || @type == 'targz'
  
        if !errors.empty?
          raise ConfigError, "Configuration errors: #{errors.join(', ')}"
        end
      end
  
      def make_tarball(destination, filename, *paths)
        begin
          tmpdir = Dir.mktmpdir
          FileUtils.mkdir tmpdir + "/" + filename
          # cp all paths into tmpdir
          paths.each do |file|
            FileUtils.cp_r(file, tmpdir + "/" + filename)
          end
  
          Dir.chdir(tmpdir + "/" + filename)
          # o = IO.popen('ls', 'r') do |p|
          #           p.read
          #         end
          # fa = o.split("\n")
          tgz = Zlib::GzipWriter.new(File.open("#{destination}", 'wb'))
          Minitar.pack(Dir["*"], tgz, true)
  
        rescue
          raise PluginError, "Error Failed to archive in tar.gz Format #{e}, #{e.class}"
        ensure
          Dir.chdir("/")
          FileUtils.rm_rf tmpdir
        end
        return destination
  
      end
  
      def make_zip(destination, filename, *paths)
        begin
          tmpdir = Dir.mktmpdir
          FileUtils.mkdir tmpdir + "/" + filename
          # cp all paths into tmpdir
          paths.each do |file|
            FileUtils.cp_r(file, tmpdir + "/" + filename)
          end
  
          Dir.chdir(tmpdir + "/" + filename)
  
          Zip::ZipFile.open(destination, 'w') do |zipfile|
            Maestro.log.debug "created file #{destination}"
            Dir.glob('./**/**').reject { |f| f == destination}.each do |entry|
              if(zipfile.find_entry(entry).nil?)
                zipfile.add(entry,entry)
              else
                zipfile.replace(entry,entry)
              end
            end
          end
  
        rescue Exception => e
          raise PluginError, "Error Failed to archive in zip Format #{e}, #{e.class}"
        ensure
          Dir.chdir("/")
          FileUtils.rm_rf tmpdir
        end
        return destination
  
      end
  
      def calculate_md5(filename)
        begin
          digest = Digest::MD5.hexdigest(File.read(filename))
          md5File = filename+'.md5'
          File.open(md5File, 'w') { |f| f.write(digest) }
          return md5File
        end
      rescue Exception => e
        raise PluginError, "Error Failed to create md5 #{e} #{e.class}"
      end
    end
  end
end
