--[[
Copyright (C) 2014 Draios inc.
 
This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License version 2 as
published by the Free Software Foundation.


This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
--]]

-- Chisel description
description = "This chisel intercepts all reads and writes to all files. Instead of all files, you can limit interception to one file."
short_description = "Echo any read/write made by any process to all files. Optionally, you can provide the name of one file to only intercept reads/writes to that file.";
category = "I/O";

-- Argument list
args = 
{
	{
		name = "read_or_write",
		description = "specify 'R' to capture only read events; 'W' to capture only write events; 'RW' to capture read and write events. By default both read and write events are captured.",
		argtype = "string",
		optional = true
	},
	{
		name = "spy_on_file_name", 
		description = "the name of the file which the chisel should spy on for all read and write activity.", 
		argtype = "string",
		optional = true
	}
}

-- Imports and globals
require "common"
local spy_file_name = nil
local read_or_write = nil
local verbose = false

-- Argument notification callback
function on_set_arg(name, val)
	if name == "read_or_write" then
		read_or_write = val
		return true
	elseif name == "spy_on_file_name" then
		spy_file_name = val
		return true
	end

	return false
end

-- Initialization callback
function on_init()	
	local filter

	-- Request the fields that we need
	fbuf = chisel.request_field("evt.buffer")
	fdata = chisel.request_field("evt.arg.data")
	ffdname = chisel.request_field("fd.name")
	fisw = chisel.request_field("evt.is_io_write")
	fpid = chisel.request_field("proc.pid")
	fpname = chisel.request_field("proc.name")
	fres = chisel.request_field("evt.rawarg.res")
	ftid = chisel.request_field("thread.tid")
	fts = chisel.request_field("evt.time")

	-- increase the snaplen so we capture more of the conversation 
	sysdig.set_snaplen(2000)

	-- set the output format to ascii
	sysdig.set_output_format("ascii")

	-- set the filter
	if spy_file_name ~= nil and spy_file_name ~= "" then
		filter = string.format("(fd.name=%s) and ", spy_file_name)
	else
		-- watching terminals risks looping in a live capture
		filter = "(not fd.name contains /dev/pt and not fd.name contains /dev/tty) and "
	end

	if read_or_write == "R" or read_or_write == "r" then
		filter = string.format("%s%s", filter, "evt.is_io_read=true and ")
	elseif read_or_write == "W" or read_or_write == "w" then
		filter = string.format("%s%s", filter, "evt.is_io_write=true and ")
	else
		filter = string.format("%s%s", filter, "evt.is_io=true and ")
	end

	filter = string.format("%s%s", filter, "fd.type=file and evt.dir=< and evt.failed=false")

	if verbose then
		print("filter=" .. filter)
	end

	chisel.set_filter(filter)

	return true
end

-- Event parsing callback
function on_event()	
	-- Extract the event details
	local data = evt.field(fdata)
	local fdname = evt.field(ffdname)
	local is_write = evt.field(fisw)
	local pid = evt.field(fpid)
	local pname = evt.field(fpname)
	local res = evt.field(fres)
	local ts = evt.field(fts)
	local read_write

	-- Render the message to screen
	if is_write == true then
		read_write = "W"
	else
		read_write = "R"
	end

	print(string.format("%s %s(%s) %s %s %s %s", ts, pname, pid, read_write, format_bytes(res), fdname, data))

	return true
end
