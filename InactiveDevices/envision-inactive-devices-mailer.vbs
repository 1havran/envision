
Set args = WScript.Arguments

Set objEmail = CreateObject("CDO.Message")
objEmail.From = "envision.from@domain.com"
objEmail.To = "envision.to@domain.com"
objEmail.Subject = "Activity Report"
objEmail.Textbody = "Enclosed the reports regarding inactive devices recorded by envision is attached."

objEmail.AddAttachment(args.Item(0))

objEmail.Configuration.Fields.Item ("http://schemas.microsoft.com/cdo/configuration/sendusing") = 2
objEmail.Configuration.Fields.Item ("http://schemas.microsoft.com/cdo/configuration/smtpserver") = "10.20.30.40"
objEmail.Configuration.Fields.Item ("http://schemas.microsoft.com/cdo/configuration/smtpserverport") = 25
objEmail.Configuration.Fields.Update


objEmail.Send
