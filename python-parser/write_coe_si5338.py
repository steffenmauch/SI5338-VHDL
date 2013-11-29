
# This function generates a 'coe' file which suits for
# Xilinx ISE FPGA-tool (initialization value for BRAM)
#   'data'
#       vector or a matrix
#   'filename'
#       the name of the desired output file
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

def write_coe_si5338(data, filename):

	depth = 9;
	width = 24;

	f = open(filename, 'w')
	f.write('; This .COE file specifies initialization values for a block\n')
	f.write('; memory of depth=%i, and width=%i. In this case, values are\n' %(2**depth , width) )
	f.write('; specified in hexadecimal format.\n')
	f.write('; script by Steffen Mauch, (c) 12/2013\n')
	f.write('memory_initialization_radix=16;\n')
	f.write('memory_initialization_vector=\n')

	sizeA = len(data)
	sizeB = len(data[0])

	for l in range(0,sizeA):
		for k in range(0,sizeB):
			f.write('%02x' % (data[l][k]) )
		if l == (sizeA-1):
			f.write(';\n')
		else:
			f.write(',\n')

	f.close()

#write_coe_si5338(1,1)
