#!/usr/bin/python

# This script generates a 'coe' file which suits for
# Xilinx ISE FPGA-tool (initialization value for BRAM)
#
# the script parse the header file from ClockBuilder
# and generates a coe file for ISE Xilinx
#  successfully tested with SI5338 configuration
#
#   copyright by:
#       Steffen Mauch (C) 2013
#       email: steffen.mauch (at) gmail.com
# 
# The MIT License (MIT)
#
# Copyright (c) 2013 Steffen Mauch
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

import write_coe_si5338
import re
import math

filename = './register_map.h'

with open(filename, 'r') as content_file:
	content = content_file.read()

m = re.search('NUM_REGS_MAX (?P<value>\d*)',content)
NUM_REGS_MAX = int(m.group('value'))
POW_NUM_REGS_MAX = math.ceil(math.log(NUM_REGS_MAX,2))

m = re.findall('\n{(?P<d1>.{3}),(?P<d2>.{2,4}),(?P<d3>.{4,5})}',content)

data = [(0,0,0)]*int(2**POW_NUM_REGS_MAX)
for k in range(0,NUM_REGS_MAX-1):
	temp = [[]]*3
	temp[0] = int( m[k][0] );
	temp[1] = int( m[k][1],0 );
	temp[2] = int( m[k][2],0 );
	data[k]=temp

temp = [[]]*3
temp[0] = 0
temp[1] = int( math.floor(NUM_REGS_MAX/256) )
temp[2] = int( NUM_REGS_MAX % 256 )
data[ int(2**POW_NUM_REGS_MAX-1) ] = temp

write_coe_si5338.write_coe_si5338(data,'si5338_coe_py.coe')
