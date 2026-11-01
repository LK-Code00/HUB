# ZYON HUB v9

Hub em Luau para o cliente Roblox, em um unico arquivo (`HUB.lua`), com suporte a mouse e toque. A versao v9 salva as preferencias, revalida os alvos durante o acompanhamento e prioriza o controle manual da camera.

## Interface

- **Geral:** ESP, aimbot, prioridade da camera manual, sensibilidade e status da partida.
- **FOV:** trava de posicao, visibilidade do circulo, raio, coordenadas X/Y e centralizacao.
- **Jogadores:** modo FFA e classificacao manual Auto → Inimigo → Aliado.
- **Visual:** quatro cores de destaque, transparencias, estado do salvamento e botao **Salvar agora**.

A janela usa cartoes e espacamentos consistentes, abas com estado selecionado e paginas rolaveis. Em telas baixas, a janela fica mais curta antes de reduzir a escala. Os sliders possuem uma area de toque maior que a linha visivel.

## Mover e travar o FOV

1. Abra a aba **FOV**.
2. Desative **Travar posicao**. O circulo e o controle **+** aparecem; a mira fica pausada durante a edicao.
3. Arraste o **+** com mouse ou toque, ou ajuste os sliders **X** e **Y**. Se o Hub estiver cobrindo o ponto, recolha a janela com **−**.
4. Toque em **TRAVAR**, na barra inferior, ou reative **Travar posicao** na aba FOV. A mira retoma seu estado anterior.

Enquanto a posicao estiver travada, arraste, sliders X/Y e centralizacao ficam desativados. O tamanho do FOV continua ajustavel.

- **Centralizar FOV** restaura X/Y para 50%, quando a posicao esta destravada.
- X = 0% corresponde a esquerda; X = 100%, a direita. Y = 0% corresponde ao topo; Y = 100%, a base.
- As coordenadas sao proporcionais a tela e permanecem na mesma posicao relativa ao redimensionar a janela, trocar a camera ou girar o dispositivo.
- A trava fixa o **centro na tela**, nao uma posicao no mundo nem um jogador.
- O novo centro e usado tanto pelo circulo quanto pela selecao de alvos. O movimento da camera continua mirando no centro da tela, como na versao anterior; mover a area de selecao nao desloca a reticula do jogo.
- O raio representa 5% a 50% da menor dimensao da tela. O circulo pode ficar parcialmente fora da tela quando seu centro estiver perto de uma borda.
- Ocultar o circulo ou perder o foco da janela encerra o modo de edicao e trava a posicao atual.
- O FOV e sua trava sao restaurados junto das demais configuracoes. Se voce salvar com a posicao destravada, a proxima execucao tambem abre em modo de edicao, com a mira pausada.

## Salvamento automatico

O Hub restaura os ajustes antes de construir a interface: ESP/Aim, filtros, sensibilidade, distancia e intervalos, tamanho/visibilidade/posicao/trava do FOV, prioridade manual, modo FFA, tema, transparencias, aba ativa, estado minimizado e posicoes da janela e da bolha. As classificacoes manuais dos jogadores tambem sao salvas e permanecem quando eles saem da partida.

- Com `readfile` e `writefile` disponiveis, o perfil e gravado em **`ZyonHub_<UserId>.json`**, na pasta de arquivos disponibilizada pelo ambiente. Ele e carregado nas proximas execucoes nesse mesmo dispositivo/ambiente.
- Cada conta tem seu perfil. Classificacoes de jogadores ficam separadas por `GameId` (ou `PlaceId` quando nao houver `GameId`).
- As alteracoes sao agrupadas em janelas de 0,4 segundo para evitar escrita por quadro durante o arraste. Fechar/reexecutar o Hub ou perder o foco tambem tenta gravar os ajustes pendentes. **Visual → Salvar agora** permite gravar imediatamente.
- A aba **Visual** informa se o salvamento esta disponivel, foi concluido ou falhou. Falhas de gravacao mantem uma copia na memoria da sessao e podem ser tentadas novamente pelo botao.
- Em um LocalScript comum do Roblox, as APIs de arquivo nao existem. Nesse caso, os ajustes sobrevivem apenas a reexecucoes na **mesma sessao**, pelo ambiente compartilhado; nao sobrevivem ao fechamento do cliente. Persistencia entre sessoes nesse contexto exige armazenamento no servidor do proprio jogo.
- Valores carregados sao validados e limitados. Um arquivo invalido nao interrompe a inicializacao; o Hub usa os padroes e informa o problema.

O arquivo guarda preferencias, nao alteracoes do codigo-fonte. Nao ha sincronizacao de configuracoes entre dispositivos.

## Correcao do acompanhamento

Antes de cada movimento da camera, a mira verifica novamente: personagem atual do jogador, vida, estado `Dead`, sinais booleanos de morte replicados, distancia, projecao na tela, limite do FOV e linha de visao ate o ponto exato de mira. Eventos `Died`, `HealthChanged`, `StateChanged` e troca/remocao de personagem liberam o alvo; um corpo antigo nao e reutilizado depois do respawn. A mira tambem para quando o personagem local morre ou a camera e controlada por um script.

A busca por novos alvos continua limitada por `TargetInterval` (0,12 segundo por padrao), inclusive quando nenhum alvo esta visivel. A verificacao do alvo atual acontece a cada quadro.

**Priorizar camera manual** vem ativado. Movimento de mouse, arraste de toque na area direita da camera e analogico direito suspendem o acompanhamento. Toque/analogico mantido conserva o controle manual; apos soltar, ha uma pausa de 0,45 segundo antes de retomar. Toques consumidos pela interface e a area habitual do joystick esquerdo nao sao tratados como arraste de camera. Arrastar os controles do proprio Hub tambem pausa a mira.

Essas verificacoes usam os dados e eventos replicados pelo Roblox. Jogos com sistemas proprios de morte ou controles de toque personalizados precisam de conferencia no proprio jogo.

## Janela e atalhos

| Acao | Controle |
| --- | --- |
| Mover a janela | Arrastar o cabecalho |
| Recolher | Botao **−** |
| Reabrir | Tocar na bolha **Z** |
| Mover a bolha | Arrastar **Z** |
| Recolher / reabrir no teclado | **Shift direito** |
| Travar o FOV no teclado | **Esc**, quando o Roblox nao consumir a tecla |
| Encerrar e remover a interface | Botao **×** |

Para usar a atualizacao, utilize o novo `HUB.lua` no mesmo ambiente cliente do Hub anterior. O arquivo continua independente, sem biblioteca de interface externa. Reexecuta-lo encerra a instancia anterior, desconecta os eventos e remove os destaques antes de criar a nova interface.

## Validacao

Compilacao com o CLI oficial do Luau (validado com 0.744):

```sh
luau-compile HUB.lua > /tmp/hub-bytecode.txt
python3 tests/run.py /caminho/para/luau
```

Os 34 testes comportamentais cobrem os controles da v8 e regressao de persistencia: restauracao sem cache de sessao, gravacao agrupada, falhas e novas tentativas, arquivo invalido, separacao por conta/jogo e ambiente sem arquivos. Tambem cobrem morte, corpo antigo, parede surgindo depois da selecao, FOV/distancia/tela, pausa manual por mouse/toque/controle e limite de frequencia das buscas.

O teste usa uma simulacao pequena das APIs do Roblox. Ele verifica a logica e a ligacao dos eventos, mas nao substitui renderizacao, encaminhamento real de toque, fontes ou comportamento de camera dentro do Roblox.

### Conferencia no Roblox

- Abrir em retrato e paisagem; rolar todas as abas sem cortes nos controles.
- Destravar, recolher o Hub, arrastar o ponto e travar pela barra inferior.
- Confirmar que o circulo e a area de selecao coincidem na posicao escolhida.
- Ajustar X/Y, centralizar, testar as bordas e girar a tela com a posicao travada.
- Testar os quatro temas, as transparencias e os estados de ESP/Aim.
- Fechar e reexecutar sem interface, destaques ou eventos duplicados.
- Alterar ajustes, conferir **Visual → Configuracoes**, fechar o cliente e reabrir no mesmo ambiente com suporte a arquivos.
- Confirmar que a mira solta um alvo morto ou que entrou atras de uma parede.
- Mover a camera com um jogador dentro do FOV e confirmar prioridade manual no dispositivo usado.
