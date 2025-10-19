# Infra Stack Security Hardening

## Compose Best Practices
- All containers run as non-root (`user: 1000:1000` or `999:999` for DB)
- Filesystems are read-only (`read_only: true`)
- All capabilities dropped (`cap_drop: [ALL]`)
- API container uses `no-new-privileges: true`
- Resource limits set (CPU/memory)
- Only necessary ports exposed; restrict externally via firewall

## .env Secrets
- Use strong, random secrets for all passwords and tokens
- Never commit real secrets to git
- Rotate credentials regularly

## Network
- Expose only API port (APP_PORT) externally; keep Prometheus/Grafana/PgAdmin internal or behind VPN/reverse proxy
- Use UFW or similar firewall on host

## Backup & Replication
- Use pgBackRest or cron+pg_dump for automated backups
- For high availability, configure streaming replication to a reserve DB VM
- Test restores regularly

## Monitoring & Logging
- Prometheus and Grafana for metrics
- Loki/Promtail for logs (see observability stack)

## Example: UFW Firewall
```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 18001/tcp    # API only
sudo ufw enable
```

## Example: Backup Cron
```bash
0 2 * * * PGPASSWORD='<pass>' pg_dump -h <IP_primario> -U ea -d ea | gzip > /srv/backups/ea_$(date +\%F).sql.gz
```

## Example: Streaming Replication (Postgres)
- Configure `pg_hba.conf` to allow replica IP
- Use `pg_basebackup` to initialize
- Set up replication slots and monitor lag

## Additional Recommendations
- Use TLS for API if exposed externally
- Consider reverse proxy (Caddy/Traefik) for rate limiting and access control
- Monitor container health endpoints
