let schemaTablePairResult = getSchemaTablePairResult(DATABASE);

while (schemaTablePairResult.next()) {
  let schema = schemaTablePairResult.getColumnValue(1);
  let table = schemaTablePairResult.getColumnValue(2);

  copyToS3(DATABASE, schema, table);
}

return `Database '${DATABASE}' successfully backed up to S3.`;

function getCurrentDate() {
  let sqlResult = snowflake.execute({
    sqlText: `SELECT TO_VARCHAR(CURRENT_DATE());`,
  });
  sqlResult.next();
  return sqlResult.getColumnValue(1);
}

function getExternalStageName(database) {
  let sqlResult = snowflake.execute({
    sqlText: `SELECT s.stage_name
		FROM ${database}.information_schema.stages s
		WHERE s.stage_name = 'SNOWFLAKE_S3_BACKUP'
		AND s.stage_type = 'External Named'
		`,
  });
  sqlResult.next();
  return sqlResult.getColumnValue(1);
}

function getSchemaTablePairResult(database) {
  return snowflake.execute({
    sqlText: `SELECT t.table_schema, t.table_name
    FROM ${database}.information_schema.tables t
    WHERE t.table_type = 'BASE TABLE'
    `,
  });
}

function copyToS3(database, schema, table) {
  snowflake.execute({
    sqlText: `COPY INTO @SANDBOX.TOOLS.SNOWFLAKE_S3_BACKUP/${getCurrentDate()}/${database}/${schema}/${table}/data_
	FROM ${database}.${schema}.${table}
	HEADER = true
	OVERWRITE = true
	MAX_FILE_SIZE = 104857600
	`,
  });
}
