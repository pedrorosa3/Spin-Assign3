/*
   Software Reliability Course
   Masters Course on CSE
   Ciencias.ULisboa
   Fall 2025

   Assignment 3, Problem 1

   Instructor: Antonia Lopes
   Student: Pedro Rosa 60294

   Model: Bounded Buffer with Reentrant Synchronization.
*/

//////////////////////////////  
// Model Parameters
//////////////////////////////

// Macros para definir valores por defeito, permitindo override via linha de comandos
// Ex: spin -DXX=4 -a model.pml

// Número de processos consumidores
#ifndef  C
#define  C  2
#endif

// Número de processos produtores
#ifndef  P
#define  P 2
#endif

// Capacidade do Buffer
#ifndef  K
#define  K 2
#endif

//////////////////////////////  
// LTL Properties 
//////////////////////////////  

// Propriedades de Vivacidade (Liveness) para expor o bug de Deadlock/Starvation.

// Propriedade 1: Liveness do Produtor
// "É sempre verdade que, eventualmente, o buffer não está vazio" (alguém produziu)
// Se houver deadlock com buffer vazio (ninguém acorda os produtores), isto falha.
ltl p1 { []<> (occupied > 0) }

// Propriedade 2: Liveness do Consumidor
// "É sempre verdade que, eventualmente, o buffer não está cheio" (alguém consumiu)
// Se houver deadlock com buffer cheio, isto falha.
ltl p2 { []<> (occupied < K) }


//////////////////////////////  
// Model Variables
//////////////////////////////

// Representação do Monitor (Lock)
byte lockOwner = 0;   // 0 se livre, caso contrário contém o PID do dono do lock
byte lockCount = 0;   // Contador para suportar sincronização reentrante (Task 3)

// Variáveis de Sincronização e Estado do Buffer
bool blocked[1+P+C];     // Array de processos bloqueados (waiting)
bool notifySome = false; // Flag para indicar ao Notifier que deve acordar alguém
byte occupied = 0;       // Número de itens atualmente no buffer

/*---- Aux Defs (Reentrant Monitor Implementation) ----*/

// Simula a entrada num bloco synchronized (aquisição do lock).
// Lógica de Reentrância:
// 1. Se ninguém tem o lock (0), adquire e define contador a 1.
// 2. Se JÁ somos o dono, apenas incrementa o contador (reentrância).
// 3. Se for de outro, bloqueia (implícito pela guarda do atomic).
inline acquireLock(i){
  atomic {
    if
    :: lockOwner == 0 -> 
         lockOwner = i; 
         lockCount = 1;
    :: lockOwner == i -> 
         lockCount++;
    // Se lockOwner != 0 && lockOwner != i, o processo bloqueia aqui.
    fi
  }
}

// Simula a saída de um bloco synchronized (libertação do lock).
// Lógica de Reentrância:
// Apenas liberta o lock físico (lockOwner = 0) quando o contador chega a 0.
inline releaseLock(i){
  atomic {
    // Assert de segurança: só o dono pode libertar
    assert(lockOwner == i);
    lockCount--;
    if
    :: lockCount == 0 -> lockOwner = 0; // Saiu do nível mais externo, liberta lock.
    :: else -> skip; // Ainda está dentro de blocos aninhados, mantém lock.
    fi
  }
}

// Simula o método Object.wait().
// Comportamento Java: O wait deve libertar TOTALMENTE o lock, independentemente
// de quantas vezes o processo entrou no monitor (reentrância).
inline wait(i){
  byte savedCount; // Variável local para guardar o nível de reentrância atual
  atomic {
    assert(lockOwner == i);
    savedCount = lockCount; // 1. Guarda a profundidade atual (ex: entrou 3 vezes)
    lockCount = 0;          // 2. Reseta o contador (libertação total)
    lockOwner = 0;          // 3. Liberta o lock físico
    blocked[i] = true;      // 4. Marca-se como bloqueado
  }
  
  // Bloqueia aqui até ser notificado (alguém coloca blocked[i] a false)
  !blocked[i];
  
  // Ao acordar, tenta readquirir o lock (comportamento Java).
  // Restaura o nível de reentrância que tinha antes de dormir.
  atomic {
    lockOwner == 0 -> 
    lockOwner = i;
    lockCount = savedCount; // Restaura a profundidade (ex: volta a 3)
  }
}

// Simula o método Object.notify().
// Apenas sinaliza o processo Notifier.
inline notify(i){
  atomic {
    assert(lockOwner == i);
    notifySome = true;
  }
}

/*---------------------------------------------------------- 
    Init Process
----------------------------------------------------------*/
init{
    atomic {
        byte i;
        // Inicia o processo auxiliar de notificação
        run Notifier();
        // Inicia Produtores
        for(i : 1 .. P){
          run Producer(i); 
        }
        // Inicia Consumidores (IDs continuam após os produtores)
        for(i : P+1 .. P+C){
           run Consumer(i);
        }
    }
}

/*---------------------------------------------------------- 
   Notifier Process
   
   NOTA: Abaixo estão duas versões.
   A versão comentada é a original (BUGGY) que causa o Lost Wakeup.
   A versão ativa é a CORRIGIDA (Task 6) usando notifyAll.
----------------------------------------------------------*/

/* VERSÃO BUGGY (Simula notify() simples - acorda um aleatório)
proctype Notifier() {
    do
    :: notifySome -> 
       atomic {
         if
         :: blocked[1] -> blocked[1] = false; notifySome = false;
         :: blocked[2] -> blocked[2] = false; notifySome = false;
         #if (P+C >= 3)
         :: blocked[3] -> blocked[3] = false; notifySome = false;
         #endif
         // ... (outros casos omitidos)
         :: else -> notifySome = false; 
         fi
       }
    od
}
*/

/*---------------------------------------------------------- 
   Notifier Process (CORREÇÃO: notifyAll)
   Esta implementação resolve o bug do Lost Wakeup.
   Em vez de escolher um aleatoriamente, acorda TODOS os processos bloqueados.
   Isto garante que a thread correta conseguirá progredir.
----------------------------------------------------------*/
proctype Notifier() {
    byte i; // Variável para iteração
    do
    :: notifySome -> 
       atomic {
         // Percorre todos os processos possíveis (Produtores + Consumidores)
         // O range é de 1 até P+C
         for (i : 1 .. (P+C)) {
             if
             :: blocked[i] -> blocked[i] = false; // Se estiver bloqueado, acorda
             :: else -> skip; // Se não estiver, ignora
             fi
         }
         
         // Reset da flag de notificação após acordar todos
         notifySome = false; 
       }
    od
}

proctype Consumer(byte i){
    do
    :: true -> 
       acquireLock(i);
       
       // Simulação do while(occupied == 0) wait();
       do
       :: occupied == 0 -> wait(i);
       :: else -> break; // Sai do loop quando houver itens
       od;

       // Secção Crítica: Consumir
       assert(occupied > 0);
       occupied--;
       printf("Process %d (Consumer) consumed. Buffer: %d\n", i, occupied);

       notify(i);
       releaseLock(i);
    od
} 

proctype Producer(byte i){
    do
    :: true ->
       acquireLock(i);
       
       // Simulação do while(occupied == K) wait();
       do
       :: occupied == K -> wait(i);
       :: else -> break; // Sai do loop quando houver espaço
       od;

       // Secção Crítica: Produzir
       assert(occupied < K);
       occupied++;
       printf("Process %d (Producer) produced. Buffer: %d\n", i, occupied);

       notify(i);
       releaseLock(i);
    od
}