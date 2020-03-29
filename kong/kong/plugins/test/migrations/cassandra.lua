-- cassandra.lua
return {
  {
    name = "2015-07-31-172400_init_keyauth_test",
    up =  [[
      CREATE TABLE IF NOT EXISTS test(
        id uuid,
        consumer_id uuid,
        key text,
        created_at timestamp,
        PRIMARY KEY (id)
      );

      CREATE INDEX IF NOT EXISTS ON test(key);
      CREATE INDEX IF NOT EXISTS keyauth_consumer_id ON test(consumer_id);
    ]],
    down = [[
      DROP TABLE test;
    ]]
  }
}