# Build the default ignore file used by the `svckill::ignore` define.
#
# @param default_ignore_file  The path to the ignore file.
#
# @author Trevor Vaughan <tvaughan@onyxpoint.com>
#
class svckill::ignore::collector (
  Stdlib::Absolutepath $default_ignore_file = '/usr/local/etc/svckill.ignore'
){
  simpcat_build { 'svckill_ignore':
    order  => ['*.ignore'],
    target => $default_ignore_file,
    quiet  => true
  }
}
