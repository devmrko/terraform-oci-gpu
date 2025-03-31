import json
import subprocess
import csv

# Run `terraform output -json` and parse
# result = subprocess.run(["terraform", "output", "-json"], capture_output=True, text=True)

import subprocess

result = subprocess.run(
    ["terraform", "output", "-json"],
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE
)

outputs = json.loads(result.stdout.decode("utf-8"))

#outputs = json.loads(result.stdout)

names = outputs["instance_names"]["value"]
ips = outputs["instance_public_ips"]["value"]
keys = outputs["instance_private_keys"]["value"]

# Save to inventory.ini
with open("inventory.ini", "w") as f:
    f.write("[gpu_nodes]\n")
    for name, ip, key_path in zip(names, ips, keys):
        f.write(f"{ip} ansible_user=ubuntu ansible_ssh_private_key_file={key_path}\n")

# Save to gpu_vm_list.csv
with open("gpu_vm_list.csv", "w", newline="") as f:
    writer = csv.writer(f)
    writer.writerow(["Instance Name", "Public IP", "Private Key Path"])
    for name, ip, key_path in zip(names, ips, keys):
        writer.writerow([name, ip, key_path])

print("# CSV and inventory.ini created successfully.")

