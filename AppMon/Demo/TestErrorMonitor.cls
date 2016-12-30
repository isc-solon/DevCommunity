/// Generate custom errors
Class Demo.TestErrorMonitor
{

/// create an exception and log it
ClassMethod CreateOneError(name As %String = "", phone As %String = "")
{
	// if name or phone wasn't passed in, use Population utilities to generate a random name and phone number
	if (name = "") { set name = ##class(%PopulateUtils).Name() }
	if (phone = "") { set phone = ##class(%PopulateUtils).USPhone() }	
	
	// change name to "first last"
	set name = $piece($piece(name, ",", 2), " ") _ " " _ $piece(name, ",", 1)
	set ex = ##class(%Exception.StatusException).%New()
	set ex.Code = 5001
	set msg = "Problem with Employee: " _ name _ " (" _ phone _ ")"
	write !, msg
	// the Data property must be a list
	set ex.Data = $lb(msg)
	// log the exception
	do ex.Log()
}

/// create multiple exceptions for the same person
ClassMethod CreateErrors(count As %Integer = 5)
{
	set name = ##class(%PopulateUtils).Name()
	set phone = ##class(%PopulateUtils).USPhone()
	for i=1:1:count {
		do ..CreateOneError(name, phone)
		// 25% of the time hang for 1 second, so that there is a difference between earliest/latest occurrence
		// this simulates the same error happening at different times, which the Alert tests for
		hang:($random(4) = 0) 1
	}
}

}
