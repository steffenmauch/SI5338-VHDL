
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
