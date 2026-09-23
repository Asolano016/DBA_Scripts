SELECT l.PatchID, h.HostName, i.InstanceName, i.TcpPort, i.Version AS 'Actual version', l.CreateDate AS 'Schedule time', l.ExitCode, l.Comment
FROM tPatchLog AS l
JOIN tHosts AS h ON h.HostID = l.HostID
JOIN tHostInstances AS hi ON hi.HostID = l.HostID
JOIN tInstances AS i ON hi.InstanceID = i.ID
--Select patching from last 7 days. If you want another period, change value
WHERE l.CreateDate > (SELECT DATEADD(day, -2, convert(date, GETDATE())))
ORDER BY h.HostName, l.CreateDate
