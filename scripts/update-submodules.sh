#!/bin/bash
set -e

echo "🔄 Actualizando submódulos al último commit de sus ramas..."
git submodule update --remote --recursive
echo "✅ Submódulos actualizados en el sistema."
echo ""

# Buscar submódulos modificados
MODIFIED_SUBS=$(git status --porcelain | grep "^.M src/" | awk '{print $2}' || true)

if [ -z "$MODIFIED_SUBS" ]; then
    echo "ℹ️ No hay cambios detectados en los submódulos con respecto a la rama principal."
    exit 0
fi

echo "📂 Submódulos modificados detectados:"
echo "$MODIFIED_SUBS"
echo ""

# Preguntar al usuario si quiere hacer commit
read -p "¿Deseas confirmar (commit) los cambios de estos submódulos en Git? [s/N]: " CONFIRM

if [[ "$CONFIRM" =~ ^[sS](i|I)?$ ]]; then
    # Mensaje sugerido de commit
    DATE_NOW=$(date +"%Y-%m-%d %H:%M")
    SUGGESTED_MSG="chore: actualizar submódulos a la última versión de desarrollo ($DATE_NOW)"
    
    echo "💡 Mensaje de commit sugerido: $SUGGESTED_MSG"
    read -p "Escribe el mensaje de commit (Presiona ENTER para usar la sugerencia): " COMMIT_MSG
    
    if [ -z "$COMMIT_MSG" ]; then
        COMMIT_MSG="$SUGGESTED_MSG"
    fi
    
    # Agregar los submódulos modificados
    for sub in $MODIFIED_SUBS; do
        git add "$sub"
    done
    
    # Realizar el commit
    git commit -m "$COMMIT_MSG"
    
    echo "✅ ¡Cambios confirmados con éxito! Mensaje: '$COMMIT_MSG'"
    echo "ℹ️ Recuerda hacer 'git push' cuando desees subir los cambios."
else
    echo "❌ Omitido. Los cambios se mantienen de forma local en tu espacio de trabajo."
fi
