
source ../src/plugins.tcl
parse_plugins "../src/plugins" no
set file [open parsed_plugins.tcl "w"]
puts $file [list set applist $applist]
puts $file [list set medialist $medialist]
puts $file [list set rules $rules]
puts $file [list set createrules $createrules]
foreach ary {tooldata mediadata fmts protos protonames fmtnames mappings attrs attrnames attrvaluenames attrflags noattrflags noattrlist defattrlist withattrs macros macrokeys fmtlayers} {
    foreach key [array names $ary] {
	puts $file [list set [set ary]($key) [set [set ary]($key)]]
    }
}
close $file
exit 0
