SET client_min_messages TO error;

CREATE TABLE no_history_system_period (a bigint, "b b" date, sys_period tstzrange);

CREATE TABLE no_history_system_period_history (a bigint, "b b" timestamp);

CREATE TRIGGER versioning_trigger
BEFORE INSERT OR UPDATE OR DELETE ON no_history_system_period
FOR EACH ROW EXECUTE PROCEDURE versioning('sys_period', 'no_history_system_period_history', true);

INSERT INTO no_history_system_period DEFAULT VALUES;

DELETE FROM no_history_system_period;