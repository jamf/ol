# function GetCallingFunctionName {
#   $callingFunctionName = (Get-PSCallStack | Where-Object { $_.InvocationInfo.MyCommand.CommandType -eq 'Function' }).InvocationInfo.MyCommand.Name
#   Write-Host "Calling Function Name: $callingFunctionName"
#   foreach ($caller in $callingFunctionName) {
#     Write-Host "Calling Function Name: $caller"
#   }
# }

# function CalledFunction2 {
#   GetCallingFunctionName
# }
# function CalledFunction1 {
#   CalledFunction2
# }

# # Call the 'CalledFunction' which, in turn, calls 'GetCallingFunctionName'
# CalledFunction1


# function GetCallingFunctionName {
#   $callStack = Get-PSCallStack

#   foreach ($call in $callStack) {
#     Write-Information $call
#     Write-Information ""
#   }
#   if ($callStack.Count -ge 3) {
#       $callingFunctionName = $callStack[3].FunctionName
#       return $callingFunctionName
#   }
# }

function log {
  $callStack = Get-PSCallStack
  # foreach ($call in $callStack) {
  #   Write-Information "$call.FunctionName"
  #   Write-Information "$call.ScriptLineNumber"
  #   Write-Information "$call.ScriptName"
  #   Write-Information ""
  # }

Write-Debug $callStack.Count

  if ($callStack.Count -ge 4) {
      $callerName = $callStack[2].FunctionName
      $callerLine = $callStack[2].ScriptLineNumber
  }
  Write-Host "message: ${callerName}:${callerLine}"
}


function log-debug {
  log
}

function myfunc {
  log-debug
}

Write-Debug "Call from func:"
myfunc

Write-Debug "Call from root:"
log-debug  # <ScriptBlock> 


# 👍👎