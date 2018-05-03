pushd VRTest/debug
echo "Running Tests"
#.\tst_vrtest.exe
.\tst_vrtest.exe -xunitxml > testres.xml

$xmlOut = new-object System.Xml.XmlDocument;
$xmlOut.AppendChild($xmlOut.CreateXmlDeclaration("1.0","UTF-8",$null));
$rootXmlOut = $xmlOut.CreateElement("testsuites");
$xmlOut.AppendChild($rootXmlOut);
$totalPass = 0;
$totalFail = 0;
$totalError = 0;
$totalSkip = 0;
$totalTime = 0;
$crashMessage = $null;
Get-ChildItem ".\" -Filter "testres.xml" | Foreach-Object {
    $XmlDocument = $null;
    $localPass = 0;
    $localFail = 0;
    $localError = 0;
    $localSkip = 0;
    $localTime = 0;
    $currentFilePath = $_.FullName;
    $testSuiteName = $_.BaseName.subString(0,$_.BaseName.Length - 11);
    if([bool]((Get-Content -Path $currentFilePath) -as [xml])){
        [xml]$XmlDocument = (Get-Content -Path $currentFilePath) -as [xml];
    }
    else{
        $localError = 1;
        $rawFilecontent = [IO.File]::ReadAllText($currentFilePath);
        if([string]::IsNullOrEmpty($rawFilecontent)){
            $crashMessage = "Output file is empty: " + $currentFilePath;
        }
        else{
            $crashMessage = $rawFilecontent;
            $rawFileMatch = [regex]::match($rawFilecontent,"(?s)(.+<\/TestCase>)(.*)");
            if($rawFileMatch.Success){
                if([bool](($rawFileMatch.captures.groups[1].value) -as [xml])){
                    [xml]$XmlDocument = ($rawFileMatch.captures.groups[1].value) -as [xml];
                    $crashMessage = $rawFileMatch.captures.groups[2].value;
                }
            }
        }
    }
    $testSuiteXmlOut = $rootXmlOut.AppendChild($xmlOut.CreateElement("testsuite"));
    if($XmlDocument -ne $null){
        $testClassName = $XmlDocument.TestCase.name;
        $testSuiteXmlOut.SetAttribute("name",$testSuiteName);
        $testSuitePropertiesXmlOut = $testSuiteXmlOut.AppendChild($xmlOut.CreateElement("properties"));
        $testSuitePropertiesPropertyXmlOut = $testSuitePropertiesXmlOut.AppendChild($xmlOut.CreateElement("property"));
        $testSuitePropertiesPropertyXmlOut.SetAttribute("name","QtVersion");
        $testSuitePropertiesPropertyXmlOut.SetAttribute("value",($XmlDocument.TestCase.Environment.QtVersion));
        $testSuitePropertiesPropertyXmlOut = $testSuitePropertiesXmlOut.AppendChild($xmlOut.CreateElement("property"));
        $testSuitePropertiesPropertyXmlOut.SetAttribute("name","QtBuild");
        $testSuitePropertiesPropertyXmlOut.SetAttribute("value",($XmlDocument.TestCase.Environment.QtBuild));
        $testSuitePropertiesPropertyXmlOut = $testSuitePropertiesXmlOut.AppendChild($xmlOut.CreateElement("property"));
        $testSuitePropertiesPropertyXmlOut.SetAttribute("name","QTestVersion");
        $testSuitePropertiesPropertyXmlOut.SetAttribute("value",($XmlDocument.TestCase.Environment.QTestVersion));
        foreach($testFunction in $XmlDocument.SelectNodes("//TestFunction")){
            $testFunctionName = $testFunction.name;
            $countIncidents = $testFunction.ChildNodes.Count;
            $testFunctionTime = [decimal]$testFunction.Duration.msecs;
            $localTime = $localTime +$testFunctionTime;
            foreach($incident in $testFunction.ChildNodes){
                if($incident.Name -ne "Incident" -and $incident.Name -ne "Message"){
                    continue;
                }
                $incidentName = $testFunctionName;
                if($incident.DataTag -ne $null){
                    $incidentName = $incidentName + " - " + $incident.DataTag.InnerText;
                }
                $incidentName = ($incidentName);
                $testSuitetestcaseXmlOut = $testSuiteXmlOut.AppendChild($xmlOut.CreateElement("testcase"));
                $testSuitetestcaseXmlOut.SetAttribute("name",$incidentName);
                $testSuitetestcaseXmlOut.SetAttribute("classname",$testClassName);
                $testSuitetestcaseXmlOut.SetAttribute("time",$testFunctionTime/(1000*$countIncidents));
                if($incident.type -eq "skip"){
                    ++$localSkip;
                    $testSuitetestcaseSkipXmlOut = $testSuitetestcaseXmlOut.AppendChild($xmlOut.CreateElement("skipped"));
                    $testSuitetestcaseSkipXmlOut.SetAttribute("message","file: " + ($incident.file + " line: " + $incident.line + " " + $incident.Description.InnerText));
                }
                ElseIf ($incident.type -eq "fail"){
                    ++$localFail;
                    $testSuitetestcaseSkipXmlOut = $testSuitetestcaseXmlOut.AppendChild($xmlOut.CreateElement("failure"));
                    $testSuitetestcaseSkipXmlOut.SetAttribute("message",("file: " + $incident.file + " line: " + $incident.line + " " + $incident.Description.InnerText));
                }
                ElseIf ($incident.type -eq "qdebug" -or $incident.type -eq "qwarn" -or $incident.type -eq "system" -or $incident.type -eq "qfatal"){
                    $testSuitetestcaseCerrXmlOut = $testSuitetestcaseXmlOut.AppendChild($xmlOut.CreateElement("system-err"));
                    $testSuitetestcaseCerrXmlOut.AppendChild($xmlOut.CreateTextNode(($incident.Description.InnerText)));
                }
                else{
                    ++$localPass;
                }
            };
        };
    }
    if($localError -eq 1){
        $testSuitetestcaseXmlOut = $testSuiteXmlOut.AppendChild($xmlOut.CreateElement("testcase"));
        $testSuitetestcaseXmlOut.SetAttribute("name","SystemError");
        $testSuitetestcaseXmlOut.SetAttribute("classname",$testClassName);
        $testSuitetestcaseErrorXmlOut = $testSuitetestcaseXmlOut.AppendChild($xmlOut.CreateElement("error"));
        $testSuitetestcaseErrorXmlOut.SetAttribute("message",($crashMessage));
    }
    $testSuiteXmlOut.SetAttribute("time",$localTime/1000);
    $testSuiteXmlOut.SetAttribute("skipped",$localSkip);
    $testSuiteXmlOut.SetAttribute("tests",$localSkip+$localFail+$localError+$localPass);
    $testSuiteXmlOut.SetAttribute("failures",$localFail);
    $testSuiteXmlOut.SetAttribute("errors",$localError);
    $totalTime = $totalTime + $localTime;
    $totalSkip = $totalSkip + $localSkip;
    $totalError = $totalError + $localError;
    $totalFail = $totalFail + $localFail;
    $totalPass = $totalPass + $localPass;
};
$rootXmlOut.SetAttribute("time",$totalTime/1000);
$rootXmlOut.SetAttribute("failures",$totalFail);
$rootXmlOut.SetAttribute("errors",$totalError);
$rootXmlOut.SetAttribute("tests",$totalPass);
$xmlOut.save($pwd.Path + "tests.xml");
if($totalError+$totalFail -gt 0){
    throw;
}

type tests.xml
popd