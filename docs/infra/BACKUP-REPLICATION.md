# Backup & Replication Guide (Timescale/Postgres)

## Automated Backups (pg_dump)
- Schedule daily backups from primary DB to reserve VM
- Example cron (on reserve VM):

```bash
0 2 * * * PGPASSWORD='<pass>' pg_dump -h <IP_primario> -U ea -d ea | gzip > /srv/backups/ea_$(date +\%F).sql.gz
```
- Rotate backups and test restores regularly

## Streaming Replication (High Availability)
- On primary, configure `pg_hba.conf` to allow replica IP
- Create replication user:
```sql
CREATE USER replica WITH REPLICATION ENCRYPTED PASSWORD 'strongpassword';
```
- On reserve VM, initialize with:
```bash
pg_basebackup -h <IP_primario> -D /var/lib/postgresql/15/main -U replica -P --wal-method=stream
```
- Set up `primary_conninfo` in `postgresql.conf` on reserve
- Monitor replication lag and status

## Tools
- [pgBackRest](https://pgbackrest.org/) for advanced backup/restore
- [repmgr](https://repmgr.org/) for replication management

## Restore Example
```bash
gunzip -c /srv/backups/ea_2025-10-18.sql.gz | psql -U ea -d ea
```

## Recommendations
- Store backups offsite or in cloud for disaster recovery
- Automate alerts for backup/replication failures
- Document and test recovery procedures
