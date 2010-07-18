require 'ipaddress/prefix'

module IPAddress; 
  # 
  # =Name
  # 
  # IPAddress::IPv4 - IP version 4 address manipulation library
  #
  # =Synopsis
  #
  #    require 'ipaddress'
  #
  # =Description
  # 
  # Class IPAddress::IPv4 is used to handle IPv4 type addresses. 
  #
  class IPv4
    
    include IPAddress
    include Enumerable  
    include Comparable                  
    
    #
    # This Hash contains the prefix values for Classful networks
    #
    # Note that classes C, D and E will all have a default 
    # prefix of /24 or 255.255.255.0
    #
    CLASSFUL = {
      /^0../ => 8,  # Class A, from 0.0.0.0 to 127.255.255.255
      /^10./ => 16, # Class B, from 128.0.0.0 to 191.255.255.255
      /^110/ => 24  # Class C, D and E, from 192.0.0.0 to 255.255.255.254
    }

    #
    # Regular expression to match an IPv4 address
    #
    REGEXP = Regexp.new(/((25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)\.){3}(25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)/)
    
    #
    # Creates a new IPv4 address object.
    #
    # An IPv4 address can be expressed in any of the following forms:
    # 
    # * "10.1.1.1/24": ip address and prefix. This is the common and
    #     suggested way to create an object                  .
    # * "10.1.1.1/255.255.255.0": ip address and netmask. Although
    #     convenient sometimes, this format is less clear than the previous
    #     one.             
    # * "10.1.1.1": if the address alone is specified, the prefix will be 
    #     assigned using the classful boundaries. In this case, the 
    #     prefix would be /8, a 255.0.0.0 netmask.
    # 
    # It is advisable to use the syntactic shortcut provided with the
    # IPAddress() method, as in all the examples below.
    # 
    # Examples:
    #
    #   # These two methods return the same object
    #   ip = IPAddress::IPv4.new("10.0.0.1/24")
    #   ip = IPAddress("10.0.0.1/24")
    #   
    #   # These three are the same
    #   IPAddress("10.0.0.1/8")
    #   IPAddress("10.0.0.1/255.0.0.0")
    #   IPAddress("10.0.0.1")
    #   #=> #<IPAddress::IPv4:0xb7b1a438 
    #         @octets=[10, 0, 0, 1], @address="10.0.0.1", @prefix=8>
    #
    def initialize(str)
      ip, netmask = str.split("/")
      
      # Check the ip and remove white space
      if IPAddress.valid_ipv4?(ip)
        @address = ip.strip
      else
        raise ArgumentError, "Invalid IP #{ip.inspect}"
      end
      
      # Check the netmask
      if netmask  # netmask is defined
        netmask.strip!
        if netmask =~ /^\d{1,2}$/  # netmask in cidr format 
          @prefix = Prefix32.new(netmask.to_i)
        elsif IPAddress.valid_ipv4_netmask?(netmask)  # netmask in IP format
          @prefix = Prefix32.parse_netmask(netmask)
        else  # invalid netmask
          raise ArgumentError, "Invalid netmask #{netmask}"
        end
      else  # netmask is nil, reverting to defaul classful mask
        @prefix = prefix_from_ip(@address)
      end

      # Array formed with the IP octets
      @octets = @address.split(".").map{|i| i.to_i}

    end # def initialize

    #
    # Returns the address portion of the IPv4 object
    # as a string.
    #
    #   ip = IPAddress("172.16.100.4/22")
    #
    #   ip.address
    #     #=> "172.16.100.4"
    #
    def address
      @address
    end

    #
    # Returns the prefix portion of the IPv4 object
    # as a IPAddress::Prefix32 object
    #
    #   ip = IPAddress("172.16.100.4/22")
    #
    #   ip.prefix
    #     #=> 22
    #
    #   ip.prefix.class
    #     #=> IPAddress::Prefix32
    #
    def prefix
      @prefix
    end

    #
    # Set a new prefix number for the object
    #
    # This is useful if you want to change the prefix
    # to an object created with IPv4::parse_u32 or
    # if the object was created using the classful
    # mask.
    #
    #   ip = IPAddress("172.16.100.4")
    #
    #   puts ip
    #     #=> 172.16.100.4/16
    #   
    #   ip.prefix = 22
    #
    #   puts ip
    #     #=> 172.16.100.4/22
    #
    def prefix=(num)
      @prefix = Prefix32.new(num)
    end

    # 
    # Returns the address as an array of decimal values
    #
    #   ip = IPAddress("172.16.100.4")
    #
    #   ip.octets
    #     #=> [172, 16, 100, 4]
    #
    def octets
      @octets
    end
    
    #
    # Returns a string with the address portion of 
    # the IPv4 object
    #
    #   ip = IPAddress("172.16.100.4/22")
    #
    #   ip.to_s
    #     #=> "172.16.100.4"
    #
    def to_s
      @address
    end

    #
    # Returns a string with the IP address in canonical
    # form.
    #
    #   ip = IPAddress("172.16.100.4/22")
    #
    #   ip.to_string
    #     #=> "172.16.100.4/22"
    #
    def to_string
      "#@address/#@prefix"
    end


    # 
    # Returns the prefix as a string in IP format
    #
    #   ip = IPAddress("172.16.100.4/22")
    #
    #   ip.netmask
    #     #=> "255.255.252.0"
    #
    def netmask
      @prefix.to_ip
    end

    #
    # Like IPv4#prefix=, this method allow you to 
    # change the prefix / netmask of an IP address
    # object.
    #
    #   ip = IPAddress("172.16.100.4")
    #
    #   puts ip
    #     #=> 172.16.100.4/16
    #
    #   ip.netmask = "255.255.252.0"
    #
    #   puts ip
    #     #=> 172.16.100.4/22
    #
    def netmask=(addr)
      @prefix = Prefix32.parse_netmask(addr)
    end

    #
    # Returns the address portion in unsigned
    # 32 bits integer format.
    #
    # This method is identical to the C function
    # inet_pton to create a 32 bits address family 
    # structure. 
    #
    #   ip = IPAddress("10.0.0.0/8")
    #
    #   ip.to_u32
    #     #=> 167772160
    #
    def to_u32
      data.unpack("N").first
    end
    alias_method :to_i, :to_u32

    #
    # Returns the address portion of an IPv4 object
    # in a network byte order format.
    #
    #   ip = IPAddress("172.16.10.1/24")
    #
    #   ip.data
    #     #=> "\254\020\n\001"
    #
    # It is usually used to include an IP address
    # in a data packet to be sent over a socket
    #
    #   a = Socket.open(params) # socket details here
    #   ip = IPAddress("10.1.1.0/24")
    #   binary_data = ["Address: "].pack("a*") + ip.data 
    #   
    #   # Send binary data
    #   a.puts binary_data
    #
    def data
      @octets.pack("C4")
    end

    #
    # Returns the octet specified by index
    #
    #   ip = IPAddress("172.16.100.50/24")
    #
    #   ip[0]
    #     #=> 172
    #   ip[1]
    #     #=> 16
    #   ip[2]
    #     #=> 100
    #   ip[3]
    #     #=> 50
    #
    def [](index)
      @octets[index]
    end
    alias_method :octet, :[]
    
    #
    # Returns the address portion of an IP in binary format,
    # as a string containing a sequence of 0 and 1
    #
    #   ip = IPAddress("127.0.0.1")
    #
    #   ip.bits
    #     #=> "01111111000000000000000000000001"
    #
    def bits
      data.unpack("B*").first
    end

    #
    # Returns the broadcast address for the given IP.
    #
    #   ip = IPAddress("172.16.10.64/24")
    #
    #   ip.broadcast.to_s
    #     #=> "172.16.10.255"
    #
    def broadcast
      self.class.parse_u32(broadcast_u32, @prefix)
    end
    
    #
    # Checks if the IP address is actually a network
    #
    #   ip = IPAddress("172.16.10.64/24")
    #
    #   ip.network?
    #     #=> false
    # 
    #   ip = IPAddress("172.16.10.64/26")
    #
    #   ip.network?
    #     #=> true
    #
    def network?
      to_u32 | @prefix.to_u32 == @prefix.to_u32
    end

    #
    # Returns a new IPv4 object with the network number 
    # for the given IP.
    #
    #   ip = IPAddress("172.16.10.64/24")
    #
    #   ip.network.to_s
    #     #=> "172.16.10.0"
    #
    def network
      self.class.parse_u32(network_u32, @prefix)
    end

    #
    # Returns a new IPv4 object with the
    # first host IP address in the range.
    # 
    # Example: given the 192.168.100.0/24 network, the first
    # host IP address is 192.168.100.1.
    #
    #   ip = IPAddress("192.168.100.0/24")
    #
    #   ip.first.to_s
    #     #=> "192.168.100.1"
    #
    # The object IP doesn't need to be a network: the method
    # automatically gets the network number from it
    #
    #   ip = IPAddress("192.168.100.50/24")
    #
    #   ip.first.to_s
    #     #=> "192.168.100.1"
    #
    def first
      self.class.parse_u32(network_u32+1, @prefix)
    end

    #
    # Like its sibling method IPv4#first, this method 
    # returns a new IPv4 object with the 
    # last host IP address in the range.
    # 
    # Example: given the 192.168.100.0/24 network, the last
    # host IP address is 192.168.100.254
    #
    #   ip = IPAddress("192.168.100.0/24")
    #
    #   ip.last.to_s
    #     #=> "192.168.100.254"
    #
    # The object IP doesn't need to be a network: the method
    # automatically gets the network number from it
    #
    #   ip = IPAddress("192.168.100.50/24")
    #
    #   ip.last.to_s
    #     #=> "192.168.100.254"
    #
    def last
      self.class.parse_u32(broadcast_u32-1, @prefix)
    end

    #
    # Iterates over all the hosts IP addresses for the given
    # network (or IP address).
    #
    #   ip = IPAddress("10.0.0.1/29")
    #
    #   ip.each do |i|
    #     p i.to_s
    #   end
    #     #=> "10.0.0.1"
    #     #=> "10.0.0.2"
    #     #=> "10.0.0.3"
    #     #=> "10.0.0.4"
    #     #=> "10.0.0.5"
    #     #=> "10.0.0.6"
    #
    def each_host
      hosts.each do |i|
        yield i
      end
    end

    #
    # Iterates over all the IP addresses for the given
    # network (or IP address).
    #
    # The object yielded is a new IPv4 object created
    # from the iteration.
    #
    #   ip = IPAddress("10.0.0.1/29")
    #
    #   ip.each do |i|
    #     p i.address
    #   end
    #     #=> "10.0.0.0"
    #     #=> "10.0.0.1"
    #     #=> "10.0.0.2"
    #     #=> "10.0.0.3"
    #     #=> "10.0.0.4"
    #     #=> "10.0.0.5"
    #     #=> "10.0.0.6"
    #     #=> "10.0.0.7"
    #
    def each
      (network_u32..broadcast_u32).each do |i|
        yield self.class.parse_u32(i, @prefix)
      end
    end

    #
    # Spaceship operator to compare IP addresses
    #
    # An IP address is considered to be minor if it 
    # has a greater prefix (thus smaller hosts
    # portion) and a smaller u32 value.
    #
    # For example, "10.100.100.1/8" is smaller than
    # "172.16.0.1/16", but it's bigger than "10.100.100.1/16".
    #
    # Example:
    #
    #   ip1 = IPAddress "10.100.100.1/8"
    #   ip2 = IPAddress "172.16.0.1/16"
    #   ip3 = IPAddress "10.100.100.1/16"
    #
    #   ip1 < ip2
    #     #=> true
    #   ip1 < ip3
    #     #=> false
    #
    def <=>(oth)
      if to_u32 > oth.to_u32
        return 1
      elsif to_u32 < oth.to_u32
        return -1
      else
        if prefix < oth.prefix
          return 1
        elsif prefix > oth.prefix
          return -1
        end
      end
      return 0
    end
    
    #
    # Returns the number of IP addresses included
    # in the network. It also counts the network
    # address and the broadcast address.
    #
    #   ip = IPAddress("10.0.0.1/29")
    #
    #   ip.size
    #     #=> 8
    #
    def size
      broadcast_u32 - network_u32 + 1
    end

    #
    # Returns an array with the IP addresses of
    # all the hosts in the network.
    # 
    #   ip = IPAddress("10.0.0.1/29")
    #
    #   ip.hosts.map {|i| i.address}
    #     #=> ["10.0.0.1",
    #     #=>  "10.0.0.2",
    #     #=>  "10.0.0.3",
    #     #=>  "10.0.0.4",
    #     #=>  "10.0.0.5",
    #     #=>  "10.0.0.6"]
    #
    def hosts
      to_a[1..-2]
    end
    
    #
    # Returns the network number in Unsigned 32bits format
    #
    #   ip = IPAddress("10.0.0.1/29")
    #
    #   ip.network_u32
    #     #=> 167772160
    #
    def network_u32
      to_u32 & @prefix.to_u32
    end

    #
    # Returns the broadcast address in Unsigned 32bits format
    #
    #   ip = IPaddress("10.0.0.1/29")
    #
    #   ip.broadcast_u32
    #     #=> 167772167
    #
    def broadcast_u32
      [to_u32 | ~@prefix.to_u32].pack("N").unpack("N").first
    end

    #
    # Checks whether a subnet includes the given IP address.
    #
    # Accepts either string with the IP or and IPAddress::IPv4
    # object.
    #
    #   ip = IPAddress("192.168.10.100/24")
    #
    #   addr = IPAddress("192.168.10.102/24")
    #
    #   ip.include? addr
    #     #=> true
    #
    #   ip.include? IPAddress("172.16.0.48/16")
    #     #=> false
    #
    def include?(oth)
      @prefix <= oth.prefix and network_u32 == self.class.new(oth.address+"/#@prefix").network_u32
    end

    #
    # Returns the IP address in in-addr.arpa format
    # for DNS lookups
    #
    #   ip = IPAddress("172.16.100.50/24")
    #
    #   ip.reverse
    #     #=> "50.100.16.172.in-addr.arpa"
    #
    def reverse
      @octets.reverse.join(".") + ".in-addr.arpa"
    end
    alias_method :arpa, :reverse
    
    #
    # Subnetting a network
    #
    # If the IP Address is a network, it can be divided into
    # multiple networks. If +self+ is not a network, the
    # method will calculate the network from the IP and then
    # subnet it.
    #
    # If +subnets+ is an power of two number, the resulting 
    # networks will be divided evenly from the supernet.
    #
    #   network = IPAddress("172.16.10.0/24")
    #
    #   network / 4   # implies map{|i| i.to_string}
    #     #=> ["172.16.10.0/26",
    #          "172.16.10.64/26",
    #          "172.16.10.128/26",
    #          "172.16.10.192/26"]
    #
    # If +num+ is any other number, the supernet will be 
    # divided into some networks with a even number of hosts and
    # other networks with the remaining addresses.
    #
    #   network = IPAddress("172.16.10.0/24")
    #
    #   network / 3   # implies map{|i| i.to_string}
    #     #=> ["172.16.10.0/26",
    #          "172.16.10.64/26",
    #          "172.16.10.128/25"]
    #
    # Returns an array of IPAddress objects
    #
    def subnet(subnets=2)
      unless (1..(2**(32-prefix.to_i))).include? subnets
        raise ArgumentError, "Value #{subnets} out of range" 
      end
      calculate_subnets(subnets)
    end
    alias_method :/, :subnet

    #
    # Returns a new IPv4 object from the supernetting
    # of the instance network.
    #
    # Supernetting is similar to subnetting, except
    # that you getting as a result a network with a
    # smaller prefix (bigger host space). For example,
    # given the network
    #
    #   ip = IPAddress("172.16.10.0/24")
    #
    # you can supernet it with a new /23 prefix
    #
    #   ip.supernet(23).to_string
    #     #=> "172.16.10.0/23"
    #
    # However if you supernet it with a /22 prefix, the
    # network address will change:
    #
    #   ip.supernet(22).to_string
    #     #=> "172.16.8.0/22"
    # 
    def supernet(new_prefix)
      raise ArgumentError, "Can't supernet a /1 network" if new_prefix < 1
      raise ArgumentError, "New prefix must be smaller than existing prefix" if new_prefix >= @prefix.to_i
      self.class.new(@address+"/#{new_prefix}").network
    end

    #
    # Returns the difference between two IP addresses
    # in unsigned int 32 bits format
    #  
    # Example:
    #
    #   ip1 = IPAddress("172.16.10.0/24")
    #   ip2 = IPAddress("172.16.11.0/24")
    #
    #   puts ip1 - ip2
    #     #=> 256
    #
    def -(oth)
      return (to_u32 - oth.to_u32).abs
    end

    #
    # Returns a new IPv4 object which is the result 
    # of the summarization, if possible, of the two 
    # objects
    #
    # Example:
    #
    #   ip1 = IPAddress("172.16.10.1/24")
    #   ip2 = IPAddress("172.16.11.2/24")
    #
    #   p (ip1 + ip2).map {|i| i.to_string}
    #     #=> ["172.16.10.0/23"]
    #
    # If the networks are not contiguous, returns
    # the two network numbers from the objects
    #
    #   ip1 = IPAddress("10.0.0.1/24")
    #   ip2 = IPAddress("10.0.2.1/24")
    #
    #   p (ip1 + ip2).map {|i| i.to_string}
    #     #=> ["10.0.0.0/24","10.0.2.0/24"]
    #
    def +(oth)
      aggregate(*[self,oth].sort.map{|i| i.network})
    end

    #
    # Checks whether the ip address belongs to a 
    # RFC 791 CLASS A network, no matter
    # what the subnet mask is.
    #
    # Example:
    # 
    #   ip = IPAddress("10.0.0.1/24")
    #
    #   ip.a?
    #     #=> true
    #
    def a?
      CLASSFUL.key(8) === bits
    end
    
    #
    # Checks whether the ip address belongs to a
    # RFC 791 CLASS B network, no matter
    # what the subnet mask is.
    #
    # Example:
    #
    #   ip = IPAddress("172.16.10.1/24")
    #
    #   ip.b?
    #     #=> true
    #
    def b?
      CLASSFUL.key(16) === bits
    end

    #
    # Checks whether the ip address belongs to a
    # RFC 791 CLASS C network, no matter
    # what the subnet mask is.
    #
    # Example:
    #
    #   ip = IPAddress("192.168.1.1/30")
    #
    #   ip.c?
    #     #=> true
    #
    def c?
      CLASSFUL.key(24) === bits
    end

    #
    # Return the ip address in a format compatible
    # with the IPv6 Mapped IPv4 addresses
    # 
    # Example:
    #
    #   ip = IPAddress("172.16.10.1/24")
    #
    #   ip.to_ipv6
    #     #=> "ac10:0a01"
    #
    def to_ipv6
      "%.4x:%.4x" % [to_u32].pack("N").unpack("nn")
    end

    #
    # Creates a new IPv4 object from an
    # unsigned 32bits integer.
    #
    #   ip = IPAddress::IPv4::parse_u32(167772160)
    #
    #   ip.prefix = 8
    #   ip.to_string
    #     #=> "10.0.0.0/8"
    #
    # The +prefix+ parameter is optional:
    #
    #   ip = IPAddress::IPv4::parse_u32(167772160, 8)
    #
    #   ip.to_string
    #     #=> "10.0.0.0/8"
    #
    def self.parse_u32(u32, prefix=nil)
      ip = [u32].pack("N").unpack("C4").join(".")
      if prefix
        self.new(ip+"/#{prefix}")
      else
        self.new(ip)
      end
    end

    #
    # Creates a new IPv4 object from binary data,
    # like the one you get from a network stream.
    # 
    # For example, on a network stream the IP 172.16.0.1
    # is represented with the binary "\254\020\n\001".
    # 
    #   ip = IPAddress::IPv4::parse_data "\254\020\n\001"
    #   ip.prefix = 24
    #
    #   ip.to_string
    #     #=> "172.16.10.1/24"
    #
    def self.parse_data(str)
      self.new str.unpack("C4").join(".")
    end

    #
    # Exctract an IPv4 address from a string and 
    # returns a new object
    #
    # Example:
    #
    #   str = "foobar172.16.10.1barbaz"
    #   ip = IPAddress::IPv4::extract str
    #
    #   ip.to_s
    #     #=> "172.16.10.1"
    #
    def self.extract(str)
      self.new REGEXP.match(str).to_s
    end
    
    #
    # Summarization (or aggregation) is the process when two or more
    # networks are taken together to check if a supernet, including all
    # and only these networks, exists. If it exists then this supernet
    # is called the summarized (or aggregated) network.
    #
    # It is very important to understand that summarization can only
    # occur if there are no holes in the aggregated network, or, in other
    # words, if the given networks fill completely the address space
    # of the supernet. So the two rules are:
    #
    # 1) The aggregate network must contain +all+ the IP addresses of the
    #    original networks;
    # 2) The aggregate network must contain +only+ the IP addresses of the
    #    original networks;
    #
    # A few examples will help clarify the above. Let's consider for
    # instance the following two networks:
    #
    #   ip1 = IPAddress("172.16.10.0/24")
    #   ip2 = IPAddress("172.16.11.0/24")
    #
    # These two networks can be expressed using only one IP address
    # network if we change the prefix. Let Ruby do the work:
    #
    #   IPAddress::IPv4::summarize(ip1,ip2).to_s
    #     #=> "172.16.10.0/23"
    #
    # We note how the network "172.16.10.0/23" includes all the addresses
    # specified in the above networks, and (more important) includes
    # ONLY those addresses. 
    #
    # If we summarized +ip1+ and +ip2+ with the following network:
    #
    #   "172.16.0.0/16"
    #
    # we would have satisfied rule #1 above, but not rule #2. So "172.16.0.0/16"
    # is not an aggregate network for +ip1+ and +ip2+.
    #
    # If it's not possible to compute a single aggregated network for all the
    # original networks, the method returns an array with all the aggregate
    # networks found. For example, the following four networks can be
    # aggregated in a single /22:
    #
    #   ip1 = IPAddress("10.0.0.1/24")
    #   ip2 = IPAddress("10.0.1.1/24")
    #   ip3 = IPAddress("10.0.2.1/24")
    #   ip4 = IPAddress("10.0.3.1/24")
    #
    #   IPAddress::IPv4::summarize(ip1,ip2,ip3,ip4).to_string
    #     #=> "10.0.0.0/22", 
    #
    # But the following networks can't be summarized in a single network:
    #
    #   ip1 = IPAddress("10.0.1.1/24")
    #   ip2 = IPAddress("10.0.2.1/24")
    #   ip3 = IPAddress("10.0.3.1/24")
    #   ip4 = IPAddress("10.0.4.1/24")
    #
    #   IPAddress::IPv4::summarize(ip1,ip2,ip3,ip4).map{|i| i.to_string}
    #     #=> ["10.0.1.0/24","10.0.2.0/23","10.0.4.0/24"]
    #
    def self.summarize(*args)
      # one network? no need to summarize
      return [args.first.network] if args.size == 1
      
      i = 0
      result = args.dup.sort.map{|ip| ip.network}
      while i < result.size-1
        sum = result[i] + result[i+1]
        result[i..i+1] = sum.first if sum.size == 1
        i += 1
      end
      
      result.flatten!
      if result.size == args.size
        # nothing more to summarize
        return result
      else
        # keep on summarizing
        return self.summarize(*result)
      end
    end

    #
    # private methods
    #
    private
    
    def bits_from_address(ip)
      ip.split(".").map{|i| i.to_i}.pack("C4").unpack("B*").first
    end
    
    def prefix_from_ip(ip)
      bits = bits_from_address(ip)
      CLASSFUL.each {|reg,prefix| return Prefix32.new(prefix) if bits =~ reg}
    end

    def calculate_subnets(subnets)
      po2 = subnets.closest_power_of_2
      new_prefix = @prefix + Math::log2(po2).to_i
      networks = Array.new
      (0..po2-1).each do |i|
        mul = i * (2**(32-new_prefix))
        networks << IPAddress::IPv4.parse_u32(network_u32+mul, new_prefix)
      end
      until networks.size == subnets
        networks = sum_first_found(networks)
      end
      return networks
    end
    
    def sum_first_found(arr)
      dup = arr.dup.reverse
      dup.each_with_index do |obj,i|
        a = [IPAddress::IPv4.summarize(obj,dup[i+1])].flatten
        if a.size == 1
          dup[i..i+1] = a
          return dup.reverse
        end
      end
      return dup.reverse
    end

    def aggregate(ip1,ip2)
      if ip1.include? ip2
        return [ip1]
      else
        snet = ip1.supernet(ip1.prefix-1)
        arr1 = ip1.subnet(2**(ip2.prefix-ip1.prefix)).map{|i| i.to_string}
        arr2 = snet.subnet(2**(ip2.prefix-snet.prefix)).map{|i| i.to_string} 
        if (arr2 - [ip2.to_string] - arr1).empty?
          return [snet]
        else
          return [ip1, ip2]
        end
      end
    end
    
  end # class IPv4
end # module IPAddress

