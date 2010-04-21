require 'test_helper'
 
class IPv6Test < Test::Unit::TestCase
  
  def setup
    @klass = IPAddress::IPv6
    
    @compress_addr = {      
      "2001:db8:0000:0000:0008:0800:200c:417a" => "2001:db8::8:800:200c:417a",
      "2001:db8:0:0:8:800:200c:417a" => "2001:db8::8:800:200c:417a",
      "ff01:0:0:0:0:0:0:101" => "ff01::101",
      "0:0:0:0:0:0:0:1" => "::1",
      "0:0:0:0:0:0:0:0" => "::"}

    @valid_ipv6 = { # Kindly taken from the python IPy library
      "FEDC:BA98:7654:3210:FEDC:BA98:7654:3210" => 338770000845734292534325025077361652240,
      "1080:0000:0000:0000:0008:0800:200C:417A" => 21932261930451111902915077091070067066,
      "1080:0:0:0:8:800:200C:417A" => 21932261930451111902915077091070067066,
      "1080:0::8:800:200C:417A" => 21932261930451111902915077091070067066,
      "1080::8:800:200C:417A" => 21932261930451111902915077091070067066,
      "FF01:0:0:0:0:0:0:43" => 338958331222012082418099330867817087043,
      "FF01:0:0::0:0:43" => 338958331222012082418099330867817087043,
      "FF01::43" => 338958331222012082418099330867817087043,
      "0:0:0:0:0:0:0:1" => 1,
      "0:0:0::0:0:1" => 1,
      "::1" => 1,
      "0:0:0:0:0:0:0:0" => 0,
      "0:0:0::0:0:0" => 0,
      "::" => 0,
      "1080:0:0:0:8:800:200C:417A" => 21932261930451111902915077091070067066,
      "1080::8:800:200C:417A" => 21932261930451111902915077091070067066}
      
    @invalid_ipv6 = [":1:2:3:4:5:6:7",
                     ":1:2:3:4:5:6:7"]
    
    @ip = @klass.new "2001:db8::8:800:200c:417a/64"
    @network = @klass.new "2001:db8:8:800::/64"
    @arr = [8193,3512,0,0,8,2048,8204,16762]
    @hex = "20010db80000000000080800200c417a"
  end
  
  
  def test_attribute_address
    addr = "2001:0db8:0000:0000:0008:0800:200c:417a"
    assert_equal addr, @ip.address
  end

  def test_initialize
    assert_instance_of @klass, @ip
    @valid_ipv6.keys.each do |ip|
      assert_nothing_raised {@klass.new ip}
    end
    @invalid_ipv6.each do |ip|
      assert_raise(ArgumentError) {@klass.new ip}
    end
    assert_equal 64, @ip.prefix
  end
  
  def test_attribute_groups
    assert_equal @arr, @ip.groups
  end

  def test_method_hexs
    arr = "2001:0db8:0000:0000:0008:0800:200c:417a".split(":")
    assert_equal arr, @ip.hexs
  end
  
  def test_method_to_i
    @valid_ipv6.each do |ip,num|
      assert_equal num, @klass.new(ip).to_i
    end
  end

  def test_method_bits
    bits = "0010000000000001000011011011100000000000000000000" +
      "000000000000000000000000000100000001000000000000010000" + 
      "0000011000100000101111010"
    assert_equal bits, @ip.bits
  end

  def test_method_prefix=()
    ip = @klass.new "2001:db8::8:800:200c:417a"
    assert_equal 128, ip.prefix
    ip.prefix = 64
    assert_equal 64, ip.prefix
    assert_equal "2001:db8::8:800:200c:417a/64", ip.to_s
  end

  def test_method_mapped?
    assert_equal false, @ip.mapped?
  end

  def test_method_literal
    str = "2001-0db8-0000-0000-0008-0800-200c-417a.ipv6-literal.net"
    assert_equal str, @ip.literal
  end

  def test_method_group
    @arr.each_with_index do |val,index|
      assert_equal val, @ip[index]
    end
  end

  def test_method_network?
    assert_equal true, @network.network?
    assert_equal false, @ip.network?
  end

  def test_method_to_hex
    assert_equal @hex, @ip.to_hex
  end
  
  def test_method_to_s
    assert_equal "2001:db8::8:800:200c:417a/64", @ip.to_s
  end

  def test_method_to_string
    str = "2001:0db8:0000:0000:0008:0800:200c:417a/64" 
    assert_equal str, @ip.to_string
  end
  
  def test_method_data
    str = " \001\r\270\000\000\000\000\000\b\b\000 \fAz"
    assert_equal str, @ip.data
  end
  
  def test_method_compressed
    assert_equal "1:1:1::1", @klass.new("1:1:1:0:0:0:0:1").compressed
    assert_equal "1:0:1::1", @klass.new("1:0:1:0:0:0:0:1").compressed
    assert_equal "1:0:0:1::1", @klass.new("1:0:0:1:0:0:0:1").compressed
    assert_equal "1::1:0:0:1", @klass.new("1:0:0:0:1:0:0:1").compressed
    assert_equal "1::1", @klass.new("1:0:0:0:0:0:0:1").compressed
  end
  
  def test_method_unspecified?
    assert_equal true, @klass.new("::").unspecified?
    assert_equal false, @ip.unspecified?    
  end
  
  def test_method_loopback?
    assert_equal true, @klass.new("::1").loopback?
    assert_equal false, @ip.loopback?        
  end
  
  def test_classmethod_expand
    compressed = "2001:db8:0:cd30::"
    expanded = "2001:0db8:0000:cd30:0000:0000:0000:0000"
    assert_equal expanded, @klass.expand(compressed)
    assert_not_equal expanded, @klass.expand("2001:0db8:0:cd3")
    assert_not_equal expanded, @klass.expand("2001:0db8::cd30")
    assert_not_equal expanded, @klass.expand("2001:0db8::cd3")
  end
  
  def test_classmethod_compress
    compressed = "2001:db8:0:cd30::"
    expanded = "2001:0db8:0000:cd30:0000:0000:0000:0000"
    assert_equal compressed, @klass.compress(expanded)
    assert_not_equal compressed, @klass.compress("2001:0db8:0:cd3")
    assert_not_equal compressed, @klass.compress("2001:0db8::cd30")
    assert_not_equal compressed, @klass.compress("2001:0db8::cd3")
  end

#   def test_classmethod_create_unpecified
#     unspec = @klass.create_unspecified
#     assert_equal "::", unspec.address
#     assert_equal 128, unspec.prefix
#     assert_equal true, unspec.unspecified?
#     assert_instance_of @klass, unspec.class
#   end
  
#   def test_classmethod_create_loopback
#     loopb = @klass.create_loopback
#     assert_equal "::1", loopb.address
#     assert_equal 128, loopb.prefix
#     assert_equal true, loopb.loopback?
#     assert_instance_of @klass, loopb.class
#   end

  def test_classmethod_parse_data
    str = " \001\r\270\000\000\000\000\000\b\b\000 \fAz"
    ip = @klass.parse_data str
    assert_instance_of @klass, ip
    assert_equal "2001:0db8:0000:0000:0008:0800:200c:417a", ip.address
    assert_equal "2001:db8::8:800:200c:417a/128", ip.to_s
  end

  def test_classhmethod_parse_u128
    @valid_ipv6.each do |ip,num|
      assert_equal @klass.new(ip).to_s, @klass.parse_u128(num).to_s
    end
  end

  def test_classmethod_parse_hex
    assert_equal @ip.to_s, @klass.parse_hex(@hex,64).to_s
  end

end # class IPv4Test

class IPv6UnspecifiedTest < Test::Unit::TestCase
  
  def setup
    @klass = IPAddress::IPv6::Unspecified
    @ip = @klass.new
    @str = "::/128"
    @string = "0000:0000:0000:0000:0000:0000:0000:0000/128"
    @u128 = 0
    @address = "::"
  end

  def test_initialize
    assert_nothing_raised {@klass.new}
    assert_instance_of @klass, @ip
  end

  def test_attributes
    assert_equal @address, @ip.compressed
    assert_equal 128, @ip.prefix
    assert_equal true, @ip.unspecified?
    assert_equal @str, @ip.to_s
    assert_equal @string, @ip.to_string
    assert_equal @u128, @ip.to_u128
  end
  
end # class IPv6UnspecifiedTest


class IPv6LoopbackTest < Test::Unit::TestCase
  
  def setup
    @klass = IPAddress::IPv6::Loopback
    @ip = @klass.new
    @str = "::1/128"
    @string = "0000:0000:0000:0000:0000:0000:0000:0001/128"
    @u128 = 1
    @address = "::1"
  end

  def test_initialize
    assert_nothing_raised {@klass.new}
    assert_instance_of @klass, @ip
  end

  def test_attributes
    assert_equal @address, @ip.compressed
    assert_equal 128, @ip.prefix
    assert_equal true, @ip.loopback?
    assert_equal @str, @ip.to_s
    assert_equal @string, @ip.to_string
    assert_equal @u128, @ip.to_u128
  end
  
end # class IPv6LoopbackTest

class IPv6MappedTest < Test::Unit::TestCase
  
  def setup
    @klass = IPAddress::IPv6::Mapped
    @ip = @klass.new("::172.16.10.1")
    @str = "::FFFF:172.16.10.1/128"
    @string = "0000:0000:0000:0000:0000:ffff:ac10:0a01/128"
    @u128 = 281473568475649
    @address = "::ffff:ac10:a01"

    @valid_mapped = {'::13.1.68.3' => 281470899930115,
      '0:0:0:0:0:FFFF:129.144.52.38' => 281472855454758,
      '::FFFF:129.144.52.38' => 281472855454758}
  end

  def test_initialize
    assert_nothing_raised {@klass.new("::172.16.10.1")}
    assert_instance_of @klass, @ip
    @valid_mapped.each do |ip, u128|
      assert_nothing_raised {@klass.new ip}
      assert_equal u128, @klass.new(ip).to_u128
    end
  end

  def test_attributes
    assert_equal @address, @ip.compressed
    assert_equal 128, @ip.prefix
    assert_equal @str, @ip.to_s
    assert_equal @string, @ip.to_string
    assert_equal @u128, @ip.to_u128
  end

  def test_mapped?
    assert_equal true, @ip.mapped?
  end
  
end # class IPv6MappedTest