#!/usr/bin/env ruby
#
# File: 	warranty.rb
# Decription: 	Contact's Apple's selfserve servers to capture warranty information
#              	about your product. Accepts arguments of machine serial numbers.
# Edit:		This is a fork @glarizza's script:
# 		https://github.com/huronschools/scripts/blob/master/ruby/warranty.rb
# Edit:   This is a fork of @chilcote's script:
#     https://github.com/chilcote/warranty
#     Adding functions to write details to plists

require 'open-uri'
require 'date'
require "osx/cocoa"
require 'pp'

myfile = 'appwarranty.plist'
my_dict = OSX::NSMutableDictionary.dictionary

def get_warranty(serial)
  hash = {}
  open('https://selfsolve.apple.com/GetWarranty.do?sn=' + serial.upcase + '&country=USA') {|item|
    item.each_line {|item|}
    warranty_array = item.strip.split('"')
    warranty_array.each {|array_item|
      hash[array_item] = warranty_array[warranty_array.index(array_item) + 2] if array_item =~ /[A-Z][A-Z\d]+/
    }
    
    puts "\nSerial Number:\t\t#{hash['SERIAL_ID']}\n"
    puts "Product Description:\t#{hash['PROD_DESCR']}\n"
    puts "Warranty Type:\t\t#{hash['HW_COVERAGE_DESC']}\n"
    puts "Purchase date:\t\t#{hash['PURCHASE_DATE']}"
    # puts (!hash['COV_END_DATE'].empty?) ? "Coverage end:\t\t#{hash['COV_END_DATE'].gsub("-",".")}\n" : "Coverage end:\t\tEXPIRED\n"
    (!hash['COV_END_DATE'].empty?) ? coverage = "#{hash['COV_END_DATE']}\n" : coverage = "EXPIRED"
    str = "#{hash['HW_END_DATE']}"
    puts (!hash['HW_END_DATE']) ? "Coverage end:\t\t#{coverage}\n" : "Coverage end:\t\t#{Date.parse str}\n"

  }
  
# Import the latest list of ASD versions and match the PROD_DESCR with the correct ASD
  asd_hash = {}
  open('https://github.com/chilcote/warranty/raw/master/asdcheck').each do |line|
    asd_arrary = line.split(":")
    asd_hash[asd_arrary[0]] = asd_arrary[1]
  end
  puts "ASD Version:\t\t#{asd_hash[hash['PROD_DESCR']]}\n"
  
  myfile = 'appwarranty.plist'
  my_dict = OSX::NSMutableDictionary.dictionary
  my_dict['Product Decription'] = "#{hash['PROD_DESCR']}"
  my_dict['Purchase date'] = "#{hash['PURCHASE_DATE'].gsub("-",".")}"
  my_dict['Coverage end'] = (!hash['COV_END_DATE'].empty?) ? "#{hash['COV_END_DATE'].gsub("-",".")}" : "EXPIRED"
  my_dict['ASD version'] = "#{asd_hash[hash['PROD_DESCR']].gsub("\n","")}"
  my_dict.writeToFile_atomically(myfile, true)
  pp my_dict

end

if ARGV.size > 0 then
  serial = ARGV.each do |serial|
    get_warranty(serial.upcase)
  end
else
  puts "Without your input, we'll use this machine's serial number."
  serial = %x(system_profiler SPHardwareDataType | awk '/Serial/ {print $4}').upcase.chomp
  get_warranty(serial)
end

