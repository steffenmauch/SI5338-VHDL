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
#  You can redistribute it and/or modify it under the terms of the GNU General Public
#  License as published by the Free Software Foundation, version 2.
# 
#  This program is distributed in the hope that it will be useful, but WITHOUT
#  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
#  FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
#  details.
# 
#  You should have received a copy of the GNU General Public License along with
#  this program; if not, write to the Free Software Foundation, Inc., 51
#  Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

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
