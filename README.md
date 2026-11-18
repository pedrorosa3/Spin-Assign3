<div align="center">

# 🔍 Verificação de Modelos com Spin

### Métodos de Fiabilidade de Software — Trabalho 3

![Spin](https://img.shields.io/badge/Spin-Model%20Checker-blue)
![Promela](https://img.shields.io/badge/Linguagem-Promela-orange)
![LTL](https://img.shields.io/badge/Propriedades-LTL-purple)
![FCUL](https://img.shields.io/badge/FCUL-2025%2F2026-darkgreen)

</div>

---

| | |
|---|---|
| 👤 **Autor** | Pedro Rosa (n.º 60294) |
| 📅 **Data** | Dezembro de 2025 |
| 🏛️ **Instituição** | Faculdade de Ciências da Universidade de Lisboa (FCUL) |
| 🎓 **Curso** | Mestrado em Engenharia Informática — 2025/2026 |
| 👩‍🏫 **Docente** | Antónia Lopes |

---

## 📌 Sobre o projeto

Este repositório contém a resolução do terceiro trabalho prático de *Software Reliability Methods*. O objetivo é aplicar **Model Checking** com a ferramenta [**Spin**](https://spinroot.com/) e a linguagem **Promela** para verificar formalmente dois algoritmos concorrentes e distribuídos.

## 📂 Conteúdo do repositório

```
Spin-Assign3/
├── Assignment3-1-60294.pml      # Problema 1 — Bounded Buffer (Produtor/Consumidor)
├── Assignment3-2-60294.pml      # Problema 2 — Eleição de Líder num Anel (Chang-Roberts)
├── Assignment3-Report-60294.pdf # Relatório com decisões de modelação e análise dos resultados
└── README.md
```

## 🧩 Problemas

### 1️⃣ Bounded Buffer com sincronização reentrante

Modelação de uma classe Java `BoundedBuffer` que usa monitores e as primitivas `wait()` / `notify()`.

- 🔒 Modela o *lock* reentrante do Java (`lockOwner`, `lockCount`).
- ✅ Asserções que garantem que só o dono do monitor mexe no buffer.
- 🐞 Expõe o bug clássico de **Lost Wakeup** causado por `notify()`, através de propriedades de vivacidade:
  - `p1`: `[]<> (occupied > 0)` — o buffer volta sempre a ter elementos;
  - `p2`: `[]<> (occupied < K)` — o buffer volta sempre a ter espaço.
- 🛠️ **Correção:** o processo `Notifier` ativo usa `notifyAll` (acorda todos os processos bloqueados). A versão original com o bug está comentada no ficheiro.

**Parâmetros** (podem ser alterados com `-D` na linha de comandos):

| Macro | Significado | Valor por defeito |
|:---:|---|:---:|
| `P` | N.º de produtores | 2 |
| `C` | N.º de consumidores | 2 |
| `K` | Capacidade do buffer | 2 |

### 2️⃣ Eleição de líder num anel unidirecional

Verificação do algoritmo de **Chang-Roberts** para `N` processos num anel (por defeito `N = 5`).

| Propriedade | Fórmula LTL | Descrição |
|---|---|---|
| `p_liveness` | `<> (nr_leaders == 1)` | **C1** — um líder é eventualmente eleito |
| `p_c2` | `(nr_leaders == 0) W (nr_leaders == 1)` | **C2** — não há líder antes de a eleição terminar |
| `p_safety` | `[] (nr_leaders <= 1)` | **C3** — no máximo um líder (unicidade) |
| `p_stability` | `[] ((nr_leaders == 1) -> [] (nr_leaders == 1))` | **C4** — o líder mantém-se líder (estabilidade) |
| `p_agreement` | `<> (∀i: known_leader[i] == N)` | **Acordo** — todos os nós conhecem o líder (só na versão com *flooding*) |

A macro `NFLOOD`, no início do ficheiro, escolhe a versão do algoritmo:

| `NFLOOD` | Versão |
|:---:|---|
| `1` | Algoritmo original (apenas eleição) |
| `0` | Eleição + *flooding* do líder eleito (**ativa por defeito**) |

> ⚠️ `NFLOOD` e `N` estão definidos com `#define` direto, por isso para mudar de versão é preciso editar o ficheiro. A propriedade `p_agreement` está escrita para `N = 5`.

---

## 🚀 Como executar

### Requisitos

- [Spin](https://spinroot.com/spin/Man/README.html) (versão 6 ou superior)
- Um compilador de C (`gcc`)

Para confirmar a instalação:

```bash
spin -V
gcc --version
```

### 🪟 Notas para Windows

Em Windows, o `gcc` vem do **MinGW** (ou MinGW-w64). O `spin.exe` usa-o em dois momentos:

1. no `spin -a`, para pré-processar o `.pml` (`gcc -E`). Sem `gcc` aparece `spin: preprocessing failed`;
2. na compilação do `pan.c`.

Por isso a pasta `bin` do MinGW (por exemplo `C:\MinGW\bin`) tem de estar no `PATH`.

> ⚠️ Se o `gcc --version` não mostrar nada ou falhar com o código `-1073741515` (`0xC0000135`), falta uma DLL na instalação do MinGW, normalmente a `libiconv-2.dll`. Reinstale o MinGW com todos os pacotes base, ou use uma das alternativas abaixo.

Alternativas recomendadas, que já trazem `gcc` funcional:

- **WSL** (Ubuntu): `sudo apt install spin gcc`
- **MSYS2**: `pacman -S mingw-w64-ucrt-x86_64-gcc` e usar o terminal *UCRT64*
- **Cygwin**, com o pacote `gcc-core`

No PowerShell ou no CMD, o verificador chama-se `pan.exe` e corre-se com `.\pan.exe` em vez de `./pan`.

### Passo a passo

O processo é o mesmo para os dois modelos: **gerar** o verificador, **compilar** e **executar**.

```bash
# 1. Gerar o verificador (pan.c) a partir do modelo Promela
spin -a Assignment3-1-60294.pml

# 2. Compilar
gcc -o pan pan.c

# 3. Verificar
./pan -a -m100000 -N p1
```

Como os modelos têm várias fórmulas `ltl`, escolhe-se qual verificar com `-N <nome>`. Se não se indicar nenhuma, o Spin usa a primeira.

> ⚠️ O Spin precisa do `gcc` no `PATH` **também no passo 1**, porque o usa para pré-processar o ficheiro `.pml` (macros `#define` / `#if`).

### 🧪 Problema 1 — Bounded Buffer

```bash
spin -a Assignment3-1-60294.pml

# Segurança (asserções e deadlocks), sem fórmulas LTL
gcc -DNOCLAIM -o pan pan.c
./pan -m100000

# Vivacidade (LTL)
gcc -o pan pan.c
./pan -a -m100000 -N p1   # o buffer não fica vazio para sempre
./pan -a -m100000 -N p2   # o buffer não fica cheio para sempre
```

> ⚠️ É necessário usar `-m100000`. Com a profundidade por defeito (10 000) o `pan` dá `error: max search depth too small` e a pesquisa fica incompleta.

Para verificar com **justiça fraca** (`-f`), o modelo tem 6 processos, por isso é preciso compilar com `-DNFAIR=3`:

```bash
gcc -DNFAIR=3 -o pan pan.c
./pan -a -f -m100000 -N p1
```

Para experimentar outra configuração (por exemplo 3 produtores, 1 consumidor e buffer de tamanho 1):

```bash
spin -DP=3 -DC=1 -DK=1 -a Assignment3-1-60294.pml
gcc -o pan pan.c
./pan -a -m100000 -N p1
```

### 🧪 Problema 2 — Eleição de Líder

```bash
spin -a Assignment3-2-60294.pml
gcc -o pan pan.c

./pan -a -N p_safety      # C3 — unicidade
./pan -a -N p_c2          # C2 — sem líder antes do fim
./pan -a -N p_stability   # C4 — estabilidade
./pan -a -N p_agreement   # acordo (versão com flooding, NFLOOD = 0)
./pan -a -N p_liveness    # C1 — eleição (versão original, NFLOOD = 1)
```

Ausência de deadlocks (sem fórmulas LTL):

```bash
gcc -DNOCLAIM -o pan pan.c
./pan
```

> ℹ️ Na versão original (`NFLOOD = 1`) esta verificação dá um *invalid end state*, e isso é esperado. Sem o anúncio do líder, os nós que perdem a eleição ficam à espera de mensagens que nunca chegam. A versão com *flooding* resolve isto e termina sem erros.

Se a verificação esgotar a memória, pode compilar-se com compressão de estados:

```bash
gcc -DCOLLAPSE -o pan pan.c
```

### 🐞 Reproduzir um contraexemplo

Quando o Spin encontra um erro, cria um ficheiro `.trail`. Para o reproduzir passo a passo:

```bash
spin -t -p -g -l Assignment3-1-60294.pml
```

| Opção | Efeito |
|:---:|---|
| `-t` | segue o ficheiro `.trail` |
| `-p` | mostra cada passo executado |
| `-g` | mostra as variáveis globais |
| `-l` | mostra as variáveis locais |

> 💡 Para ver o bug de *Lost Wakeup* no Problema 1, descomente o `Notifier` original (com o bug) e comente a versão corrigida com `notifyAll`. O `./pan -a -m100000 -N p1` passa a encontrar um *acceptance cycle*. No `.trail` vê-se que todos os processos ficam com `blocked[i] = 1`.

### 🧹 Limpar os ficheiros gerados

```bash
rm -f pan pan.* *.trail _spin_nvr.tmp
```

---

## 📄 Relatório

O ficheiro [`Assignment3-Report-60294.pdf`](Assignment3-Report-60294.pdf) explica as decisões de modelação (tamanho dos canais e dos arrays, uso de blocos `atomic`), os comandos usados e a interpretação dos resultados do Spin.

---

<div align="center">

Feito por **Pedro Rosa** · FCUL · Dezembro de 2025

</div>
