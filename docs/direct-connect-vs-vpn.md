# Site-to-Site VPN or Direct Connect?

These services solve related problems, but they are not interchangeable.

| Question | Site-to-Site VPN | Direct Connect |
| --- | --- | --- |
| Path | Encrypted tunnels over the public internet | Dedicated connection into the AWS network |
| Provisioning | Usually minutes to hours after router readiness | Often weeks or longer, including provider work |
| Capacity | Per-tunnel limits; ECMP can increase aggregate capacity on supported designs | Port or hosted-connection bandwidth options with more predictable throughput |
| Performance | Internet path can vary | More consistent latency and throughput |
| Encryption | IPsec encryption is built into the design | Not encrypted by default; use MACsec where supported or an IPsec VPN over Direct Connect |
| Cost profile | Low entry cost plus hourly and transfer charges | Port-hours, provider/circuit, location, and transfer charges |
| Best fit | Fast setup, branch connectivity, labs, backup, moderate workloads | Predictable high-volume transfer, private deterministic connectivity, steady enterprise traffic |

## Decision rule

Start with Site-to-Site VPN when delivery speed and cost matter more than predictable network performance. Move to Direct Connect when measured traffic volume, latency variation, or business requirements justify a dedicated circuit. A mature design often uses Direct Connect as the primary path and VPN as an independent backup.

Direct Connect still needs redundancy. Production designs commonly use connections in separate locations and customer routers, with BGP controlling failover. One circuit is not a high-availability design.

## Migration path for this project

1. Order a Direct Connect or hosted connection.
2. Create a Direct Connect gateway and associate it with the Transit Gateway.
3. Configure the private virtual interface and BGP session.
4. Control route preference using BGP attributes and test both directions.
5. Keep the existing VPN until Direct Connect behavior is verified.
6. Retain VPN as backup if the recovery requirement calls for path diversity.

For encrypted private VPN over Direct Connect, AWS supports a Site-to-Site VPN whose outside IP type is private IPv4 and whose transport attachment comes from a Direct Connect gateway association. That is a different design from an ordinary public-internet VPN.

