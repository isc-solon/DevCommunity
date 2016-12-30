/// Demo Application Errors Monitor
Class Demo.MonitorErrors Extends %Monitor.Adaptor
{

/// set this parameter to 1 to turn on logging in ^demolog global
Parameter LOG = 0;

/*
   *** these are internal "helper" properties for the object
   *** they remain in memory while this class is activated and running
*/
/// Used for BOTH queries on the Application Error Log
Property Query As %ResultSet [ Internal ];

/// Holds the *filtered* rows returned by the query, suscripted by the SerialNumber:Currency key
Property FilteredRows As %String [ Internal, MultiDimensional ];

/// Subscript (Name:Phone) of the FilteredRows, for looping
Property Key As %String [ Internal ];

/// Total Errors for today
Property TodaysCount As %Integer [ Internal ];

/*
   *** the parameter and these 5 properties define a sample
   *** the sample properties are STORED in the generated class <package>.Sample.<class>
   *** any alerts are based on the stored sample data
*/
/// The key for the sample data is the combination of Name and Phone
Parameter INDEX = "Name,Phone";

/// Employee name
Property Name As %Monitor.String;

/// Employee Phone
Property Phone As %Monitor.String;

/// count of errors for an employee
Property ErrorCount As %Monitor.String(CAPTION = "Error Count");

/// earliest time of error for an employee
Property Earliest As %Monitor.String(CAPTION = "Earliest Occurrence");

/// latest time of error for an employee
Property Latest As %Monitor.String(CAPTION = "Latest Occurrence");

/// Run the queries for Application Errors for today
Method Initialize() As %Status
{
	try {
		kill:(..#LOG = 0) ^demolog
		
	    set today = $zdate(+$h)
	    
	    // run this simple query first (returns one row) to see if there are ANY errors in %SYS namespace today
	    set ..Query = ##class(%Library.ResultSet).%New("SYS.ApplicationError:DateList")
	    do ..Query.%Execute("%SYS")
	    set latestErrorCount = 0
	    if (..Query.%Next() = 1) && (..Query.Date = today) {
	    		// get current error count for today
		    set latestErrorCount = ..Query.Qty
	    }
	    do ..Query.Close()
	    
	    // if there are more errors since last time, update ..TodaysCount and continue.
	    // Otherwise, wait until next sample run
	    if (latestErrorCount > ..TodaysCount) {
			set:(..#LOG = 1) ^demolog($i(^demolog)) = "collect sample (" _ $ztime($piece($h, ",", 2)) _ ")"
			set ..TodaysCount = latestErrorCount
	    }
	    else {
		    set:(..#LOG = 1) ^demolog($i(^demolog)) = "don't sample   (" _ $ztime($piece($h, ",", 2)) _ ")"
		    return 0  /// this ends Initialize() AND prevents any call(s) to GetSample()
	    }

		
	    // get the list of errors for this namespace today
	    set ..Query = ##class(%Library.ResultSet).%New("SYS.ApplicationError:ErrorList")
	    do ..Query.%Execute("%SYS", today)

	    // query returns errors from most recent to oldest
	    // Demo.TestErrorMonitor creates #5001 errors like this:
	    //    ERROR #5001: Problem with Employee: John Smith (111-222-3333)
	    // ...so find only the #5001 errors and put info about them into ..FilteredRows
	    
	    // at the beginning of each sample run, destroy the sample data
	    kill ..FilteredRows
	    while (..Query.%Next() '= 0) {
		    set errorMessage= ..Query.Get("Error message")
		    if (errorMessage '[ "#5001") { continue }
		    // the Employee name is between "Employee: " and " ("
		    set name = $piece($piece(errorMessage, "Employee: ", 2), " (")
		    // the Employee phone is between "(" and ")"
		    set phone = $piece($piece(errorMessage, "(", 2), ")")
		    set time = $zth(..Query.Get("Time"))
		    
		    // access/create/update this entry
		    set key = name _ ":" _ phone
		    set entry = $get(..FilteredRows(key))
		    if (entry = "") {
			    // data for first entry
			    set count = 1, (earliest, latest) = time
		    }
		    else {
			    // update data for this entry 
			    	set earliest = $list(entry, 2)
			    	set latest = $list(entry, 3)
			    	if (time < earliest) {
				    	set earliest = time
				}
			    	elseif (time > latest) {
				    	set latest = time
				}
				set count = $list(entry, 1) + 1 // increment count
		    }
		    set ..FilteredRows(key) = $listbuild(count, earliest, latest)
	    }
	    // finished looping through results, so initialize for looping through ..FilteredRows in GetSample()
	    set ..Key = "" 

	}
	catch ex {
		#dim ex as %Exception.SystemException
		do ex.Log()
	}
		
	do ..Query.Close()
    return $$$OK
}

/// this is called repeatedly until it returns 0<br>
/// return $$$OK means store this row of sample data (and GetSample() is called again)
Method GetSample() As %Status
{
	set:(..#LOG = 1) ^demolog($i(^demolog)) = "store sample   (" _ $ztime($piece($h, ",", 2)) _ ")"
	set ..Key = $order(..FilteredRows(..Key), 1, entry)
	if (..Key = "") { return 0 }
	set ..Name = $piece(..Key, ":", 1)
	set ..Phone = $piece(..Key, ":", 2)
	set ..ErrorCount = $list(entry, 1)
	set ..Earliest = $ztime($list(entry, 2))
	set ..Latest = $ztime($list(entry, 3))
    return $$$OK
}

/*
   *** these are additional methods (NOT used by the example)
*/

/// This method is called once when the control object is created when Application Monitor starts.
/// Use it to initialize the control class.
Method Startup() As %Status
{
	Quit $$$OK
}

/// This method is called once when the control object is destroyed when Application Monitor stops.
/// Use it to cleanup the control class.
Method Shutdown() As %Status
{
	Quit $$$OK
}
}
