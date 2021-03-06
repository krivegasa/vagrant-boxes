# Insall EPEL repository

yum -y install epel-release

# Disable firewall and SELinux
systemctl disable firewalld
systemctl stop firewalld
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
setenforce 0
#reboot

yum -y install git ansible python-psycopg2

ansible --version

# for v12 support use github repo
#git clone https://github.com/ANXS/postgresql /home/vagrant/roles/anxs.postgresql

git clone https://github.com/krivegasa/ansible /home/vagrant/ansible
mkdir -p /home/vagrant/roles
mv /home/vagrant/ansible/postgresql /home/vagrant/roles/postgresql

mkdir -p /home/vagrant/host_vars
mkdir -p /home/vagrant/group_vars
chown -R vagrant:vagrant /home/vagrant/

cat > inventory <<EOF
[dbmaster]
#master  ansible_connection=local ansible_python_interpreter="/usr/libexec/platform-python"
master  ansible_host=192.168.4.2
[dbslave]
slave1  ansible_host=192.168.4.3
slave2  ansible_host=192.168.4.4
slave3  ansible_host=192.168.4.5
slave4  ansible_host=192.168.4.6
slave5  ansible_host=192.168.4.7
slave6  ansible_host=192.168.4.8
EOF


#create group vars files
cat > /home/vagrant/group_vars/dbslave.yaml <<EOF
      postgresql_is_slave: "yes"
      masterip: master

      masterpass: postgres123

      postgresql_pg_hba_custom:
         - { type: host,  database: all, user: all, address: "10.0.0.0/8",   method: "{{ postgresql_default_auth_method_hosts }}", comment: "Enable external connections:" }
         - { type: host,  database: all, user: all, address: "192.168.4.0/24",   method: "{{ postgresql_default_auth_method_hosts }}", comment: "Enable external connections:" }
EOF


#create host vars files
cat > /home/vagrant/host_vars/master.yaml <<EOF
#prepare for standby
postgresql_wal_level: hot_standby
postgresql_wal_log_hints: on
postgresql_max_wal_senders: 64
postgresql_wal_keep_segments: 128
postgresql_hot_standby: on
postgresql_users:
   - name: replicate
     pass: replicate123
   - name: postgres
     pass: postgres123

postgresql_pg_hba_custom:
   - { type: host,  database: all, user: all, address: "10.0.0.0/8",   method: "{{ postgresql_default_auth_method_hosts }}", comment: "Enable external connections:" }
   - { type: host,  database: all, user: all, address: "192.168.4.0/24",   method: "{{ postgresql_default_auth_method_hosts }}", comment: "Enable external connections:" }
   - { type: host,  database: replication, user: all, address: "192.168.4.0/24",   method: "{{ postgresql_default_auth_method_hosts }}", comment: "Enable external connections:" }

postgresql_databases:
   - name: db01
     owner: postgres

postgresql_database_extensions:
  - db: db01
    extensions:
       - pg_stat_statements

postgresql_user_privileges:
   - name: replicate
     db: db01
     priv: "ALL"
     role_attr_flags: "SUPERUSER"
# flags: "LOGIN,SUPERUSER"
EOF

cat > pg-all.yaml <<EOF
- hosts: all
  become: yes
  pre_tasks:
   - name: Enabling epel repository
     yum:
       name:
          - epel-release
       state: latest
     tags: software

   - name: Install packages
     yum:
       state: latest
       name:
          - zip
          - unzip
          - atop
          - wget
          - mytop
          - htop
          - mc
          - telnet
          - net-tools
     tags: software
   - name: Add IP address of all hosts to all hosts
     lineinfile:
          dest: /etc/hosts
          regexp: '.*{{ item }}$'
          line: "{{ hostvars[item].ansible_host }} {{item}}"
          state: present
     when: hostvars[item].ansible_host is defined
     with_items: "{{ groups.all }}"
     tags: etc_hosts

  vars:
     postgresql_version: 10
     postgresql_ext_install_contrib: yes
     postgresql_listen_addresses: "*"
     postgresql_max_connections: 150
     postgresql_data_directory: "/u01/data"
     postgresql_conf_directory: "{{ postgresql_data_directory }}"
     postgresql_shared_preload_libraries: 
        - pg_stat_statements
     postgresql_extensions:
        - hstore
        - pg_stat_statements
  roles:
    - role: postgresql

EOF

ssh-keygen -q -t rsa -N '' -f ~/.ssh/id_rsa

sed -i -e "s|#ChallengeResponseAuthentication yes|ChallengeResponseAuthentication yes|g" /etc/ssh/sshd_config
sed -i -e "s|ChallengeResponseAuthentication no|#ChallengeResponseAuthentication no|g" /etc/ssh/sshd_config
service sshd restart

echo "vagrant" | sshpass  ssh-copy-id root@192.168.4.2 -f  -o StrictHostKeyChecking=no
echo "vagrant" | sshpass  ssh-copy-id root@192.168.4.3 -f  -o StrictHostKeyChecking=no
echo "vagrant" | sshpass  ssh-copy-id root@192.168.4.4 -f  -o StrictHostKeyChecking=no
echo "vagrant" | sshpass  ssh-copy-id root@192.168.4.5 -f  -o StrictHostKeyChecking=no
echo "vagrant" | sshpass  ssh-copy-id root@192.168.4.6 -f  -o StrictHostKeyChecking=no
echo "vagrant" | sshpass  ssh-copy-id root@192.168.4.7 -f  -o StrictHostKeyChecking=no
echo "vagrant" | sshpass  ssh-copy-id root@192.168.4.8 -f  -o StrictHostKeyChecking=no

cat > pg.sh << EOF
export ANSIBLE_FORCE_COLOR=true
ansible-playbook -i inventory pg-all.yaml
EOF
sh pg.sh
# check version and replication
su -l postgres -c "psql --version"
su -l postgres -c "psql -c \"SELECT pid,usesysid,usename,client_addr,client_port,backend_start,state,sync_priority,sync_state FROM pg_stat_replication;\""
