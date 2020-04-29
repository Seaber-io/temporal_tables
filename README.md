
# Temporal Tables

_Version: 0.2.0_

This is an attempt to rewrite the postgresql [temporal_tables](https://github.com/arkhipov/temporal_tables) extension in PL/pgSQL, without the need for external c extension.

The goal is to be able to use it on AWS RDS and other hosted solutions, where using custom extensions or c functions is not an option.

The version provided in `versioning_function.sql` is a drop-in replacement.

It works exactly the same way, but lacks the [set_system_time](https://github.com/arkhipov/temporal_tables#advanced-usage) function to work with the current time.

The version in `versioning_function_nochecks.sql` is similar to the previous one, but all validation checks have been removed. This version is 2x faster than the normal one, but more dangerous and prone to errors.

<a name="usage"></a>
## Usage

Create a database and the versioning function:

```sh
createdb temporal_test
psql temporal_test < versioning_function.sql
```

Connect to the db:

```
psql temporal_test
```

Create the table to version, in this example it will be a "subscription" table:

```sql
CREATE TABLE subscriptions
(
  name text NOT NULL,
  state text NOT NULL
);
```

Add the system period column:

```sql
ALTER TABLE subscriptions
  ADD COLUMN sys_period tstzrange NOT NULL DEFAULT tstzrange(current_timestamp, null);
```

Create the history table:

```sql
CREATE TABLE subscriptions_history (LIKE subscriptions);
```

Finally, create the trigger:

```sql
CREATE TRIGGER versioning_trigger
BEFORE INSERT OR UPDATE OR DELETE ON subscriptions
FOR EACH ROW EXECUTE PROCEDURE versioning(
  'sys_period', 'subscriptions_history', true
);
```

Now test with some data:

```sql
INSERT INTO subscriptions (name, state) VALUES ('test1', 'inserted');
UPDATE subscriptions SET state = 'updated' WHERE name = 'test1';
UPDATE subscriptions SET state = 'updated twice' WHERE name = 'test1';
DELETE FROM subscriptions WHERE name = 'test1';
```

Take some time between a query and the following, otherwise the difference in the time periods won't be noticeable.

After all the query are completed, you should check the tables content.

```sql
SELECT * FROM subscriptions;
```

Should return 0 rows

```sql
SELECT * FROM subscriptions_history
```

Should return something similar to:


name  |     state     |                            sys_period
----- | ------------- | -------------------------------------------------------------------
 test1 | inserted      | ["2017-08-01 16:09:45.542983+02","2017-08-01 16:09:54.984179+02")
 test1 | updated       | ["2017-08-01 16:09:54.984179+02","2017-08-01 16:10:08.880571+02")
 test1 | updated twice | ["2017-08-01 16:10:08.880571+02","2017-08-01 16:10:17.33659+02")

<a name="migrations"></a>
## Migrations

During the life of an application is may be necessary to change the schema of a table. In order for temporal_tables to continue to work properly the same migrations should be applied to the history table as well.

### What happens if a column is added to the original table but not to the history table?

The new column will be ignore, meaning that the updated row is transferred to the history table, but without the value of the new column. This means that you will lose that specific data.

There are valid use case for this, in example when you are not interested in storing the historic values of that column.

**Beware that temporal_tables won't raise an error**

### What should I do if I need to remove a column from the original table but want to keep the historic values for it?

You remove the column in the original table, but keep it in the history table - provided it accepts null values.

From that point on the old column in the history table will be ignored and will get null values.

If the column doesn't accept null values you'll need to modify it to allow for null values, otherwise temporal_tables won't be able to create new rows and all operations on the original table will fail

<a name="test"></a>
## Test

In order to run tests:

```sh
make run_test
```

The test suite will run the queries in test/sql and store the output in test/result, and will then diff the output from test/result with the prerecorded output in test/expected.

A test suite is also available for the nochecks alternative:

```sh
make run_test_nochecks
```

Obviously, this suite won't run the tests about the error reporting.

<a name="performance_tests"></a>
## Performance tests

For performance tests run:

```sh
make performance_test
```

This will create the temporal_tables_test database, add all necessary tables, run test tests and drop the database.

Is it also possible to test against the nochecks version:

```sh
make performance_test_nochecks
```

or the original c extension run:

```sh
make performance_test_original
```

This required the original extentions to be installed, but will automatically add it to the database.

On the test machine (my laptop) the complete version is 2x slower than the nochecks versions and 16x slower than the original version.

Two comments about those results:
- original c version makes some use of caching (i.e to share an execution plan), whilst this version doesn't. This is propably accounting for a good chunk of the performance difference. At the moment there's not plan of implementing such caching in this version.
- The trigger still executes in under 1ms and in production environments the the network latency should be more relevant than the trigger itself.

### Run tests in Docker

Create the container for running tests:

```sh
docker run -d -v $(pwd):/tmp --name temporal_tables_test -e POSTGRES_PASSWORD=postgres postgres:alpine
```

If container has been created but not running:

```sh
docker start temporal_tables_test
```

Run bash inside the container:

```sh
docker exec -ti temporal_tables_test bash
```

From inside the Docker container:

```sh
cd /tmp && PGUSER=postgres PGPASSWORD=postgres make run_test
```

<a name="the-team"></a>
## The team

### Paolo Chiodi

[https://github.com/paolochiodi](https://github.com/paolochiodi)

[https://twitter.com/paolochiodi](https://twitter.com/paolochiodi)

<a name="acknowledgements"></a>
## Acknowledgements

This project was kindly sponsored by [nearForm](http://nearform.com).

## License

Licensed under [MIT](./LICENSE).

The test scenarios in test/sql and test/expected have been copied over from the original temporal_tables extension, whose license is [BSD 2-clause](https://github.com/arkhipov/temporal_tables/blob/master/LICENSE)
