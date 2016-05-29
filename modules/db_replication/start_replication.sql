CHANGE MASTER TO
MASTER_HOST = '${master_ip}',
MASTER_USER = '${user_name}',
MASTER_PASSWORD = '${password}';
START SLAVE;
