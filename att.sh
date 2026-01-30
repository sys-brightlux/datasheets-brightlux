#!/bin/bash

# ==========================================================
# CONFIGURACAO
# ==========================================================
JSON_FILE="dados.json"
TARGET_DIR="arquivos"
REPO_BRANCH="main"
TEMP_PY="temp_script_gen.py"

# Cores para o terminal
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # Sem cor

echo -e "\n${BLUE}[1/5] Verificando ambiente...${NC}"

# Verifica GIT
if ! command -v git &> /dev/null; then
    echo -e "${RED}[ERRO] Git nao encontrado. Instale o git.${NC}"
    exit 1
fi

# Cria pasta de arquivos se nao existir
if [ ! -d "$TARGET_DIR" ]; then
    mkdir -p "$TARGET_DIR"
    echo -e "[INFO] Pasta '$TARGET_DIR' criada."
fi

# ==========================================================
# 2. COPIAR ARQUIVOS
# ==========================================================
echo -e "${BLUE}[2/5] Replicando PDFs para a pasta do repositorio...${NC}"
# Verifica se existem PDFs antes de copiar para evitar erro de 'ls'
if ls *.pdf 1> /dev/null 2>&1; then
    cp *.pdf "$TARGET_DIR/"
    echo -e "[INFO] Arquivos copiados para '$TARGET_DIR'. Originais mantidos."
else
    echo -e "[INFO] Nenhum PDF encontrado na raiz para copiar."
fi

# ==========================================================
# 3. GERAR SCRIPT DE ATUALIZAÇÃO (PYTHON)
# ==========================================================
# Usamos Python por ser o padrão em Linux para manipular JSON
echo -e "${BLUE}[3/5] Gerando logica de atualizacao do JSON...${NC}"

cat << EOF > "$TEMP_PY"
import json
import os

json_path = '$JSON_FILE'
dir_path = '$TARGET_DIR'
base_url = 'arquivos'

# Carrega ou cria o JSON
if os.path.exists(json_path):
    try:
        with open(json_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except:
        data = []
else:
    data = []

existing_files = [item['arquivo'] for item in data]
updated = False

# Lista arquivos no disco
if os.path.exists(dir_path):
    files_on_disk = [f for f in os.listdir(dir_path) if f.lower().endswith('.pdf')]
    
    for filename in files_on_disk:
        relative_path = f"{base_url}/{filename}"
        
        if relative_path not in existing_files:
            print(f"[NOVO] Adicionando ao indice: {filename}")
            
            # Calcula próximo ID
            max_id = max([item['id'] for item in data], default=0)
            new_id = max_id + 1
            
            # Remove a extensão para o nome do produto
            produto_nome = os.path.splitext(filename)[0]
            
            new_obj = {
                "id": new_id,
                "produto": produto_nome,
                "descricao": f"Documento técnico ou folha de dados para o produto {produto_nome}.",
                "arquivo": relative_path
            }
            data.append(new_obj)
            updated = True

if updated:
    with open(json_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=4, ensure_ascii=False)
    exit(0)
else:
    exit(2)
EOF

# ==========================================================
# 4. EXECUTAR
# ==========================================================
echo -e "${BLUE}[4/5] Processando JSON...${NC}"

python3 "$TEMP_PY"
EXIT_CODE=$?

rm "$TEMP_PY"

if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}[SUCESSO] $JSON_FILE atualizado.${NC}"
elif [ $EXIT_CODE -eq 2 ]; then
    echo -e "[INFO] Sem novos registros para adicionar."
else
    echo -e "${RED}[ERRO] Falha no processamento Python.${NC}"
    exit 1
fi

# ==========================================================
# 5. GIT PUSH
# ==========================================================
echo -e "${BLUE}[5/5] Sincronizando repositorio...${NC}"

git add "$JSON_FILE"
git add "$TARGET_DIR"/*.pdf 2>/dev/null

if ! git diff-index --quiet HEAD; then
    echo -e "[GIT] Enviando alteracoes para '$REPO_BRANCH'..."
    git commit -m "auto: atualizacao de datasheets e json"
    git push origin "$REPO_BRANCH"
    echo -e "${GREEN}[GIT] Concluido com sucesso.${NC}"
else
    echo -e "[GIT] Tudo atualizado. Nada para enviar."
fi

echo -e "\nProcesso finalizado. Pressione Enter para sair."
read