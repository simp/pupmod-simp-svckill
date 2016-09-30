# Ensure that service $name will not be killed by svckill.
#
# @param name [String] The name of the service to prevent from being killed.
#
# @author Trevor Vaughan <tvaughan@onyxpoint.com>
#
define svckill::ignore {
  include '::svckill::ignore::collector'

  simpcat_fragment { "svckill_ignore+${name}.ignore": content => "${name}\n" }
}
