if not main.makeRoster then
	launchFight{}
	setMatchNo(-1)
	return
end

if main.storyboard.intro and matchno() == 1 and not continue() then
    -- Determine the reference side for arcade intro
    local sideRef = main.singlePlayerSide or 1
    if not start.p[sideRef].t_selected[1] then
        if start.p[1].t_selected[1] then
            sideRef = 1
        elseif start.p[2].t_selected[1] then
            sideRef = 2
        end
    end
    local firstSel = start.p[sideRef].t_selected[1]
    if firstSel then
        launchStoryboard(start.f_getCharData(firstSel.ref).intro)
    end
end

for i = matchno(), #start.t_roster do
	if start.t_roster[i][1] == -1 then --infinite matches flag detected
		return --restart lua script after appending new entries
	end
	local t_p2char = {}
	for _, v in ipairs(start.t_roster[i]) do
		table.insert(t_p2char, start.f_getCharData(v).char)
	end
	main.f_tableShuffle(t_p2char)
	if not launchFight{p2char = t_p2char, p2numchars = #t_p2char} then return end
end

if main.storyboard.ending then
	if not launchStoryboard(start.f_getCharData(start.p[1].t_selected[1].ref).ending) and motif.default_ending.enabled == 1 then
		launchStoryboard(motif.default_ending.storyboard)
	end
end

setMatchNo(-1)