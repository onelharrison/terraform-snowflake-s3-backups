locals {
  sys_admin_role = "SYSADMIN"
  snowflake_user = "ONEL_HARRISON"
}

data "snowflake_current_account" "this" {}

resource "snowflake_database" "sandbox" {
  provider = snowflake.sys_admin
  name = "SANDBOX"
}

resource "snowflake_role" "sandbox_rw" {
  provider = snowflake.security_admin
  name = "SANDBOX_RW"
}

resource "snowflake_role_grants" "sandbox_rw" {
  provider = snowflake.security_admin
  role_name = snowflake_role.sandbox_rw.name

  roles = [
    local.sys_admin_role
  ]

  users = [
    local.snowflake_user
  ]
}

resource "snowflake_schema" "sandbox_tools" {
  provider = snowflake.sys_admin
  database = snowflake_database.sandbox.name
  name     = "TOOLS"
}

resource "snowflake_schema" "sandbox_activity" {
  provider = snowflake.sys_admin
  database = snowflake_database.sandbox.name
  name     = "ACTIVITY"
}

resource "snowflake_table" "sandbox_activity_users" {
  provider = snowflake.sys_admin
  database = snowflake_database.sandbox.name
  schema   = snowflake_schema.sandbox_activity.name

  name     = "USERS"

  column {
    name = "ID"
    type = "STRING"
    nullable = false
  }

  column {
    name = "NAME"
    type = "STRING"
    nullable = false
  }
}

resource "snowflake_table" "sandbox_activity_events" {
  provider = snowflake.sys_admin
  database = snowflake_database.sandbox.name
  schema   = snowflake_schema.sandbox_activity.name

  name     = "EVENTS"

  column {
    name = "ID"
    type = "STRING"
    nullable = false
  }

  column {
    name = "USER_ID"
    type = "STRING"
    nullable = false
  }

  column {
    name = "EVENT_TYPE"
    type = "STRING"
    nullable = false
  }

  column {
    name = "EVENT_TS"
    type = "TIMESTAMP"
    nullable = false
  }
}

resource "snowflake_database_grant" "usage_sandbox_database" {
  provider = snowflake.security_admin
  database_name = snowflake_database.sandbox.name
  privilege     = "USAGE"

  roles = [
    snowflake_role.sandbox_rw.name,
    snowflake_role.task_admin.name
  ]
}

resource "snowflake_schema_grant" "usage_sandbox_activity" {
  provider = snowflake.security_admin
  database_name = snowflake_database.sandbox.name
  schema_name   = snowflake_schema.sandbox_activity.name
  privilege     = "USAGE"

  roles = [
    snowflake_role.sandbox_rw.name
  ]
}

resource "snowflake_schema_grant" "usage_sandbox_tools" {
  provider = snowflake.security_admin
  database_name = snowflake_database.sandbox.name
  schema_name   = snowflake_schema.sandbox_tools.name
  privilege     = "USAGE"

  roles = [
    snowflake_role.sandbox_rw.name,
    snowflake_role.task_admin.name
  ]
}

resource "snowflake_table_grant" "select_sandbox_tables" {
  provider = snowflake.security_admin
  database_name = snowflake_database.sandbox.name
  privilege     = "SELECT"

  roles = [
    snowflake_role.sandbox_rw.name
  ]

  on_future = true
}

resource "snowflake_table_grant" "insert_sandbox_tables" {
  provider = snowflake.security_admin
  database_name = snowflake_database.sandbox.name
  privilege     = "INSERT"

  roles = [
    snowflake_role.sandbox_rw.name
  ]

  on_future = true
}

resource "snowflake_table_grant" "update_sandbox_tables" {
  provider = snowflake.security_admin
  database_name = snowflake_database.sandbox.name
  privilege     = "UPDATE"

  roles = [
    snowflake_role.sandbox_rw.name
  ]

  on_future = true
}

resource "snowflake_table_grant" "truncate_sandbox_tables" {
  provider = snowflake.security_admin
  database_name = snowflake_database.sandbox.name
  privilege     = "TRUNCATE"

  roles = [
    snowflake_role.sandbox_rw.name
  ]

  on_future = true
}

resource "snowflake_table_grant" "delete_sandbox_tables" {
  provider = snowflake.security_admin
  database_name = snowflake_database.sandbox.name
  privilege     = "DELETE"

  roles = [
    snowflake_role.sandbox_rw.name
  ]

  on_future = true
}

resource "snowflake_storage_integration" "snowflake_s3_backup" {
  provider = snowflake.account_admin
  name    = "SNOWFLAKE_S3_BACKUP"
  comment = "A storage integration for handling Snowflake S3 backups"
  type    = "EXTERNAL_STAGE"

  enabled = true

  storage_allowed_locations = ["s3://${aws_s3_bucket.snowflake_backups_bucket.bucket}/"]

  storage_provider      = "S3"
  storage_aws_role_arn  = aws_iam_role.snowflake.arn
}

resource "snowflake_integration_grant" "usage_snowflake_s3_backup_integration" {
  provider = snowflake.security_admin
  integration_name = snowflake_storage_integration.snowflake_s3_backup.name

  privilege = "USAGE"

  roles = [
    snowflake_role.sandbox_rw.name
  ]
}

resource "snowflake_stage" "snowflake_s3_backup" {
  provider    = snowflake.account_admin
  name        = "SNOWFLAKE_S3_BACKUP"
  url         = "s3://${aws_s3_bucket.snowflake_backups_bucket.bucket}/"
  database    = snowflake_database.sandbox.name
  schema      = snowflake_schema.sandbox_tools.name
  file_format = "TYPE=CSV COMPRESSION=GZIP FIELD_OPTIONALLY_ENCLOSED_BY= '\"' SKIP_HEADER=1"
  storage_integration = snowflake_storage_integration.snowflake_s3_backup.name
}

resource "snowflake_stage_grant" "snowflake_s3_backup" {
  provider      = snowflake.security_admin
  database_name = snowflake_stage.snowflake_s3_backup.database
  schema_name   = snowflake_stage.snowflake_s3_backup.schema
  roles         = [
    snowflake_role.sandbox_rw.name,
  ]
  privilege     = "USAGE"
  stage_name    = snowflake_stage.snowflake_s3_backup.name
}

resource "snowflake_procedure" "backup_database" {
  provider = snowflake.sys_admin
  name     = "SPROC_BACKUP_DATABASE"
  database = snowflake_database.sandbox.name
  schema   = snowflake_schema.sandbox_tools.name

  arguments {
    name = "DATABASE"
    type = "VARCHAR"
  }

  comment             = "Procedure for backuping up a database to S3"
  return_type         = "VARCHAR"
  execute_as          = "CALLER"
  return_behavior     = "IMMUTABLE"
  null_input_behavior = "RETURNS NULL ON NULL INPUT"
  statement           = file("${path.module}/stored_procedures/sproc_backup_database.js")
}

resource "snowflake_procedure_grant" "usage_sproc_backup_database" {
  provider = snowflake.security_admin
  database_name   = snowflake_database.sandbox.name
  schema_name     = snowflake_schema.sandbox_tools.name
  procedure_name  = snowflake_procedure.backup_database.name

  arguments {
    name = "DATABASE"
    type = "VARCHAR"
  }

  return_type = "VARCHAR"
  privilege   = "USAGE"

  roles = [
    snowflake_role.sandbox_rw.name
  ]
}

resource "snowflake_warehouse" "warehouse" {
  provider = snowflake.sys_admin
  name = "COMPUTE_WH"
  warehouse_size = "XSMALL"
}

resource "snowflake_warehouse_grant" "usage_warehouse" {
  provider = snowflake.security_admin
  warehouse_name = snowflake_warehouse.warehouse.name

  privilege = "USAGE"

  roles = [
    snowflake_role.sandbox_rw.name,
    snowflake_role.task_admin.name
  ]
}

resource "snowflake_role" "task_admin" {
  provider = snowflake.security_admin
  name     = "TASKADMIN"
}

resource "snowflake_role_grants" "task_admin_grants" {
  provider = snowflake.security_admin
  role_name = snowflake_role.task_admin.name

  roles = [
    local.sys_admin_role
  ]

  users = [
    local.snowflake_user
  ]
}

resource "snowflake_account_grant" "execute_task" {
  provider  = snowflake.account_admin
  roles     = [
    snowflake_role.task_admin.name
  ]
  privilege = "EXECUTE TASK"
}

resource "snowflake_account_grant" "execute_managed_task" {
  provider  = snowflake.account_admin
  roles     = [
    snowflake_role.task_admin.name
  ]
  privilege = "EXECUTE MANAGED TASK"
}

resource "snowflake_task" "backup_sandbox_database" {
  provider  = snowflake.account_admin # owner role needs to have execute task privilege
  database  = snowflake_database.sandbox.name
  schema    = snowflake_schema.sandbox_tools.name
  enabled   = true
  name      = upper("task_call_${snowflake_procedure.backup_database.name}")
  warehouse = snowflake_warehouse.warehouse.name

  schedule      = "USING CRON 0 2 */30 * * UTC" # Every 30 days at 2am UTC/9pm Eastern
  sql_statement = "CALL ${snowflake_procedure.backup_database.name}('${snowflake_database.sandbox.name}')"
}

resource "snowflake_task_grant" "operate_task_backup_database" {
  provider      = snowflake.account_admin
  database_name = snowflake_database.sandbox.name
  schema_name   = snowflake_schema.sandbox_tools.name
  task_name     = snowflake_task.backup_sandbox_database.name

  privilege = "OPERATE"

  roles = [
    snowflake_role.task_admin.name
  ]
}
