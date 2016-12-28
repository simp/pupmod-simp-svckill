# Ensure that service ``$name`` will not be killed by svckill
#
# @param name [String]
#   The name of the service to prevent being killed
#
# @author Trevor Vaughan <tvaughan@onyxpoint.com>
#
define svckill::ignore {
  include '::svckill::ignore::collector'

  ensure_resource('concat::fragment', "svckill_ignore_${name}", {
    'target'  => $::svckill::ignore::collector::default_ignore_file,
    'content' => $name
  })
}
