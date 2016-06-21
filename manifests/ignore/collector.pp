# Build the default ignore file used by the `svckill::ignore` define.
#
# @param default_ignore_file [Absolute Path] The path to the ignore file.
#
# @author Trevor Vaughan <tvaughan@onyxpoint.com>
#
class svckill::ignore::collector (
  $default_ignore_file = '/usr/local/etc/svckill.ignore'
){

  validate_absolute_path($default_ignore_file)

  concat_build { 'svckill_ignore':
    order  => ['*.ignore'],
    target => $default_ignore_file,
    quiet  => true
  }
}
