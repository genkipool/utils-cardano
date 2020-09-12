# utils-cardano
Repsoitorio de scripts de utlidades cardano.

## simWinAda.py
Script que calcula de forma aproximada las ganancias que puede obtener un delegante al hacer stake.

```
python3 simWinAda.py

 [?] Cuántas ADAS quieres delegar: 1000
 [?] En cuantos pools quieres delegar: 1
 [?] Quieres delegar la misma cantidad de ADAs en los diferentes pools [y/n]: y
 [?] Quieres delegar las recompensas obtenidas [y/n]: n
 [?] Cuántos días dura una epoca: 5
 [?] Durante cuántos años quieres delegar: 1
 [?] Quieres Euros o Dolares [€/$]: €
 [?] Cúal es el precio de ADA: 0.10
 [?] Quieres que las recompensas se reduzcan segun van pasando los años [y/n]: n

```
## crearStakePool.sh
Script con las opciones necesarias para instalar, crear, configurar, registrar y mantener un stake pool de cardano.

```
./crearStakePool.sh

   0: Instalar programas: net-tools, mlocate tmux, htop, git, tree, curl, openssh, fail2ban, wget, Knockd, tcpdump, gnupg2 bc
   1: Instalar dependencias
   2: Instalar Libsodium
   3: Instalar Cabal y GHC
   4: Instalar Cardano-cli y Cardano-node
   5: Actualizar Cardano-node y Cardano-cli
   6: Configurar nodos relays
   7: Configurar Block Producer
   8: Crear script para iniciar los nodos
   9: Iniciar Nodos
   10: Calcular Kes period y parametros protocol
   11: Generar Keys Pool, cold, kes, vrf, operational certificate
   12: Generar Keys Address
   13: Solicitar Faucet
   14: Consultar saldo
   15: Crear script nodo block producer
   16: Registrar stake address
   17: Registrar stake pool
   18: Reclamar stake pool
   19: Descargar script get_buddies
   20: Cifrar keys Pool y keys address
   21: Descifrar keys Pool y keys address
   22: Consultar Recompensas
   23: Renovar certificado kes period
   24: Cambiar Pledge Fee y Margin
   25: Actualizar Metadata
   26: Retirar StakePool
   27: Consultar Retiro StakePool
   28: Iniciar Stake Pool de forma autoática cuando el sistema se reinicia
   29: Instalar prometheus
   30: Instalar Node Exporter
   31: Instalar grafana
   32: Configurar prometheus.yml
   33: Configurar Grafana
   34: Configurar Node Exporter
   35: Ayuda
   
   [*] Elige una o más opciones [0-35]: 0 1 2 3 4 5

```

