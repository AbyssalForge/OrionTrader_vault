# OrionTrader Vault - Production Deployment

Service de gestion des secrets sécurisé basé sur HashiCorp Vault pour le projet OrionTrader.

## Description

Ce repository contient uniquement le service **Vault** (HashiCorp Vault) configuré pour un déploiement en production sur VPS. Le Vault stocke de manière sécurisée tous les secrets et credentials nécessaires au projet OrionTrader (API keys, tokens, credentials de base de données, etc.).

## Déploiement

Ce projet est conçu pour être déployé automatiquement via GitHub Actions sur votre VPS OVH.

**📖 Consultez [DEPLOYMENT.md](DEPLOYMENT.md) pour les instructions complètes de déploiement.**

## Architecture

```
GitHub Push → GitHub Actions → SSH + VPN → VPS OVH → Docker Vault
```

## Démarrage rapide

1. **Configurer les secrets GitHub**
   - Ajoutez vos credentials VPS dans GitHub Secrets
   - Voir [DEPLOYMENT.md](DEPLOYMENT.md) pour la liste complète

2. **Déployer**
   ```bash
   git push origin main
   ```
   Le déploiement se fait automatiquement via GitHub Actions.

3. **Accéder au Vault**
   ```bash
   # Connectez-vous au VPN WireGuard
   wg-quick up wg0

   # Accédez au Vault
   export VAULT_ADDR="http://10.0.0.1:8200"
   vault status
   ```

## Sécurité

- 🔒 Déploiement dans un réseau VPN WireGuard (recommandé)
- 🔑 Auto-unseal au démarrage
- 📦 Isolation via Docker
- 🛡️ Backup automatique des données

## Structure

```
.
├── .github/workflows/       # Workflows GitHub Actions
│   ├── deploy-vault.yml           # Déploiement avec VPN (recommandé)
│   └── deploy-vault-no-vpn.yml    # Déploiement sans VPN
├── docker-init/             # Scripts d'initialisation
├── vault/
│   ├── config/              # Configuration Vault
│   ├── policies/            # Policies de sécurité
│   ├── data/                # Données (non versionné)
│   └── example/             # Exemples de secrets
├── docker-compose.prod.yaml # Config Docker production
├── .env.example             # Variables d'environnement
└── DEPLOYMENT.md            # Guide de déploiement complet
```

## Documentation

- [DEPLOYMENT.md](DEPLOYMENT.md) - Guide de déploiement complet
- [vault/config/vault.hcl](vault/config/vault.hcl) - Configuration Vault
- [HashiCorp Vault Docs](https://developer.hashicorp.com/vault) - Documentation officielle

## Support

Pour toute question :
1. Consultez [DEPLOYMENT.md](DEPLOYMENT.md)
2. Vérifiez les logs : `docker logs orion_vault_prod`
3. Ouvrez une issue GitHub

## License

Projet privé OrionTrader