function write_coe_si5338_file(data, filename)
% This function generates a 'coe' file which suits for
% Xilinx ISE FPGA-tool (initialization value for BRAM)
%   'data'
%       vector or a matrix
%   'filename'
%       the name of the desired output file
%
%   copyright by:
%       Steffen Mauch (C) 2013
%       email: steffen.mauch (at) gmail.com
%
% The MIT License (MIT)
%
% Copyright (c) 2014 Steffen Mauch
%
% Permission is hereby granted, free of charge, to any person obtaining a copy
% of this software and associated documentation files (the "Software"), to deal
% in the Software without restriction, including without limitation the rights
% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
% copies of the Software, and to permit persons to whom the Software is
% furnished to do so, subject to the following conditions:
%
% The above copyright notice and this permission notice shall be included in
% all copies or substantial portions of the Software.
%
% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
% THE SOFTWARE.
    
depth = 9;
width = 24;

fd = fopen(filename,'w');  %#ok<MFAMB>

fprintf(fd,'; This .COE file specifies initialization values for a block\n');  %#ok<MFAMB>
fprintf(fd,'; memory of depth=%d, and width=%d. In this case, values are\n',2^depth , width);
fprintf(fd,'; specified in hexadecimal format.\n');
fprintf(fd,'; script by Steffen Mauch, (c) 11/2013\n');
fprintf(fd,'memory_initialization_radix=16;\n');
fprintf(fd,'memory_initialization_vector=\n');

[a,b] = size(data); %#ok<MFAMB>

for l=1:a
    for k=1:b
        fprintf(fd,'%02x', data(l,k) );
    end
    if( l == a )
        fprintf(fd,';\n');
    else
        fprintf(fd,',\n');
    end
end
fclose(fd);  %#ok<MFAMB>
