
source ../src/plugins.tcl
parse_plugins "../src/plugins" no
set file [open parsed_plugins.tcl "w"]
puts $file "set applist \"$applist\""
puts $file "set medialist \"$medialist\""
puts $file "set rules \"$rules\""
puts $file "set createrules \"$createrules\""
foreach ary {mediadata fmts protos protonames fmtnames mappings attrs attrnames attrvaluenames attrflags noattrflags noattrlist defattrlist withattrs macros macrokeys} {
    foreach key [array names $ary] {
	puts $file "set [set ary]($key) \"[set [set ary]($key)]\""
    }
}
close $file
exit 0
