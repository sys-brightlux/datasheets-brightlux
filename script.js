document.addEventListener('DOMContentLoaded', () => {
    // Registra o Service Worker (necessário para o PWA)
    if ('serviceWorker' in navigator) {
        window.addEventListener('load', () => {
            navigator.serviceWorker.register('/sw.js').then((reg) => {
                console.log('Service worker registrado com sucesso.');
            }).catch(err => {
                console.log('Falha no registro do Service worker: ', err);
            });
        });
    }

    const caixaPesquisa = document.getElementById('caixa-pesquisa');
    const resultadosDiv = document.getElementById('resultados');
    let dados = [];

    // Busca os dados do arquivo JSON local
    fetch('dados.json')
        .then(response => response.json())
        .then(data => {
            dados = data;
            exibirResultados(dados); // Exibe todos os itens inicialmente
        })
        .catch(error => {
            console.error('Erro ao carregar o arquivo de dados:', error);
            resultadosDiv.innerHTML = '<p class="no-results">Não foi possível carregar os arquivos.</p>';
        });

    // Filtra os resultados em tempo real enquanto o usuário digita
    caixaPesquisa.addEventListener('keyup', (e) => {
        const termoPesquisado = e.target.value.toLowerCase();
        const resultadosFiltrados = dados.filter(item => {
            return item.produto.toLowerCase().includes(termoPesquisado) ||
                   item.descricao.toLowerCase().includes(termoPesquisado);
        });
        exibirResultados(resultadosFiltrados);
    });

    // Função que cria o HTML para os resultados e os exibe na página
    function exibirResultados(resultados) {
        resultadosDiv.innerHTML = '';
        if (resultados.length === 0) {
            resultadosDiv.innerHTML = '<p class="no-results">Nenhum resultado encontrado.</p>';
            return;
        }

        resultados.forEach(item => {
            const itemDiv = document.createElement('div');
            itemDiv.classList.add('item-resultado');
            itemDiv.innerHTML = `
                <h2>${item.produto}</h2>
                <p>${item.descricao}</p>
                <div class="item-actions">
                    <a href="${item.arquivo}" target="_blank" download>Baixar Arquivo</a>
                    <button class="share-btn" data-url="${item.arquivo}" data-title="${item.produto}">Compartilhar</button>
                </div>
            `;
            resultadosDiv.appendChild(itemDiv);
        });
    }
    
    // Delegação de evento para os botões de compartilhar
    resultadosDiv.addEventListener('click', function(event) {
        if (event.target && event.target.classList.contains('share-btn')) {
            const url = event.target.getAttribute('data-url');
            const title = event.target.getAttribute('data-title');
            compartilharArquivo(url, title);
        }
    });
});

// Função de compartilhamento que usa a API nativa do navegador/celular
function compartilharArquivo(arquivoUrl, titulo) {
    const fullUrl = new URL(arquivoUrl, window.location.href).href;

    if (navigator.share) { // Verifica se o navegador suporta a API de compartilhamento
        navigator.share({
            title: `Arquivo: ${titulo}`,
            text: `Confira este arquivo: ${titulo}`,
            url: fullUrl
        }).catch((error) => console.log('Erro ao compartilhar:', error));
    } else {
        // Se não suportar (ex: Chrome no Desktop), copia o link para a área de transferência
        navigator.clipboard.writeText(fullUrl).then(() => {
            alert('Link do arquivo copiado para a área de transferência!');
        });
    }
}