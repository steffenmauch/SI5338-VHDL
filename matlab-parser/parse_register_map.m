% This script generates a 'coe' file which suits for
% Xilinx ISE FPGA-tool (initialization value for BRAM)
%
% the script parse the header file from ClockBuilder
% and generates a coe file for ISE Xilinx
%  successfully tested with SI5338 configuration
%
%   copyright by:
%       Steffen Mauch (C) 2013
%       email: steffen.mauch (at) gmail.com
% 
%  You can redistribute it and/or modify it under the terms of the GNU General Public
%  License as published by the Free Software Foundation, version 2.
% 
%  This program is distributed in the hope that it will be useful, but WITHOUT
%  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
%  FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
%  details.
% 
%  You should have received a copy of the GNU General Public License along with
%  this program; if not, write to the Free Software Foundation, Inc., 51
%  Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

filename = 'register_map.h';

fid = fopen(filename);

data = fgets(fid);
data1 = '';
while ischar(data1)
    data = [ data data1];
    data1 = fgets(fid);
end

fclose(fid);


temp = regexp(data,'NUM_REGS_MAX (?<value>\d*)\r', 'names');
NUM_REGS_MAX = str2double( temp.value );
POW_NUM_REGS_MAX = ceil(log2(NUM_REGS_MAX));

temp = regexp(data,'\n{(?<d1>.{3}),(?<d2>.{2,4}),(?<d3>.{4,5})}', 'names');

data = zeros(2^POW_NUM_REGS_MAX,3);
for k=1:NUM_REGS_MAX-1
	data(k,1) = str2num( temp(k).d1 );
    d2 = strtrim(temp(k).d2);
	if( length(d2) > 2 && strcmp( d2(1:2), '0x') )
        data(k,2) = hex2dec( d2(3:end) );
    else
        data(k,2) = str2num( temp(k).d2 );
    end
    d3 = strtrim(temp(k).d3);
    if( length(d3) > 2 &&  strcmp( d3(1:2), '0x')  )
        data(k,3) = hex2dec( d3(3:end) );
    else
        data(k,3) = str2num( temp(k).d3 );
    end
end

data(2^POW_NUM_REGS_MAX,2) = floor(NUM_REGS_MAX/256);
data(2^POW_NUM_REGS_MAX,3) = mod(NUM_REGS_MAX,256);

write_coe_si5338_file(data,'si5338_coe.coe')
