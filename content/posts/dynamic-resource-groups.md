---
title: "Updating resource groups without restarting Trino"
date: 2022-02-07T10:25:06-05:00
draft: false
---

[Resource groups](https://trino.io/docs/current/admin/resource-groups.html) is
an admission control feature in Trino. Typically, this is configured by storing
the resource groups configuration in a JSON file and telling Trino where to read
this file from. Any updates to the JSON file are not reflected in Trino until 
the cluster is restarted.

Recently, I was working on a cluster that had a requirement to be able to update
resource group defintions without restarting the cluster. Trino does have support
for a database-based resource group manager. This means Trino will load the 
resource group definitions from a relational database instead of a JSON file. The
supported databases are MySQL, PostgreSQL, and Oracle (in versions prior to 369,
only MySQL is supported).

To configure Trino to use a database-based resource group manager, add an
`etc/resource-groups.properties` file. Here is an example of the file contents
when using a MySQL database for storing resource group definitions:

```
resource-groups.configuration-manager=db
resource-groups.config-db-url=jdbc:mysql://localhost:3306/resource_groups
resource-groups.config-db-user=trino
resource-groups.config-db-password=trino
```

The resource groups are configured through tables
`resource_groups_global_properties`, `resource_groups`, and `selectors`.
If any of the tables are not present when Trino starts, they will be created
automatically.

The rules in the `selectors` table are processed in descending order of the
values in the `priority` field.

The `resource_groups` table also contains an `environment` field which is
matched with the value contained in the `node.environment` property in
`node.properties`. This allows the resource group configuration for different
Trino clusters to be stored in the same database.

The configuration is reloaded from the database every second, and the changes
are reflected automatically for incoming queries. 

Once Trino is configured to use a database resource group manager, you will
see something like the following in the `server.log` file on startup:

```
2022-02-03T20:20:09.623-0500	INFO	main	io.trino.execution.resourcegroups.InternalResourceGroupManager	-- Loading resource group configuration manager --
2022-02-03T20:20:09.818-0500	INFO	main	io.trino.plugin.resourcegroups.db.FlywayMigration	Performing migrations...
2022-02-03T20:20:10.173-0500	INFO	main	org.flywaydb.core.internal.license.VersionPrinter	Flyway Community Edition 7.15.0 by Redgate
2022-02-03T20:20:10.174-0500	INFO	main	org.flywaydb.core.internal.database.base.BaseDatabaseType	Database: jdbc:mysql://localhost:3306/resource_groups (MySQL 8.0)
2022-02-03T20:20:10.263-0500	INFO	main	org.flywaydb.core.internal.command.DbValidate	Successfully validated 4 migrations (execution time 00:00.045s)
2022-02-03T20:20:10.522-0500	INFO	main	org.flywaydb.core.internal.schemahistory.JdbcTableSchemaHistory	Creating Schema History table `resource_groups`.`flyway_schema_history` ...
2022-02-03T20:20:10.669-0500	INFO	main	org.flywaydb.core.internal.command.DbMigrate	Current version of schema `resource_groups`: << Empty Schema >>
2022-02-03T20:20:10.681-0500	INFO	main	org.flywaydb.core.internal.command.DbMigrate	Migrating schema `resource_groups` to version "1 - add resource groups global properties"
2022-02-03T20:20:10.760-0500	INFO	main	org.flywaydb.core.internal.command.DbMigrate	Migrating schema `resource_groups` to version "2 - add resource groups"
2022-02-03T20:20:10.847-0500	INFO	main	org.flywaydb.core.internal.command.DbMigrate	Migrating schema `resource_groups` to version "3 - add selectors"
2022-02-03T20:20:10.931-0500	INFO	main	org.flywaydb.core.internal.command.DbMigrate	Migrating schema `resource_groups` to version "4 - add exact match source selectors"
2022-02-03T20:20:11.093-0500	INFO	main	org.flywaydb.core.internal.command.DbMigrate	Successfully applied 4 migrations to schema `resource_groups`, now at version v4 (execution time 00:00.435s)
2022-02-03T20:20:11.104-0500	INFO	main	io.trino.plugin.resourcegroups.db.FlywayMigration	Performed 4 migrations
```

Notice the messages related to migrations. This means Trino created the
necessary tables in MySQL because they did not exist. Now the correct schema
exists but there are no resource groups configured.

If you try to run a query in Trino now, you will get an error:

```
trino> show catalogs;
Query 20220204_012217_00000_ajzng failed: No selectors are configured

trino>
```

We will use a tool I put together named [trino-db-resource-groups-cli](https://github.com/posulliv/trino-db-resource-groups-cli)
that can take a JSON file with a resource groups defined and load them into a
database (see the README for instructions on how to install the tool). For
example, assume we have a JSON file with the following contents:

```
{
  "rootGroups": [
    {
      "name": "global",
      "softMemoryLimit": "95%",
      "hardConcurrencyLimit": 100,
      "maxQueued": 1000,
      "subGroups": [
        {
          "name": "adhoc",
          "softMemoryLimit": "50%",
          "hardConcurrencyLimit": 50,
          "maxQueued": 100,
          "hardCpuLimit": "10h",
          "subGroups": [
            {
              "name": "adhoc-${USER}",
              "softMemoryLimit": "30%",
              "hardConcurrencyLimit": 10,
              "maxQueued": 10
            }
          ]
        }
      ]
    },
    {
      "name": "admin",
      "softMemoryLimit": "100%",
      "hardConcurrencyLimit": 500,
      "maxQueued": 100
    }
  ],
  "selectors": [
    {
      "user": "bob",
      "group": "admin"
    },
    {
      "user": "verifier",
      "group": "global.adhoc"
    },
    {
      "source": "jdbc#(?<toolname>.*)",
      "clientTags": ["hipri", "urgent"],
      "group": "global.adhoc.adhoc-${USER}"
    },
    {
      "group": "global.adhoc.adhoc-${USER}"
    }
  ],
  "cpuQuotaPeriod": "1h"
}
```

We run `trino-db-resource-groups-cli` to take this JSON and populate the database
tables for a specific environment. When running the tool, you will see output like:

```
$ trino-db-resource-groups-cli create_resource_groups --db-config=resource-groups.properties --resource-groups-json=example.json --environment=test
2022-02-03T20:23:34.925-0500	INFO	main	io.airlift.log.Logging	Logging to stderr
2022-02-03T20:23:34.928-0500	INFO	main	Bootstrap	Loading configuration
2022-02-03T20:23:35.161-0500	INFO	main	Bootstrap	Initializing logging
2022-02-03T20:23:35.401-0500	INFO	main	Bootstrap	PROPERTY                                      DEFAULT     RUNTIME                                      DESCRIPTION
2022-02-03T20:23:35.401-0500	INFO	main	Bootstrap	resource-groups.config-db-password            [REDACTED]  [REDACTED]                                   Database password
2022-02-03T20:23:35.401-0500	INFO	main	Bootstrap	resource-groups.config-db-url                 ----        jdbc:mysql://localhost:3306/resource_groups
2022-02-03T20:23:35.401-0500	INFO	main	Bootstrap	resource-groups.config-db-user                ----        trino                                        Database user name
2022-02-03T20:23:35.401-0500	INFO	main	Bootstrap	resource-groups.exact-match-selector-enabled  false       false
2022-02-03T20:23:35.401-0500	INFO	main	Bootstrap	resource-groups.max-refresh-interval          1.00h       1.00h                                        Time period for which the cluster will continue to accept queries after refresh failures cause configuration to become stale
2022-02-03T20:23:35.605-0500	INFO	main	io.airlift.bootstrap.LifeCycleManager	Life cycle starting...
2022-02-03T20:23:35.605-0500	INFO	main	io.airlift.bootstrap.LifeCycleManager	Life cycle started
2022-02-03T20:23:35.606-0500	INFO	main	io.trino.resourcegroups.db.CreateResourceGroupsCommand	Environment to update resource groups for: test
2022-02-03T20:23:35.606-0500	INFO	main	io.trino.resourcegroups.db.CreateResourceGroupsCommand	Input JSON file: example.json
2022-02-03T20:23:36.748-0500	INFO	main	io.trino.resourcegroups.db.CreateResourceGroupsCommand	Resource groups created successfully
2022-02-03T20:23:36.749-0500	INFO	main	io.airlift.bootstrap.LifeCycleManager	Life cycle stopping...
2022-02-03T20:23:36.749-0500	INFO	main	io.airlift.bootstrap.LifeCycleManager	Life cycle stopped
$
```

The tool validates the resource groups defined in the JSON file before loading them
into the database tables. If there is any invalid configuration in the input JSON,
the CLI will throw an error and not update the database tables.

Now if we look at the Trino `server.log` file, we see the resource groups have
been loaded from the database automatically:

```
2022-02-03T20:23:37.198-0500	INFO	DbResourceGroupConfigurationManager	io.trino.plugin.resourcegroups.db.DbResourceGroupConfigurationManager	Resource group spec global changed to ResourceGroupSpec{name=global, softMemoryLimit=Optional.empty, maxQueued=1000, softConcurrencyLimit=Optional.empty, hardConcurrencyLimit=100, schedulingPolicy=Optional.empty, schedulingWeight=Optional.empty, jmxExport=Optional[false], softCpuLimit=Optional.empty, hardCpuLimit=Optional.empty}
2022-02-03T20:23:37.199-0500	INFO	DbResourceGroupConfigurationManager	io.trino.plugin.resourcegroups.db.DbResourceGroupConfigurationManager	Resource group spec admin changed to ResourceGroupSpec{name=admin, softMemoryLimit=Optional.empty, maxQueued=100, softConcurrencyLimit=Optional.empty, hardConcurrencyLimit=500, schedulingPolicy=Optional.empty, schedulingWeight=Optional.empty, jmxExport=Optional[false], softCpuLimit=Optional.empty, hardCpuLimit=Optional.empty}
2022-02-03T20:23:37.199-0500	INFO	DbResourceGroupConfigurationManager	io.trino.plugin.resourcegroups.db.DbResourceGroupConfigurationManager	Resource group spec global.adhoc.adhoc-${USER} changed to ResourceGroupSpec{name=adhoc-${USER}, softMemoryLimit=Optional.empty, maxQueued=10, softConcurrencyLimit=Optional.empty, hardConcurrencyLimit=10, schedulingPolicy=Optional.empty, schedulingWeight=Optional.empty, jmxExport=Optional[false], softCpuLimit=Optional.empty, hardCpuLimit=Optional.empty}
2022-02-03T20:23:37.199-0500	INFO	DbResourceGroupConfigurationManager	io.trino.plugin.resourcegroups.db.DbResourceGroupConfigurationManager	Resource group spec global.adhoc changed to ResourceGroupSpec{name=adhoc, softMemoryLimit=Optional.empty, maxQueued=100, softConcurrencyLimit=Optional.empty, hardConcurrencyLimit=50, schedulingPolicy=Optional.empty, schedulingWeight=Optional.empty, jmxExport=Optional[false], softCpuLimit=Optional.empty, hardCpuLimit=Optional[10.00h]}
```

If we try to run a query now, we will see it is successful:

```
trino> show catalogs;
   Catalog
--------------
 blackhole
 druid
 
 Query 20220204_012425_00001_ajzng, FINISHED, 1 node
Splits: 11 total, 11 done (100.00%)
0.94 [0 rows, 0B] [0 rows/s, 0B/s]

trino>
```

We can verify in the web UI that the query was assigned to the correct resource group:

![Trino web UI](/img/trino_dynamic_resource_groups_post.png)

That's all I wanted to cover in this post. If you have any questions or run
into issues when trying this, you can find me on Trino's [slack](https://trino.io/slack.html).
