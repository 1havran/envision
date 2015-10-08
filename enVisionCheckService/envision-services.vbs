outFile = "services.txt"

Set objFSO = CreateObject("Scripting.FilesystemObject")
IF objFSO.FileExists(outFile) THEN
	objFSO.DeleteFile(outFile)
END IF

Dim nicservices(23)
Dim strComputer 
strComputer = "."
nicservices(0) = "ASANYs_NIC_DBSERVER"
nicservices(1) = "NIC DB Report Server"
nicservices(2) = "NIC Alerter"
nicservices(3) = "NIC Asset Collector Service"
nicservices(4) = "NIC Asset Processor Service"
nicservices(5) = "NIC Collector"
nicservices(6) = "NIC DHCP Polling Service"
nicservices(7) = "NIC EDI Service"
nicservices(8) = "NIC File Reader"
nicservices(9) = "NIC FW-1 Lea Client"
nicservices(10) = "NIC Locator"
nicservices(11) = "NIC Logger"
nicservices(12) = "NIC ODBC Service"
nicservices(13) = "NIC Packager"
nicservices(14) = "NIC Scheduler"
nicservices(15) = "NIC SDEE Collection"
nicservices(16) = "NIC Server"
nicservices(17) = "NIC Service Manager"
nicservices(18) = "NIC Trapd Service"
nicservices(19) = "NIC Web Server"
nicservices(20) = "NIC Windows Service"
nicservices(21) = "vmcollect"
nicservices(22) = "winrmcollect"
nicservices(23) = "WinSSHD"

Set objFile = objFSO.CreateTextFile(outFile, True)
For Each service In nicservices
	IF isServiceRunning(strComputer,service) THEN
		WScript.echo "enVision service is running: " & service
	ELSE
		wscript.echo "enVision service is not running: " & service
		objFile.Write service & vbCrLf
	END IF
Next

objFile.Close

WScript.echo "sending email..."
Set objFile = objFSO.GetFile(outFile)
If ObjFile.Size > 0 Then
	WScript.Echo "Output bigger than 0"
	Set objEmail = CreateObject("CDO.Message")
	objEmail.From = "email.from@domain.com"
	objEmail.To = "email.to@domain.com"
	objEmail.Subject = "RSA enVision: Services Down"

	set ostream = objFSO.OpenTextFile(outfile)
	objEmail.Textbody = ostream.ReadAll()

	objEmail.Configuration.Fields.Item ("http://schemas.microsoft.com/cdo/configuration/sendusing") = 2
	objEmail.Configuration.Fields.Item ("http://schemas.microsoft.com/cdo/configuration/smtpserver") = "10.20.30.40"
	objEmail.Configuration.Fields.Item ("http://schemas.microsoft.com/cdo/configuration/smtpserverport") = 25
	objEmail.Configuration.Fields.Update

	objEmail.Send

End If

FUNCTION isServiceRunning(strComputer,strServiceName)
	DIM objWMIService, strWMIQuery

	strWMIQuery = "Select * from WIN32_Service Where Name ='" & strServiceName & "' and state='Running'"
	SET objWMIService = GETOBJECT("winmgmts:"_
		& "{impersonationLevel=impersonate}!\\" & strComputer & "\root\cimv2")

	IF objWMIService.ExecQuery(strWMIQUery).Count > 0 THEN
		isServiceRunning = TRUE
	ELSE
		isServiceRunning = FALSE
	END IF
END FUNCTION