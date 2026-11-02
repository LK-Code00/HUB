# ZYON HUB

Hub em Luau para o cliente Roblox, em um unico arquivo (`HUB.lua`), com suporte a mouse e toque. O Hub salva as preferencias, revalida os alvos durante o acompanhamento e prioriza o controle manual da camera.

## Interface

- **Geral:** ESP, aimbot, prioridade da camera manual, sensibilidade e status da partida.
- **FOV:** trava de posicao, visibilidade do circulo, raio, coordenadas X/Y e centralizacao.
- **Jogadores:** modo FFA e classificacao manual Auto → Inimigo → Aliado.
- **Visual:** quatro cores de destaque, transparencias, estado do salvamento e botao **Salvar agora**.
- **Graficos:** modo leve, reducao de particulas, presets de efeitos e intensidade.

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

## Sniper Duels: equipes, rankeds e diagnostico

A investigacao e as fontes estao em [RESEARCH.md](RESEARCH.md). Um diagnostico recebido mostrou `Workspace.Characters.{partida}.B.<personagem>` para o jogador local e seu colega, enquanto o filtro dizia `FFA manual`. O Hub agora reconhece a estrutura de duas equipes A/B nesse universo: mesma equipe e outra partida sao excluidas antes de FFA e de classificacoes manuais. A verificacao de ancestralidade e repetida durante o acompanhamento para detectar trocas de equipe.

O adaptador e limitado a `Workspace.Characters.<GUID>.A/B.<Player.Character>`; nao adivinha lados em outros formatos. O lado B foi observado no diagnostico; a contraparte A e validada em testes simulados e ainda precisa ser conferida na partida real. O diagnostico lista tambem os modelos A/B da partida atual, ate 24 entradas, informando quando nao estao associados a um `Player.Character`. Essa listagem nao ativa mira em modelos desconhecidos. A deteccao prioriza marcadores de rodada, preserva equipes com ID zero, consulta containers de dados e trata revive no mesmo personagem. Nao ha garantia de todos os modos sem teste no jogo; a estrutura interna das rankeds nao e publica.

Em **Jogadores**, use **Gerar diagnostico** durante a partida. O relatorio mostra por que cada jogador foi incluido/bloqueado e as condicoes do personagem. **Copiar** usa o clipboard do ambiente, quando disponivel; caso contrario, imprime no console. O relatorio e local e nao e enviado automaticamente.

Os campos opcionais **Equipe** e **Partida** aceitam nomes de atributos/ValueBases observados no diagnostico (ate 48 letras, numeros ou `_`). Deixe vazio para Auto. Esses ajustes ficam salvos. Nao use `Forcar modo FFA` numa partida com equipes para contornar um campo desconhecido: classifique os jogadores manualmente enquanto verifica os dados.

## Amigos e classificacao manual

Na aba **Jogadores**, a classificacao explicita tem prioridade sobre o filtro de amizade: **Inimigo** permite selecionar inclusive amigos, mesmo se a consulta de amizade estiver pendente; **Aliado** exclui o jogador. Em **Auto**, os filtros de amizade, equipe e partida voltam a ser aplicados. A escolha afeta a selecao da mira e o ESP, e continua sendo salva por jogo. No Sniper Duels, a estrutura confirmada de equipes impede selecionar um colega ou alguem de outra partida, mesmo com uma classificacao manual antiga de Inimigo.

## Graficos e shaders

- **Modo leve:** desliga sombras globais e pos-efeitos existentes no Lighting e na camera, sem destruir objetos ou texturas do jogo.
- **Reduzir particulas:** desativa emissores, rastros, feixes, fumaca, fogo e brilhos; tambem acompanha novos efeitos carregados na cena.
- **Shaders / efeitos:** Desligado, Suave, Quente e Frio, com intensidade de 0 a 100%. Usam ColorCorrection e Bloom nativos do Roblox; nao instalam shaders externos.
- Ativar o modo leve desliga os shaders do Hub. Selecionar um preset liga os efeitos e desativa o modo leve. A reducao de particulas e independente.
- **Restaurar graficos do jogo** desliga os ajustes e restaura as propriedades modificadas. Fechar ou reexecutar o Hub tambem limpa seus efeitos e restaura os valores anteriores, antes de reaplicar as preferencias salvas.

Os ajustes sao locais, persistem no mesmo perfil e nao mudam a geometria ou a logica do jogo. O ganho de desempenho e a aparencia dependem do dispositivo, da qualidade grafica do Roblox e da cena. Reduzir particulas tambem pode ocultar efeitos visuais de habilidades; a opcao e independente para permitir desliga-la.

## Salvamento automatico

O Hub restaura os ajustes antes de construir a interface: ESP/Aim, filtros, sensibilidade, distancia e intervalos, tamanho/visibilidade/posicao/trava do FOV, prioridade manual, modo FFA, tema, transparencias, opcoes graficas, preset/intensidade de efeitos, aba ativa, estado minimizado e posicoes da janela e da bolha. As classificacoes manuais dos jogadores tambem sao salvas e permanecem quando eles saem da partida.

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

Os 58 testes comportamentais cobrem os controles da interface e regressao de persistencia: restauracao sem cache de sessao, gravacao agrupada, falhas e novas tentativas, arquivo invalido, separacao por conta/jogo e ambiente sem arquivos. Tambem cobrem morte, corpo antigo, parede surgindo depois da selecao, FOV/distancia/tela, pausa manual por mouse/toque/controle e limite de frequencia das buscas. Os novos testes verificam a prioridade manual sobre amizades, graficos reversiveis, novos emissores, presets, intensidade e restauracao das preferencias graficas.

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

- Testar a classificacao manual de um amigo como Inimigo, depois voltar para Auto.
- Alternar modo leve, particulas e presets; fechar o Hub e conferir a restauracao da cena.
