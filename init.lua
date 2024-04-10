local function splitAndGetFirst(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local sepStart, sepEnd = string.find(inputstr, sep)
    if sepStart then
        return string.sub(inputstr, 1, sepStart - 1)
    end
    return inputstr
end

local state = ya.sync(function() return tostring(cx.active.current.cwd) end)

local function fail(s, ...) ya.notify { title = "Fzf", content = string.format(s, ...), timeout = 5, level = "error" } end

local function entry(_, args)
	local _permit = ya.hide()
	local cwd = state()
	local shell_value = os.getenv("SHELL"):match(".*/(.*)")
	local cmd_args = ""
	if args[1] == "fzf" then
		cmd_args = [[fzf --preview='bat --color=always {1}']]
	elseif shell_value == "fish" then
		cmd_args = [[rg ./ --line-number | fzf --preview='set line {2} && set begin ( test $line -lt 7  &&  echo (math "$line-1") || echo  6 ) && bat --highlight-line={2} --color=always --line-range (math "$line-$begin"):(math "$line+10") {1}' --delimiter=':' --preview-window up:60% --nth 3]]
	else
		cmd_args = "rg ./ --line-number | fzf --preview='line={2} && begin=$( if [[ $line -lt 7 ]]; then echo $((line-1)); else echo 6; fi ) && bat --highlight-line={2} --color=always --line-range $((line-begin)):$((line+10)) {1}' --delimiter=':' --preview-window up:60% --nth 3"
	end
	
	local child, err =
		Command(shell_value):args({"-c", cmd_args}):cwd(cwd):stdin(Command.INHERIT):stdout(Command.PIPED):stderr(Command.INHERIT):spawn()

	if not child then
		return fail("Spawn `rfzf` failed with error code %s. Do you have it installed?", err)
	end

	local output, err = child:wait_with_output()
	if not output then
		return fail("Cannot read `fzf` output, error code %s", err)
	elseif not output.status:success() and output.status:code() ~= 130 then
		return fail("`fzf` exited with error code %s", output.status:code())
	end

	local target = output.stdout:gsub("\n$", "")

    local file_url = splitAndGetFirst(target,":")

	if file_url ~= "" then
		ya.manager_emit(file_url:match("[/\\]$") and "cd" or "reveal", { file_url })
	end
end

return { entry = entry }