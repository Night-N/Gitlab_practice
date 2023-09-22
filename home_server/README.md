## Installing gitlab and gitlab runner on local home server.

## Gitlab community edition install 
```
apt-get install -y curl openssh-server ca-certificates tzdata perl
curl -LO https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh
chmod +x script.deb.sh
./script.deb.sh
apt install gitlab-ce
```

## Openssl keys for local domain gitlab.local
- gitlab will be accessible under local domain gitlab.local through https protocol
- generate root certificate and key file
```
openssl genrsa -aes256 -out rootCA.key 4096
openssl req -x509 -new -nodes -key rootCA.key -sha256 -days 3650 -out rootCA.crt -subj '/CN=Your Root CA/C=RU/ST=YourState/L=RU/O=Your Organization'
```
- generate certificate for domain gitlab.local
```
openssl req -new -nodes -out ubuntu-home.csr -newkey rsa:4096 -keyout ubuntu-home.key -subj '/CN=Gitlab Server/C=RU/ST=YourState/L=YourCity/O=Your Organization'
```
- sign certificate. Should be signed using SAN extention (provided in file gitlab.v3.ext), otherwise runner won't connect to gitlab instance. 
```
openssl x509 -req -in ubuntu-home.csr -CA rootCA.crt -CAkey rootCA.key -CAcreateserial -out ubuntu-home.crt -days 825 -sha256 -extfile gitlab.v3.ext
```
gitlab.v3.ext
```
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = gitlab.local
DNS.2 = localhost
IP.1 = 192.168.0.52
```

- copy certificate to gitlab folder and reconfigure it.
```
cp ubuntu-home.crt /etc/gitlab/ssl/gitlab.local.crt
cp ubuntu-home.key /etc/gitlab/ssl/gitlab.local.key
gitlab-ctl reconfigure
```
- copy certificate to gitlab runner folder, which later will be mounted into container
```
cp ubuntu-home.crt /srv/gitlab-runner/certs/ca.crt
```
## Gitlab
Modify /etc/gitlab/gitlab.rb and reconfigure
```
external_url 'https://gitlab.local'
letsencrypt['enable'] = false
gitlab-ctl reconfigure
```


## Gitlab runner
- runner is started in docker container:
```
docker run -d --name gitlab-runner --restart always --network host \
-v /srv/gitlab-runner:/etc/gitlab-runner \
-v /var/run/docker.sock:/var/run/docker.sock \
gitlab/gitlab-runner:latest
```
- config.toml for runner:
```
concurrent = 1
check_interval = 0
shutdown_timeout = 0

[session_server]
  session_timeout = 1800

[[runners]]
  name = "Docker runner"
  url = "https://gitlab.local"
  id = 1
  token = "TOKEN_OBTAINED_FROM_GITLAB_GUI"
  token_obtained_at = 2023-09-20T18:00:04Z
  token_expires_at = 0001-01-01T00:00:00Z
  executor = "docker"
  [runners.cache]
    MaxUploadedArchiveSize = 0
  [runners.docker]
    tls_verify = false
    image = "docker:latest"
    privileged = false
    disable_entrypoint_overwrite = false
    oom_kill_disable = false
    disable_cache = false
    volumes = ["/cache"]
    shm_size = 0
    network_mode = "host"
```
