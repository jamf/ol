# Logging helper

# TO-DO:
# Logging should be more in keeping with PowerShell standards 


function Write-Log_Error {
  param ([string]$message = "")
  Log -messageLogLevel "Error" -message $message
}
function Write-Log_Info {
  param ([string]$message = "")
  Log -messageLogLevel "Info" -message $message
}
function Write-Log_Warning {
  param ([string]$message = "")
  Log -messageLogLevel "Warning" -message $message
}
function Write-Log_Verbose {
  param ([string]$message = "")
  Log -messageLogLevel "Verbose" -message $message
}
function Write-Log_Debug {
  param ([string]$message = "")
  # $callingFunctionName = $PSCmdlet.MyInvocation.MyCommand.Name
  # $callingFunctionName = $MyInvocation.MyCommand.Name
  # $callingFunctionName = $MyInvocation.PSCommandPath
  # $callingScriptName = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.ScriptName)
  # $callingScriptLineNumber = $MyInvocation.ScriptLineNumber
  Log -messageLogLevel "Debug" -message $message
}
function Log {
  param (
    [string]$messageLogLevel = "Info",
    [string]$message = ""
  )
  $logLevels = @{
    Error=0
    Warning=1
    Info=2
    Debug=3
    Verbose=4
  }

  $messageLogLevelNumber = $logLevels[$messageLogLevel]
  if (-not $logLevel) {
    $logLevel = "Info"
  }
  $minimumLogLevelNumber = $logLevels[$logLevel]
  # Write-Host "messageLogLevel: $messageLogLevel"
  # Write-Host "logLevels[messageLogLevel]: $messageLogLevelNumber"
  # Write-Host "logLevel: $logLevel"
  # Write-Host "logLevels[logLevel]: $minimumLogLevelNumber"
  if ($messageLogLevelNumber -le $minimumLogLevelNumber) {
    $callStack = Get-PSCallStack
    if ($callStack.Count -ge 4) {
      $callerName = $callStack[2].FunctionName
      $callerLine = $callStack[2].ScriptLineNumber
    }
    $timeStamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
    $messageLogLevelPrint = if ($messageLogLevel.Length -gt 7) {$messageLogLevel.Substring(0, 7)} else {$messageLogLevel.PadRight(7, ' ')}
    $logLine = "${timeStamp} [${messageLogLevelPrint}] ${message} (${callerName}:${callerLine})"
    switch ($messageLogLevel) {
      "Error" {Write-Error $logLine}
      "Warning" {Write-Warning $logLine}
      "Info" {Write-Information $logLine}
      "Debug" {Write-Debug $logLine}
      "Verbose" {Write-Debug $logLine}
      Default {Write-Host $logLine}
    }    
  }
}
