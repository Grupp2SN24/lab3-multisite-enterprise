# SSH-Bastion MFA Setup

## Användare
| User | Password | MFA Secret |
|------|----------|------------|
| anton | SecurePass123! | OSZFF652BV46RX64HCWQOYMAU4 |
| fredrik | FredrikPass123! | IOJR2PZHAJIN4ENO52WMEFY5EY |
| backup | BackupPass123! | (ej konfigurerat) |

## Emergency Scratch Codes

### anton
- 10839784
- 58592252
- 86398927
- 97919470
- 66958276

### fredrik
- 33536692
- 59324898
- 78015787
- 14807849
- 10604757

## Testa MFA
```bash
ssh anton@10.10.0.50
# Password: SecurePass123!
# Verification code: [från Google Authenticator app]
```

## Installation
```bash
apt install -y openssh-server libpam-google-authenticator
useradd -m -s /bin/bash USERNAME
su - USERNAME -c "google-authenticator -t -d -f -r 3 -R 30 -w 3"
echo "auth required pam_google_authenticator.so" >> /etc/pam.d/sshd
sed -i 's/KbdInteractiveAuthentication no/KbdInteractiveAuthentication yes/' /etc/ssh/sshd_config
systemctl restart sshd
```
