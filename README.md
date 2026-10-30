# ZYON HUB v8

Hub em Luau para o cliente Roblox, em um unico arquivo (`HUB.lua`), com suporte a mouse e toque. A versao v8 reorganiza a interface e permite mover e travar a area do FOV.

## Interface

- **Geral:** ESP, aimbot, sensibilidade e status da partida.
- **FOV:** trava de posicao, visibilidade do circulo, raio, coordenadas X/Y e centralizacao.
- **Jogadores:** modo FFA e classificacao manual Auto → Inimigo → Aliado.
- **Visual:** quatro cores de destaque, transparencia do Hub e transparencia do ESP.

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
- As opcoes duram durante a execucao atual. Reexecutar o arquivo restaura os valores iniciais; nao ha gravacao em disco.

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

Os 14 testes comportamentais exercitam inicializacao, mouse, toque com dois dedos, limites da tela, bloqueio de controles, sliders, pausa da mira, redimensionamento, troca de camera, selecao de alvos no FOV deslocado, foco, temas, abas, minimizacao e limpeza ao encerrar/reexecutar.

O teste usa uma simulacao pequena das APIs do Roblox. Ele verifica a logica e a ligacao dos eventos, mas nao substitui renderizacao, encaminhamento real de toque, fontes ou comportamento de camera dentro do Roblox.

### Conferencia no Roblox

- Abrir em retrato e paisagem; rolar todas as abas sem cortes nos controles.
- Destravar, recolher o Hub, arrastar o ponto e travar pela barra inferior.
- Confirmar que o circulo e a area de selecao coincidem na posicao escolhida.
- Ajustar X/Y, centralizar, testar as bordas e girar a tela com a posicao travada.
- Testar os quatro temas, as transparencias e os estados de ESP/Aim.
- Fechar e reexecutar sem interface, destaques ou eventos duplicados.
