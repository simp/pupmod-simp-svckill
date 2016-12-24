# Build the default ignore file used by the ``svckill::ignore`` define.
#
# @param default_ignore_file
#   The path to the ignore file
#
# @author Trevor Vaughan <tvaughan@onyxpoint.com>
#
class svckill::ignore::collector (
  Stdlib::Absolutepath $default_ignore_file = '/usr/local/etc/svckill.ignore'
){
  concat { $default_ignore_file:
    owner          => 'root',
    group          => 'root',
    mode           => '0600',
    ensure_newline => true,
    warn           => true
  }
}
