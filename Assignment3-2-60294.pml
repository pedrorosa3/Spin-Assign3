/*
   Software Reliability Course
   Masters Course on CSE
   Ciencias.ULisboa
   Fall 2025

   Assignment 3, Problem 2

   Instructor: Antonia Lopes
   Student: Pedro Rosa 60294
   
   Model: Leader Election Algorithm by Chang-Roberts.
*/

// Macro NFLOOD:
// Define qual a versão do algoritmo a ser verificada.
// 1 = Algoritmo Original (apenas eleição, sem anúncio).
// 0 = Algoritmo com Flooding (eleição + anúncio do líder a todos).
#define NFLOOD 0

#define N 5  // Número de nós no anel (Nodes)

// Definição dos Canais:
// Cria um array de N canais. Cada canal tem buffer de tamanho 1.
// O tipo de mensagem transporta uma etiqueta (mtype) e um valor (byte ID).
chan c[N] = [1] of { mtype, byte };

#if NFLOOD

//////////////////////////////////////////////////////
// 1. ORIGINAL ALGORITHM (Sem aviso de liderança)
//////////////////////////////////////////////////////

mtype = { ELECTION_MSG }; 

// Variáveis Globais para verificação
byte nr_leaders = 0; // Contador de quantos processos se autoproclamaram líderes

/*
  Processo Node (Versão Original)
  Argumentos:
  - myId: O ID único deste processo (gerado aleatoriamente).
  - myIdx: O índice deste processo no array de canais (0..N-1). 
           CRUCIAL: Usamos myIdx em vez de _pid para garantir que o anel
           fica ligado corretamente (0->1->...->N->0).
  - nextNode: O índice do canal onde devemos escrever (vizinho da direita).
*/
proctype Node (byte myId; byte myIdx; byte nextNode)
{  
    byte receivedId;
    
    // 1. Inicia a eleição enviando o seu ID ao vizinho da direita
    c[nextNode]!ELECTION_MSG, myId;

    // 2. Loop de processamento de mensagens
    // Lê explicitamente do canal 'myIdx' atribuído a este nó.
    do
    :: c[myIdx] ? ELECTION_MSG, receivedId -> 
       if
       :: (receivedId > myId) -> 
          // O ID recebido é maior do que o meu.
          // O vizinho (ou alguém atrás dele) é um candidato melhor.
          // Repasso a mensagem para a frente.
          c[nextNode] ! ELECTION_MSG, receivedId;
          
       :: (receivedId < myId) -> 
          // O ID recebido é menor do que o meu.
          // Eu sou um candidato melhor. "Engulo" a mensagem (não repasso).
          // O candidato 'receivedId' perdeu a eleição.
          skip; 
          
       :: (receivedId == myId) -> 
          // O meu próprio ID deu a volta completa ao anel.
          // Significa que sou o maior ID do sistema. Ganhei!
          nr_leaders++;
          printf("Node %d is the LEADER!\n", myId);
          
          // Termina a execução pois a eleição acabou para mim.
          break; 
       fi
    od
}

/*---------------------------------------------------------- 
    Init Process
    Responsável por configurar o sistema num estado válido.
----------------------------------------------------------*/
init {
    byte proc;
    byte assignedIds[N];
    bool used[N+1]; // Helper para garantir que não atribuímos IDs repetidos
    byte randId;    
    byte i;
    
    // Bloco atomic: Garante que toda a inicialização (gerar IDs e arrancar processos)
    // acontece de uma só vez antes de qualquer processo começar a trocar mensagens.
    atomic {
        // 1. Geração de IDs únicos e aleatórios de 1 a N.
        // Isto é importante para verificar que o algoritmo funciona
        // independentemente da ordem dos processos no anel.
        i = 0;
        do
        :: i < N -> 
           if
           :: !used[1] -> randId = 1;
           :: !used[2] -> randId = 2;
           :: !used[3] -> randId = 3;
           #if N >= 4
           :: !used[4] -> randId = 4;
           #endif
           #if N >= 5
           :: !used[5] -> randId = 5;
           #endif
           fi;
           
           used[randId] = true;
           assignedIds[i] = randId;
           i++;
        :: else -> break;
        od
        
        // 2. Inicia os processos ligados em anel
        i = 0;
        do
        :: i < N ->
           // CORREÇÃO TOPOLÓGICA:
           // Passamos 'i' como o índice de leitura (myIdx) e '(i+1)%N' como escrita.
           // Isto fecha o anel corretamente: 0->1, 1->2, ..., (N-1)->0.
           run Node(assignedIds[i], i, (i+1)%N);
           i++;
        :: else -> break;
        od
    }
}

// PROPERTIES FOR ORIGINAL ALGORITHM

// C3: Exactly one leader is elected (Safety part - Max 1)
// Garante que nunca há 2 líderes simultâneos.
ltl p_safety { [] (nr_leaders <= 1) }

// C1: Leader(s) will eventually be elected (Liveness)
// Garante que o contador de líderes chega a 1.
ltl p_liveness { <> (nr_leaders == 1) }

// C2: There is no leader until one leader is elected (Safety/Weak Until)
// O número de líderes deve manter-se 0 até se tornar 1.
ltl p_c2 { (nr_leaders == 0) W (nr_leaders == 1) }

// C4: Stability
// Se um processo for eleito (nr_leaders == 1), mantém-se eleito para sempre.
ltl p_stability { [] ( (nr_leaders == 1) -> [] (nr_leaders == 1) ) }

#else

//////////////////////////////////////////////////////
// 2. ALGORITHM WITH FLOODING (Com aviso de liderança)
//////////////////////////////////////////////////////

mtype = { ELECTION_MSG, LEADER_MSG };

// Variáveis Globais
byte nr_leaders = 0;
byte known_leader[N]; // Array onde cada nó regista quem ele acha que é o líder

/*
  Processo Node (Versão Flooding)
  Diferença: Após ganhar, envia uma mensagem LEADER_MSG para informar todos.
*/
proctype Node (byte myId; byte myIdx; byte nextNode)
{  
    byte receivedId;
    
    // 1. Inicia eleição
    c[nextNode]!ELECTION_MSG, myId;

    // 2. Loop principal
    do
    // --- Tratamento de Mensagens de Eleição ---
    :: c[myIdx] ? ELECTION_MSG, receivedId -> 
       if
       :: (receivedId > myId) -> 
          c[nextNode] ! ELECTION_MSG, receivedId;
          
       :: (receivedId < myId) -> 
          skip; 
          
       :: (receivedId == myId) -> 
          // Venci!
          nr_leaders++;
          // Atualizo o meu conhecimento local (usando myIdx)
          known_leader[myIdx] = myId;
          printf("Node %d (idx %d) won. Sending LEADER_MSG...\n", myId, myIdx);
          
          // INÍCIO DO FLOODING: Envia mensagem de vitória ao vizinho
          c[nextNode] ! LEADER_MSG, myId;
       fi
       
    // --- Tratamento de Mensagens de Anúncio de Líder ---
    :: c[myIdx] ? LEADER_MSG, receivedId ->
       
       // Registo quem é o líder
       known_leader[myIdx] = receivedId;
       
       if
       :: receivedId != myId -> 
          // Recebi o anúncio, mas não sou o líder.
          // Passo a palavra ao próximo nó.
          c[nextNode] ! LEADER_MSG, receivedId;
          printf("Node %d knows leader is %d\n", myId, receivedId);
          
          // IMPORTANTE: Break.
          // O nó já sabe quem é o líder e já avisou o próximo. 
          // Deve terminar para evitar ciclos de espera infinita (acceptance cycles).
          break; 
          
       :: else ->
          // A mensagem deu a volta completa e chegou a mim (o Líder).
          // Todos foram avisados.
          printf("Announcement completed.\n");
          break; // Fim do algoritmo.
       fi
    od
}

init {
    byte assignedIds[N];
    bool used[N+1];
    byte randId; // Variável renomeada para evitar conflito com 'rand()' do C
    byte i;
    
    atomic {
        // 1. Gerar IDs aleatórios (igual à versão anterior)
        i = 0;
        do
        :: i < N -> 
           if
           :: !used[1] -> randId = 1;
           :: !used[2] -> randId = 2;
           :: !used[3] -> randId = 3;
           #if N >= 4
           :: !used[4] -> randId = 4;
           #endif
           #if N >= 5
           :: !used[5] -> randId = 5;
           #endif
           fi;
           used[randId] = true;
           assignedIds[i] = randId;
           i++;
        :: else -> break;
        od
        
        // 2. Correr os nós com a topologia correta
        i = 0;
        do
        :: i < N ->
           // Instanciação com myIdx = i
           run Node(assignedIds[i], i, (i+1)%N);
           i++;
        :: else -> break;
        od
    }
}

// PROPERTIES FOR FLOODING

// C3 (Safety part): Max 1 leader
ltl p_safety { [] (nr_leaders <= 1) }

// C2: There is no leader until one leader is elected
ltl p_c2 { (nr_leaders == 0) W (nr_leaders == 1) }

// C1 & Agreement: Everyone eventually knows the correct leader
// Como os IDs são 1..N, o maior ID é N (neste caso 5).
// A propriedade verifica se todos os índices do array known_leader contêm N.
ltl p_agreement { <> (known_leader[0] == N && known_leader[1] == N && known_leader[2] == N && known_leader[3] == N && known_leader[4] == N) }

// C4: Stability
ltl p_stability { [] ( (nr_leaders == 1) -> [] (nr_leaders == 1) ) }

#endif