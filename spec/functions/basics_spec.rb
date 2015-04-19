require 'spec_helper'

RSpec.describe 'A Diakonos user can' do

  before do
    @d = $diakonos
    @b = @d.open_file( SAMPLE_FILE )
    cursor_should_be_at 0,0
  end

  after do
    @d.close_buffer  @b, to_all: Diakonos::CHOICE_NO_TO_ALL
  end

  it 'delete the current character' do
    @d.delete
    cursor_should_be_at 0,0
    expect(@b.to_a[ 0 ]).to eq '!/usr/bin/env ruby'
  end

  it 'backspace the previous character' do
    3.times{ @d.cursor_right }
    cursor_should_be_at 0,3
    @d.backspace
    expect(@b.to_a[ 0 ]).to eq '#!usr/bin/env ruby'
    cursor_should_be_at 0,2
  end

  it 'insert a newline character' do
    5.times{ @d.cursor_right }
    @d.carriage_return
    cursor_should_be_at 1,0
    lines = @b.to_a
    expect(lines[ 0..3 ]).to eq [
      '#!/us',
      'r/bin/env ruby',
      '',
      '# This is only a sample file used in the tests.',
    ]
  end

end
