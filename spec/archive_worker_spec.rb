# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
# 
#  http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'zlib'
require 'archive/tar/minitar'
require 'json'

describe MaestroDev::ArchiveWorker do

  before(:all) do
    Maestro::MaestroWorker.mock!

    @destination = "/tmp"
    @filename = "archive_test"
    @dir = Dir.mktmpdir
    Dir.mkdir @dir + "/subdir1"
    File.open(@dir + "/subdir1/file1.txt", 'w') {|f| f.write("hello1") }
    Dir.mkdir @dir + "/subdir2"
    File.open(@dir + "/subdir2/file2.txt", 'w') {|f| f.write("hello2") }
  end

  describe 'archive()' do
    it 'should tar a directory' do
      workitem = {'fields' => {'path' => @dir, 
        'destination' => @destination, 
        'filename' => @filename}
      }

      subject.perform(:archive, workitem)

      workitem['fields']['__error__'].should be_nil
      out = JSON.parse(workitem['fields']['archive'])
      out['archiveFile'].should include("#{@destination}/#{@filename}.tar.gz")
      File.read(out['archiveMD5']).should have(32).characters
    end

    it 'should tar multiple directories' do
      @dir2 = Dir.mktmpdir
      Dir.mkdir @dir2 + "/subdir3"
      File.open(@dir2 + "/subdir3/file3.txt", 'w') {|f| f.write("hello3") }

      da = [@dir + "/subdir1", @dir + "/subdir2", @dir2 + "/subdir3"]

      workitem = {'fields' => {'path' => da, 
        'destination' => @destination, 
        'filename' => 'multiple_dir',
        'type' => 'targz'}}

      subject.perform(:archive, workitem)

      workitem['fields']['__error__'].should be_nil, "ERROR: #{workitem['fields']['__error__']}"
      out = JSON.parse(workitem['fields']['archive'])
      out['archiveFile'].should include("#{@destination}/multiple_dir.tar.gz")
      File.read(out['archiveMD5']).should have(32).characters
    end

    it 'should tar multiple directories and files' do
      @dir2 = Dir.mktmpdir
      Dir.mkdir @dir2 + "/subdir3"
      File.open(@dir2 + "/subdir3/file3.txt", 'w') {|f| f.write("hello3") }
      File.open("/tmp/file4.txt", 'w') {|f| f.write("hello4") }

      da = [@dir, @dir2, "/tmp/file4.txt"]

      workitem = {'fields' => {'path' => da, 
        'destination' => @destination, 
        'filename' => 'multiple_dir_file',
        'type' => 'targz'}
      }

      subject.perform(:archive, workitem)

      workitem['fields']['__error__'].should be_nil, "ERROR: #{workitem['fields']['__error__']}"
      out = JSON.parse(workitem['fields']['archive'])
      out['archiveFile'].should include("multiple_dir_file.tar.gz")
      File.read(out['archiveMD5']).should have(32).characters
    end

    it 'should zip a directory' do
      workitem = {'fields' => {'path' => @dir, 
        'destination' => @destination, 
        'filename' => @filename,
        'type' => 'zip'}
      }

      subject.perform(:archive, workitem)

      workitem['fields']['__error__'].should be_nil
      out = JSON.parse(workitem['fields']['archive'])
      out['archiveFile'].should include("#{@destination}/#{@filename}.zip")
      File.read(out['archiveMD5']).should have(32).characters
    end

    it 'should zip multiple directories' do
      @dir2 = Dir.mktmpdir
      Dir.mkdir @dir2 + "/subdir3"
      File.open(@dir2 + "/subdir3/file3.txt", 'w') {|f| f.write("hello3") }

      da = [@dir + "/subdir1", @dir + "/subdir2", @dir2 + "/subdir3"]

      workitem = {'fields' => {'path' => da, 
        'destination' => @destination, 
        'filename' => @filename,
        'filename' => 'multiple_dir1',
        'type' => 'zip'}
      }

      subject.perform(:archive, workitem)

      workitem['fields']['__error__'].should be_nil, "ERROR: #{workitem['fields']['__error__']}"
      out = JSON.parse(workitem['fields']['archive'])
      out['archiveFile'].should include("#{@destination}/multiple_dir1.zip")
      File.read(out['archiveMD5']).should have(32).characters
    end

    it 'should zip multiple directories and files' do
      @dir2 = Dir.mktmpdir
      Dir.mkdir @dir2 + "/subdir3"
      File.open(@dir2 + "/subdir3/file3.txt", 'w') {|f| f.write("hello3") }
      File.open("/tmp/file4.txt", 'w') {|f| f.write("hello4") }

      da = [@dir, @dir2, "/tmp/file4.txt"]

      workitem = {'fields' => {'path' => da, 
        'destination' => @destination, 
        'filename' => 'multiple_dir_file1',
        'type' => 'zip'}
      }

      subject.perform(:archive, workitem)
        
      workitem['fields']['__error__'].should be_nil, "ERROR: #{workitem['fields']['__error__']}"
      out = JSON.parse(workitem['fields']['archive'])
      out['archiveFile'].should include("multiple_dir_file1.zip")
      File.read(out['archiveMD5']).should have(32).characters
    end

    it 'should report error if path not found' do
      workitem = {'fields' => {'path' => '/not/real'}}

      subject.perform(:archive, workitem)

      workitem['fields']['__error__'].should include("path '/not/real' No such file or directory")
    end

    it 'should report error if destination not found' do
      workitem = {'fields' => {'path' => @dir, 'destination' => '/not/real'}}

      subject.perform(:archive, workitem)

      workitem['fields']['__error__'].should include("No such directory")
    end

    it 'should report error if filename not provided' do
      workitem = {'fields' => {'path' => @dir, 
        'destination' => @destination}
      }
      
      subject.perform(:archive, workitem)

      workitem['fields']['__error__'].should include("filename not specified")
    end

    after(:all) do
      FileUtils.rm_rf @dir
    end
  end
end
