# Установка номера тестового ПРА

namespace eval vizir {
	set regnumPRA 0000000000000001
}	

#
#
# Собственно тестовый фреймворк



namespace eval test {
	# Уровень логгинга по умолчанию. Может быть переопределен явным
	# присваиванием перед созданием контекста. Действует на контексты
	# созданные makeCtx, makeCtx2 и threecontexts.
	# Задание -logminpriority в test::ctxParams имеет приоритет.
	set logLevel 3	
	# Переменная хранящая имя динамической библиотеки для userlib
	variable userlib {}
	# Чтобы timestamp была определена всегда
	variable timestamp [clock seconds]
	proc findUserLib {} {
		variable userlib
		if {$::tcl_platform(platform)!="dos"} {
			set dirlist  [list [file dirname [info script]]\
				[file dirname [info nameofexecutable]]]
			if {$::tcl_platform(platform) == "windows"} {
				lappend dirlist\
				[file normalize [file join [file dirname [info script]] ..  obj_mid.w32]]\
				[file normalize [file join [file dirname [info script]] ..  obj_mid.w32]]
			} elseif {$::tcl_platform(os) == "Linux"} {
				lappend dirlist\
				[file normalize [file join [file dirname [info script]] ..  obj_sid.lnx]]
			} elseif {$::tcl_platform(os) == "SunOS"} {
				if {$::tcl_platform(wordSize) == 8} {
					set for s64
				} elseif {$::tcl_platform(byteOrder) == "littleEndian"} {
					set for s86
				} else {
					set for s32
				}
				lappend dirlist\
				[file normalize [file join [file dirname [info script]] ..  obj_sid.$for]]
			}	 
			foreach dir $dirlist {
			set userlib_file [file join  $dir  usermci[info sharedlibextension]]
				if {[file exists $userlib_file]} {
					break
				}	
			}	
			if {![file exists $userlib_file]} {
				error "No usable userlib found in $dirlist"
			}	
			set userlib [list -userlib $userlib_file]
		} else {
			set userlib {}
		}	
	}	
	#
	# 
	#
	# Вызывается в начале тестового скрипта. Инициализирует необходимые
	# переменные пакета, открывает лог и пишет в него заголовок
	# Параметры name - заголовок тестового скрипта.
	#  
	# Побочные эффекты - создается <имя-скрипта>.log
	#
	proc start_tests {name} {
		variable suffix
		if {![info exists suffix]} {
			set binary [file rootname [file tail [info nameofexecutable]]]
			if {$binary != "tclsh"} {
				set suffix "_[string range [file tail [info nameofexecutable]] 0 2]"
			} else {
				set suffix ""
			}	
		}
		variable logname [file rootname [file tail [info script]]]$suffix.log
		variable no 0 ok 0 failed 0 p_skip 0 c_skip 0 t_name $name logchannel [open $logname w] tempfiles {}
		if {![catch {package present Vizir}]} {
			findUserLib
		}	
		puts [format [rus "=========== Группа тестов: %s ================="] [rus $name]]
		puts $::test::logchannel [format [rus "Группа тестов \"%s\""] $name]
	}	
	#
	# Завершает выполнение теста и выводит отчет
	# Вызывает exit 
	#
	proc end_tests {} {
		variable no
		variable ok
		variable failed
		variable p_skip
		variable t_name
		variable c_skip
		variable logname
		variable tempfiles
		variable suffix
		puts "==================================================="
		puts [format [rus "Всего %d тестов. Выполнено %d успешно, %d неуспешно"] $no $ok $failed]
		if {$p_skip || $c_skip} {
			puts [format [rus "Пропущено: %d на данной платформе %d из-за невыполнения других тестов"] $p_skip $c_skip]
		}
		if {$failed} {
			puts [format [rus "Смотри более подробную информацию в %s"] $logname]
		} 
		set test_id [file rootname [file tail [info script]]]$suffix
		set stat [open "stats" a]
		fconfigure $stat -encoding utf-8
		puts $stat [list $test_id [rus $t_name] $no $ok $failed $p_skip $c_skip] 
		close $stat
		if {!$failed} {	
			foreach file $tempfiles {

				if [info exists $file] {puts [test_log] "Deleting $file"
				   file delete $file}
			}	
		} {
			# signal to a caller that we had failures
			exit 1
		}
	}
   #
   # Вовзращает идентификатор канала, куда пишется лог тестов.
   # Рекомендуется назначать его в качестве -logchannel создаваемым
   # контекстам чтобы вся выдача была в одном месте
   # 
   proc test_log {} {
		variable logchannel
		return $logchannel
	}
	#
	# Собственно тест 
	#   Параметры
	#   1. Название теста
	#   2. Код (рекомендуется писать {
	#       код
	#     }
	#   3. Ожидаемый результат выполнения - 0 успешно 1 - ошибка. Варианты
	#     больше 1 (TCL_BREAK, TCL_CONTINUE и TCL_RETURN) возможны, но вряд
	#     ли интересны
	#   4. Ожидаемый возвращаемый результат
	#      Если предыдущий параметр 0, результат сравнивается на точное
	#      совпадение, если 1 - результат - регексп, которому должно
	#      удовлетворять сообщение об ошибке.
	proc test args {
		array set opts {}
		variable tempfiles
		variable timestamp
		while {[string match -* [lindex $args 0]]} {
			set key [lindex $args 0]
			set val [lindex $args 1]
			set args [lrange $args 2 end]
			set opts($key) $val
		}
	    foreach {message code exitStatus expectedResult} $args break
		global errorInfo 
		if {[info exists opts(-platform)] && [lsearch -exact $opts(-platform) $::tcl_platform(platform)]==-1} {
			logskip $message "platform"
			return
		}
		if {[info exists opts(-platformex)] && ![uplevel expr $opts(-platformex)]} {
			logskip $message "platform"
			return
		}	
		if {[info exists opts(-skip)] && [uplevel expr $opts(-skip)]} {
			logskip $message "prereq" 
			return
		}	
		if {[info exists opts(-fixme)] && [uplevel expr $opts(-fixme)]} {
			logmiss $message "FIXME" 
			return
		}	
		if {[info exists opts(-createsfiles)]} {
			foreach file $opts(-createsfiles) {
				lappend tempfiles $file
				if {[file exists $file]} {file delete $file}
			}
		}
		if {[info exists opts(-createsvars)]} {
			foreach var $opts(-createsvars) {
				uplevel  "if {\[info exists $var\]} {unset $var}"
			}
		}	
		logbegin $message
		set teststart [clock seconds]
		set status [catch {uplevel $code} result]
		set testend [clock seconds]
		if {$teststart == $testend} {
			set timestamp $teststart
		} else {
			# Handle negative intervals correctly
			if {$teststart > $testend} {
				set timestamp "$testend+[expr $teststart-$testend]"
			} else {	
				set timestamp "$teststart+[expr $testend-$teststart]"
			}
		}	
		if {($exitStatus!=-1 && $status!=$exitStatus) ||
		       	($exitStatus!=0?![regexp --\
			[rus $expectedResult] $result]:([info exists opts(-time)]?\
		    ![listcompare $result $expectedResult $opts(-time)]:\
			[string compare "$result" "$expectedResult"]))} {
			logend "failed"
			if {$status == 1} {
				set expectedResult [rus $expectedResult]
			}	
			log   "Code:----$code---------------"
			log	"Expected status $exitStatus got $status"
			log   "Expected result: [list $expectedResult]"
			log 	"     Got result: [list $result]"
			if {$status == 1} {
				log "errorCode = $::errorCode"
			}	
		} else {
			logend "ok"
		}	
	}
#
# Внутренние (неэкспортируемые)процедуры
#
#

#
# Сравнение списков с учетом того что некоторые элементы могут быть
# метками времени, которые проверяются с точностью +-секунда
# Параметр time - список, каждый элемент которого является индексом
# элемента в списке, либо списком индексов во вложенных списках
# 
proc listcompare {list1 list2 time} {
	foreach e $time {
		if {[llength $e]>1} {
			lappend a([lindex $e 0]) [lrange $e 1 end]
		} else {
			set a($e) {}
		}	
	}
	if {[llength $list1] !=[llength $list2]} {
		return 0
	}	
	set i 0
	foreach e1 $list1 e2 $list2 {
		if {![info exists a($i)]} {
			if {[string compare $e1 $e2]!=0} {
				return 0
			}
		} elseif {[llength $a($i)]} {
			if {![listcompare $e1 $e2 $a($i)]} {
				return 0
			}
		} else {
			if {$e2 == "::test::timestamp"} {
				set e2 $::test::timestamp
			}	
			if {[regexp {^([[:digit:]]+)\+([[:digit:]]+)$} $e2 m start delta]} {
				if {$e1<$start || $e1 >$start+$delta} {
					return 0
				}
			} elseif {abs($e1-$e2)>1} {
				return 0
			}
		}
		incr i
	}	
	return 1
}
proc rus {string} {
	return $string
}
   #
   # Пишет строку в лог
   #
   proc log {message} {
		variable logchannel
		puts $logchannel $message
	}
	#
	# Вызывается при начале теста
	# 
	proc logbegin {testname} {
		variable no
		variable curtest
		incr no
		puts -nonewline [rus [format "Тест%5d: %-60s:" $no [string range $testname 0 59]]]
		flush stdout
		set curtest $testname
		log [rus "\n\nТест $no: $testname start"]
	}
	#
	# Вызывается при пропуске теста
	#
	proc logskip {testname reason} {
		variable no
		variable p_skip
		variable c_skip
		puts "[rus [format "Тест%5d: %-60s:" $no [string rang $testname 0 59]]]skipped "
		log "[rus "Тест $no: skipped "][expr {$reason=="platform"?"on
		the platform $::tcl_platform(platform)":"due to failed prerequisites"}]:[rus $testname]" 
		incr no
		if {$reason == "platform"} {
			incr p_skip
		} else {
			incr c_skip
		}	
	}
	
	#
	# Вызывается при игнорировании теста
	#
	proc logmiss {testname reason} {
		variable no
		variable c_skip
		puts "[rus [format "Тест%5d: %-60s:" $no [string rang $testname 0 59]]]missed "
		log "[rus "Тест $no: missed "][expr {$reason=="platform"?"on
		the platform $::tcl_platform(platform)":"by reason: $reason"}]:[rus $testname]" 
		incr no
		incr c_skip
	}

	#
	# Вызывается конце теста и с параметром ok или failed
	#
	proc logend {status} {
		variable no
		variable curtest
		variable $status
		incr $status
		puts $status
		log [rus "Тест $no: $curtest ends $status"]
	}
	
	#####################################################################
	# Вспомогательные процедуры, не специфичные для тестируемого
	# приложения
	#####################################################################

	#
	# Записывает  данные из data в файл name. По умолчанию пишет в
	# текущей системной кодировке. Можно указать кодировку явно третьим
	# аргументом
	#
	proc makeFile {name data {encoding {}}} {
		set f [open $name w]
		setFileEncoding $f $encoding
		puts -nonewline $f $data 
		close $f
	}	
	proc setFileEncoding {f encoding} {
		if {[string length $encoding]} {
			if {"$encoding" == "binary"} {
				fconfigure $f -translation binary
			} else {	
				fconfigure $f -encoding $encoding
			}	
		}
	}	
#
# Возвращает содeржимое файла 
#

proc getFile {filename {encoding {}}} {
	set f [open $filename]
	setFileEncoding $f $encoding
	set data [read $f]
	close $f
	return $data
}	
#
# Возвращает содержимое бинарного файла. Для совместимости со старыми
# тестами
#
proc getfile {filename} {
	return [getFile $filename binary]
}	
	# 
	# Зачитывает указанный файл, удаляет его и возвращает содержимое.
	# По умолчанию читает файл в текущей системной кодировке. Можно
	# указать кодировку явно вторым аргументом.
	#

	proc readAndDel {name {encoding {}}} {
		set f [open $name]
		setFileEncoding $f $encoding
		set data [read $f]
		close $f
		file delete $name
		return $data
	}	


	#
	# Защищает файл от записи средствами операционной системы
	# denywrite filename ?boolean?
	# Если boolean не указан, или он true, файл становится read-only
	# Если указан - readwrite (для владельца. Впрочем для не-владельца все
	# равно не сработает)
	#
	proc denyWrite {filename {deny 1}} {
		global tcl_platform
		if {$tcl_platform(platform) == "unix"} {
			set cur_attr [file attributes $filename -permissions]
			if {$deny} {
				set new_attr [expr {$cur_attr &~ 0200}]
			} else {
				set new_attr [expr {$cur_attr | 0200}]
			}	
			file attributes $filename -permissions $new_attr
		} else {
			file attributes $filename -readonly $deny 
		}
	}	
	#
	# Записывает в лог 16-ричный дамп указанной переменной
	#

	proc hexdump {data } {
		while {[string length $data]} {
			set block [string range $data 0 15] 
			set data [string replace $data 0 15]
			binary scan [encoding convertto $block] c* list
			set line ""
			set i 0
			foreach code $list {
				append line [format "%02x " [expr $code>=0?$code:$code +256]]
				if {[incr i]%4==0} {
					append line "| "
				}
			}
			append line [string repeat " " [expr 56-[string length $line]]]
			regsub -all "\[\0-\37\]" $block . printable
			append line [rus $printable]
			log $line
		}
	}	
	namespace export test start_tests end_tests test_log rus log\
	makeFile readAndDel hexdump denyWrite getFile getfile
}	
namespace import ::test::*

package provide test 0.2
