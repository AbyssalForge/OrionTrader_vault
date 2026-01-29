#!/bin/bash

# Script de vérification du Vault
# Utilise ce script pour vérifier que le Vault est accessible et fonctionnel

set -e

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🔍 Vérification du Vault OrionTrader..."
echo ""

# Vérifier que VAULT_ADDR est défini
if [ -z "$VAULT_ADDR" ]; then
    echo -e "${YELLOW}⚠️  VAULT_ADDR n'est pas défini${NC}"
    echo "   Définissez-le avec: export VAULT_ADDR='http://VOTRE_IP:8200'"
    echo ""
    read -p "Entrez l'adresse du Vault (ex: http://10.0.0.1:8200): " VAULT_ADDR
    export VAULT_ADDR
fi

echo "✓ VAULT_ADDR: $VAULT_ADDR"
echo ""

# Vérifier la connectivité
echo "1. Test de connectivité..."
if curl -s -o /dev/null -w "%{http_code}" "$VAULT_ADDR/v1/sys/health" | grep -q "20[0-9]\|429\|472\|473"; then
    echo -e "${GREEN}✓ Le Vault est accessible${NC}"
else
    echo -e "${RED}✗ Impossible de joindre le Vault${NC}"
    echo "  Vérifiez:"
    echo "  - Que le conteneur Docker est démarré"
    echo "  - Que vous êtes connecté au VPN (si configuré)"
    echo "  - Que l'adresse $VAULT_ADDR est correcte"
    exit 1
fi
echo ""

# Vérifier le statut du Vault
echo "2. Vérification du statut..."
STATUS=$(vault status 2>&1)

if echo "$STATUS" | grep -q "Sealed.*false"; then
    echo -e "${GREEN}✓ Le Vault est déverrouillé${NC}"
elif echo "$STATUS" | grep -q "Sealed.*true"; then
    echo -e "${YELLOW}⚠️  Le Vault est verrouillé (sealed)${NC}"
    echo "  Déverrouillez-le avec: vault operator unseal \$VAULT_UNSEAL_KEY"
    exit 1
else
    echo -e "${RED}✗ Impossible de déterminer le statut du Vault${NC}"
    echo "$STATUS"
    exit 1
fi
echo ""

# Vérifier l'authentification
echo "3. Test d'authentification..."
if [ -z "$VAULT_TOKEN" ]; then
    echo -e "${YELLOW}⚠️  VAULT_TOKEN n'est pas défini${NC}"
    read -sp "Entrez votre token Vault: " VAULT_TOKEN
    export VAULT_TOKEN
    echo ""
fi

if vault token lookup > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Token valide${NC}"

    # Afficher les informations du token
    echo ""
    echo "Informations du token:"
    vault token lookup | grep -E "display_name|policies|ttl"
else
    echo -e "${RED}✗ Token invalide ou expiré${NC}"
    echo "  Vérifiez votre VAULT_TOKEN"
    exit 1
fi
echo ""

# Vérifier les secrets engines
echo "4. Vérification des secrets engines..."
if vault secrets list > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Secrets engines accessibles${NC}"
    echo ""
    echo "Secrets engines disponibles:"
    vault secrets list
else
    echo -e "${RED}✗ Impossible de lister les secrets engines${NC}"
    exit 1
fi
echo ""

# Test de lecture/écriture (optionnel)
echo "5. Test de lecture/écriture (optionnel)..."
TEST_PATH="secret/test-connection"

if vault kv put "$TEST_PATH" test="ok" timestamp="$(date)" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Écriture OK${NC}"

    if vault kv get "$TEST_PATH" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Lecture OK${NC}"

        # Nettoyer
        vault kv delete "$TEST_PATH" > /dev/null 2>&1
        echo -e "${GREEN}✓ Suppression OK${NC}"
    else
        echo -e "${RED}✗ Échec de la lecture${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Permissions d'écriture limitées (normal pour un token non-root)${NC}"
fi
echo ""

# Résumé
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✓ Tous les tests sont passés!${NC}"
echo ""
echo "Le Vault est opérationnel et prêt à être utilisé."
echo ""
echo "Commandes utiles:"
echo "  vault kv list secret/          # Lister les secrets"
echo "  vault kv get secret/path       # Lire un secret"
echo "  vault kv put secret/path key=value  # Écrire un secret"
echo "  vault token lookup             # Info sur le token actuel"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
