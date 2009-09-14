#!/bin/bash
appname=${0##*/}
ver=0.1.5.2009020211
copy=2003-2009
mail=mehl@PointedEars.de
mail_feedback=chkmadd@PointedEars.de
latest_uri=http://PointedEars.de/tools/network/chkmadd/
# ----------------------------------------------------------------------------
#     chkmadd 0.1.5 -- E-Mail Address Checker
#     Copyright (C) 2003-2009  Thomas Lahn <mehl@PointedEars.de>
#
#     This program is free software; you can redistribute it and/or modify
#     it under the terms of the GNU General Public License as published by
#     the Free Software Foundation; either version 2 of the License, or
#     (at your option) any later version.
#
#     This program is distributed in the hope that it will be useful,
#     but WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#     GNU General Public License for more details.
#
#     You should have received a copy of the GNU General Public License
#     along with this program; if not, write to the Free Software
#     Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301
#     USA.
#
## Standard shell script disclaimer blurb thing:
##
## This script is a hack.  It's brute force.  It's horrible.
## It doesn't use Artificial Intelligence.  It doesn't use Virtual Reality.
## It's not perl.  It's not python.  It probably won't work unchanged on
## the "other" thousands of unices.  But it worksforme.  --ramiro
# (from /usr/local/mozilla/run-mozilla.sh)
#
#     This is work in progress.  If you have an improvement, patch,
#     idea, whatever, on how to make this script better, please
#     drop me a mail (see above).
#
# ChangeLog
# ==========
# 
# See the ChangeLog text file for further information.
#
# 
# TO DO (0.1.5b)
# ===============
#
# * Read interactively from stdin on missing arguments (help only on -h)
# * Send to host $h, port $p with netcat on -s $h -p $p
# * Read from port $p with netcat on -lp $p
# * Error if expect script cannot be called on -a
# * Avoid checking duplicate hosts (same IP address) by default;
#   allow to override with -d option
# * Tell chkmadd.exp to skip VFRY command on -y (requires chkmadd.exp update)
#
# ----------------------------------------------------------------------------

E_NO_ERROR=0
E_ADDRESS_DOESNT_EXIST=1
E_ADDRESS_DONT_KNOW=2
E_INVALID_MXS=3
E_ERROR=127

seq ()
{
  _start=$1 || 0
  _stop=$2 || $((${_start}+1))
  step=1
  [ -n "$2" -a -n "$3" ] && step=$2 && _stop=$3
  i=${_start}
  while [ $i -le ${_stop} ]
  do
    echo $i
    let i=$i+$step
  done
}

leadingCh ()
{
  local s=$1

  while [ "${#s}" -lt ${2:-1} ]
  do  
    s="${3:- }$s"
  done
  echo "$s"
}

_help()
{
  echo "\
${extd}$1${norm}
  [${extd}-Vadhvy${norm}] [${extd}-E${norm} PROGRAM] [${extd}-e${norm} SCRIPT]\
 [${extd}-f${norm} [FILE]] [${extd}-l${norm}|${extd}-s${norm} SERVER] [${extd}-p${norm} PORT] 
  [${extd}-t${norm} SECONDS] EMAIL_ADDRESS...

Verify EMAIL_ADDRESS(es) by retrieving the mail exchangers (MXs) and, if
necessary, the A record, for their domain part(s) and accessing them via
SMTP ${extd}telnet${norm}(1).  An Expect script for talking SMTP to MXs\
 automagically
and a ${extd}chkmadd${norm} server to listen for incoming requests are supported.
"

  echo "Tests showed that the Expect script \"${_exp_script}\" is "
  [ $use_expect -eq 1 ] \
    && echo "${done}available and can be executed${norm}." \
    || {
      [ $have_exp_script -eq 1 ] \
        && echo "${warn}available but cannot be executed since the
\"${_exp}\" program is missing${norm}." \
        || echo "${warn}not available${norm}."
      echo "So you should either use the -a option or specify the correct path."
    }

  echo "\
  
  ${extd}-a${norm}, ${extd}--auto${norm}                  Force automatic verification\
 via the Expect
                                SCRIPT.  ${extd}(TODO)${norm}
  ${extd}-d${norm}, ${extd}--force-dupes${norm}           Force MXs with different\
 hostname but same
                                Internet address to be asked for EMAIL_ADDRESS.
                                ${extd}(TODO)${norm}
  ${extd}-E${norm}, ${extd}--expect${norm} PROGRAM        Specify the Expect PROGRAM\
 to be used.
  ${extd}-e${norm}, ${extd}--expect-script${norm} SCRIPT  Specify the Expect SCRIPT\
 to be used.
  ${extd}-f${norm}, ${extd}--file${norm} FILE             Read EMAIL_ADDRESS(es) from\
 FILE.  The default
                                is the standard input which can be equally
                                specified as \`-'.
  ${extd}-H${norm}, ${extd}--force-helo${norm}            Force HELO command.\
  ${extd}(TODO)${norm}
  ${extd}-h${norm}, ${extd}--help${norm}                  Display this help screen and\
 exit.
  ${extd}-l${norm}, ${extd}--listen${norm}                Listen for parameters from\
 stdin or on the PORT
                                specified with ${extd}-p${norm}.\
  ${extd}(TODO)${norm}
  ${extd}-p${norm}, ${extd}--port${norm} PORT             Specify the port\
 where either requests should
                                be addressed to (${extd}-s${norm}) or where the\
 ${extd}chkmadd${norm}
                                SERVER should listen on (${extd}-l${norm}).\
  The default
                                is telnet(23)/tcp.  ${extd}(TODO)${norm}
  ${extd}-s${norm}, ${extd}--server${norm} SERVER         Specify a ${extd}chkmadd${norm} SERVER to be used instead of
                                the local program.  ${extd}(TODO)${norm}
  ${extd}-t${norm}, ${extd}--timeout${norm} TIMEOUT       Specify the TIMEOUT for the Expect SCRIPT in
                                seconds.
  ${extd}-V${norm}, ${extd}--version${norm}               Display version information\
 and exit.
  ${extd}-v${norm}, ${extd}--verbose${norm}               Be verbose.
  ${extd}-y${norm}, ${extd}--no-vrfy${norm}               Skip VRFY command.
  EMAIL_ADDRESS               E-mail address to be verified. May be delimited
                              by \"<\" and \">\".  Separate e-mail addresses by
                              space (\$IFS in general)."  

  if [ "$getopt_type" = 'short' ]; then
# _XPG=1
    ( echo "\

Note that the long options are not available on this system, so you
must use the short options instead.  Also, optional arguments are not
supported, so if you do not pass an argument to an option, you must
use \"\" instead." ) | $fmt
# _XPG=0
  fi
  echo "
See ${extd}chkmadd${norm}(1) for details."
}

# ********************************** MAIN **************************************

# from /etc/rc.status
# check for $COLUMNS
[ -z "$LINES" -o -z "$COLUMNS" ] && {
  eval `stty size 2>/dev/null | (read L C; echo LINES=${L:-24} \
COLUMNS=${C:-80})`
}
[ $LINES -eq 0 ]   && LINES=24
[ $COLUMNS -eq 0 ] && COLUMNS=80

if [ "$TERM" != "raw" ] && stty size >/dev/null 2>&1; then
  esc=`echo -en "\033"`
  tab=`echo -en "\t"`
  extd="${esc}[1m"
  warn="${esc}[1;33m"
  done="${esc}[1;32m"
  norm=`echo -en "${esc}[m\017"`
  norm=${norm%% }
  norm=${norm## }
  stat="... "
else
  esc=""
  tab=" "        
  extd=""
  warn=""
  done=""
  norm=""
  up=""
fi

     rc_done="${done}done${norm}"
   rc_failed="${warn}failed${norm}"
    rc_reset="${norm}"
     rc_save="${esc}7"
  rc_restore="${esc}8"

# check for fold
fold="fold -sw $COLUMNS"
chk=`which fold 2>/dev/null`
[ $? -ne 0 ] && fold=cat
chk=`echo x | $fold 2>/dev/null`
[ -n "$chk" ] && fold=cat

# check for fmt
fmt=cat
if [ $COLUMNS -ne 80 ]; then # output is preformatted for 80 cols
  chk=`which fmt 2>/dev/null`
  if [ $? -ne 0 ]; then
    fmt=$fold
  else
    # check for columns
    fmt="fmt -w $COLUMNS"
    chk=`echo x | $fmt 2>/dev/null`
    [ -z "$chk" ] && fmt=fmt
    # check for -c|--crown-margin
    chk=`echo x | $fmt -c 2>/dev/null`
    if [ -n "$chk" ]; then
      fmt="$fmt -c"
    else
      chk=`echo x | $fmt --crown-margin 2>/dev/null`
      [ -n "$chk" ] && fmt="$fmt --crown-margin"
    fi
#fmt="'$fmt'"
  fi
fi

# Note that we use '"$@"' to let each command-line parameter expand to a
# separate word. The quotes around '$@' are essential!
# We need 'tmp' as the 'eval set --' would nuke the return value of getopt.

#echo "$extd
#Debug output for POSIX conform command-line
#parsing (will require -vv in the release).  
#
#Original arguments: $*$norm" >&2
if `getopt -T >/dev/null 2>&1`; [ $? = 4 ]; then
  getopt_type=long
#  echo "getopt(1) type:     enhanced" >&2
  tmp=`getopt -o vhVadE:e:f::p:s:t:y \
              -l verbose,help,version,auto,force-dupes,expect:,expect-script:\
,file::,port:,server:,timeout:,skip-verify \
              -n "$appname" \
              -- "$@"`
else
  getopt_type=short
#  echo "getopt(1) type:     old" >&2
  tmp=`getopt vhVadE:e:f:p:s:t:y "$@"`
fi

getopt_exit_code=$?
help=0
unset verbose
show_version=0
force_auto=0
force_dupes=0
file=''
port=$CHKMADD_PORT
server=$CHKMADD_SERVER
_exp='/usr/bin/expect'
_exp_script="`dirname "$0"`/chkmadd.exp"
args=""

if [ $getopt_exit_code -eq 0 ]; then
##     getopt  returns  error  code 0 for successful parsing, 1 if
##     getopt(3) returns errors, 2 if it does not understand its
##     own parameters, 3 if an internal error occurs like out-of-
##     memory, and 4 if it is called with -T.
#
# Note the quotes around '$tmp': they are essential!
#  echo $tmp
# remove "--"
#  for i in $tmp; do if [ "$i" != "--" ]; then tmp2="${tmp2} $i"; fi; done
  eval set -- "$tmp"
# echo "${extd}New arguments:      $*$norm" >&2
  while true
  do
    case "$1" in
      -h | --help)          help=1; shift;;
      -v | --verbose)       verbose='-v'; shift;;
      -V | --version)       show_version=1; shift;;
      -E | --expect)        shift; _exp="$1"; shift;;
      -e | --expect-script) shift; _exp_script="$1"; shift;;
      -a | --auto)          force_auto=1; shift;;
      -d | --force-dupes)   force_dupes=1; shift;;
      -f | --file)          shift; file="${1:--}"; shift;;
      -p | --port)          shift; port=$1; shift;;
      -s | --server)        shift; server=$1; shift;;
      -t | --timeout)       shift; timeout=$1; shift;;
      -y | --skip-verify)   skip_verify='--skip-verify'; shift;;
      --)                   shift; break;;
    esac
  done
  [ -n "$*" ] && args=$args" $*"
  [ -z "$args" -a $show_version -eq 0 -a -z "$file" ] && help=1
  set -- $args
else
#  echo "getopt exited: $getopt_exit_code
#  " >&2
  if [ $getopt_exit_code -eq 1 ] || [ $getopt_exit_code -eq 2 ]; then
    echo
    help=1
  else
    exit $getopt_exit_code
  fi
fi

use_expect=0
have_exp=0
have_exp_script=0
exp_script_exe=0
[ -f "${_exp}" -a -x ${_exp} ] && have_exp=1
[ -f "${_exp_script}" ] && have_exp_script=1
[ -x "${_exp_script}" ] && exp_script_exe=1
[ $have_exp -eq 1 -a $have_exp_script -eq 1 ] && use_expect=1

[ -n "$verbose" -o $help -eq 1 -o $show_version -eq 1 ] && echo "\
${extd}chkmadd ${ver} -- (C) ${copy}  Thomas Lahn <${mail}>${norm}
Distributed under the terms of the GNU General Public License (GPL).
See COPYING file or <http://www.fsf.org/copyleft/gpl.html> for details."

bugs_info ()
{
  echo "Report bugs to <${mail_feedback}>.
"
}
[ -n "$verbose" -a $show_version -eq 0 ] && bugs_info

j=0
if [ -n "$1" ]; then
  for i in $*
  do
    i=${i##\<}
    addresses[$j]=${i%%\>}
    let j=$j+1
  done
elif [ -n "$file" ]; then
  [ "$file" = "-" ] && file=/dev/stdin
  while read i
  do
    i=${i##\<}
    addresses[$j]=${i%%\>}
    let j=$j+1
  done < $file
# TODO: Should we return $E_ERROR and show help screen if no addresses are read?
# [ ${#addresses[@]} -eq 0 ] && help=1
  [ "$file" = "/dev/stdin" ] && echo
fi

[ $help -eq 1 -o $show_version -eq 1 ] && {
  [ $show_version -eq 0 ] && echo && _help "$appname"
 
  echo "\

The latest version is available from
<${latest_uri}>."

  bugs_info
  exit $E_ERROR
}

IFS="
"

[ -n "$server" -a "$server" != '-' ] &&
{
  [ -n "$verbose" ] &&
  {
    echo "Using chkmadd server $server${port:+:$port}"
    echo
  }

  [ "$port" = "-" ] && unset port

  # TODO: Pass all options
  ssh "$server" "${port:+-p $port}" \
    chkmadd $verbose ${timeout:+-t $timeout} -- $*

  exit $?
}

if [ ${#addresses[@]} -gt 0 ]; then
  [ -n "$verbose" ] && echo "E-mail address(es) to check:"
else
  echo "No e-mail addresses to check."
  exit_code=$E_ERROR
fi

[ -n "$verbose" ] && {
  ( echo ${addresses[@]} ) | $fold
  [ $timeout ] && {
    echo
    echo "Using a $timeout second(s) timeout."
  }  
}  

for i in ${addresses[@]}
do
  if [ -n "$verbose" ]; then
    echo
    echo "Verifying <$i>..." >&2
  fi

atext="[A-Za-z0-9!#\$%&'*+/=?^_\`{|}~-]"
dot_atom_text="$atext+(\\.$atext+)*"
dot_atom=$dot_atom_text
  
  if [ -z "`echo "$i" | egrep -e "${dot_atom}@${dot_atom}"`" ]; then
    if [ -n "$verbose" ]; then
      ( echo "<$i>
is definitely not a (valid) e-mail address, since it lacks compliance
with RFC 2822, section 3.4.1 (Addr-spec Specification)." ) | $fmt
    else
      echo "<$i>${tab}-${tab}INVALID_FORMAT"
    fi
    
    exit_code=$E_ADDRESS_DOESNT_EXIST
    continue
  fi
  
#  if [ -z "`echo "$i" | grep -e @`" ]; then
#    if [ -n "$verbose" ]; then
#      ( echo "The @ character is missing, thus <$i>
#is definitely not a (valid) e-mail address." ) | $fmt
#    else
#      echo "<$i>${tab}-${tab}NO_AT"
#    fi
#    exit_code=$E_ADDRESS_DOESNT_EXIST
#    continue
#  fi
  
#  if [ -z "${i%%@*}" ]; then
#    if [ -n "$verbose" ]; then
#      ( echo "The local-part is missing, thus <$i>
#is definitely not a (valid) e-mail address." ) | $fmt
#    else
#      echo "<$i>${tab}-${tab}NO_LOCAL_PART"
#    fi
#    exit_code=$E_ADDRESS_DOESNT_EXIST
#    continue
#  fi
  
  # pass domain part of e-mail address to `host'
  domain=${i##*@}
  if [ -z "$domain" ]; then
    if [ -n "$verbose" ]; then
      ( echo "The domain-part is missing, thus <$i>
is definitely not a (valid) e-mail address." ) | $fmt
    else
      echo "<$i>${tab}-${tab}NO_DOMAIN_PART"
    fi
    
    exit_code=$E_ADDRESS_DOESNT_EXIST
    continue
  fi

  while true
  do
    if [ -n "$verbose" ]; then
      [ "$domain" != "${i##*@}" ] && echo "none." >&2
      echo -n "Mail exchanger(s) for $domain: " >&2
    fi  
    
    mx_query=`host -t MX "${domain}" 2>&1`
    
    exit_code=$?
    if [ ${exit_code} -eq 0 ]; then
      [ -z "`echo "${mx_query}" | egrep -e ';;|\*\*'`" ] && break
    elif [ ${exit_code} -eq 127 ]; then
      mx_query=`nslookup -querytype=MX "${domain}" 2>&1`

      exit_code=$?
      if [ ${exit_code} -eq 0 ]; then
        [ -z "`echo "${mx_query}" | egrep -e '\*\*\*.+non-existent'`" ] && break
      fi
    fi

    # next: test domain of higher level
    domain=`echo "${domain}" | sed -e 's/^[^.]\{1,\}\.\(.\{1,\}\)/\1/'`

    # if we are already at second level
    [ -z "`echo "${domain}" | egrep -e '^.+\..+$'`" ] && break
  done

  mxs=`echo "${mx_query}" | egrep -e 'mail|MX' | egrep -ve '(^|[^.])no[nt]? '`

  if [ -z "${mxs}" ]; then
    domain=${i##*@}
    while true
    do
      if [ -n "$verbose" ]; then
        if [ "$domain" != "${i##*@}" ]; then
          echo "none." >&2
        else
          echo -n "none.
\`A' record for $domain: "

        fi
      fi
      
      mx_query=`host -t A "${domain}" 2>&1`
      exit_code=$?
### FIXME: same condition twice; TODO: check if we have host or nslookup first
      if [ ${exit_code} -eq 0 ]; then
        [ -z "`echo "${mx_query}" | grep -e ';;\|\*\*\|not exist'`" ] && break
      elif [ ${exit_code} -eq 0 ]; then
        mx_query=`nslookup -querytype=A "${domain}" 2>&1`

        exit_code=$?
        if [ ${exit_code} -eq 0 ]; then
          [ -z "`echo "${mx_query}" | egrep -e '\*\*\*.+non-existent'`" ] &&
            break
        fi
      fi

      # next: test domain of higher level
      domain=`echo "${domain}" | sed -e 's/^[^.]\{1,\}\.\(.\{1,\}\)/\1/'`

      # if we are already at second level
      [ -z "`echo "${domain}" | grep -e '^.\{1,\}\..\{1,\}$'`" ] && break
    done
      
    mxs=`echo "${mx_query}" | head -1 | egrep -ve 'not? '`
      
    if [ -z "${mxs}" ]; then
      if [ -n "$verbose" ]; then
        echo "
None, thus <$i> is definitely not an e-mail address (no MX)." | $fmt
      else
        echo "<$i>${tab}-${tab}NO_MX"
      fi
      
      exit_code=$E_ADDRESS_DOESNT_EXIST
      continue
    fi
  fi

  [ -n "$verbose" ] && echo "
${mxs}" >&2
  unset hosts
  for j in ${mxs}
  do
    hosts[${#hosts[@]}]=`echo $j |
      sed -e 's/.*[ '$'\t'']\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\|.*[^.]\)\.\?$/\1/'`
  done
  
  for j in `seq 0 $((${#hosts[@]}-1))`
  do
    if [ ${use_expect} -eq 0 ] && [ $j -gt 0 ]; then
      echo
      read -p "Try next host ${hosts[$j]} (y/n)? " -n 1 reply
      [ "${reply}" != 'y' ] && echo && break || echo;
    fi
  
    [ -n "$verbose" ] && echo
    if [ ${use_expect} -eq 1 ]; then
      if [ ${exp_script_exe} -eq 1 ]; then
        if [ -n "$verbose" ]; then
          ${_exp_script} ${skip_verify} "${hosts[$j]}" "$i" $timeout
        else
          ${_exp_script} ${skip_verify} "${hosts[$j]}" "$i" $timeout >/dev/null
        fi
      else
        if [ -n "$verbose" ]; then
          ${_exp} ${_exp_script} ${skip_verify} "${hosts[$j]}" "$i" $timeout
        else
          ${_exp} ${_exp_script} ${skip_verify} "${hosts[$j]}" "$i" $timeout >/dev/null
        fi
      fi
  
      exit_code=$?
      if [ $exit_code -eq 0 ]; then
        if [ -n "$verbose" ]; then
          ( echo "
<$i>
is most certainly an e-mail address." ) | $fmt
        else
          echo "<$i>${tab}+${tab}OK"
        fi
        
        break
      fi
    else
      telnet -- "${hosts[$j]}" smtp
    fi  
  done
  
  if [ $use_expect -eq 1 ] && [ $exit_code -ne 0 ]; then
    if [ -n "$verbose" ]; then
      case $exit_code in
        1)
        ( echo "
<$i>
is apparently not an e-mail address (delivery impossible)." ) | $fmt;;
        2) ( echo "
<$i>
could not be verified." ) | $fmt;;
        3) ( echo "
<$i>
is definitely not an e-mail address (invalid MXs)." ) | $fmt;;
        *) ( echo "
<$i>
could not be verified (reason unknown)." ) | $fmt;;
      esac
    else
      case $exit_code in
        1) echo "<$i>${tab}-${tab}CANNOT_DELIVER";;
        2) echo "<$i>${tab}?${tab}CANNOT_VERIFY";;
        3) echo "<$i>${tab}-${tab}INVALID_MXS";;
        *) echo "<$i>${tab}?${tab}UNKNOWN";;
      esac  
    fi
  fi
done

exit ${exit_code}
