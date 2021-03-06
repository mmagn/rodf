# Copyright (c) 2008 Thiago Arrais
#
# This file is part of rODF.
#
# rODF is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as
# published by the Free Software Foundation, either version 3 of
# the License, or (at your option) any later version.

# rODF is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.

# You should have received a copy of the GNU Lesser General Public License
# along with rODF.  If not, see <http://www.gnu.org/licenses/>.

require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'date'

require 'rodf/cell'

describe RODF::Cell do
  it "should hold text content in a paragraph tag" do
    output = RODF::Cell.new('Test').xml
    output.should have_tag('//table:table-cell/*')
    output.should have_tag('//text:p')
    Hpricot(output).at('text:p').innerHTML.should == 'Test'
  end

  it "should allow value types to be specified" do
    output = RODF::Cell.new(34.2, type: :float).xml
    Hpricot(output).at('table:table-cell')['office:value-type'].should=='float'
  end

  it "should place strings in a paragraph tag and floats in value attribute" do
    output = RODF::Cell.new('Test').xml
    output.should have_tag('//text:p')
    Hpricot(output).at('text:p').innerHTML.should == 'Test'

    output = RODF::Cell.new(47, type: :float).xml
    output.should_not have_tag('//table:table-cell/*')
    Hpricot(output).at('table:table-cell')['office:value'].should == '47'

    output = RODF::Cell.new(34.2, type: :string).xml
    output.should have_tag('//text:p')
    Hpricot(output).at('text:p').innerHTML.should == '34.2'
  end

  it "should accept formulas" do
    output = RODF::Cell.new(type: :float,
                           formula: "oooc:=SUM([.A1:.A4])").xml

    elem = Hpricot(output).at('table:table-cell')
    elem['office:value-type'].should == 'float'
    elem['table:formula'].should == 'oooc:=SUM([.A1:.A4])'
  end

  it "should accept matrix formulas" do
    output = RODF::Cell.new(type: :float, matrix_formula: true,
                           formula: "oooc:=SUM([.A1:.A4])").xml

    elem = Hpricot(output).at('table:table-cell')
    elem['table:number-matrix-columns-spanned'].should == '1'
    elem['table:number-matrix-rows-spanned'].should == '1'
  end

  it "should not make a matrix formula when asked not too" do
    output = RODF::Cell.new(type: :float, matrix_formula: false,
                           formula: "oooc:=SUM([.A1:.A4])").xml

    elem = Hpricot(output).at('table:table-cell')
    elem['table:number-matrix-columns-spanned'].should be_nil
    elem['table:number-matrix-rows-spanned'].should be_nil
  end

  it "should not have an empty paragraph" do
    [RODF::Cell.new, RODF::Cell.new(''), RODF::Cell.new('  ')].each do |cell|
      cell.xml.should_not have_tag('text:p')
    end
  end

  it "should allow an style to be specified in the constructor" do
    cell = RODF::Cell.new 45.8, type: :float, style: 'left-column-cell'
    Hpricot(cell.xml).at('table:table-cell')['table:style-name'].
      should == 'left-column-cell'
  end

  it "should allow and style to be specified through a method call" do
    cell = RODF::Cell.new 45.8, type: :float
    cell.style = 'left-column-cell'
    Hpricot(cell.xml).at('table:table-cell')['table:style-name'].
      should == 'left-column-cell'
  end

  it "should span multiple cells when asked to" do
    cell = RODF::Cell.new 'Spreadsheet title', span: 4
    doc = Hpricot(cell.xml)
    doc.at('table:table-cell')['table:number-columns-spanned'].should == '4'
    doc.search('table:table-cell').size.should == 4
  end

  it "should have the URL set correctly when requested on a string" do
    cell = RODF::Cell.new 'Example Link', url: 'http://www.example.org'
    doc = Hpricot(cell.xml)
    doc.at('text:a')['xlink:href'].should == 'http://www.example.org'
  end

  it "should ignore the URL requested on anything other than a string" do
    cell = RODF::Cell.new(47.1, type: :float, url: 'http://www.example.org')
    cell.xml.should_not have_tag('text:p')
    cell.xml.should_not have_tag('text:a')

    cell = RODF::Cell.new(Date.parse('15 Apr 2010'), type: :date, url: 'http://www.example.org')
    cell.xml.should_not have_tag('text:p')
    cell.xml.should_not have_tag('text:a')
  end

  it "should have the date set correctly" do
    cell = Hpricot(RODF::Cell.new(Date.parse('15 Apr 2010'), type: :date).xml).
      at('table:table-cell')
    cell['office:value-type'].should == 'date'
    cell['office:date-value'].should == '2010-04-15'
    cell['office:value'].should be_nil
  end

  it "should also accept strings as date values" do
    Hpricot(RODF::Cell.new(Date.parse('16 Apr 2010'), type: :date).xml).
      at('table:table-cell')['office:date-value'] = '2010-04-16'
  end

  it "should contain paragraph" do
    c = RODF::Cell.new
    c.paragraph "testing"
    output = c.xml

    output.should have_tag("//table:table-cell/*", count: 1)
    output.should have_tag("//text:p")

    Hpricot(output).at('text:p').innerHTML.should == 'testing'
  end

  it "should be able to hold multiple paragraphs" do
    output = RODF::Cell.create do |c|
      c.paragraph "first"
      c.paragraph "second"
    end

    output.should have_tag("//table:table-cell/*", count: 2)
    output.should have_tag("//text:p")

    ps = Hpricot(output).search('text:p')
    ps[0].innerHTML.should == 'first'
    ps[1].innerHTML.should == 'second'
  end

  it "should not render value type for non-string nil values" do
    Hpricot(RODF::Cell.new(nil, type: :string).xml).
      at('table:table-cell').innerHTML.should == ''

    [:float, :date].each do |t|
      cell = Hpricot(RODF::Cell.new(nil, type: t).xml).at('table:table-cell')
      cell.innerHTML.should == ''
      cell['office:value'].should be_nil
      cell['office:date-value'].should be_nil
      cell['office:value-type'].should be_nil
    end
  end

  it "should accept parameterless blocks" do
    output = RODF::Cell.create do
      paragraph "first"
      paragraph "second"
    end

    output.should have_tag("//table:table-cell/*", count: 2)
    output.should have_tag("//text:p")

    ps = Hpricot(output).search('text:p')
    ps[0].innerHTML.should == 'first'
    ps[1].innerHTML.should == 'second'
  end
end
