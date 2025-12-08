-- micro-run - Press F5 to run the current file, F12 to run make, F9 to make in background
-- Copyright 2020-2022 Tero Karvinen http://TeroKarvinen.com/micro
-- https://github.com/terokarvinen/micro-run

local config = import("micro/config")
local shell = import("micro/shell")
local micro = import("micro")
local os = import("os")

function init()
	config.MakeCommand("runit", runitCommand, config.NoComplete)
	config.TryBindKey("Ctrl-R", "command:runit", true)
end

-- ### F5 runit ###

function runitCommand(bp) -- bp BufPane
	-- save & run the file we're editing
	-- choose run command according to filetype detected by micro
	bp:Save()

	local filename = bp.Buf.GetName(bp.Buf)
	local filetype = bp.Buf:FileType()

	if filetype == "c" then
		-- c is a special case
		-- c compilation only supported on Linux-like systems
		shell.RunInteractiveShell("clear", false, false)

		-- we must create the temporary file here 
		-- so that local attacker can't create a hostile one beforehand		
		-- RunInteractiveShell(input string, wait bool, getOutput bool) (string, error)
		cmd = string.format("mktemp '/tmp/micro-run-binary-XXXXXXXXXXX'", filename)
		tmpfile, err = shell.RunInteractiveShell(cmd, false, true)
		-- TODO: error handling

		shell.RunInteractiveShell("echo", false, false)
		
		-- compile to temporary file with unique(ish) tmp file name
		cmd = string.format("gcc '%s' -o '%s'", filename, tmpfile)
		shell.RunInteractiveShell(cmd, false, false)

		-- run temporary file
		cmd = string.format("'%s'", tmpfile)
		shell.RunInteractiveShell(cmd, false, false)

		-- remove temp file
		cmd = string.format("rm '%s'", tmpfile)
		shell.RunInteractiveShell(cmd, true, false)

		return -- early exit
	end

	if filetype == "rust" then -- filetype can be different from suffix
		-- Rust rs is handled like C.
		shell.RunInteractiveShell("clear", false, false)

		-- we must create the temporary file here 
		-- so that local attacker can't create a hostile one beforehand		
		-- RunInteractiveShell(input string, wait bool, getOutput bool) (string, error)
		cmd = string.format("mktemp '/tmp/micro-run-binary-XXXXXXXXXXX'", filename)
		tmpfile, err = shell.RunInteractiveShell(cmd, false, true)
		-- TODO: error handling

		shell.RunInteractiveShell("echo", false, false)
		
		-- compile to temporary file with unique(ish) tmp file name
		cmd = string.format("rustc '%s' -o '%s'", filename, tmpfile)
		shell.RunInteractiveShell(cmd, false, false)

		-- run temporary file
		cmd = string.format("'%s'", tmpfile)
		shell.RunInteractiveShell(cmd, false, false)

		-- remove temp file
		cmd = string.format("rm '%s'", tmpfile)
		shell.RunInteractiveShell(cmd, true, false)

		return -- early exit
	end


	local cmd = string.format("./%s", filename) -- does not support spaces in filename
	if filetype == "go" then
		if string.match(filename, "_test.go$") then
			cmd = "go test"
		else
			cmd = string.format("go run '%s'", filename)
		end
	elseif filetype == "python" then
		cmd = string.format("python3 '%s'", filename)
	elseif filetype == "html" then
		cmd = string.format("firefox-esr '%s'", filename)
	elseif filetype == "lua" then
		cmd = string.format("lua '%s'", filename)
	elseif filetype == "shell" then
		-- Give execute permission to bash script
		permissionCmd = string.format("chmod +x '%s'", filename)
		shell.RunInteractiveShell(permissionCmd, false, false)
	
		cmd = string.format("bash '%s'", filename) -- we just assume the shell is bash
	end

	shell.RunInteractiveShell("clear", false, false)
	shell.RunInteractiveShell(cmd, true, false)		
end

