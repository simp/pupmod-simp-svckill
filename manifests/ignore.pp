#
# == Define: svckill::ignore
#
# Ensure that service $name will not be killed by svckill.
#
# == Parameters
#
# [*name*]
# Type: String
#   The name of the service to prevent from being killed.
#
# == Authors
#   * Trevor Vaughan <tvaughan@onyxpoint.com>
#
define svckill::ignore {
  include 'svckill'

  concat_fragment { "svckill_ignore+$name.ignore": content => "$name\n" }
}
