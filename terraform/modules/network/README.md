# Network module

This module owns the environment's virtual network, subnet, network security group, security rules, and subnet-to-NSG association. Its interface uses generic concepts such as address spaces and trusted administrative source ranges while its implementation uses Azure resources.

## Resources

- One virtual network
- One monitoring subnet
- One network security group
- SSH ingress on TCP/22 from trusted administrator CIDRs
- Grafana ingress on TCP/3000 from trusted administrator CIDRs
- One subnet-level NSG association

Prometheus (9090), Alertmanager (9093), and Node Exporter (9100) receive no public ingress rule. Azure's default NSG rules deny other unsolicited inbound internet traffic.

The NSG is associated with the subnet rather than a future network interface, establishing a consistent policy boundary for every workload placed in that subnet.

## Outputs

The module exposes virtual-network, subnet, and NSG identifiers needed by downstream components. The compute module will consume only `subnet_id`, preserving a narrow dependency between modules.

## Cost

The resource group, VNet, subnet, and NSG do not normally carry direct hourly charges. Charges begin with attached services such as the VM, managed disk, public IP, and outbound traffic.
