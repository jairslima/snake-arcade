# Snake Arcade by Jair Lima

Snake em modo texto com experiência de fliperama, escrito em Harbour 3.0 (compatível com o estilo Clipper). Mostra o potencial de jogos ASCII no terminal, com som.

- Tela de abertura animada com INSERT COIN e tabela de recordes
- 3 vidas, vida extra a cada 1000 pontos, fases com mais velocidade e obstáculos
- Fruta bônus com tempo, recordes com iniciais de 3 letras
- Efeitos sonoros sintetizados em tempo de execução (WAV de onda quadrada, via `hbwin`)
- Autoteste sem interface: `snake.exe --selftest`

## Controles

Setas ou WASD movem, `P` pausa, `M` liga/desliga o som, `ESC` sai. Terminal mínimo 80x25.

## Compilar

Requer Harbour 3.0.0 (hbmk2 em `C:\hb30\bin`):

```
build.bat
```

## Documentação

- `PROJECT.md`: estado do projeto e decisões
- `REVIEW.md`: segunda opinião (GitHub Copilot) conferida por testes
- `BEST_PRACTICES.md`: boas práticas para jogos ASCII em Harbour/Clipper

Licença MIT.
