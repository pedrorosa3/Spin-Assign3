# Software Reliability Methods - Assignment 3 (Model Checking)

**Instituição:** Faculdade de Ciências da Universidade de Lisboa (FCUL)
**Curso:** Mestrado em Engenharia Informática (2025/2026)
**Autor:** Pedro Rosa (60294)

## 📌 Descrição do Projeto
Este repositório contém a resolução do terceiro trabalho prático da disciplina de *Software Reliability Methods*. O objetivo principal é a aplicação de técnicas de *Model Checking* utilizando a ferramenta **Spin** (com linguagem Promela) para verificar formalmente algoritmos concorrentes e distribuídos.

## 📂 Estrutura e Exercícios
O trabalho foca-se na verificação de duas classes de problemas de concorrência:

* **1. Bounded Buffer (Producer-Consumer):**
    * **Objetivo:** Modelação e análise de uma classe Java `BoundedBuffer` que utiliza monitorização e primitivas intrínsecas (`wait()` e `notify()`). O objetivo é encontrar um bug clássico de concorrência que afeta esta implementação específica usando o Spin.
    * **Funcionalidades:** Modelação da sincronização reentrante do Java, verificação de concorrência através de *assertions* (para monitor ownership) e geração de um *counter-example* que expõe o bloqueio ou corrupção de estado. Inclui (opcionalmente) uma correção validada para o problema no modelo.
* **2. Leader Election in a Ring:**
    * **Objetivo:** Verificação formal de um algoritmo distribuído para eleição de líder num anel unidirecional de $N > 2$ processos.
    * **Funcionalidades:** Modelação do algoritmo em Promela, garantia de ausência de *deadlocks* e verificação das propriedades principais de um algoritmo de eleição (usando LTL ou asserções):
        * C1: Um líder será eventualmente eleito.
        * C2: Não há líder antes da eleição terminar.
        * C3: Exatamente um líder é eleito (Uniqueness).
        * C4: Se um processo se considera líder, mantém-se líder (Stability).
    * **Extensão:** Implementação e verificação de um algoritmo de *flooding* secundário, iniciado pelo líder eleito, para garantir a propriedade de *Agreement* na rede.

## 📦 Ficheiros Submetidos
Os ficheiros da solução cumprem as diretrizes de entrega do projeto:

* `Assignment3-1-60294.pml` (Modelo Promela para o problema do Bounded Buffer, incluindo as asserções de controlo de concorrência)
* `Assignment3-2-60294.pml` (Modelo Promela para o algoritmo de Leader Election, incluindo a extensão de flooding)
* `Assignment3-Report-60294.pdf` (Relatório detalhado com decisões de modelação, tamanhos de canais/arrays, justificação de blocos `atomic`, comandos de execução no Unix e interpretação dos *outputs* do Spin).

## 🚀 Como Executar e Verificar
A verificação formal destes ficheiros requer a instalação da ferramenta [Spin](https://spinroot.com/).

**Fluxo geral de execução (exemplo para o Exercício 1):**

1.  Gerar o verificador C a partir do código Promela:
    ```bash
    spin -a Assignment3-1-60294.pml
    ```
2.  Compilar o verificador gerado:
    ```bash
    gcc -o pan pan.c
    ```
3.  Executar a verificação exaustiva:
    ```bash
    ./pan -a
    ```
*(Para verificar fórmulas LTL ou reproduzir *counter-examples* (`.trail`), devem ser seguidos os comandos exatos detalhados no relatório `Assignment3-Report-60294.pdf`)*
