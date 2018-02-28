name "webserver"
description "Example webserver"

default_attributes "audit" => {
    "reporter" => "chef-server-automate",
    "profiles" => [
        {
            "name": "ssh-baseline",
            "compliance": "admin/ssh-baseline",
        }
    ]
}

run_list(
  "recipe[chef-client]",
  "recipe[ssh-hardening]",
  "recipe[nginx]",
  "recipe[inspec-page]",
  "recipe[audit]",
)