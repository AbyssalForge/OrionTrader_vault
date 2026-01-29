# Déploiement du Vault OrionTrader sur VPS OVH

Ce guide explique comment déployer uniquement le service Vault (HashiCorp Vault) en production sur votre VPS OVH.

## Architecture

```
┌─────────────────────────────────────┐
│         VPS OVH                     │
│  ┌──────────────────────────────┐   │
│  │   WireGuard VPN              │   │
│  │  ┌────────────────────────┐  │   │
│  │  │   Docker Container     │  │   │
│  │  │   ┌──────────────┐     │  │   │
│  │  │   │ Vault :8200  │     │  │   │
│  │  │   └──────────────┘     │  │   │
│  │  └────────────────────────┘  │   │
│  └──────────────────────────────┘   │
└─────────────────────────────────────┘
         ▲
         │ Connexion VPN sécurisée
         │
    ┌────────────┐
    │   Client   │
    │ (Airflow)  │
    └────────────┘
```

## Prérequis

### Sur votre VPS OVH

1. **Docker et Docker Compose installés**
   ```bash
   curl -fsSL https://get.docker.com -o get-docker.sh
   sudo sh get-docker.sh
   sudo apt-get install docker-compose-plugin
   ```

2. **WireGuard VPN configuré** (recommandé)
   ```bash
   sudo apt install wireguard
   # Configurez votre interface wg0 selon vos besoins
   ```

3. **Accès SSH configuré**
   - Clé SSH ajoutée aux `~/.ssh/authorized_keys`
   - Firewall configuré (UFW ou iptables)

### Sur GitHub

Ajoutez les secrets suivants dans : `Settings > Secrets and variables > Actions > Repository secrets`

| Secret | Description | Exemple |
|--------|-------------|---------|
| `VPS_HOST` | Adresse IP du VPS | `51.178.xx.xx` |
| `VPS_PORT` | Port SSH | `22` |
| `VPS_USERNAME` | Utilisateur SSH | `ubuntu` ou `debian` |
| `VPS_SSH_KEY` | Clé privée SSH complète | Contenu de `id_rsa` |
| `WG_CONFIG` | Config WireGuard complète | Contenu de `/etc/wireguard/wg0.conf` |
| `VAULT_UNSEAL_KEY` | Clé de déverrouillage Vault | Obtenue lors de l'init |
| `VAULT_ROOT_TOKEN` | Token root Vault | Obtenu lors de l'init |

## Configuration initiale du Vault

### 1. Première installation (manuelle)

Lors de la première installation, le Vault doit être initialisé :

```bash
# Connexion SSH au VPS
ssh -p $VPS_PORT $VPS_USERNAME@$VPS_HOST

# Aller dans le répertoire de déploiement
cd ~/orion-vault

# Démarrer Vault pour la première fois
docker-compose -f docker-compose.prod.yaml up -d

# Attendre quelques secondes
sleep 10

# Vérifier les logs pour obtenir les clés d'initialisation
docker-compose -f docker-compose.prod.yaml logs vault

# Les clés seront affichées dans vault/data/init-output.txt
docker exec orion_vault_prod cat /vault/data/init-output.txt
```

Vous obtiendrez une sortie comme :
```
Unseal Key 1: xxxxxxxxxxxxxxxxxxxxxxxxxxxxx
Initial Root Token: hvs.xxxxxxxxxxxxxxxxxxxxxx
```

### 2. Ajouter les clés dans GitHub Secrets

Copiez les valeurs obtenues et ajoutez-les dans les secrets GitHub :
- `VAULT_UNSEAL_KEY` : La clé "Unseal Key 1"
- `VAULT_ROOT_TOKEN` : Le "Initial Root Token"

### 3. Configuration WireGuard

Créez votre configuration WireGuard complète et ajoutez-la dans `WG_CONFIG` :

```ini
[Interface]
PrivateKey = VOTRE_PRIVATE_KEY
Address = 10.0.0.2/24
DNS = 8.8.8.8

[Peer]
PublicKey = VOTRE_PUBLIC_KEY_VPS
Endpoint = VPS_IP:51820
AllowedIPs = 10.0.0.0/24
PersistentKeepalive = 25
```

## Déploiement automatique

Une fois les secrets configurés, chaque push sur `main` déclenchera automatiquement le déploiement.

### Déploiement manuel

Vous pouvez aussi déclencher un déploiement manuel :
1. Allez dans l'onglet `Actions` de votre repo GitHub
2. Sélectionnez le workflow "Deploy Vault to VPS"
3. Cliquez sur "Run workflow"

## Accès au Vault

### Via le VPN (Recommandé)

```bash
# 1. Connectez-vous au VPN WireGuard
wg-quick up wg0

# 2. Accédez au Vault
export VAULT_ADDR="http://10.0.0.1:8200"
export VAULT_TOKEN="your_root_token"

# 3. Testez la connexion
vault status

# 4. Lister les secrets
vault kv list secret/
```

### Via SSH Tunnel (Alternative)

Si vous n'utilisez pas le VPN :

```bash
# Créer un tunnel SSH
ssh -L 8200:localhost:8200 -p $VPS_PORT $VPS_USERNAME@$VPS_HOST

# Dans un autre terminal
export VAULT_ADDR="http://localhost:8200"
export VAULT_TOKEN="your_root_token"
vault status
```

## Sécurité

### Recommandations importantes

1. **Utilisez le VPN** : Ne jamais exposer le Vault directement sur Internet
2. **Sauvegardez les clés** : Conservez `VAULT_UNSEAL_KEY` et `VAULT_ROOT_TOKEN` dans un gestionnaire de mots de passe
3. **Backup régulier** : Sauvegardez le dossier `vault/data` régulièrement
4. **Tokens limités** : En production, créez des tokens avec des permissions limitées au lieu d'utiliser le root token
5. **TLS en production** : Pour une sécurité maximale, activez TLS dans [vault.hcl](vault/config/vault.hcl)

### Configuration TLS (optionnel mais recommandé)

Pour activer TLS, modifiez [vault/config/vault.hcl](vault/config/vault.hcl) :

```hcl
listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_disable   = "false"
  tls_cert_file = "/vault/certs/vault.crt"
  tls_key_file  = "/vault/certs/vault.key"
}
```

## Maintenance

### Vérifier le statut

```bash
ssh -p $VPS_PORT $VPS_USERNAME@$VPS_HOST
cd ~/orion-vault
docker-compose -f docker-compose.prod.yaml ps
docker-compose -f docker-compose.prod.yaml logs -f vault
```

### Redémarrer le Vault

```bash
docker-compose -f docker-compose.prod.yaml restart vault
```

### Backup des données

```bash
# Sur le VPS
cd ~/orion-vault
tar -czf vault-backup-$(date +%Y%m%d).tar.gz vault/data/

# Télécharger le backup localement
scp -P $VPS_PORT $VPS_USERNAME@$VPS_HOST:~/orion-vault/vault-backup-*.tar.gz ./backups/
```

### Restaurer un backup

```bash
# Sur le VPS
cd ~/orion-vault
docker-compose -f docker-compose.prod.yaml down
tar -xzf vault-backup-YYYYMMDD.tar.gz
docker-compose -f docker-compose.prod.yaml up -d
```

## Troubleshooting

### Le Vault est "sealed"

```bash
docker exec orion_vault_prod vault operator unseal $VAULT_UNSEAL_KEY
```

### Impossible de se connecter au Vault

1. Vérifiez que le VPN est actif : `wg show`
2. Vérifiez que le conteneur tourne : `docker ps | grep vault`
3. Vérifiez les logs : `docker logs orion_vault_prod`

### GitHub Actions échoue

1. Vérifiez que tous les secrets sont correctement configurés
2. Vérifiez la connexion SSH : `ssh -p $VPS_PORT $VPS_USERNAME@$VPS_HOST`
3. Consultez les logs du workflow dans l'onglet Actions

## Structure des fichiers

```
OrionTrader_vault/
├── .github/
│   └── workflows/
│       └── deploy-vault.yml        # Workflow de déploiement
├── docker-init/                    # Scripts d'initialisation
│   ├── vault-entrypoint.sh         # Point d'entrée du conteneur
│   └── vault-auto-unseal.sh        # Auto-unseal au démarrage
├── vault/
│   ├── config/
│   │   └── vault.hcl               # Configuration Vault
│   ├── policies/                   # Policies Vault (optionnel)
│   ├── data/                       # Données Vault (non versionné)
│   └── example/                    # Exemples de secrets
├── docker-compose.prod.yaml        # Configuration Docker pour prod
├── .env.example                    # Variables d'environnement exemple
├── .gitignore                      # Fichiers à ignorer
└── DEPLOYMENT.md                   # Ce fichier
```

## Support

Pour toute question ou problème :
1. Consultez les logs : `docker-compose -f docker-compose.prod.yaml logs vault`
2. Vérifiez la documentation officielle : https://developer.hashicorp.com/vault
3. Vérifiez les issues GitHub du projet

## Prochaines étapes

Après le déploiement du Vault :
1. Configurez vos clients (Airflow, FastAPI) pour utiliser le Vault via le VPN
2. Créez des policies et tokens avec des permissions limitées
3. Ajoutez vos secrets dans le Vault
4. Configurez des backups automatiques
5. Activez TLS pour une sécurité renforcée
