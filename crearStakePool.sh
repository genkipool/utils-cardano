#!/bin/bash

# Autor: LRB85
#---------------------------------------------------------------------
# File:    crearStakePool.sh
# Created: 27/06/2020
#=====================================================================
# Version Script: 2
# Software: Ubuntu 20.04
#
# ACTUALIZACIONES:
#  * 27/06/2020: cardano-node 1.14.1. Haskell Shelley Testnet
#  * 15/07/2020: cardano-node 1.15.1. Haskell Shelley Testnet 2
#  * 26/07/2020: cardano-node 1.18.0. Haskell Mainnet-Candidate-4
#  * 29/07/2020: cardano-node 1.18.0. Haskell Mainnet
#  * 13/08/2020: Se corrige error al copiar los binarios de cardano-node y cardano-cli
#  * 06/09/2020: Añade apartado extended metadata json
#  * 12/10/2020: Se añade apartado para actualizar IPs relay Pool
#  * 28/11/2020: actualizar cardano-node y cardano-cli 1.23.0 y ghcup 8.10.2
#  * 5/12/2020: se añade pool id hex, consultar saldo de direcciń concreta, enviar ADAS, reclamar recompensas, elegir pool mainnet o testnet
#
# DESCRIPCION:
#  * Este script crea un stake pool en Shelley Mainnet Haskell.
#

#################################################
#					Colores						#
#################################################

# High Intensity
End='\033[0m'       	  # End color
IBlack='\033[0;90m'       # Black
IRed='\033[0;91m'         # Red
IGreen='\033[0;92m'       # Green
IYellow='\033[0;93m'      # Yellow
IBlue='\033[0;94m'        # Blue
IPurple='\033[0;95m'      # Purple
ICyan='\033[0;96m'        # Cyan
IWhite='\033[0;97m'       # White


#################################################
#				Cancelar Script					#
#################################################

trap ctrl_c INT

ctrl_c() {
	echo -e "$IYellos \n [*] Exit Script $End"
	exit 0
}

trap cmd_error ERR

cmd_error() {
	echo $?
	echo -e "$IRed [!!!] Script Error $End"
	read line file <<<$(caller)
    echo  -e "$IRed [!] Ha ocurrido un error en la línea $line del archivo $file:" >&2

	sleep 2
	exit 100
}

#################################################
#				Instalar Programas              #
#################################################

instalarProgramas(){

	echo $1
	sudo apt update -y
	sudo apt upgrade -y
	for programa in ${Programas[@]}
		do
			case $programa in
				Knockd) 
					echo -e "$IGreen \n [*] Instalar $programa $End"
					sudo add-apt-repository universe
					sudo apt-get install -y $programa
					echo -e "$IGreen \n [+] $programa instalado \n$End"
				;;
				GHC)
					echo -e "$IGreen \n [*] Instalar $programa $End"
				    echo -e "$IGreen \n [*] Instalar ghcup (The Haskell Toolchain installer) .."
				    # TMP: Dirty hack to prevent ghcup interactive setup, yet allow profile set up
				    unset BOOTSTRAP_HASKELL_NONINTERACTIVE
				    export BOOTSTRAP_HASKELL_NO_UPGRADE=1
				    CURL_TIMEOUT=60

  					curl -s -m ${CURL_TIMEOUT} --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sed -e 's#read.*#answer=Y;next_answer=Y;hls_answer=N#' | bash

				    # shellcheck source=/dev/null
				    . ~/.ghcup/env
				    ghcup install 8.10.2
				    ghcup set  8.10.2
				    ghc --version
				    echo -e "$IGreen \n [+] $programa instalado \n$End"
			  	;;
			  	Libsodium)
					echo -e "$IGreen \n [*] Instalar $programa $End"
					cd
					if ! grep -q "/usr/local/lib:\$LD_LIBRARY_PATH" "${HOME}"/.bashrc; then
					    echo "export LD_LIBRARY_PATH=/usr/local/lib:\$LD_LIBRARY_PATH" >> "${HOME}"/.bashrc
					    export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
					fi
					if ! grep -q "/usr/local/lib:\$PKG_CONFIG_PATH" "${HOME}"/.bashrc; then
					    echo "export PKG_CONFIG_PATH=/usr/local/lib:\$PKG_CONFIG_PATH" >> "${HOME}"/.bashrc
					    export PKG_CONFIG_PATH=/usr/local/lib:$LD_LIBRARY_PATH
					fi

					git clone https://github.com/input-output-hk/libsodium &>/dev/null
					cd libsodium
					git checkout 66f017f1 &>/dev/null
					./autogen.sh > autogen.log > /tmp/libsodium.log 2>&1
					./configure > configure.log >> /tmp/libsodium.log 2>&1
					make > make.log 2>&1
					sudo make install > install.log 2>&1
					echo "IOG fork of libsodium installed to /usr/local/lib/"

				;;
				Cabal) 
					echo -e "$IGreen \n [*] Instalar $programa $End"
					cd ~
					#wget https://downloads.haskell.org/~cabal/cabal-install-3.2.0.0/cabal-install-3.2.0.0-x86_64-unknown-linux.tar.xz
					#tar -xf cabal-install-3.2.0.0-x86_64-unknown-linux.tar.xz
					#rm cabal-install-3.2.0.0-x86_64-unknown-linux.tar.xz cabal.sig
					if ! grep -q "$HOME/.ghcup/env" "${HOME}"/.bashrc; then
						echo export GHCUP_INSTALL_BASE_PREFIX="$HOME/.ghcup/env" >> ~/.bashrc
						export GHCUP_INSTALL_BASE_PREFIX=$HOME/.ghcup/env
					fi
					. "${HOME}/.bashrc"
					sleep 1
					ghcup install-cabal
					echo -e "$IGreen \n [+] $programa instalado \n$End"

				;;
				"cardano-cli-cardano-node") 
					echo -e "$IGreen \n [*] Instalar $programa $End"
					cd ~; sleep 1
					git clone https://github.com/input-output-hk/cardano-node
					if [ $? -eq 0 ]; then git clone https://github.com/input-output-hk/cardano-node; fi
					cd cardano-node
					echo -e "package cardano-crypto-praos\n  flags: -external-libsodium-vrf" > cabal.project.local
						
					if [ ! -d ~/.local/bin ]; then mkdir -p ~/.local/bin; fi
					if [ ! -d ~/.cabal/bin ]; then mkdir -p ~/.cabal/bin; fi

					export PATH=~/.local/bin:~/.cabal/bin:$PATH

					if !  grep '~/.local/bin:' ~/.bashrc > /dev/null; then echo PATH="~/.local/bin:~/.cabal/bin:$PATH" >> ~/.bashrc
					else echo -e "$IGreen \n [i] Ya existe $PATH \n$End"; fi

					. "${HOME}/.bashrc"
					sed -i 's/-- overwrite-policy:/-- overwrite-policy: always/' ~/.cabal/config

					tmux new -d -s $USER; sleep 1
					tmux send-keys "source ~/.bashrc" C-m; sleep 1
					tmux send-keys "~/.ghcup/bin/cabal build all 2>&1 | tee /tmp/build.log && exit" C-m; sleep 1
					tmux attach -t $USER

					grep "^Linking" /tmp/build.log | while read -r line ; do
					    act_bin_path=$(echo "$line" | awk '{print $2}')
					    act_bin=$(echo "$act_bin_path" | awk -F "/" '{print $NF}')
					    echo "Copiando $act_bin al directorio $HOME/.cabal/bin/"
					    cp "$act_bin_path" "$HOME/.cabal/bin/"
					done
					
					if [ ! -f ~/.cabal/bin/cardano-node ]; then echo -e "$IRed \n[!!!] cardano-node no se ha instalado correctamente, ejecute de nuevo el script $End"
					else echo -e "$IGreen \n [+] $programa instalado \n$End"; fi
					
				;;
				"Actualizar-Cardano-Node-y-Cardano-CLI")
					cd $dirCardanoNode
					echo -e "$IGreen \n [*] Version instalada $End"
					cardano-node version
					cardano-cli version
					read -p " [?] Quieres actualizar a una nueva version [y/n]: " respuesta
					if [[ $respuesta =~ ^[Yy]$ ]]; then
						git fetch --all --tags
						git tag
						while true; do
							read -p " [?] Escriba que version quiere instalar [ejemplo: 1.16.x]: " version
							git checkout tags/$version
							if [ $? -eq 0 ]; then 
								cabal update
								cabal clean
								cabal install cardano-node cardano-cli --overwrite-policy=always
								cabal build all
								ghc_version=$( ghc -V | awk '{printf $NF}')
								cardano_cli_version=$version
								cardano_node_version=$version
								if [ -f "~/.local/bin/stopNodos" ]; then sudo systemctl stop cardano-stakepool.service; fi
								cp "$HOME/cardano-node/dist-newstyle/build/x86_64-linux/ghc-$ghc_version/cardano-cli-$cardano_cli_version/x/cardano-cli/build/cardano-cli/cardano-cli" "$HOME/.cabal/bin/"
								cp "$HOME/cardano-node/dist-newstyle/build/x86_64-linux/ghc-$ghc_version/cardano-node-$cardano_node_version/x/cardano-node/build/cardano-node/cardano-node" "$HOME/.cabal/bin/"
								if [ -f "~/.local/bin/stopNodos" ]; then sudo systemctl start cardano-stakepool.service; fi
								break
								if [ $? -eq 0 ]; then  echo -e "$IGreen \n [*] cardano-node y cardano-cli se han actualizado correctamente \n$End"
								else  echo -e "$IRed [!!!] Error, cardano-node y cardano-cli no se han actualizado correctmente, repita los pasos instalar GHC, Cabal, cardano-node y cardano-cli  $End"; fi
							else
								echo -e "$IRed [!!!] Error, version incorrecta prueba con la versión 1.16.x $End"
							fi 
						done
					fi
				;;
				"prometheus"*)
					cd
					sudo apt autoremove -y
					echo -e "$IGreen \n [*] Instalar $programa $End"
					sudo apt-get install -y $programa
					echo -e "$IGreen \n [+] $programa instalado \n$End"

				;;
				"prometheus-node-exporter")
					cd
					sudo apt autoremove -y
					echo -e "$IGreen \n [*] Instalar $programa $End"
					sudo apt-get install -y $programa
					echo -e "$IGreen \n [+] $programa instalado \n$End"
				;;
				"Instalar-gafana")
					sudo apt autoremove -y
					sudo wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
					#sudo su
					sudo su -c "echo 'deb https://packages.grafana.com/oss/deb stable main' > /etc/apt/sources.list.d/grafana.list"
					#su 
					sudo apt-get update && sudo apt-get install -y grafana
					cd /etc/grafana
					sudo sed -i.bak -e "s/;http_port = 3000/http_port = 30000/g" grafana.ini
					echo -e "$IGreen \n [*] Grafana instalado y configurado en el puerto 30000 $End"

				;;
				*)
					echo -e "$IGreen \n [*] Instalar $programa $End"
					sudo apt-get install -y $programa
					echo -e "$IGreen \n [+] $programa instalado \n$End"
			esac
	done
}


#####################################################
#			Chequear Datos Nodos				    # 
#####################################################

checkDatosNodo(){

	if [ ! -f "${dirNodos}/$filedatosPool" -o $registros == "actualizarDatos" ]; then
		while true; do
			while true; do
				read -p " [?] Has instalado ya algún nodo relay en otra/s máquina/s [y/n]: " respuesta
				if [[ $respuesta =~ ^[Yy]$ ]]; then 
					read -p " [?] Cuántos nodos relays has instalado en la otra/s máquina/s [1-20]: " datosPool["Relays_en_otra_Maquina"]
					if [ ${datosPool["Relays_en_otra_Maquina"]} -gt 0 -a ${datosPool["Relays_en_otra_Maquina"]} -lt 21 ]; then break;
					 else echo -e "$IYellow \n [!!] Dato incorrecto introduce un número entre el 1 y el 20 $End"; continue; fi
				else 
					datosPool["Relays_en_otra_Maquina"]=0
					break 
				fi
			done
			while true; do
				read -p " [?] Cuántos nodos relays quieres instalar en esta máquina [0-20]: " datosPool["Relays_en_esta_Maquina"]
				if [ ${datosPool["Relays_en_esta_Maquina"]} -ge 0 -a ${datosPool["Relays_en_esta_Maquina"]} -lt 21 ]; then
					if [ -z ${datosPool["Relays_en_otra_Maquina"]} ]; then relayInstalados=${datosPool["Relays_en_esta_Maquina"]}
					else relayInstalados=$(expr ${datosPool["Relays_en_esta_Maquina"]} + ${datosPool["Relays_en_otra_Maquina"]}); fi
					read -p " [?] Cuantos nodos relays quieres instalar en total entre todas las máquinas [$relayInstalados-20]: " datosPool["Relays_total_Maquinas"]

					if [ ${datosPool["Relays_total_Maquinas"]} -ge $relayInstalados -a ${datosPool["Relays_total_Maquinas"]} -lt 21 ]; then break;
					 else echo -e "$IYellow \n [!!] Dato incorrecto, el número total de relays a instalar no puede ser inferior a la suma de relays instalados en otras máquinas $End"; continue; fi
				 else echo -e "$IYellow \n [!!] Dato incorrecto introduce un número entre el 1 y el 20 $End"; continue; fi
			done
			if [ -z ${datosPool["Relays_en_otra_Maquina"]} ]; then
				numRelay=1
				relayMaquina=${datosPool["Relays_en_esta_Maquina"]}
			else
				numRelay=$( expr ${datosPool["Relays_en_otra_Maquina"]} + 1 )
				relayMaquina=$( expr ${datosPool["Relays_en_esta_Maquina"]} + ${datosPool["Relays_en_otra_Maquina"]} )
			fi
			if [ ${datosPool["Relays_en_esta_Maquina"]} -gt 0 ]; then echo -e "$IGreen [+] En esta máquina se van a instalar los relay_$numRelay al relay_$relayMaquina $End"; fi
			
			numrealy=${datosPool["Relays_total_Maquinas"]}

			regexHostname='^[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)' 

			while true; do
				for (( c=1; c<=$numrealy; c++ )); do
					while true; do
						read -p " [+] Introduce un nombre para el relay_$c [ejemplo: realy_cardano]: " datosPool["nombre_Relay_$c"]
						read -p " [+] Ingrese dirección IPv4 pública relay_$c [ejemplo: 80.59.87.20]: " datosPool["IP_Pub_realy_$c"]
						if [[ ${datosPool["IP_Pub_realy_$c"]} =~ ^([0-9]{1,3}[\.]){3}[0-9]{1,3}$ ]]; then break;
						else echo -e "$IYellow \n [!!] Dirección IPv4 pública incorrecta $End"; continue; fi 
					done 
					while true; do
						read -p " [+] Ingrese dirección IPv4 privada relay_$c [ejemplo: 192.168.1.1]: " datosPool["IP_Priv_realy_$c"]
						if [[ ${datosPool["IP_Priv_realy_$c"]} =~ ^([0-9]{1,3}[\.]){3}[0-9]{1,3}$ ]]; then break;
						else echo -e "$IYellow \n [!!] Dirección IPv4 privada incorrecta $End"; continue; fi 
					done
		            while true; do
		                read -p " [+] Ingrese puerto relay_$c [1024 - 49151]: " datosPool["Port_realy_$c"]
		                if [ ${datosPool["Port_realy_$c"]} -gt 1023 -a ${datosPool["Port_realy_$c"]} -lt 49152 ]; then break;
		                else echo -e "$IYellow \n [!!] Dato incorrecto, introduce un puerto comprendido entre los números 1024 y 49151 $End"; continue; fi
		            done
		             read -p " [?] Quieres añadir un hostname a cada uno de los relays [y/n]: " datosPool["añadir_hostname"]
		            if [[ ${datosPool["añadir_hostname"]} =~ ^[Yy]$ ]]; then
			            while true; do
			                read -p " [+] Ingrese hostname relay_$c [ejemplo: relay1.stakepool.com]: " datosPool["Hostname_realy_$c"]
			                if [[ ${datosPool["Hostname_realy_$c"]} =~ $regexHostname ]]; then break;
			                else echo -e "$IYellow \n [!!] Dato incorrecto, introduce un dominio valido $End"; continue; fi
			            done
			        fi
		        done
		        break
		    done
		 
			while true; do
				read -p " [+] Introduce un nombre para el nodo Block Producer [ejemplo: block_cardano]: " datosPool["nombre_Block"]
				read -p " [+] Ingrese dirección IPv4 pública del Block Producer [ejemplo: 80.59.87.20]: " datosPool["IP_block_Pub"]
				if [[  ${datosPool["IP_block_Pub"]} =~ ^([0-9]{1,3}[\.]){3}[0-9]{1,3}$ ]]; then break;
				else echo -e "$IYellow \n [!!] Dirección IPv4 privada incorrecta $End"; continue; fi 
			done
			while true; do
				read -p " [+] Ingrese dirección IPv4 privada del Block Producer [ejemplo: 192.168.1.1]: " datosPool["IP_block_Priv"]
				if [[  ${datosPool["IP_block_Priv"]} =~ ^([0-9]{1,3}[\.]){3}[0-9]{1,3}$ ]]; then break;
				else echo -e "$IYellow \n [!!] Dirección IPv4 privada incorrecta $End"; continue; fi 
			done
			while true; do
				read -p " [+] Ingrese puerto Block Producer [1024 - 49151]: " datosPool["Port_block"]
				if [ ${datosPool["Port_block"]} -gt 1023 -a ${datosPool["Port_block"]} -lt 49152 ] ; then break;
				else echo -e "$IYellow \n [!!] Dato incorrecto, introduce un puerto comprendido entre los números 1024 y 49151 $End"; continue; fi
			done
			while true; do
				read -p " [+] Quieres que el nodo Block Producer se comunique con los nodos Relays por IPv4 privada o IPv4 pública [priv/pub]: " datosPool["comunicacion_Nodos"]
				if [[ ${datosPool["comunicacion_Nodos"]} == "priv" ]]; then break;
				elif [[ ${datosPool["comunicacion_Nodos"]} == "pub" ]]; then break;
				else echo -e "$IYellow \n [!!] Dato incorrecto, introduce priv o pub $End"; continue; fi
			done
			echo -e "$IGreen \n [*] Ha introducido los siguientes datos: $End" 
			for datosNodos in "${!datosPool[@]}"; do
				echo -e "$IGreen [+] $datosNodos: ${datosPool[$datosNodos]} $End" 
			done
			read -p " [?] Esta deacuerdo con los datos introducidos [y/n]: " respuesta
			if [[ $respuesta =~ ^[Yy]$ ]]; then break;
			else continue; fi
		done
		declare -p datosPool > ${dirNodos}/$filedatosPool
	fi

	 
}

#################################################
#			Descarfgar Archivos Json		    # 
#################################################

DecargarAchivosJson(){

	cd ~
	if [ ! -d "${dirNodos}" ]; then 
		mkdir -p $dirNodos;
		cd $dirNodos 
		echo -e "$IGreen \n [*] Descargando archivos  .json $End" 
		wget -N $webIOHKfilesJson/$fileShelleyConfig
		wget -N $webIOHKfilesJson/$fileShelleyGenesis
		wget -N $webIOHKfilesJson/$fileShelleyGenesisByron
		wget -N $webIOHKfilesJson/$fileShelleytopology
		wget -N $webIOHKfilesJson/$fileShelleyresConfig
		wget -N $webIOHKfilesJson/$fileShelleydbSyn
		#mv *-shelley-genesis.json shelley_testnet-genesis.json

		echo -e "$IGreen \n [*] Configurando LiveView y TraceBlockFetchDecisions true \n $End" 
		sed -i.bak -e "s/SimpleView/LiveView/g" -e "s/TraceBlockFetchDecisions\": false/TraceBlockFetchDecisions\": true/g" $fileShelleyConfig
	else
		cd $dirNodos 
		echo -e "$IGreen \n [*] Descargando archivos  .json $End" 
		wget -N $webIOHKfilesJson/$fileShelleyConfig
		wget -N $webIOHKfilesJson/$fileShelleyGenesis
		wget -N $webIOHKfilesJson/$fileShelleyGenesisByron
		wget -N $webIOHKfilesJson/$fileShelleytopology
		wget -N $webIOHKfilesJson/$fileShelleyresConfig
		wget -N $webIOHKfilesJson/$fileShelleydbSyn
		#mv *-shelley-genesis.json shelley_testnet-genesis.json

		echo -e "$IGreen \n [*] Configurando LiveView y TraceBlockFetchDecisions true \n $End" 
		sed -i.bak -e "s/SimpleView/LiveView/g" -e "s/TraceBlockFetchDecisions\": false/TraceBlockFetchDecisions\": true/g" $fileShelleyConfig
	 fi
}

#################################################
#			Configurar Relays 				    # 
#################################################

configTopoRealys(){

	
	totalRelays=${datosPool["Relays_total_Maquinas"]}
	
	if [ -z ${datosPool["Relays_en_otra_Maquina"]} ]; then
		numRelay=1
		relayMaquina=${datosPool["Relays_en_esta_Maquina"]}
	else
		numRelay=$( expr ${datosPool["Relays_en_otra_Maquina"]} + 1 )
		relayMaquina=$( expr ${datosPool["Relays_en_esta_Maquina"]} + ${datosPool["Relays_en_otra_Maquina"]} )
	fi

	cd $dirNodos
	for (( c=numRelay; c<=$relayMaquina; c++ )); do
		if [ ! -d "${dirRelay}$c" ]; then mkdir $dirRelay$c; fi
			echo -e "$IGreen \n [*] Creando directorio $dirRelay$c .json $End" 
			echo -e "$IGreen [*] Copiando archivos .json a $dirRelay$c $End" 
			cp $filesJson*.json $dirRelay$c
	done

	if [[ ${datosPool["comunicacion_Nodos"]} == "priv" ]]; then 
		blockIP=${datosPool["IP_block_Priv"]}
	else blockIP=${datosPool["IP_block_Pub"]}; fi

	echo -e "\n"
	for (( c=$numRelay; c<=$relayMaquina; c++ )); do
		cd $dirRelay$c
		echo -e "$IGreen [*] Creando archivo $fileShelleytopology para nodo relay_$c $End"  
		echo  "{" > $fileShelleytopology
		echo "  \"Producers\": [" >> $fileShelleytopology
		echo "    {" >> $fileShelleytopology
		echo "      \"opertor\": \"${datosPool[nombre_Block]}\"," >> $fileShelleytopology
		echo "      \"addr\": \"$blockIP\"," >> $fileShelleytopology
		echo "      \"port\": ${datosPool[Port_block]}," >> $fileShelleytopology
		echo "      \"valency\": 1" >> $fileShelleytopology
		echo "    }," >> $fileShelleytopology
		for (( n=1; n<=$totalRelays; n++ )); do
			if [[ $c != $n ]]; then
				if [[ ${datosPool["comunicacion_Nodos"]} == "priv" ]]; then 
					relayIP=${datosPool["IP_Priv_realy_$n"]}
				else relayIP=${datosPool["IP_Pub_realy_$n"]}; fi
				echo "    {" >> $fileShelleytopology
				echo "      \"opertor\": \"${datosPool[nombre_Relay_$n]}\"," >> $fileShelleytopology
		        echo "      \"addr\": \"$relayIP\"," >> $fileShelleytopology
		        echo "      \"port\": ${datosPool[Port_realy_$n]}," >> $fileShelleytopology
		        echo "      \"valency\": 1" >> $fileShelleytopology
		      	echo "    }," >> $fileShelleytopology
		   	fi
		done
		echo "    {" >> $fileShelleytopology
		echo "      \"opertor\": \"$nameIOHK\"," >> $fileShelleytopology
		echo "      \"addr\": \"$IPIOHK\"," >> $fileShelleytopology
		echo "      \"port\": $PortIOHK," >> $fileShelleytopology
		echo "      \"valency\": 2" >> $fileShelleytopology
		echo "    }" >> $fileShelleytopology
		echo "  ]" >> $fileShelleytopology
		echo "}" >> $fileShelleytopology
	done
	cd ..
	declare -p datosPool > ${dirNodos}/$filedatosPool


}

#################################################
#			Configurar Block Producer		    # 
#################################################

configTopoblockProducer(){

	totalRelays=${datosPool["Relays_total_Maquinas"]}

	cd $dirNodos
	if [ ! -d "${dirBlock}" ]; then mkdir $dirBlock; fi
		echo -e "$IGreen \n [*] Creando directorio $dirBlock .json $End" 
		echo -e "$IGreen [*] Copiando archivos .json a $dirBlock $End" 
		cp $filesJson*.json $dirBlock

	cd $dirBlock

	echo -e "$IGreen [*] Creando archivo $fileShelleytopology para nodo block_producer $End"  
	echo  "{" > $fileShelleytopology
	echo "  \"Producers\": [" >> $fileShelleytopology
	for (( n=1; n<=$totalRelays; n++ )); do
		if [[ ${datosPool["comunicacion_Nodos"]} == "priv" ]]; then 
			relayIP=${datosPool["IP_Priv_realy_$n"]}
		else relayIP=${datosPool["IP_Pub_realy_$n"]}; fi
		echo "    {" >> $fileShelleytopology
		echo "      \"opertor\": \"${datosPool[nombre_Relay_$n]}\"," >> $fileShelleytopology
		echo "      \"addr\": \"$relayIP\"," >> $fileShelleytopology
		echo "      \"port\": ${datosPool[Port_realy_$n]}," >> $fileShelleytopology
		echo "      \"valency\": 1" >> $fileShelleytopology
		if [[ $n == $totalRelays ]]; then echo "    }" >> $fileShelleytopology
		else echo "    }," >> $fileShelleytopology; fi
	done
	echo "  ]" >> $fileShelleytopology
	echo "}" >> $fileShelleytopology


	if ! grep 'CARDANO_NODE_SOCKET_PATH' ~/.bashrc > /dev/null; then 
		export CARDANO_NODE_SOCKET_PATH="${dirBlock}/db/socket"
		echo export CARDANO_NODE_SOCKET_PATH="${dirBlock}/db/socket" >> ~/.bashrc
		. "${HOME}/.bashrc"
	fi
	cd ..
	declare -p datosPool > ${dirNodos}/$filedatosPool
}

#########################################################
#			Crear Scripts para iniciar nodos		    # 
#########################################################

scriptIniciarNodos(){

	if [ -f "${dirNodos}/$filedatosPool" -o ! -z "${datosPool["Relays_total_Maquinas"]}" ]; then
		totalRelays=${datosPool["Relays_total_Maquinas"]}
		for (( n=1; n<=$totalRelays; n++ )); do
			if [ -d "${dirRelay}$n" ]; then
				cd ${dirRelay}$n

				echo "cardano-node run --topology ${dirRelay}${n}/$fileShelleytopology \\" > $fileIniciarRelay$n
				echo "--database-path ${dirRelay}${n}/db \\" >> $fileIniciarRelay$n
				echo "--socket-path ${dirRelay}${n}/db/socket \\" >> $fileIniciarRelay$n
				echo "--host-addr ${ipTopoRelayPub} \\" >> $fileIniciarRelay$n
				echo "--port ${datosPool[Port_realy_$n]} \\" >> $fileIniciarRelay$n
				echo "--config ${dirRelay}${n}/$fileShelleyConfig" >> $fileIniciarRelay$n

				echo -e "$IGreen \n [*] Se va a crear el siguiente script en el directorio ${dirRelay}$n con los siguientes datos: \n $End" 
				cat $fileIniciarRelay$n
				echo -e "\n"
				read -p " [?] Esta deacuerdo con los datos introducidos [y/n]: " respuesta
				if [[ $respuesta =~ ^[Yy]$ ]]; then
					chmod +x  $fileIniciarRelay$n
				else 
					while true; do
						echo -e "$IGreen \n [*] Cambie los datos con los que no este deacuerdo del relay_$n: $End" 
						while true; do
							read -p " [?] Ingrese la ruta completa del directorio de archivo topologia [ejemplo /home/pepe/relay/testnet-topology.json]: " topologia
							if [ -f "$topologia" ]; then 
								break
							else 
								echo -e "$IYellow [!!] El archivo $topologia no existe $End"
								continue
							fi
						done
						read -p " [?] Ingrese la ruta completa del directorio de base de datos [ejemplo /home/pepe/relay/db]: " baseDatos
						read -p " [?] Ingrese la ruta completa del directorio de archivo configuración [ejemplo /home/pepe/relay/testnet-config.json]: " config
						while true; do
							read -p " [?] Ingrese dirección IPv4 que quiere poner a la escucha en el nodo realy_$n [ejemplo: 192.168.1.1]: " ipRelay
							if [[  ${ipRelay} =~ ^([0-9]{1,3}[\.]){3}[0-9]{1,3}$ ]]; then break;
							else echo -e "$IYellow \n [!!] Dirección IPv4 incorrecta $End"; continue; fi 
						done
						
						while true; do
							read -p " [+] Ingrese puerto que se pondra a la escucha en nodo realy_$n [1024 - 49151]: " puerto
							if [ ${puerto} -gt 1023 -a ${puerto} -lt 49152 ] ; then break;
							else echo -e "$IYellow \n [!!] Dato incorrecto, introduce un puerto comprendido entre los números 1024 y 49151 $End"; continue; fi
						done


						echo "cardano-node run --topology $topologia \\" > $fileIniciarRelay$n
						echo "--database-path $baseDatos \\" >> $fileIniciarRelay$n
						echo "--socket-path $baseDatos/socket \\" >> $fileIniciarRelay$n
						echo "--host-addr $ipRelay \\" >> $fileIniciarRelay$n
						echo "--port ${puerto} \\" >> $fileIniciarRelay$n
						echo "--config ${config}" >> $fileIniciarRelay$n

						echo -e "$IGreen \n [*] Se va a crear el siguiente script con los siguientes datos: \n $End" 
						cat $fileIniciarRelay$n
						echo -e "\n"
						read -p " [?] Esta deacuerdo con los datos introducidos [y/n]: " respuesta
						if [[ $respuesta =~ ^[Yy]$ ]]; then
							chmod +x  $fileIniciarRelay$n
							break
						else
							continue
						fi
					done
				fi	
				echo -e "$IGreen \n [*] Script $fileIniciarRelay$n creado en el directorio  ${dirRelay}$n $End" 
				echo -e "$IGreen [*] Copiando script $fileIniciarRelay$n al directorio ~/.local/bin $End" 
				cp $fileIniciarRelay$n ~/.local/bin
				echo -e "$IGreen [*] Para iniciar el nodo relay_$n ejecute el comando $fileIniciarRelay$n $End" 		
			fi				
		done

		if [ -d "${dirBlock}" ]; then
			cd ${dirBlock}

			if [[ ${datosPool["comunicacion_Nodos"]} == "priv" ]]; then 
				addrHost=${datosPool["IP_block_Priv"]}
			else addrHost="$ipTopoBlockPub"; fi

			echo "cardano-node run --topology ${dirBlock}/$fileShelleytopology \\" > $fileIniciarBlock
			echo "--database-path ${dirBlock}/db \\" >> $fileIniciarBlock
			echo "--socket-path ${dirBlock}/db/socket \\" >> $fileIniciarBlock
			echo "--host-addr $addrHost \\"  >> $fileIniciarBlock
			echo "--port ${datosPool[Port_block]} \\" >> $fileIniciarBlock
			if [ -f "${dirBlock}/${dirKeysPool}/$cert_issue_op" ]; then
				 echo "--config ${dirBlock}/$fileShelleyConfig \\" >> $fileIniciarBlock
				 echo "--shelley-kes-key ${dirBlock}/${dirKeysPool}/$keyKES_Skey \\" >> $fileIniciarBlock
				 echo "--shelley-vrf-key ${dirBlock}/${dirKeysPool}/$keyVRF_Skey \\" >> $fileIniciarBlock
				 echo "--shelley-operational-certificate ${dirBlock}/${dirKeysPool}/$cert_issue_op" >> $fileIniciarBlock
			else
				 echo "--config ${dirBlock}/$fileShelleyConfig " >> $fileIniciarBlock
			fi

			echo -e "$IGreen \n [*] Se va a crear el siguiente script con los siguientes datos: \n $End" 
			cat $fileIniciarBlock
			echo -e "\n"
			read -p " [?] Esta deacuerdo con los datos introducidos [y/n]: " respuesta
			if [[ $respuesta =~ ^[Yy]$ ]]; then
				chmod +x $fileIniciarBlock
			else 
				while true; do
					echo -e "$IGreen \n [*] Cambie los datos con los que no este deacuerdo del Block Producer: $End" 
					while true; do
						read -p " [?] Ingrese la ruta completa del directorio de archivo topologia [ejemplo /home/pepe/block/testnet-topology.json]: " topologia
						if [ -f "$topologia" ]; then 
							break
						else 
							echo -e "$IYellow [!!] El archivo $topologia no existe $End"
							continue
						fi
					done
					read -p " [?] Ingrese la ruta completa del directorio de base de datos [ejemplo /home/pepe/block/db]: " baseDatos
					read -p " [?] Ingrese la ruta completa del directorio de archivo configuración [ejemplo /home/pepe/block/testnet-config.json]: " config
					while true; do
						read -p " [?] Ingrese dirección IPv4 que quiere poner a la escucha en el nodo Block Producer [ejemplo: 192.168.1.1]: " ipBlock
						if [[  ${ipBlock} =~ ^([0-9]{1,3}[\.]){3}[0-9]{1,3}$ ]]; then break;
						else echo -e "$IYellow \n [!!] Dirección IPv4 incorrecta $End"; continue; fi 
					done
					
					while true; do
						read -p " [+] Ingrese puerto que se pondra a la escucha en nodo Block_Producer [1024 - 49151]: " puerto
						if [ ${puerto} -gt 1023 -a ${puerto} -lt 49152 ] ; then break;
						else echo -e "$IYellow \n [!!] Dato incorrecto, introduce un puerto comprendido entre los números 1024 y 49151 $End"; continue; fi
					done

					echo "cardano-node run --topology ${topologia} \\" > $fileIniciarBlock
					echo "--database-path ${baseDatos} \\" >> $fileIniciarBlock
					echo "--socket-path ${baseDatos}/socket \\" >> $fileIniciarBlock
					echo "--host-addr ${ipBlock} \\"  >> $fileIniciarBlock
					echo "--port ${puerto} \\" >> $fileIniciarBlock
					if [ -f "${dirBlock}/${dirKeysPool}/$cert_issue_op" ]; then
						 echo "--config ${config} \\" >> $fileIniciarBlock
					else echo "--config ${config}" >> $fileIniciarBlock; fi

					for nodo in ${nodoblock[@]}; do
						case $nodo in
							block) 
							while true; do
								read -p " [?] Ingrese la ruta completa del directorio de la key $keyKES_Skey [ejemplo /home/pepe/block/$keyKES_Skey]: " keyKESskey
								if [ -f "$keyKES_Skey" ]; then 
									break
								else 
									echo -e "$IYellow [!!] La key $keyKES_Skey no existe $End"
									continue
								fi
							done
						while true; do
							read -p " [?] Ingrese la ruta completa del directorio de la key $keyVRF_Skey [ejemplo /home/pepe/block/$keyVRF_Skey]: " keyVRFkey
							if [ -f "$topologia" ]; then 
								break
							else 
								echo -e "$IYellow [!!] LA key $keyVRF_Skey no existe $End"
								continue
							fi
						done
						while true; do
							read -p " [?] Ingrese la ruta completa del certificado $cert_issue_op [ejemplo /home/pepe/block/$cert_issue_op]: " kesCert
							if [ -f "$topologia" ]; then 
								break
							else 
								echo -e "$IYellow [!!] El certificado $cert_issue_op no existe $End"
								continue
							fi
						done
							echo "--shelley-kes-key ${keyKESskey} \\" >> $fileIniciarBlock
							echo "--shelley-vrf-key ${keyVRFkey} \\" >> $fileIniciarBlock
							echo "--shelley-operational-certificate ${kesCert}" >> $fileIniciarBlock
						;;
						esac
					done

					echo -e "$IGreen \n [*] Se va a crear el siguiente script con los siguientes datos: \n $End" 
					cat $fileIniciarBlock
					echo -e "\n"
					read -p " [?] Esta deacuerdo con los datos introducidos [y/n]: " respuesta
					if [[ $respuesta =~ ^[Yy]$ ]]; then
						chmod +x $fileIniciarBlock
						break
						else
							continue
					fi
				done
			fi	
			echo -e "$IGreen \n [*] Script $fileIniciarBlock creado en el directorio ${dirBlock} $End" 
			echo -e "$IGreen [*] Copiando script $fileIniciarBlock al directorio ~/.local/bin $End" 
			cp $fileIniciarBlock ~/.local/bin
			echo -e "$IGreen [*] Para iniciar el nodo Block Producer ejecute el comando $fileIniciarBlock $End" 
		fi
	else
		echo -e "$IYellow \n [!!] No se han encontrado los datos de configuración del stake pool, antes de realizar esta opción debe configurar los nodos relays y el nodo block producer, opciones 4 y 5 $End"
	fi
}

#################################################
#				Iniciar Nodos					#
#################################################

iniciarNodos(){

	cd $dirNodos
	if [ -f "${dirNodos}/$filedatosPool" -o ! -z "${datosPool["Relays_total_Maquinas"]}" ]; then
		totalRelays=${datosPool["Relays_total_Maquinas"]}
		echo "#!/bin/bash" > $fileIniciarNodos
		echo "IGreen='\033[0;92m'" >> $fileIniciarNodos
		echo "IYellow='\033[0;93m'" >> $fileIniciarNodos
		echo "End='\033[0m'"  >> $fileIniciarNodos
		echo "echo -e '$IGreen [i] Se ha creado el script $fileIniciarNodos y se ha guardado en el directorio ~/.local/bin $End'" >> $fileIniciarNodos
		echo "echo -e '$IGreen [i] Los nodos se han iniciado, para ver la información establezca una nueva sesión SSH con su máquina y ejecute el comando $IYellow tmux -2 attach -t $USER $End'"  >> $fileIniciarNodos
		echo "echo -e '$IGreen [i] Si quiere iniciar los nodos de forma manual sin necesidad de el script ejecute el comando iniciarNodos y repita el paso anterior $End'" >> $fileIniciarNodos
		echo "echo -e '$IGreen [i] Si no te gusta la colocación de los paneles pulsa la tecla control+b + scpace \n $End'"  >> $fileIniciarNodos
		echo "crearPaneles() { " >> $fileIniciarNodos
		if [ -f "${dirBlock}/$fileIniciarBlock" ]; then
			echo "    tmux select-pane -t 0" >> $fileIniciarNodos
			echo "    tmux send-keys ${dirBlock}/$fileIniciarBlock C-m " >> $fileIniciarNodos
			echo "    tmux split-window -v -p 5" >> $fileIniciarNodos
			echo "    tmux send-keys htop C-m " >> $fileIniciarNodos
			echo "    tmux select-pane -t 0" >> $fileIniciarNodos
		else
			echo "    tmux split-window -v -p 5" >> $fileIniciarNodos
			echo "    tmux send-keys htop C-m " >> $fileIniciarNodos
			echo "    tmux select-pane -t 0" >> $fileIniciarNodos
		fi

		for (( n=1; n<=$totalRelays; n++ )); do
			if [ -d "${dirRelay}$n" ]; then
				fileRelay=$(echo ${dirRelay}/$fileIniciarRelay$n | awk -F/ '{print $NF}')
				if [ -f "${dirBlock}/$fileIniciarBlock" ]; then 
					echo "    tmux split-window -h " >> $fileIniciarNodos 
					echo "    tmux send-keys $fileRelay C-m " >> $fileIniciarNodos
				else
					num=$((${datosPool["Relays_en_otra_Maquina"]} + ${datosPool["Relays_en_esta_Maquina"]}))
					echo "    tmux send-keys $fileRelay C-m " >> $fileIniciarNodos
					if [ "$n" -lt  "$num" ]; then echo " tmux split-window -h"  >> $fileIniciarNodos; fi
				fi
			fi
		done
		echo "}" >> $fileIniciarNodos
		echo "if ( tmux ls | grep $USER )  < /dev/null > /dev/null 2>&1; then"  >> $fileIniciarNodos
		echo "    pgrep cardano-node > /dev/null"  >> $fileIniciarNodos
		echo "    if [ $(echo '$?') -eq 0 ]; then" >> $fileIniciarNodos
		echo "        echo -e '$IGreen [i] Los nodos se han iniciado, para ver la información establezca una nueva sesión SSH con su máquina y ejecute el comando $IYellow tmux -2 attach -t $USER $End'"  >> $fileIniciarNodos
		echo "    else" >> $fileIniciarNodos 
		echo "        tmux kill-session -t $USER 2> /dev/null" >> $fileIniciarNodos
		echo "        sleep 1 " >> $fileIniciarNodos
		echo "        tmux -2 new-session -d -s $USER 2> /dev/null" >> $fileIniciarNodos
		echo "        sleep 1"  >> $fileIniciarNodos
		echo "        crearPaneles" >> $fileIniciarNodos
		echo "        sleep 5" >> $fileIniciarNodos
		echo "    fi" >> $fileIniciarNodos
		
		echo "     echo -e '$IGreen [i] Si algún nodo no esta ejecuta inicialo con los siguientes comandos: $End'" >> $fileIniciarNodos
		if [ -f "${dirBlock}/$fileIniciarBlock" ]; then
			echo "    echo -e '$IYellow [ii] $fileIniciarBlock $End'" >> $fileIniciarNodos 
		fi
		for (( n=1; n<=$totalRelays; n++ )); do
			if [ -d "${dirRelay}$n" ]; then
				fileRelay=$(echo ${dirRelay}/$fileIniciarRelay$n | awk -F/ '{print $NF}')
				echo "    echo -e '$IYellow [ii] $fileRelay  $End'" >> $fileIniciarNodos
			fi
		done
		
		echo "else" >> $fileIniciarNodos
		echo "    tmux -2 new-session -d -s $USER > /dev/null 2>&1 " >> $fileIniciarNodos
		echo "    crearPaneles" >> $fileIniciarNodos
		echo "    sleep 5" >> $fileIniciarNodos
		echo "fi" >> $fileIniciarNodos

		chmod +x $fileIniciarNodos
		cp $fileIniciarNodos ~/.local/bin
		
		echo -e "$IGreen [*] Copiando script $fileIniciarNodos al directorio ~/.local/bin $End" 
		echo -e "$IGreen [i] Se ha creado el script $fileIniciarNodos y se ha guardado en el directorio ~/.local/bin $End" 
		echo -e "$IGreen [i] Los nodos se han iniciado, para ver la información establezca una nueva sesión SSH con su máquina y ejecute el comando $IYellow tmux -2 attach -t $USER $End" 
		echo -e "$IGreen [i] Si quiere iniciar los nodos de forma manual sin necesidad de el script ejecute el comando iniciarNodos y repita el paso anterior $End" 
		echo -e "$IGreen [i] Si no te gusta la colocación de los paneles pulsa la tecla control+b + scpace $End" 
	
	fi
	./$fileIniciarNodos

}

#########################################################################
#				Cifrar Archivos y Decifrar Archivos 					#
#########################################################################

cifrarDescifrarArchivos(){

	which gpg | xargs sudo chmod  744 2>/dev/null

	while true; do
		read -s -p " [?] Ingrese una contraseña para cifrar/descifrar las keys [minimo 10 cracteres, recomendado 16 caracteres]: " pass
		read -s -p " [?] Ingrese de nuevo la contrasña: " pass2
		if [ $pass == $pass2 ]; then
			character=$(printf $pass | wc -c)
			 if [ "$character" -gt 9 ]; then
			 	echo -e "$IGreen [*] Contraseña correcta $End" 
				break
			else
				echo -e "$IYellow [ii] La contraseña no puede ser inferior a 10 caracteres $End"
			fi
		else
			echo -e "$IYellow [ii] La contraseña no coincide $End"
		fi
	done
	

	for dato in ${cifrarDescifrar[@]}; do
		case $dato in
			"poolKeys") 
				cd ${dirBlock}/$dirKeysPool
			;;
			"addressKeys")
				cd ${dirBlock}/$dirAddressKeys
			;;
			"cifrar")
				files=$(ls)
				modo="sudo gpg --symmetric --yes --batch --cipher-algo AES256 --passphrase-fd 0 "
				for file in $files; do
					echo $pass | $modo $file 
					echo -e "$IGreen \n [i] Archivo $file cifrado $End" 
					echo "y" | rm $file
				done
			;;
			"descifrar")
				files=$(ls)
				modo="sudo gpg -d --yes --batch --cipher-algo AES256 --passphrase-fd 0 "
				for file in $files; do
					echo $pass | $modo $file > ${file::-4}
					echo -e "$IGreen \n [i] Archivo $file descifrado $End" 
					echo "y" | rm $file
				done
			;;
		esac
	done

	echo -e "$IGreen \n [*] keys cifradas, guarde bien la contraña para poder descifrar los archivos $End"
	sleep 5 

}


#####################################################
#			Comprobar sincronización				#
#####################################################

checkSynBlockchainCardano(){

 	if [ -z "${datosPool["syn_Blockchain"]}" ]; then
		echo -e "$IGreen \n [*] Esta opcion solo puede ejecutarse cuando los nodos terminen de sincronizar con la cadena blockchain $End" 
		echo -e "$IGreen [*] Seleccione <y> cuando los nodos terminen de sincronizar para continuar con las configuraciones $End" 
		while true; do
			read -p " [?] Los nodos han terminado de sincronizar [y/n]: " respuesta
			if [[ $respuesta =~ ^[Yy]$ ]]; then
				datosPool["syn_Blockchain"]=$respuesta
				pgrep cardano-node > /dev/null
				if [ "$?" -eq 0 ]; then break;
				else echo -e "$IRed [!!!] Error, los nodos no se estan ejecutando, deben estar ejecutandose para poder comprobar que han terminado de sincronizar $End"; fi
			else
				continue
			fi
		done
		declare -p datosPool > ${dirNodos}/$filedatosPool
	fi
}

#####################################################
#			Comprobar KES period 					#
#####################################################

calcularKesPeriod(){

	if ( tmux ls | grep $USER )  < /dev/null > /dev/null 2>&1; then
		pgrep cardano-node > /dev/null
		if [ $? -eq 0 ]; then 
			slotNo=$( cardano-cli shelley query tip --testnet-magic $magig_Number | jq -r ."slotNo" )
			if [ $? -eq 0 ]; then 
				echo -e "$IGreen [i] Kes period calculado ${dirBlock}/$dirAddressKeys $End" 
			else
				echo -e "$IRed [!!!] Error, el comando no se ha ejecutado correctamente, compruebe los datos y la configuracion de cardano-cli $End"
			fi 
			slotNoKesPeriod=$( cat ${dirBlock}/$fileShelleyGenesis | jq -r '.slotsPerKESPeriod' )
			datosPool["kesPeriod"]=$((${slotNo} / ${slotNoKesPeriod}))
			datosPool["startkesPeriod"]=$(( ${datosPool["kesPeriod"]} + 0 ))
			declare -p datosPool > ${dirNodos}/$filedatosPool
		else
			which iniciarNodos | xargs bash -c 
			echo -e "$IGreen [i] Espera 120 segundos para que la blockchain pueda sincronizar de nuevo $End"; sleep 120
			calcularKesPeriod
		fi
	else
		which iniciarNodos | xargs bash -c 
		echo -e "$IGreen [i] Espera 120 segundos para que la blockchain pueda sincronizar de nuevo $End"; sleep 120
		calcularKesPeriod
	fi
}

#####################################################
#				Activar Internet 					#
#####################################################

activarInternet(){

	tcpdump -D | grep '\['| cut -d. -f2 | awk '{print $1}' | while read -r line; do sudo ip link set $(echo $line) up 2> /dev/null; done
	while true; do
		internet=$(ping 8.8.8.8 -c 2 | grep loss | tr -d '%' | awk -F " " '{printf $6}')
		if [ "$internet" == 0 ]; then 
			echo -e "$IGreen \n [i] Internet Activado $End" 
			break
		else 
			echo -e "$Yellow \n [ii] No se ha podido activar Internet, activelo usted mismo manualmente $End" 
			echo -e "$IGreen [i] Espera 5 segundos para volver a comprobar que Internet se ha activado $End" 
			sleep 5
		fi
	done
}

#####################################################
#				Generar claves Cold					#
#####################################################

generarColdKeys(){

	echo -e "$IYellow [ii] No almacene las keys cold en su servidor o en cualquier computadora con acceso a Internet. El mejor lugar para sus keys cold es un USB SEGURO u otro DISPOSITIVO EXTERNO SEGURO. $End"
	echo -e "$IYellow [ii] Para generar las keys cold de forma segura se desconectara internet en el caso de que no este conectado a su máquina servidor por medio de una sesión SSH  $End"
	echo -e "$IYellow [ii] Para generar las keys cold ademas de desconectar Internet se dejaran de ejecutar los nodos en caso de que se esten ejecutando $End"
	echo -e "$IGreen \n [*] Seleccione <y> en caso de no estar conectado por SSH y si desea desconectar Internet $End" 

	read -p " [?] Quiere que a continuación se desconecte Internet [y/n]:" respuesta
	if [[ $respuesta =~ ^[Yy]$ ]]; then
		tcpdump -D | grep '\['| cut -d. -f2 | awk '{print $1}' | while read -r line; do sudo ip link set $(echo $line) down 2> /dev/null; done
		while true; do
			internet=$(ping 8.8.8.8 -c 2 | grep loss | tr -d '%' | awk -F " " '{printf $6}')
			if [ "$internet" != 0 ]; then 
				echo -e "$IGreen \n [i] Internet desconectado $End" 
				break
			else 
				echo -e "$Yellow \n [ii] No se ha podido desconectar Internet, desconectelo usted mismo manualmente $End" 
				echo -e "$IGreen [i] Espera 5 segundos para volver a comprobar que Internet se ha desconectado $End" 
				sleep 5
			fi
		done
	fi

	#pgrep cardano-node  | xargs kill
	#echo -e "$IGreen [i] Nodos desconectados $End" 
	#echo -e "$IGreen [i] Cerrando sesión tmux $USER $End" 
	#sleep 1
	#tmux kill-session -a -t $USER

	echo -e "$IGreen \n [*] Generando keys cold $End" 
	if [ ! -d ${dirBlock}/$dirKeysPool ]; then mkdir -p ${dirBlock}/$dirKeysPool; fi
	cd ${dirBlock}/$dirKeysPool
	

	cardano-cli shelley node key-gen \
	--cold-verification-key-file $keyPoolCold_Vkey \
	--cold-signing-key-file $keyPoolCold_Skey \
	--operational-certificate-issue-counter-file $cert_PoolCold_Counter

	if [ $? -eq 0 ]; then 
		echo -e "$IGreen [i] key $keyPoolCold_Vkey $keyPoolCold_Skey $cert_PoolCold_Counter guardadas en el directorio ${dirBlock}/$dirKeysPool $End" 
	else
		echo -e "$IRed [!!!] Error, el comando no se ha ejecutado correctamente, compruebe los datos y la configuracion de cardano-cli $End"
		exit 1
	fi

}

#####################################################
#				Generar claves VRF					#
#####################################################

generarVRFKeys(){

	echo -e "$IGreen \n [*] Generando keys VRF $End" 

	if [ ! -d ${dirBlock}/$dirKeysPool ]; then mkdir -p ${dirBlock}/$dirKeysPool; fi
	cd ${dirBlock}/$dirKeysPool
	

	cardano-cli shelley node key-gen-VRF \
	--verification-key-file $keyVRF_Vkey \
	--signing-key-file $keyVRF_Skey

	if [ $? -eq 0 ]; then 
		echo -e "$IGreen [i] key $keyVRF_Vkey  $keyVRF_Vkey guardadas en el directorio ${dirBlock}/$dirKeysPool $End" 
	else
		echo -e "$IRed [!!!] Error, el comando no se ha ejecutado correctamente, compruebe los datos y la configuracion de cardano-cli $End"
		exit 1
	fi

}

#####################################################
#				Generar claves KES					#
#####################################################

generarKESKeys(){

	echo -e "$IGreen \n [*] Generando keys KES $End" 

	if [ ! -d ${dirBlock}/$dirKeysPool ]; then mkdir -p ${dirBlock}/$dirKeysPool; fi
	cd ${dirBlock}/$dirKeysPool
	

	cardano-cli shelley node key-gen-KES \
	--verification-key-file $keyKES_Vkey \
	--signing-key-file $keyKES_Skey

	if [ $? -eq 0 ]; then 
		echo -e "$IGreen [i] key $keyKES_Vkey $keyKES_Skey guardadas en el directorio ${dirBlock}/$dirKeysPool $End" 
	else
		echo -e "$IRed [!!!] Error, el comando no se ha ejecutado correctamente, compruebe los datos y la configuracion de cardano-cli $End"
		exit 1
	fi

}

#################################################################
#				Generar Certificado de operador					#
#################################################################

generarOperationalCert(){

	echo -e "$IGreen \n [*] Generando certificado de operador $End" 

	if [ ! -d ${dirBlock}/$dirKeysPool ]; then mkdir -p ${dirBlock}/$dirKeysPool; fi
	cd ${dirBlock}/$dirKeysPool
	

	
	echo -e "$IGreen [*] slotNo: $slotNo $End" 
	echo -e "$IGreen [*] slotNoKesPeriod: $slotNoKesPeriod $End" 
	echo -e "$IGreen [*] kesPeriod: ${datosPool["kesPeriod"]} $End" 
	echo -e "$IGreen [*] kesPeriod: ${datosPool["startkesPeriod"]} $End" 

	cd ${dirBlock}/$dirKeysPool

	cardano-cli shelley node issue-op-cert \
	--kes-verification-key-file $keyKES_Vkey \
	--cold-signing-key-file $keyPoolCold_Skey \
	--operational-certificate-issue-counter  $cert_PoolCold_Counter \
	--kes-period ${datosPool["startkesPeriod"]} \
	--out-file $cert_issue_op

	if [ $? -eq 0 ]; then 
		echo -e "$IGreen [i] Certificado $cert_issue_op guardado en el directorio ${dirBlock}/$dirKeysPool $End" 
	else
		echo -e "$IRed [!!!] Error, el comando no se ha ejecutado correctamente, compruebe los datos y la configuracion de cardano-cli $End"
		exit 1
	fi 

}

#################################################################
#				Generar Parametros de protocolo 				#
#################################################################

parametrosProtocolo(){

	if ( tmux ls | grep $USER )  < /dev/null > /dev/null 2>&1; then
		pgrep cardano-node > /dev/null
		if [ $? -eq 0 ]; then 
			
			echo -e "$IGreen \n [*] Generando parametros de protocolo $End" 

			if [ ! -d ${dirBlock}/$dirAddressKeys ]; then mkdir -p ${dirBlock}/$dirAddressKeys; fi
			cd ${dirBlock}/$dirAddressKeys	

			cardano-cli shelley query protocol-parameters \
			--testnet-magic $magig_Number \
			--out-file $protocolParameters 

			if [ $? -eq 0 ]; then 
				echo -e "$IGreen [i] $protocolParameters guardado en el directorio ${dirBlock}/$dirAddressKeys $End" 
			else
				echo -e "$IRed [!!!] Error, el comando no se ha ejecutado correctamente, compruebe los datos y la configuracion de cardano-cli $End"
				exit 1
			fi 
		else
			which iniciarNodos | xargs bash -c
			sleep 2
			parametrosProtocolo
		fi
	else
		which iniciarNodos | xargs bash -c
		sleep 2
		parametrosProtocolo
	fi
}

#################################################################
#				Generar Keys Payment 			 				#
#################################################################

keysPayment(){

	if [ ! -d ${dirBlock}/$dirAddressKeys ]; then mkdir -p ${dirBlock}/$dirAddressKeys; fi
	cd ${dirBlock}/$dirAddressKeys
	

	echo -e "$IGreen \n [*] Generando keys payment $End" 

	cardano-cli shelley address key-gen \
	--verification-key-file $keyPayment_Vkey \
	--signing-key-file $keyPayment_Skey

	if [ $? -eq 0 ]; then 
		echo -e "$IGreen [i] $keyPayment_Vkey $keyPayment_Skey guardads en el directorio ${dirBlock}/$dirAddressKeys $End" 
	else
		echo -e "$IRed [!!!] Error, el comando no se ha ejecutado correctamente, compruebe los datos y la configuracion de cardano-cli $End"
		exit 1
	fi 
}

#################################################################
#				Generar Keys Staking 			 				#
#################################################################

keysStaking(){

	if [ ! -d ${dirBlock}/$dirAddressKeys ]; then mkdir -p ${dirBlock}/$dirAddressKeys; fi
	cd ${dirBlock}/$dirAddressKeys
	

	echo -e "$IGreen \n [*] Generando keys staking $End" 

	cardano-cli shelley stake-address key-gen \
	--verification-key-file $keyStaking_Vkey \
	--signing-key-file $keyStaking_Skey

	if [ $? -eq 0 ]; then 
		echo -e "$IGreen [i] Certificado $cert_issue_op guardado en el directorio ${dirBlock}/$dirAddressKeys $End" 
	else
		echo -e "$IRed [!!!] Error, el comando no se ha ejecutado correctamente, compruebe los datos y la configuracion de cardano-cli $End"
		exit 1
	fi 
}

#################################################################
#				Generar address Payment		 					#
#################################################################

addressPayment(){

	if [ ! -d ${dirBlock}/$dirAddressKeys ]; then mkdir -p ${dirBlock}/$dirAddressKeys; fi
	cd ${dirBlock}/$dirAddressKeys
	

	echo -e "$IGreen \n [*] Generando address payment $End" 

	cardano-cli shelley address build \
	--payment-verification-key-file $keyPayment_Vkey \
    --out-file $addressPayment \
    --testnet-magic $magig_Number

	if [ $? -eq 0 ]; then 
		echo -e "$IGreen [i] Dirección $ $addressPayment guardada en el directorio ${dirBlock}/$dirAddressKeys $End" 
	else
		echo -e "$IRed [!!!] Error, el comando no se ha ejecutado correctamente, compruebe los datos y la configuracion de cardano-cli $End"
		exit 1
	fi 
}

#################################################################
#				Generar address Staking 			 			#
#################################################################

addressStaking(){

	if [ ! -d ${dirBlock}/$dirAddressKeys ]; then mkdir -p ${dirBlock}/$dirAddressKeys; fi
	cd ${dirBlock}/$dirAddressKeys
	

	echo -e "$IGreen \n [*] Generando address staking $End" 

	cardano-cli shelley stake-address build \
    --staking-verification-key-file $keyStaking_Vkey \
    --out-file $addressStaking \
    --testnet-magic $magig_Number

	if [ $? -eq 0 ]; then 
		echo -e "$IGreen [i] Dirección $addressStaking guardada en el directorio ${dirBlock}/$dirAddressKeys $End" 
	else
		echo -e "$IRed [!!!] Error, el comando no se ha ejecutado correctamente, compruebe los datos y la configuracion de cardano-cli $End"
		exit 1
	fi 
}

#################################################################
#				Generar address base 			 				#
#################################################################

addressBase(){

	if [ ! -d ${dirBlock}/$dirAddressKeys ]; then mkdir -p ${dirBlock}/$dirAddressKeys; fi
	cd ${dirBlock}/$dirAddressKeys
	

	echo -e "$IGreen \n [*] Generando address staking $End" 

	cardano-cli shelley address build \
    --payment-verification-key-file $keyPayment_Vkey \
    --staking-verification-key-file $keyStaking_Vkey \
    --out-file $addressBase \
    --testnet-magic $magig_Number

	if [ $? -eq 0 ]; then 
		echo -e "$IGreen [i] Dirección $addressBase guardada en el directorio ${dirBlock}/$dirAddressKeys $End" 
	else
		echo -e "$IRed [!!!] Error, el comando no se ha ejecutado correctamente, compruebe los datos y la configuracion de cardano-cli $End"
		exit 1
	fi 
}

#################################################################
#				Solicitar Faucet 	 			 				#
#################################################################

faucet(){

	activarInternet
	
	if ( tmux ls | grep $USER )  < /dev/null > /dev/null 2>&1; then
		if [ ! -d ${dirBlock}/$dirAddressKeys ]; then mkdir -p ${dirBlock}/$dirAddressKeys; fi
	
		pgrep cardano-node > /dev/null
		if [ $? -eq 0 ]; then 
			cd ${dirBlock}/$dirAddressKeys

			echo -e "$IGreen [i] Solicitando Faucet $End" 
			curl -v -XPOST $webFaucet/"$(cat $addressBase)"
			echo -e "\n" 

			cardano-cli shelley query utxo \
		    --address $(cat $addressBase) \
		    --testnet-magic $magig_Number

		    if [ $? -eq 0 ]; then 
		    	echo -e "$IGreen [i] Espera 120 segundos para que termine de realizarse la transaccion $End"; sleep 120
				echo -e "$IGreen [i] Saldo dispolible para el pledge $End" 
			else
				echo -e "$IRed [!!!] Error, el comando no se ha ejecutado correctamente, compruebe los datos y la configuracion de cardano-cli $End"
				echo -e "$IRed [!!!] Error, si estas utilizando la versión 1.15.1 hay que pedir fondos en el grupo ingles de telegram $End"
				exit 1
			fi 
		else
			which iniciarNodos | xargs bash -c 
			echo -e "$IGreen [i] Espera 120 segundos para que la blockchain pueda sincronizar de nuevo $End"; sleep 120
			faucet
		fi
	else
		which iniciarNodos | xargs bash -c 
		echo -e "$IGreen [i] Espera 120 segundos para que la blockchain pueda sincronizar de nuevo $End"; sleep 120
		faucet
	fi
}

#################################################################
#				Consultar Saldo 	 			 				#
#################################################################

consultarSaldo(){

	activarInternet
	if ( tmux ls | grep $USER )  < /dev/null > /dev/null 2>&1; then
	
		pgrep cardano-node > /dev/null
		if [ $? -eq 0 ]; then 

			for registro in ${registros[@]}; do
				case $registro in
					"EnviarAdas") 
					echo -e "$IGreen [i] Consultando saldo $End" 
					cardano-cli shelley query utxo \
					--address ${datosPool["direccionOrigen"]} \
					--testnet-magic $magig_Number > fullUtxo.out
				;;
					"Recompensas") 
					echo -e "$IGreen [i] Consultando saldo $End" 
					cardano-cli shelley query utxo \
					--address $(cat $addressBase)  \
					--testnet-magic $magig_Number > fullUtxo.out
				;;

					"direccion") 
						echo -e "$IGreen [i] Consultando saldo $End" 
						cardano-cli shelley query utxo \
						--address ${datosPool["direccion"]} \
						--testnet-magic $magig_Number > fullUtxo.out
				;;

					*)
						cd ${dirBlock}/$dirAddressKeys
						echo -e "$IGreen [i] Consultando saldo $End" 
						cardano-cli shelley query utxo \
					    --address $(cat $addressBase) \
					    --testnet-magic $magig_Number > fullUtxo.out
				;;
				esac
			done

		    if [ $? -eq 0 ]; then 

				tail -n +3 fullUtxo.out | sort -k3 -nr > balance.out

				tx_in=""
				total_balance=0
				while read -r utxo; do
				    in_addr=$(awk '{ print $1 }' <<< "${utxo}")
				    idx=$(awk '{ print $2 }' <<< "${utxo}")
				    utxo_balance=$(awk '{ print $3 }' <<< "${utxo}")
				    total_balance=$((${total_balance}+${utxo_balance}))
				    tx_in="${tx_in} --tx-in ${in_addr}#${idx}"
				done < balance.out

				txcnt=$(cat balance.out | wc -l)

				datosPool["TXCNT"]=$txcnt
				datosPool["BALANCE"]=$total_balance
				datosPool["UTXO"]=$in_addr
				datosPool["ID"]=$idx
				datosPool["INPUT"]="${tx_in}"

				declare -p datosPool > ${dirNodos}/$filedatosPool

				echo -e "$IGreen [i] Txcnt: ${datosPool["TXCNT"]} $End" 
				echo -e "$IGreen [i] TxHash: ${datosPool["UTXO"]} $End" 
				echo -e "$IGreen [i] TxIx: ${datosPool["ID"]}  $End" 
				echo -e "$IGreen [i] Lovelace: ${datosPool["BALANCE"]}  $End" 
				echo -e "$IGreen [i] Input: ${datosPool["INPUT"]}  $End" 


				echo -e "$IGreen [i] Saldo dispolible: ${datosPool["BALANCE"]} $End" 
			else
				echo -e "$IRed [!!!] Error, el comando no se ha ejecutado correctamente, compruebe los datos y la configuracion de cardano-cli $End"
				exit 1
			fi 
		else
			which iniciarNodos | xargs bash -c 
			echo -e "$IGreen [i] Espera 120 segundos para que la blockchain pueda sincronizar de nuevo $End"; sleep 120
			consultarSaldo
		fi
	else
		which iniciarNodos | xargs bash -c 
		echo -e "$IGreen [i] Espera 120 segundos para que la blockchain pueda sincronizar de nuevo $End"; sleep 120
		consultarSaldo
	fi
}

certificadoStake(){


	if ( tmux ls | grep $USER )  < /dev/null > /dev/null 2>&1; then
		if [ ! -d ${dirBlock}/$dirAddressKeys ]; then mkdir -p ${dirBlock}/$dirAddressKeys; fi
	
		pgrep cardano-node > /dev/null
		if [ $? -eq 0 ]; then 
			cd ${dirBlock}/$dirAddressKeys

			echo -e "$IGreen [i] Creando certificado stake $End" 
			cardano-cli shelley stake-address registration-certificate \
		    --staking-verification-key-file $keyStaking_Vkey \
		    --out-file $cert_stake

		    if [ $? -eq 0 ]; then 
				echo -e "$IGreen [i] Certificado $cert_stake creado $End" 
			else
				echo -e "$IRed [!!!] Error, el comando no se ha ejecutado correctamente, compruebe los datos y la configuracion de cardano-cli $End"
				exit 1
			fi 
		else
			which iniciarNodos | xargs bash -c 
			echo -e "$IGreen [i] Espera 120 segundos para que la blockchain pueda sincronizar de nuevo $End"; sleep 120
			certificadoStake
		fi
	else
		which iniciarNodos | xargs bash -c 
		echo -e "$IGreen [i] Espera 120 segundos para que la blockchain pueda sincronizar de nuevo $End"; sleep 120
		certificadoStake
	fi

}



calcularTransaccionFee(){

	if ( tmux ls | grep $USER )  < /dev/null > /dev/null 2>&1; then
		if [ ! -d ${dirBlock}/$dirAddressKeys ]; then mkdir -p ${dirBlock}/$dirAddressKeys; fi
	
		pgrep cardano-node > /dev/null
		if [ $? -eq 0 ]; then 
			cd ${dirBlock}/$dirAddressKeys

			echo -e "$IGreen [i] Calculando Transaccion Fee $End" 

			slotNo=$( cardano-cli shelley query tip --testnet-magic $magig_Number | jq -r ."slotNo" )
			if [ $? -eq 0 ]; then 
				((ttl_num=$slotNo+1000))
				echo -e "$IGreen [i] ttl: $ttl_num $End" 
			else
				echo -e "$IRed [!!!] Error, el comando no se ha ejecutado correctamente, compruebe los datos y la configuracion de cardano-cli $End"
			fi 

			echo "cardano-cli shelley transaction calculate-min-fee \\" > $fileTransaccionFee
			echo "--tx-body-file $fileTransaccionTemporal \\"  >> $fileTransaccionFee
			echo "--tx-in-count ${datosPool["TXCNT"]} \\"  >> $fileTransaccionFee
			echo "--testnet-magic $magig_Number \\" >> $fileTransaccionFee
			echo "--byron-witness-count 0 \\" >> $fileTransaccionFee
			echo "--protocol-params-file $protocolParameters \\" >> $fileTransaccionFee 
			

			for registro in ${registros[@]}; do
				case $registro in
					"stake") 
						echo "--tx-out-count 1" \\ >> $fileTransaccionFee
						echo "--witness-count 2 " >> $fileTransaccionFee
			  		;;
			  		"stakePool")
						echo "--tx-out-count 1" \\ >> $fileTransaccionFee
			  			echo "--witness-count 3 " >> $fileTransaccionFee
			  		;;
			  		"pledge")
						echo "--tx-out-count 1" \\ >> $fileTransaccionFee
			  			echo "--witness-count 3 " >> $fileTransaccionFee
			  		;;
			  		"metadataUpdate")
						echo "--tx-out-count 1" \\ >> $fileTransaccionFee
			  			echo "--witness-count 3 " >> $fileTransaccionFee
			  		;;
					"retirarPool") 
						echo "--tx-out-count 1" \\ >> $fileTransaccionFee
						echo "--witness-count 2 " >> $fileTransaccionFee
			  		;;
					"EnviarAdas") 
						echo  "--tx-out-count 2" \\  >> $fileTransaccionFee
						echo "--witness-count 1 " >> $fileTransaccionFee
			  		;;
					"Recompensas") 
						echo  "--tx-out-count 1" \\  >> $fileTransaccionFee
						echo "--witness-count 2 " >> $fileTransaccionFee
			  		;;
			  	esac
			done

			chmod +x $fileTransaccionFee
			tx_fee=$(bash -c ./$fileTransaccionFee | awk '{ print $1}')
			rm $fileTransaccionFee

		    if [ $? -eq 0 ]; then 
				echo -e "$IGreen [i] Calculo Fee: $tx_fee $End" 
			else
				echo -e "$IRed [!!!] Error, el comando no se ha ejecutado correctamente, compruebe los datos y la configuracion de cardano-cli $End"
				exit 1
			fi 
		else
			which iniciarNodos | xargs bash -c 
			echo -e "$IGreen [i] Espera 120 segundos para que la blockchain pueda sincronizar de nuevo $End"; sleep 120
			calcularTransaccionFee
		fi
	else
		which iniciarNodos | xargs bash -c 
		echo -e "$IGreen [i] Espera 120 segundos para que la blockchain pueda sincronizar de nuevo $End"; sleep 120
		calcularTransaccionFee
	fi

}

crearTransaccion(){

	if ( tmux ls | grep $USER )  < /dev/null > /dev/null 2>&1; then
		if [ ! -d ${dirBlock}/$dirAddressKeys ]; then mkdir -p ${dirBlock}/$dirAddressKeys; fi
	
		pgrep cardano-node > /dev/null
		if [ $? -eq 0 ]; then 
			cd ${dirBlock}/$dirAddressKeys

			echo -e "$IGreen [i] Crear transaccion $End" 

			slotNo=$( cardano-cli shelley query tip --testnet-magic $magig_Number | jq -r ."slotNo" )
			if [ $? -eq 0 ]; then 
				((ttl_num=$slotNo+1000))
				echo -e "$IGreen [i] ttl: $ttl_num $End" 
			else
				echo -e "$IRed [!!!] Error, el comando no se ha ejecutado correctamente, compruebe los datos y la configuracion de cardano-cli $End"
			fi 
			poolDeposit=$(cat ${dirBlock}/$dirAddressKeys/$protocolParameters | jq -r '.poolDeposit')

			for registro in ${registros[@]}; do
				case $registro in
					"stake") 
						cardano-cli shelley transaction build-raw \
					    ${datosPool["INPUT"]} \
					    --tx-out $(cat $addressBase)+0 \
					    --ttl $ttl_num \
					    --fee 0 \
					    --out-file $fileTransaccionTemporal \
					    --certificate $cert_stake 
					;;
					"stakePool") 
						cardano-cli shelley transaction build-raw \
					    ${datosPool["INPUT"]} \
					    --tx-out $(cat $addressBase)+$(( ${datosPool["BALANCE"]} - ${poolDeposit})) \
					    --ttl $ttl_num \
					    --fee 0 \
					    --out-file $fileTransaccionTemporal \
					    --certificate ${dirBlock}/$dirKeysPool/$cert_pool \
					    --certificate ${dirBlock}/$dirKeysPool/$cert_pledge
					;;
					"pledge") 
						cardano-cli shelley transaction build-raw \
					    ${datosPool["INPUT"]} \
					    --tx-out $(cat $addressBase)+${datosPool["BALANCE"]} \
					    --ttl $ttl_num \
					    --fee 0 \
					    --out-file $fileTransaccionTemporal \
					    --certificate ${dirBlock}/$dirKeysPool/$cert_pool \
					    --certificate ${dirBlock}/$dirKeysPool/$cert_pledge
					;;
					"metadataUpdate") 
						cardano-cli shelley transaction build-raw \
					    ${datosPool["INPUT"]} \
					    --tx-out $(cat $addressBase)+${datosPool["BALANCE"]} \
					    --ttl $ttl_num \
					    --fee 0 \
					    --out-file $fileTransaccionTemporal \
					    --certificate ${dirBlock}/$dirKeysPool/$cert_pool \
					    --certificate ${dirBlock}/$dirKeysPool/$cert_pledge
					;;
					"retirarPool") 
						cardano-cli shelley transaction build-raw \
					    ${datosPool["INPUT"]} \
					    --tx-out $(cat $addressBase)+${datosPool["BALANCE"]} \
					    --ttl $ttl_num \
					    --fee 0 \
					    --out-file $fileTransaccionTemporal \
					    --certificate ${dirBlock}/$dirKeysPool/$cert_Retirar_Pool 
					;;
					"EnviarAdas") 
						cardano-cli shelley transaction build-raw \
					    ${datosPool["INPUT"]} \
					    --tx-out ${datosPool["direccionOrigen"]}+0 \
					    --tx-out ${datosPool["direccionDestino"]}+0 \
					    --ttl $ttl_num \
					    --fee 0 \
					    --out-file $fileTransaccionTemporal 
					;;
					"Recompensas") 
						cardano-cli shelley transaction build-raw \
					    ${datosPool["INPUT"]} \
					    --tx-out $(cat $addressBase)+0 \
					    --ttl $ttl_num \
					    --fee 0 \
					    --withdrawal $(cat $addressStaking)+${datosPool["recompensas"]} \
					    --out-file $fileTransaccionTemporal 
					;;
				esac
			done

		    if [ $? -eq 0 ]; then 
				echo -e "$IGreen [i] Transaccion creada $End" 
			else
				echo -e "$IRed [!!!] Error, el comando no se ha ejecutado correctamente, compruebe los datos y la configuracion de cardano-cli $End"
				exit 1
			fi 
		else
			which iniciarNodos | xargs bash -c 
			echo -e "$IGreen [i] Espera 120 segundos para que la blockchain pueda sincronizar de nuevo $End"; sleep 120
			crearTransaccion
		fi
	else
		which iniciarNodos | xargs bash -c 
		echo -e "$IGreen [i] Espera 120 segundos para que la blockchain pueda sincronizar de nuevo $End"; sleep 120
		crearTransaccion
	fi

}

construirTransaccion(){

	if ( tmux ls | grep $USER )  < /dev/null > /dev/null 2>&1; then
		if [ ! -d ${dirBlock}/$dirAddressKeys ]; then mkdir -p ${dirBlock}/$dirAddressKeys; fi
	
		pgrep cardano-node > /dev/null
		if [ $? -eq 0 ]; then 
			cd ${dirBlock}/$dirAddressKeys

			echo -e "$IGreen [i] Construyendo transaccion $End" 

			for registro in ${registros[@]}; do
				case $registro in
					"stake") 
						costRegistro=$(cat $protocolParameters | jq -r '.keyDeposit')
						cambio=$(( ${datosPool["BALANCE"]} - $costRegistro - $tx_fee ))
					;;
					"stakePool")
						costRegistro=$(cat $protocolParameters | jq -r '.poolDeposit')
						cambio=$(( ${datosPool["BALANCE"]} - $costRegistro - $tx_fee ))
					;;
					"pledge")
						costRegistro=0
						cambio=$(( ${datosPool["BALANCE"]} - $costRegistro - $tx_fee ))
					;;
					"metadataUpdate")
						costRegistro=0
						cambio=$(( ${datosPool["BALANCE"]} - $costRegistro - $tx_fee ))
					;;
					"EnviarAdas")
						costRegistro=${datosPool["cantidadADAs"]}
						cambio=$(( ${datosPool["BALANCE"]} - $costRegistro - $tx_fee ))
					;;
					"Recompensas")
						costRegistro=${datosPool["recompensas"]}
						cambio=$(( ${datosPool["BALANCE"]} + $costRegistro - $tx_fee ))
				esac
			done

			echo -e "$IGreen [i] Balance: ${datosPool["BALANCE"]} $End" 
			echo -e "$IGreen [i] Cantidad a enviar: $costRegistro $End" 
			gasto=$(( $costRegistro + $tx_fee ))
			echo -e "$IGreen [i] Gasto: $gasto $End" 
			datosPool["BALANCE"]=$cambio
			declare -p datosPool > ${dirNodos}/$filedatosPool


			if [ "$cambio" -lt 0 ]; then
				echo -e "$IRed [!!!] Error no tiene suficientes ADAs para pagar enviar. Balance: ${datosPool["BALANCE"]} $End" 
				echo -e "$IGreen [i] Consiga más ADAs $End" 
				exit 127
			fi

			echo -e "$IGreen [i] Balance despues de realizar el pago: ${datosPool["BALANCE"]} $End" 

			for registro in ${registros[@]}; do
				case $registro in
					"stake") 
						cardano-cli shelley transaction build-raw \
					    ${datosPool["INPUT"]} \
					    --tx-out $(cat $addressBase)+${datosPool["BALANCE"]} \
					    --ttl $ttl_num \
					    --fee $tx_fee \
					    --out-file $fileTransaccion \
					    --certificate $cert_stake 
					;;
					"stakePool") 
						cardano-cli shelley transaction build-raw \
					    ${datosPool["INPUT"]}  \
					    --tx-out $(cat $addressBase)+${datosPool["BALANCE"]} \
					    --ttl $ttl_num \
					    --fee $tx_fee \
					    --out-file $fileTransaccion \
					    --certificate ${dirBlock}/$dirKeysPool/$cert_pool \
					    --certificate ${dirBlock}/$dirKeysPool/$cert_pledge
					;;
					"pledge") 
						cardano-cli shelley transaction build-raw \
					    ${datosPool["INPUT"]}  \
					    --tx-out $(cat $addressBase)+${datosPool["BALANCE"]} \
					    --ttl $ttl_num \
					    --fee $tx_fee \
					    --out-file $fileTransaccion \
					    --certificate ${dirBlock}/$dirKeysPool/$cert_pool \
					    --certificate ${dirBlock}/$dirKeysPool/$cert_pledge
					;;
					"metadataUpdate") 
						cardano-cli shelley transaction build-raw \
					    ${datosPool["INPUT"]}  \
					    --tx-out $(cat $addressBase)+${datosPool["BALANCE"]} \
					    --ttl $ttl_num \
					    --fee $tx_fee \
					    --out-file $fileTransaccion \
					    --certificate ${dirBlock}/$dirKeysPool/$cert_pool \
					    --certificate ${dirBlock}/$dirKeysPool/$cert_pledge
					;;
					"retirarPool") 
						cardano-cli shelley transaction build-raw \
					    ${datosPool["INPUT"]}  \
					    --tx-out $(cat $addressBase)+${datosPool["BALANCE"]} \
					    --ttl $ttl_num \
					    --fee $tx_fee \
					    --out-file $fileTransaccion \
					    --certificate ${dirBlock}/$dirKeysPool/$cert_Retirar_Pool
					;;
					"EnviarAdas") 
						cardano-cli shelley transaction build-raw \
					    ${datosPool["INPUT"]}  \
					    --tx-out ${datosPool["direccionOrigen"]}+${datosPool["BALANCE"]} \
					    --tx-out ${datosPool["direccionDestino"]}+${datosPool["cantidadADAs"]} \
					    --ttl $ttl_num \
					    --fee $tx_fee \
					    --out-file $fileTransaccion \
					;;
					"Recompensas") 
						cardano-cli shelley transaction build-raw \
					    ${datosPool["INPUT"]}  \
					    --tx-out $(cat $addressBase)+${datosPool["BALANCE"]} \
					    --ttl $ttl_num \
					    --fee $tx_fee \
					    --withdrawal $(cat $addressStaking)+${datosPool["recompensas"]} \
					    --out-file $fileTransaccion 
					;;

				esac
			done

		    if [ $? -eq 0 ]; then 
				echo -e "$IGreen [i] Transaccion construida $End" 
			else
				echo -e "$IRed [!!!] Error, el comando no se ha ejecutado correctamente, compruebe los datos y la configuracion de cardano-cli $End"
				exit 1
			fi 
		else
			which iniciarNodos | xargs bash -c 
			echo -e "$IGreen [i] Espera 120 segundos para que la blockchain pueda sincronizar de nuevo $End"; sleep 120
			construirTransaccion
		fi
	else
		which iniciarNodos | xargs bash -c 
		echo -e "$IGreen [i] Espera 120 segundos para que la blockchain pueda sincronizar de nuevo $End"; sleep 120
		construirTransaccion
	fi

}

firmarTransaccion(){

	if ( tmux ls | grep $USER )  < /dev/null > /dev/null 2>&1; then
		if [ ! -d ${dirBlock}/$dirAddressKeys ]; then mkdir -p ${dirBlock}/$dirAddressKeys; fi
	
		pgrep cardano-node > /dev/null
		if [ $? -eq 0 ]; then 
			cd ${dirBlock}/$dirAddressKeys
			echo -e "$IGreen [i] Firmando transaccion $End" 

			for registro in ${registros[@]}; do
				case $registro in
					"stake") 
						cardano-cli shelley transaction sign \
						--tx-body-file $fileTransaccion \
						--signing-key-file $dirBlock/$dirAddressKeys/$keyPayment_Skey \
						--signing-key-file $dirBlock/$dirAddressKeys/$keyStaking_Skey \
						--testnet-magic $magig_Number \
						--out-file $fileFirmaTransaccion
					;;
					"stakePool")
						cardano-cli shelley transaction sign \
						--tx-body-file $fileTransaccion \
						--signing-key-file $dirBlock/$dirAddressKeys/$keyPayment_Skey \
						--signing-key-file $dirBlock/$dirKeysPool/$keyPoolCold_Skey \
						--signing-key-file $dirBlock/$dirAddressKeys/$keyStaking_Skey \
						--testnet-magic $magig_Number \
						--out-file $fileFirmaTransaccion
					;;
					"pledge")
						cardano-cli shelley transaction sign \
						--tx-body-file $fileTransaccion \
						--signing-key-file $dirBlock/$dirAddressKeys/$keyPayment_Skey \
						--signing-key-file $dirBlock/$dirKeysPool/$keyPoolCold_Skey \
						--signing-key-file $dirBlock/$dirAddressKeys/$keyStaking_Skey \
						--testnet-magic $magig_Number \
						--out-file $fileFirmaTransaccion
					;;
					"metadataUpdate")
						cardano-cli shelley transaction sign \
						--tx-body-file $fileTransaccion \
						--signing-key-file $dirBlock/$dirAddressKeys/$keyPayment_Skey \
						--signing-key-file $dirBlock/$dirKeysPool/$keyPoolCold_Skey \
						--signing-key-file $dirBlock/$dirAddressKeys/$keyStaking_Skey \
						--testnet-magic $magig_Number \
						--out-file $fileFirmaTransaccion
					;;
					"retirarPool")
						cardano-cli shelley transaction sign \
						--tx-body-file $fileTransaccion \
						--signing-key-file $dirBlock/$dirAddressKeys/$keyPayment_Skey \
						--signing-key-file $dirBlock/$dirKeysPool/$keyPoolCold_Skey \
						--testnet-magic $magig_Number \
						--out-file $fileFirmaTransaccion
					;;
					"EnviarAdas")
						cardano-cli shelley transaction sign \
						--tx-body-file $fileTransaccion \
						--signing-key-file ${datosPool["directorioPaymentskey"]} \
						--testnet-magic $magig_Number \
						--out-file $fileFirmaTransaccion
					;;
					"Recompensas")
						cardano-cli shelley transaction sign \
						--tx-body-file $fileTransaccion \
						--signing-key-file $dirBlock/$dirAddressKeys/$keyPayment_Skey \
						--signing-key-file $dirBlock/$dirAddressKeys/$keyStaking_Skey \
						--testnet-magic $magig_Number \
						--out-file $fileFirmaTransaccion
					;;
				esac
			done

		    if [ $? -eq 0 ]; then 
				echo -e "$IGreen [i] Transaccion firmada $End" 
			else
				echo -e "$IRed [!!!] Error, el comando no se ha ejecutado correctamente, compruebe los datos y la configuracion de cardano-cli $End"
				exit 1
			fi 
		else
			which iniciarNodos | xargs bash -c 
			echo -e "$IGreen [i] Espera 120 segundos para que la blockchain pueda sincronizar de nuevo $End"; sleep 120
			firmarTransaccion
		fi
	else
		which iniciarNodos | xargs bash -c 
		echo -e "$IGreen [i] Espera 120 segundos para que la blockchain pueda sincronizar de nuevo $End"; sleep 120
		firmarTransaccion
	fi

}

enviarTransaccion(){

	if ( tmux ls | grep $USER )  < /dev/null > /dev/null 2>&1; then
		if [ ! -d ${dirBlock}/$dirAddressKeys ]; then mkdir -p ${dirBlock}/$dirAddressKeys; fi
	
		pgrep cardano-node > /dev/null
		if [ $? -eq 0 ]; then 
			cd ${dirBlock}/$dirAddressKeys
			echo -e "$IGreen [i] Enviando transaccion $End" 

			cardano-cli shelley transaction submit \
			--tx-file $fileFirmaTransaccion \
			--testnet-magic $magig_Number 

		    if [ $? -eq 0 ]; then 
				echo -e "$IGreen [i] Transaccion enviada $End" 
			else
				echo -e "$IRed [!!!] Error, el comando no se ha ejecutado correctamente, compruebe los datos y la configuracion de cardano-cli $End"
				exit 1
			fi 
		else
			which iniciarNodos | xargs bash -c 
			echo -e "$IGreen [i] Espera 120 segundos para que la blockchain pueda sincronizar de nuevo $End"; sleep 120
			enviarTransaccion
		fi
	else
		which iniciarNodos | xargs bash -c 
		echo -e "$IGreen [i] Espera 120 segundos para que la blockchain pueda sincronizar de nuevo $End"; sleep 120
		enviarTransaccion
	fi


}

metadataPool(){

	if ( tmux ls | grep $USER )  < /dev/null > /dev/null 2>&1; then
		if [ ! -d ${dirBlock}/$dirAddressKeys ]; then mkdir -p ${dirBlock}/$dirAddressKeys; fi
	
		pgrep cardano-node > /dev/null
		if [ $? -eq 0 ]; then 
			cd ${dirBlock}/$dirKeysPool

			regex='https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)' 
			while true; do
				read -p " [*] Introduce el nombre de tu stake pool: " datosPool["namePool"] 
				read -p " [*] Pon una descripción a tu stake pool: " datosPool["descripcionPool"]
				while true; do
					read -p " [*] Añade el ticker de tu stake pool [ caracteres 3-5 ]: " datosPool["tickerPool"] 
					character=$(printf ${datosPool[tickerPool]}  | wc -c)
					if [ "$character" -gt 2 -a "$character" -lt 6 ]; then
						break
					else
						echo -e "$IRed [!!!] Error, el ticker no puede tener menos de 3 caracateres y más de 5 caracteres $End"
						continue
					fi
				done
			 	while true; do
					read -p " [*] Escriebe la web de tu stake pool [ ejemplo: https://www.pruebaStakePool.com ]: " datosPool["webPool"]  

					if [[  ${datosPool[webPool]} =~ $regex && ${#datosPool[webPool]} -lt 65 ]]; then 
						break
					else
						echo -e "$IRed [!!!] Error, la sintaxis no corresponde a una pagina web o la url tiene más de 64 caracteres $End"
						continue
					fi
				done
			 	while true; do
					read -p " [*] Escriebe la web extended de tu stake pool [ ejemplo: https://www.pruebaStakePool.com ]: " datosPool["webextended"]  
					if [[  ${datosPool[webextended]} =~ $regex && ${#datosPool[webPool]} -lt 65  ]]; then 
						break
					else
						echo -e "$IRed [!!!] Error, la sintaxis no corresponde a una pagina web o la url tiene más de 64 caracteres $End"
						continue
					fi
				done

				declare -p datosPool > ${dirNodos}/$filedatosPool
					
				echo "{" > $fileMetadataPool
				echo "      \"name\": \"${datosPool["namePool"]}\"," >> $fileMetadataPool
				echo "      \"description\": \"${datosPool["descripcionPool"]}\"," >> $fileMetadataPool
				echo "      \"ticker\": \"${datosPool["tickerPool"]}\"," >> $fileMetadataPool
				echo "      \"homepage\": \"${datosPool["webPool"]}\"," >> $fileMetadataPool
				echo "      \"extended\": \"${datosPool["webextended"]}\"" >> $fileMetadataPool
				echo "}" >> $fileMetadataPool


				echo -e "$IGreen \n [*] Se va a crear el siguiente archivo con los siguientes datos: \n $End" 
				cat $fileMetadataPool
				echo -e "\n"
				read -p " [?] Esta deacuerdo con los datos introducidos [y/n]: " respuesta
				if [[ $respuesta =~ ^[Yy]$ ]]; then
					chmod +x $fileMetadataPool
					break
				fi
			done
		else
			which iniciarNodos | xargs bash -c 
			echo -e "$IGreen [i] Espera 120 segundos para que la blockchain pueda sincronizar de nuevo $End"; sleep 120
			metadataPool
		fi
	else
		which iniciarNodos | xargs bash -c 
		echo -e "$IGreen [i] Espera 120 segundos para que la blockchain pueda sincronizar de nuevo $End"; sleep 120
		metadataPool
	fi

}

generarMetaHash(){

	if ( tmux ls | grep $USER )  < /dev/null > /dev/null 2>&1; then
		if [ ! -d ${dirBlock}/$dirAddressKeys ]; then mkdir -p ${dirBlock}/$dirAddressKeys; fi
	
		pgrep cardano-node > /dev/null
		if [ $? -eq 0 ]; then 
			cd ${dirBlock}/$dirKeysPool

			cardano-cli shelley stake-pool metadata-hash --pool-metadata-file $fileMetadataPool > $fileMetaHashPool

			 if [ $? -eq 0 ]; then 
				echo -e "$IGreen [i] Archvio  $fileMetaHashPool creado $End" 
			else
				echo -e "$IRed [!!!] Error, el comando no se ha ejecutado correctamente, compruebe los datos y la configuracion de cardano-cli $End"
				exit 1
			fi 

		else
			which iniciarNodos | xargs bash -c 
			echo -e "$IGreen [i] Espera 120 segundos para que la blockchain pueda sincronizar de nuevo $End"; sleep 120
			generarMetaHash
		fi
	else
		which iniciarNodos | xargs bash -c 
		echo -e "$IGreen [i] Espera 120 segundos para que la blockchain pueda sincronizar de nuevo $End"; sleep 120
		generarMetaHash
	fi

}

crearCertificadoPool(){

	if ( tmux ls | grep $USER )  < /dev/null > /dev/null 2>&1; then
		if [ ! -d ${dirBlock}/$dirAddressKeys ]; then mkdir -p ${dirBlock}/$dirAddressKeys; fi
	
		pgrep cardano-node > /dev/null
		if [ $? -eq 0 ]; then 
			cd ${dirBlock}/$dirKeysPool


			for registro in ${registros[@]}; do
				case $registro in
					"stakePool")
						costRegistro=$(cat ${dirBlock}/$dirAddressKeys/$protocolParameters | jq -r '.poolDeposit')
						pledgeRecomendado=$(( ${datosPool["BALANCE"]} - $costRegistro - 1000000 ))
					;;
					"pledge")
						costRegistro=0
						pledgeRecomendado=$(( ${datosPool["BALANCE"]} - $costRegistro - 1000000 ))
					;;
					"metadataUpdate")
						costRegistro=0
						pledgeRecomendado=$(( ${datosPool["BALANCE"]} - $costRegistro - 1000000 ))
				esac
			done

			while true; do
				while true; do
					echo -e "$IYellow \n [ii] Promete una cantidad menor al balance disponible ${datosPool["BALANCE"]} ya que al pagar los certificados tu balance será menor al actual $End" 
					echo -e "$IYellow \n [ii] Si promete un pledge mayor al balance del que dispone en su direccion de owner stake $addressBase su nodo no firmará bloques \n $End"
					echo -e "$IYellow \n [ii] Pledge recomendado $pledgeRecomendado (Balance aproximado que tendrá después de pagar el certificado del pool) $End" 
					read -p " [*] Introduce la cantidad de Lovelace que quieres añadir al plege del stake pool [ 1000000 - ${datosPool["BALANCE"]} ]: " lovelacePledge
					if [ "$lovelacePledge" -gt 999999 -a "$lovelacePledge" -lt "${datosPool["BALANCE"]}" ]; then
						break
					else
						echo -e "$IRed [!!!] Error, la cantidad ingresa no puede ser mayor a la que dispones en el balance $End"
					fi
				done

				minPoolCost=$(cat ${dirBlock}/$dirAddressKeys/$protocolParameters | jq -r .minPoolCost)
				echo -e "$IGreen \n [*] El coste minimo tarifa fija es: minPoolCost: ${minPoolCost}  \n $End" 

				read -p " [*] Ingresa <y> si quieres establecer otro valor de tarifa fija [y/n]: " respuesta
				if [[ $respuesta =~ ^[Yy]$ ]]; then
					read -p " [*] Ingresa la cantidad de lovelace que quieres establecer como tarifa fija [ejemplo: 10000000]: " minPoolCost
				fi

				regex='https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)'
				read -p " [*] Ingresa la cantidad de margen (Tarifa Variable) que quieres recibir de las recompensas [ejemplo: 0.05 sería un 5% ]: " marginPool
				while true; do
					read -p " [*] Ingresa la url en donde has subido el archivo $poolMetaData : " urlMetadataPool
					if [[  $urlMetadataPool =~ $regex && ${#urlMetadataPool} -lt 65 ]]; then 
							break;
						else
							echo -e "$IRed [!!!] Error, la sintaxis no corresponde a una pagina web o la url tiene más de 64 caracteres $End"
							continue
					fi
				done

				if [[ ${datosPool["añadir_hostname"]} =~ ^[Yy]$ ]]; then
					while true; do
						read -p " [+] Quieres registrar IPv4 publica o hostname [host/pub]: " datosPool["register"]
						if [[ ${datosPool["register"]} == "host" ]]; then break;
						elif [[ ${datosPool["register"]} == "pub" ]]; then break;
						else echo -e "$IYellow \n [!!] Dato incorrecto, introduce host o pub $End"; continue; fi
					done
				else
					datosPool["register"]="pub"
				fi

				echo "cardano-cli shelley stake-pool registration-certificate \\" > $fileRegisterPool
				echo "--cold-verification-key-file $keyPoolCold_Vkey \\" >> $fileRegisterPool
				echo "--vrf-verification-key-file $keyVRF_Vkey \\" >> $fileRegisterPool
				echo "--pool-pledge $lovelacePledge \\" >> $fileRegisterPool
				echo "--pool-cost ${minPoolCost} \\" >> $fileRegisterPool
				echo "--pool-margin $marginPool \\" >> $fileRegisterPool
				echo "--pool-reward-account-verification-key-file ${dirBlock}/${dirAddressKeys}/${keyStaking_Vkey} \\" >> $fileRegisterPool
				echo "--pool-owner-stake-verification-key-file ${dirBlock}/${dirAddressKeys}/${keyStaking_Vkey} \\" >> $fileRegisterPool
				echo "--testnet-magic $magig_Number \\" >> $fileRegisterPool


				totalRelays=${datosPool["Relays_total_Maquinas"]}

				for (( n=1; n<=$totalRelays; n++ )); do
					if [[ ${datosPool["register"]} == "pub" ]]; then 
						echo "--pool-relay-ipv4 ${datosPool[IP_Pub_realy_$n]} \\" >> $fileRegisterPool
						echo "--pool-relay-port ${datosPool[Port_realy_$n]} \\" >> $fileRegisterPool
					else
						echo "--single-host-pool-relay ${datosPool[Hostname_realy_$n]} \\" >> $fileRegisterPool
						echo "--pool-relay-port ${datosPool[Port_realy_$n]} \\" >> $fileRegisterPool
					fi		
				done 

				echo "--metadata-url $urlMetadataPool \\" >> $fileRegisterPool
				echo "--metadata-hash $(cat poolMetaDataHash.txt) \\" >> $fileRegisterPool
				echo "--out-file $cert_pool"  >> $fileRegisterPool


				echo -e "$IGreen \n [*] Se va a crear el siguiente script con los siguientes datos: \n $End" 
				cat $fileRegisterPool
				echo -e "\n"
				read -p " [?] Esta deacuerdo con los datos introducidos [y/n]: " respuesta
				if [[ $respuesta =~ ^[Yy]$ ]]; then
					chmod +x $fileRegisterPool
					sleep 1
					echo -e "$IGreen [i] Creando certificado $cert_pool $End" 
					./$fileRegisterPool
					if [ $? -eq 0 ]; then 
						echo -e "$IGreen [i] Certificado $cert_pool creado $End" 
						break
					else
						echo -e "$IRed [!!!] Error, el comando no se ha ejecutado correctamente, compruebe los datos y la configuracion de cardano-cli $End"
						exit 1
					fi 
				else
						continue
				fi
			done
		else
			which iniciarNodos | xargs bash -c 
			echo -e "$IGreen [i] Espera 120 segundos para que la blockchain pueda sincronizar de nuevo $End"; sleep 120
			crearCertificadoPool
		fi
	else
		which iniciarNodos | xargs bash -c 
		echo -e "$IGreen [i] Espera 120 segundos para que la blockchain pueda sincronizar de nuevo $End"; sleep 120
		crearCertificadoPool
	fi

}



crearCertificadoDelegacion(){

	if ( tmux ls | grep $USER )  < /dev/null > /dev/null 2>&1; then
		if [ ! -d ${dirBlock}/$dirAddressKeys ]; then mkdir -p ${dirBlock}/$dirAddressKeys; fi
	
		pgrep cardano-node > /dev/null
		if [ $? -eq 0 ]; then 
			cd ${dirBlock}/$dirKeysPool

			echo -e "$IGreen [i] Creando certificado $cert_pledge creado $End" 

			cardano-cli shelley stake-address delegation-certificate \
			--staking-verification-key-file $dirBlock/$dirAddressKeys/$keyStaking_Vkey \
			--cold-verification-key-file $keyPoolCold_Vkey \
			--out-file $cert_pledge

			 if [ $? -eq 0 ]; then 
				echo -e "$IGreen [i] Certificado $cert_pledge creado $End" 
			else
				echo -e "$IRed [!!!] Error, el comando no se ha ejecutado correctamente, compruebe los datos y la configuracion de cardano-cli $End"
				exit 1
			fi 

		else
			which iniciarNodos | xargs bash -c 
			echo -e "$IGreen [i] Espera 120 segundos para que la blockchain pueda sincronizar de nuevo $End"; sleep 120
			crearCertificadoDelegacion
		fi
	else
		which iniciarNodos | xargs bash -c 
		echo -e "$IGreen [i] Espera 120 segundos para que la blockchain pueda sincronizar de nuevo $End"; sleep 120
		crearCertificadoDelegacion
	fi

}

reclamarStakePool(){

	if ( tmux ls | grep $USER )  < /dev/null > /dev/null 2>&1; then
		if [ ! -d ${dirBlock}/$dirAddressKeys ]; then mkdir -p ${dirBlock}/$dirAddressKeys; fi
	
		pgrep cardano-node > /dev/null
		if [ $? -eq 0 ]; then 
			cd ${dirBlock}/$dirKeysPool

			echo -e "$IGreen [i] Creando ID Pool $End" 

			cardano-cli shelley stake-pool id --cold-verification-key-file $keyPoolCold_Vkey > $filestakepoolid
			cardano-cli shelley stake-pool id --cold-verification-key-file $keyPoolCold_Vkey --output-format hex  > $filestakepoolidHex
			echo -e "$IGreen [i] Su ID de Pool es: $(cat $filestakepoolid) $End" 
			sleep 1
			echo -e "$IGreen [i] Verificando que su stake pool ya ha sido registrado en la cadena ID Pool $End" 
			estado=$(cardano-cli shelley query ledger-state --testnet-magic $magig_Number | grep publicKey | grep $(cat $filestakepoolid))
			echo -e "$IGreen [i] pool registrado en la cadena: \n $estado $End" 
			echo -e "$IGreen \n [i] dirigete a la siguiente web para reclamar tu stake pool https://htn.pooltool.io/ $End" 

		else
			which iniciarNodos | xargs bash -c 
			echo -e "$IGreen [i] Espera 120 segundos para que la blockchain pueda sincronizar de nuevo $End"; sleep 120
			reclamarStakePool
		fi
	else
		which iniciarNodos | xargs bash -c 
		echo -e "$IGreen [i] Espera 120 segundos para que la blockchain pueda sincronizar de nuevo $End"; sleep 120
		reclamarStakePool
	fi

}

descargarGetbuddies(){

	if ( tmux ls | grep $USER )  < /dev/null > /dev/null 2>&1; then
	
		pgrep cardano-node > /dev/null
		if [ $? -eq 0 ]; then 

			totalRelays=${datosPool["Relays_total_Maquinas"]}
			for (( n=1; n<=$totalRelays; n++ )); do
				if [ -d "${dirRelay}$n" ]; then
					fileRelay=$(echo ${dirRelay}/$fileIniciarRelay$n | awk -F/ '{print $NF}')
					cd "${dirRelay}$n" 
					curl -o $fileGetBuddies $urlBuddies/$fileGetBuddies
					 if [ $? -eq 0 ]; then 
						echo -e "$IGreen [i] script $fileGetBuddies descargado en el directorio ${dirRelay}$n $End" 
						read -p " [?] Ingrese su PT_MY_POOL_ID para el ${fileRelay:(-7)} [con comillas]: " PT_MY_POOL_ID
						read -p " [?] Ingrese su PT_MY_API_KEY para el ${fileRelay:(-7)}  [con comillas]: " PT_MY_API_KEY
						read -p " [?] Ingrese su PT_MY_NODE_ID para el ${fileRelay:(-7)}  [con comillas]: " PT_MY_NODE_ID 

						sed -i "s|PT_MY_POOL_ID=\"XXXXXXXX\"|PT_MY_POOL_ID=${PT_MY_POOL_ID}|" $fileGetBuddies
						sed -i "s|PT_MY_API_KEY=\"XXXXXXXX\"|PT_MY_API_KEY=${PT_MY_API_KEY}|" $fileGetBuddies
						sed -i "s|PT_MY_NODE_ID=\"XXXXXXXX\"|PT_MY_NODE_ID=${PT_MY_NODE_ID}|" $fileGetBuddies
						sed -i "s|PT_TOPOLOGY_FILE=\"\$CNODE_HOME/files/ff-topology-buddies.json\"|PT_TOPOLOGY_FILE=${dirRelay}${n}/${filePT_TOPOLOGY_FILE}|" $fileGetBuddies
						chmod +x $fileGetBuddies
						./$fileGetBuddies
						
					else
						echo -e "$IRed [!!!] Error, no se ha podido descargar el script $fileGetBuddies descargado en el directorio ${dirRelay}$n$End"
						exit 1
					fi 
				fi
			done
			echo -e "$IGreen [i] Añada manualmente los relays amigos a su topologia $End"
		else
			which iniciarNodos | xargs bash -c 
			echo -e "$IGreen [i] Espera 120 segundos para que la blockchain pueda sincronizar de nuevo $End"; sleep 120
			descargarGetbuddies
		fi
	else
		which iniciarNodos | xargs bash -c 
		echo -e "$IGreen [i] Espera 120 segundos para que la blockchain pueda sincronizar de nuevo $End"; sleep 120
		descargarGetbuddies
	fi

}

scriptStopPool(){

	cd $dirNodos
	echo "#!/bin/bash" > $fileStopNodos
	echo "SESSION=\$(whoami)" >> $fileStopNodos
	echo "tmux has-session -t \$SESSION 2>/dev/null" >> $fileStopNodos
	echo "if [ \$? != 0 ]; then" >> $fileStopNodos
	echo "   pgrep cardano-node > /dev/null" >> $fileStopNodos
	echo "   if [ $? -eq 1 ]; then " >> $fileStopNodos
	echo "      echo Los nodos no estan activos" >> $fileStopNodos
	echo "   else" >> $fileStopNodos
	echo "      echo Los nodos estan activos" >> $fileStopNodos
	echo "      pgrep cardano-node  | xargs kill"  >> $fileStopNodos
	echo "      echo Stop Nodos" >> $fileStopNodos
	echo "   fi" >> $fileStopNodos
	echo "else" >> $fileStopNodos
	echo "   pgrep cardano-node > /dev/null" >> $fileStopNodos
	echo "   if [ $? -eq 1 ]; then " >> $fileStopNodos
	echo "      echo Los nodos no estan activos" >> $fileStopNodos
	echo "   else" >> $fileStopNodos
	echo "      echo Los nodos estan activos" >> $fileStopNodos
	echo "      tmux kill-session -t \$SESSION" >> $fileStopNodos
	echo "      echo Stop Nodos" >> $fileStopNodos
	echo "   fi" >> $fileStopNodos
	echo "fi" >> $fileStopNodos

	chmod +x $fileStopNodos
	cp $fileStopNodos ~/.local/bin

}

daemonNode(){

	cd $dirNodos

	echo "# The Cardano Stakepool service (part of systemd)" > $fileAutoIniciarNodos
	echo "# file: /etc/systemd/system/cardano-stakepool.service" >> $fileAutoIniciarNodos
	echo "[Unit]" >> $fileAutoIniciarNodos
	echo "Description     = Cardano Stakepool Service" >> $fileAutoIniciarNodos
	echo "Wants           = network-online.target" >> $fileAutoIniciarNodos
	echo "After           = network-online.target" >> $fileAutoIniciarNodos
	echo "[Service]" >> $fileAutoIniciarNodos
	echo "User            = $(whoami)" >> $fileAutoIniciarNodos
	echo "Type            = forking" >> $fileAutoIniciarNodos
	echo "WorkingDirectory= /home/$(whoami)/" >> $fileAutoIniciarNodos
	echo "ExecStart       = /home/$(whoami)/.local/bin/$fileIniciarNodos" >> $fileAutoIniciarNodos
	echo "ExecStop       = /home/$(whoami)/.local/bin/$fileStopNodos" >> $fileAutoIniciarNodos
	echo "KillSignal      = SIGINT" >> $fileAutoIniciarNodos
	echo "ExecReload      = /home/$(whoami)/.local/bin/$fileStopNodos &&  /home/$(whoami)/.local/bin/$fileIniciarNodos" >> $fileAutoIniciarNodos
	echo "Restart         = always" >> $fileAutoIniciarNodos
	echo "TimeoutStopSec  = 5"  >> $fileAutoIniciarNodos
	echo "KillMode        = mixed"  >> $fileAutoIniciarNodos

	echo "[Install]" >> $fileAutoIniciarNodos
	echo "WantedBy        = multi-user.target" >> $fileAutoIniciarNodos


	sudo cp $fileAutoIniciarNodos /etc/systemd/system/$fileAutoIniciarNodos
	sudo chmod 644 /etc/systemd/system/$fileAutoIniciarNodos

	sudo systemctl daemon-reload
	sudo systemctl enable cardano-stakepool 
	echo -e "$IGreen [i] Daemon server cardano-node creado $End"

}


ConsultarRecompensas(){

	if ( tmux ls | grep $USER )  < /dev/null > /dev/null 2>&1; then
		if [ ! -d ${dirBlock}/$dirAddressKeys ]; then mkdir -p ${dirBlock}/$dirAddressKeys; fi
	
		pgrep cardano-node > /dev/null
		if [ $? -eq 0 ]; then 
			cd ${dirBlock}/$dirAddressKeys

			echo -e "$IGreen [i] Consultando Recompensas $End" 

			datosPool["datosRecompensas"]=$(cardano-cli shelley query stake-address-info --address $(cat $addressStaking) \
			--testnet-magic $magig_Number)

			datosPool["recompensas"]=$(cardano-cli shelley query stake-address-info --address $(cat $addressStaking) \
			--testnet-magic $magig_Number | jq -r ".[0].rewardAccountBalance")
			
			
			datoDireccion=$(echo ${datosPool["datosRecompensas"]} | jq -r ".[0].address")
			delegacion=$(echo ${datosPool["datosRecompensas"]} | jq -r ".[0].delegation")
			recompensa=$(echo ${datosPool["datosRecompensas"]} | jq -r ".[0].rewardAccountBalance")

        	echo -e "$IGreen [i] Direccion: $datoDireccion $End"
        	echo -e "$IGreen [i] delegación: $delegacion $End"
			echo -e "$IGreen [i] Recompesas: $recompensa Lovelace $End"


			 if [ $? -eq 0 ]; then 
				echo -e "$IGreen [i] Recompesas Consultadas $End" 
			else
				echo -e "$IRed [!!!] Error, el comando no se ha ejecutado correctamente, compruebe los datos y la configuracion de cardano-cli $End"
				exit 1
			fi 

		else
			which iniciarNodos | xargs bash -c 
			echo -e "$IGreen [i] Espera 120 segundos para que la blockchain pueda sincronizar de nuevo $End"; sleep 120
			ConsultarRecompensas
		fi
	else
		which iniciarNodos | xargs bash -c 
		echo -e "$IGreen [i] Espera 120 segundos para que la blockchain pueda sincronizar de nuevo $End"; sleep 120
		ConsultarRecompensas
	fi

	declare -p datosPool > ${dirNodos}/$filedatosPool

}


certificadoRetirarStakePool(){

	if ( tmux ls | grep $USER )  < /dev/null > /dev/null 2>&1; then
		if [ ! -d ${dirBlock}/$dirAddressKeys ]; then mkdir -p ${dirBlock}/$dirAddressKeys; fi
	
		pgrep cardano-node > /dev/null
		if [ $? -eq 0 ]; then 
			cd ${dirBlock}/

			echo -e "$IGreen [i] Calculado slots por epoca $End" 
			epochLength=$(cat $fileShelleyGenesis | jq -r '.epochLength')
			echo -e "$IGreen [i] epochLength: ${epochLength} $End" 
			echo -e "$IGreen [i] Slots por epoca realizado \n $End" 

			echo -e "$IGreen [i] Consultando slot actual $End" 
			slotNo=$(cardano-cli shelley query tip --testnet-magic $magig_Number | jq -r '.slotNo')
			echo -e "$IGreen [i] slotNo: ${slotNo} $End" 
			echo -e "$IGreen [i] Slot actual consultado \n $End" 

			echo -e "$IGreen [i] Calcula epoca actual  $End" 
			epoch=$((${slotNo} / ${epochLength}))
			echo -e "$IGreen [i] Epoca Actual: ${epoch} $End" 
			echo -e "$IGreen [i] Epoca actual calculada \n $End" 

			echo -e "$IGreen [i] Calcular epoca máxima de retiro slots por epoca $End" 
			eMax=$(cat  ${dirBlock}/$dirAddressKeys/$protocolParameters | jq -r '.eMax')
			echo -e "$IGreen [i]  eMax: ${eMax} $End" 
			echo -e "$IGreen [i] Epoca máxima de retiro calculada \n $End" 

			primeraEpocaReiro=$((${epoch} + 1 ))
			ultimaEpocaRetiro=$((${eMax} ${epoch} + 1 ))

			echo -e "$IGreen [i] Creando certificado para retirar su stake pool $End"

			while true; do
				echo -e "$IGreen [i] Uster puede retirar su stake pool entre las epocas ${primeraEpocaReiro} y ${ultimaEpocaRetiro} $End" 
				read -p " [*] En que epoca quiere retirar su stakePool [ ${primeraEpocaReiro} - ${ultimaEpocaRetiro} ]: " epocaRetiro
				if [ "$epocaRetiro -ge ${primeraEpocaReiro} -a $epocaRetiro -le  ${ultimaEpocaRetiro}" ]; then
					cd ${dirBlock}/$dirKeysPool
					cardano-cli shelley stake-pool deregistration-certificate \
					--cold-verification-key-file $keyPoolCold_Vkey \
					--epoch "${epocaRetiro}" \
					--out-file $cert_Retirar_Pool

					if [ $? -eq 0 ]; then 
						echo -e "$IGreen [i] Certificado de retiro de stake pool creado con exito \n $End"  
						break
					else
						echo -e "$IRed [!!!] Error, el comando no se ha ejecutado correctamente, compruebe los datos y la configuracion de cardano-cli $End"
						exit 1
					fi
				else:
					echo -e "$IRed [!!!] Error, no se puede retirar el stakePool en la epoca seleccionada, debe seleccionar otra epoca $End"
				fi
			done

		else
			which iniciarNodos | xargs bash -c 
			echo -e "$IGreen [i] Espera 120 segundos para que la blockchain pueda sincronizar de nuevo $End"; sleep 120
			certificadoRetirarStakePool
		fi
	else
		which iniciarNodos | xargs bash -c 
		echo -e "$IGreen [i] Espera 120 segundos para que la blockchain pueda sincronizar de nuevo $End"; sleep 120
		certificadoRetirarStakePool
	fi

}



consultarRetiroPool(){

	if ( tmux ls | grep $USER )  < /dev/null > /dev/null 2>&1; then
		if [ ! -d ${dirBlock}/$dirAddressKeys ]; then mkdir -p ${dirBlock}/$dirAddressKeys; fi
	
		pgrep cardano-node > /dev/null
		if [ $? -eq 0 ]; then 
			cd ${dirBlock}/$dirKeysPool


			cardano-cli shelley query ledger-state --testnet-magic $magig_Number \
			--out-file $fileLedger
			jq -r '.esLState._delegationState._pstate._pParams."'"$(cat $filestakepoolid)"'"  // empty' $fileLedger
					
			if [ $? -eq 0 ]; then 
				echo -e "$IGreen [i] Su pool se ha retirado con exito si la respuesta es vacia \n $End"  
			else
				echo -e "$IRed [!!!] Error, el comando no se ha ejecutado correctamente, compruebe los datos y la configuracion de cardano-cli $End"
				exit 1
			fi
		else
			which iniciarNodos | xargs bash -c 
			echo -e "$IGreen [i] Espera 120 segundos para que la blockchain pueda sincronizar de nuevo $End"; sleep 120
			consultarRetiroPool
		fi
	else
		which iniciarNodos | xargs bash -c 
		echo -e "$IGreen [i] Espera 120 segundos para que la blockchain pueda sincronizar de nuevo $End"; sleep 120
		consultarRetiroPool
	fi


}

EnviarADas(){

    while true; do
		while true; do
			read -p " [*] Itroduce dirección de origen: " direccionOrigen
			if [ ${#direccionOrigen} -eq $longdDireccionPayment -o ${#direccionOrigen} -eq $longDireccionBase ]; then
				datosPool["direccionOrigen"]=$direccionOrigen
				break
			else
				echo -e "$IRed [!!!] Dirección incorrecta, debe tener una lonfigtud de $longDireccionPayment  o $longDireccionBase caracteres. $End"
				contiue
			fi
		done

		while true; do
			read -p " [*] Itroduce directorio de payment.skey: " directorioPaymentskey
			if [ -f "$directorioPaymentskey" ]; then
				datosPool["directorioPaymentskey"]=$directorioPaymentskey
				break
			else
				echo -e "$IRed [!!!] El $direcotio directorioPaymentskey no existe. $End"
			fi
		done

		while true; do
			read -p " [*] Itroduce dirección de Destino: " direccionDestino
			if [ ${#direccionDestino} -eq $longdDireccionPayment -o ${#direccionDestino} -eq $longDireccionBase ]; then
				datosPool["direccionDestino"]=$direccionDestino
				break
			else
				echo -e "$IRed [!!!] Dirección incorrecta, debe tener una lonfigtud de $longdDireccionPayment o $longDireccionBase caracteres. $End"
			fi
		done

		while true; do
			re='^[0-9]+$'
			read -p " [*] Itroduce la cantidad de Lovelaces que quieres enviar: " cantidadADAs
			if [[ $cantidadADAs =~ $re ]] ; then
				datosPool["cantidadADAs"]=$cantidadADAs
				break
			else
				echo -e "$IRed [!!!] La cantidad a ingresar solo debe contener caracteres numericos. $End"
			fi
		done

		echo -e "$IGreen [*] Dirección Origen:  ${datosPool["direccionOrigen"]} $End"
		echo -e "$IGreen [*] Directorio payment.skey:  ${datosPool["directorioPaymentskey"]} $End"
		echo -e "$IGreen [*] Dirección Destino:  ${datosPool["direccionDestino"]} $End"
		echo -e "$IGreen [*] Cantidad Lovelace:  ${datosPool["cantidadADAs"]} $End"

		read -p " [*] Estas deacuerdo con los datos [y/n]: " respuesta
		if [[ $respuesta =~ ^[Yy]$ ]]; then
			break
		fi
	done
		

	declare -p datosPool > ${dirNodos}/$filedatosPool


}


direccion(){

    while true; do
		while true; do
			read -p " [*] Itroduce dirección a consultar: " direccion
			if [ ${#direccion} -eq $longdDireccionPayment -o ${#direccion} -eq $longDireccionBase ]; then
				datosPool["direccion"]=$direccion
				break
			else
				echo -e "$IRed [!!!] Dirección incorrecta, debe tener una lonfigtud de $longdDireccionPayment o $longDireccionBase caracteres. $End"
			fi
		done

		echo -e "$IGreen [*] Dirección:  ${datosPool["direccion"]} $End"

		read -p " [*] Estas deacuerdo con los datos [y/n]: " respuesta
		if [[ $respuesta =~ ^[Yy]$ ]]; then
			break
		fi
	done

	declare -p datosPool > ${dirNodos}/$filedatosPool

}


ConfigurarPrometheus(){

	sudo sed -i.bak -e "s|ARGS=\"\"|ARGS=\"--web.listen-address=127.0.0.1:9090\"|"  /etc/default/prometheus

	configPrometheus=$(echo -e "\"
global:
  scrape_interval:     15s # By default, scrape targets every 15 seconds.

  # Attach these labels to any time series or alerts when communicating with
  # external systems (federation, remote storage, Alertmanager).
  external_labels:
    monitor: 'codelab-monitor'

# A scrape configuration containing exactly one endpoint to scrape:
# Here it's Prometheus itself.
scrape_configs:
  # The job name is added as a label job=<job_name> to any timeseries scraped from this config.
  - job_name: 'prometheus'

    # Override the global default and scrape targets from this job every 5 seconds.
    scrape_interval: 5s

    static_configs:
\"")

	sudo su -c "echo $configPrometheus > /etc/prometheus/prometheus.yml"

	read -p " [*] Seleccione <y> si has instaldo prometheus y grafana en la misma maquina que has instalado todos tus nodos relays y tu nodo producer: " respuesta
	if [[ $respuesta =~ ^[Yy]$ ]]; then
		echo -e "${dirNodos}/$filedatosPool" "${dirBlock}"
		if [ -f "${dirNodos}/$filedatosPool" -a -d "${dirBlock}" ]; then
			space2=$(echo "  ")
			space4=$(echo "    ")
			trargetNodeExporter=$(echo -e "     "  - targets: [\'localhost:9100\'] | base64 )
			trargetProducer=$( echo -e "     "     - targets: [\'localhost:12700\'] | base64 )
			labelProducer=$(echo -e "       "         labels:  | base64 )
			aliasProducer=$(echo -e "         "     alias:  \'block-producing-node\' | base64 )
			typeProduce=$(echo -e "         "       type:  \'cardano-node\'  | base64 )

			sudo su -c "echo $trargetNodeExporter | base64 -d >> /etc/prometheus/prometheus.yml"
		    sudo su -c "echo $trargetProducer | base64 -d >> /etc/prometheus/prometheus.yml"
		   	sudo su -c "echo $labelProducer | base64 -d  >> /etc/prometheus/prometheus.yml"
		    sudo su -c "echo $aliasProducer | base64 -d  >> /etc/prometheus/prometheus.yml"
		    sudo su -c "echo $typeProduce | base64 -d  >>  /etc/prometheus/prometheus.yml"


		    totalRelays=${datosPool["Relays_total_Maquinas"]}
		    for (( n=1; n<=$totalRelays; n++ )); do
				if [ -d "${dirRelay}$n" ]; then
					cd ${dirRelay}$n
					fileRelay=$(echo ${dirRelay}/$fileIniciarRelay$n | awk -F/ '{print $NF}')
					trargetRelay=$( echo -e "     "  - targets: [\'localhost:1270$n\'] | base64 )
					labelRelay=$(echo -e "       "       labels:  | base64 )
					aliasRelay=$(echo -e "         "     alias:  \'${fileRelay:(-7)}\' | base64 )
					typeRelay=$(echo -e "         "       type:  \'cardano-node\'  | base64 )

				    sudo su -c "echo $trargetRelay | base64 -d >> /etc/prometheus/prometheus.yml"
				   	sudo su -c "echo $labelRelay | base64 -d  >> /etc/prometheus/prometheus.yml"
				    sudo su -c "echo $aliasRelay | base64 -d  >> /etc/prometheus/prometheus.yml"
				    sudo su -c "echo $typeRelay | base64 -d  >>  /etc/prometheus/prometheus.yml"
				fi
			done
		fi
	else
		read -p " [*] Ingresa la IPv4 de escucha del node exporter del nodo producer: " ipProducer
		while true; do
			read -p " [*] Cuanto nodos relays en total has configurado [1-20]: " numTotalRelays
			if [ $numTotalRelays -gt 0 -a $numTotalRelays -lt 21 ]; then
				for (( n=1; n<=$numTotalRelays; n++ )); do 
					while true; do
						read -p " [*] Ingresa la IPv4 en la que esta escuchado el node exporte del relay_$n: " ipRelays
						if [[  ${ipRelays} =~ ^([0-9]{1,3}[\.]){3}[0-9]{1,3}$ ]]; then break;
						else echo -e "$IYellow \n [!!] Dirección IPv4 incorrecta $End"; continue; fi 
					done
					trargetNodeExporter=$(echo -e "     "   - targets: [\'${ipRelays}:9100\'] | base64 )
					trargetRelay=$( echo -e "     "  - targets: [\'${ipRelays}:1270$n\'] | base64 )
					labelRelay=$(echo -e "       "       labels:  | base64 )
					aliasRelay=$(echo -e "         "     alias: \'relay_$n\' | base64 )
					typeRelay=$(echo -e "         "       type:  \'cardano-node\'  | base64 )

					sudo su -c "echo $trargetNodeExporter | base64 -d >> /etc/prometheus/prometheus.yml"
					sudo su -c "echo $trargetRelay | base64 -d >> /etc/prometheus/prometheus.yml"
					sudo su -c "echo $labelRelay | base64 -d  >> /etc/prometheus/prometheus.yml"
					sudo su -c "echo $aliasRelay | base64 -d  >> /etc/prometheus/prometheus.yml"
					sudo su -c "echo $typeRelay | base64 -d  >>  /etc/prometheus/prometheus.yml"
				done
				break
			fi
		done
		

		trargetNodeExporter=$(echo -e "     "   - targets: [\'$ipProducer:9100\'] | base64 )
		trargetProducer=$( echo -e "     "   - targets: [\'$ipProducer:12700\'] | base64 )
		labelProducer=$(echo -e "       "       labels:  | base64 )
		aliasProducer=$(echo -e "         "     alias: \'block-producing-node\' | base64 )
		typeProduce=$(echo -e "         "       type:  \'cardano-node\'  | base64 )

		sudo su -c "echo $trargetNodeExporter | base64 -d >> /etc/prometheus/prometheus.yml"
		sudo su -c "echo $trargetProducer | base64 -d >> /etc/prometheus/prometheus.yml"
		sudo su -c "echo $labelProducer | base64 -d  >> /etc/prometheus/prometheus.yml"
		sudo su -c "echo $aliasProducer | base64 -d  >> /etc/prometheus/prometheus.yml"
		sudo su -c "echo $typeProduce | base64 -d  >>  /etc/prometheus/prometheus.yml"
	fi

	echo -e "$IGreen [i] Prometheus configurado para que se inicie al iniciar el sistema $End"
	sudo systemctl enable prometheus.service
	sudo systemctl restart prometheus.service


}

ConfigurarNodeExporter(){


	while true; do
		read -p " [*] Cuanto nodos relays en total has configurado [1-20]: " numTotalRelays
		if [ $numTotalRelays -gt 0 -a $numTotalRelays -lt 21 ]; then
			while true; do
				read -p " [*] Vas a relaizar la comunicación del node exporter con prometheus con IPs publica o IPs privadas [pub/priv]: " respuesta
				if [[ "${respuesta}" == "priv" ]]; then 
					for (( n=1; n<=$numTotalRelays; n++ )); do 
						if [ -d "${dirBlock}" ]; then
							cd $dirBlock
							sudo sed -i.bak -e "s|ARGS=\"\"|ARGS=\"--web.listen-address=${datosPool["IP_block_Priv"]}:9100\"|"  /etc/default/prometheus-node-exporter
							sed -i.bak -e "s|    \"127.0.0.1\"|     \"${datosPool["IP_block_Priv"]}\"|" $fileShelleyConfig
							sed -i.bak -e "s/    12798/    12700/g" -e "s/hasEKG\": 12788/hasEKG\": 12600/g" $fileShelleyConfig
							echo -e "$IGreen [i] EKG configurado en el puerto 12600 $End"
							echo -e "$IGreen [i] El node producer y_$n esta escuchado en la IP ${datosPool["IP_block_Pub"]} hasEKG en el puerto 12600 y Prometheus 12700 $End"
						fi
						if [ -d "${dirRelay}$n" ]; then
							cd ${dirRelay}$n
							sudo sed -i.bak -e "s|ARGS=\"\"|ARGS=\"--web.listen-address=${datosPool["IP_Priv_realy_$n"]}:9100\"|"  /etc/default/prometheus-node-exporter
							fileRelay=$(echo ${dirRelay}/$fileIniciarRelay$n | awk -F/ '{print $NF}')
							sed -i.bak -e "s|    \"127.0.0.1\"|     \"${datosPool["IP_Priv_realy_$n"]}\"|" $fileShelleyConfig
							echo -e "$IGreen [i] ${fileRelay:(-7)} configurado en el puerto  1270$n $End"
							sed -i.bak -e "s|    12798|    1270$n|" -e "s|hasEKG\": 12788|hasEKG\": 1260$n|" $fileShelleyConfig
							echo -e "$IGreen [i] EKG del ${fileRelay:(-7)} configurado en el puerto 1260$n $End"
							sed -i.bak -e "s|    12798|    1270$n|" -e "s|hasEKG\": 12788|hasEKG\": 1260$n|" $fileShelleyConfig
							echo -e "$IGreen [i] EKG del relay_$n configurado en el puerto 1260$n $End"
							echo -e "$IGreen [i] El relay_$n esta escuchado en la IP ${datosPool["IP_Priv_realy_$n"]} hasEKG en el puerto  1260$n y Prometheus  1270$n $End"
						fi
					done
					break
				elif [[ "${respuesta}" == "pub" ]]; then
					for (( n=1; n<=$numTotalRelays; n++ )); do 
						if [ -d "${dirBlock}" ]; then
							cd $dirBlock
							sudo sed -i.bak -e "s|ARGS=\"\"|ARGS=\"--web.listen-address=${datosPool["IP_block_Pub"]}:9100\"|"  /etc/default/prometheus-node-exporter
							sed -i.bak -e "s|    \"127.0.0.1\"|     \!${datosPool["IP_block_Pub"]}\"|" $fileShelleyConfig
							sed -i.bak -e "s/    12798/    12700/g" -e "s/hasEKG\": 12788/hasEKG\": 12600/g" $fileShelleyConfig
							echo -e "$IGreen [i] EKG configurado en el puerto 12600 $End"
							echo -e "$IGreen [i] El node producer y_$n esta escuchado en la IP ${datosPool["IP_block_Pub"]} hasEKG en el puerto 12600 y Prometheus 12700 $End"
						fi
						if [ -d "${dirRelay}$n" ]; then
							cd ${dirRelay}$n
							sudo sed -i.bak -e "s|ARGS=\"\"|ARGS=\"--web.listen-address=${datosPool["IP_Pub_realy_$n"]}:9100\"|"  /etc/default/prometheus-node-exporter
							fileRelay=$(echo ${dirRelay}/$fileIniciarRelay$n | awk -F/ '{print $NF}')
							sed -i.bak -e "s|    \"127.0.0.1\"|     \"${datosPool["IP_Pub_realy_$n"]}\"|" $fileShelleyConfig
							echo -e "$IGreen [i] ${fileRelay:(-7)} configurado en el puerto  1270$n $End"
							sed -i.bak -e "s|    12798|    1270$n|" -e "s|hasEKG\": 12788|hasEKG\": 1260$n|" $fileShelleyConfig
							echo -e "$IGreen [i] EKG del ${fileRelay:(-7)} configurado en el puerto 1260$n $End"
							sed -i.bak -e "s|    12798|    1270$n|" -e "s|hasEKG\": 12788|hasEKG\": 1260$n|" $fileShelleyConfig
							echo -e "$IGreen [i] EKG del relay_$n configurado en el puerto 1260$n $End"
							echo -e "$IGreen [i] El relay_$n esta escuchado en la IP ${datosPool["IP_Pub_realy_$n"]} hasEKG en el puerto  1260$n y Prometheus  1270$n $End"
						fi
					done
					break
				else 
					echo -e "$IYellow \n [!!] Dato incorrecto, introduce priv o pub $End"
					continue
				fi
			done
			break
		fi
	done


	sudo systemctl enable prometheus-node-exporter.service
	sudo systemctl restart prometheus-node-exporter.service

	sleep 2
	pgrep cardano-node  | xargs kill
	tmux kill-session -t $USER 2> /dev/null
	sleep 1
	cd $HOME/.local/bin
	./$fileIniciarNodos

}

ConfigurarGrafana(){

	
	while true; do
		read -s -p " [?] Ingrese contraseña de acceso admin " pass
		echo -e ""
		read -s -p " [?] Ingrese de nuevo la contrasña: " pass2
		if [ $pass == $pass2 ]; then
			character=$(printf $pass | wc -c)
			 if [ "$character" -gt 9 ]; then
			 	echo -e "$IGreen \n [*] Contraseña correcta $End" 
				break
			else
				echo -e "$IYellow \n [ii] La contraseña no puede ser inferior a 10 caracteres $End"
			fi
		else
			echo -e "$IYellow \n [ii] La contraseña no coincide $End"
		fi
	done

	while true; do
		read -p " [?] Ingrese dirección IPv4 que quiere poner a la escucha Grafana [ejemplo: 192.168.1.1]: " ipGrafana
		if [[  $ipGrafana =~ ^([0-9]{1,3}[\.]){3}[0-9]{1,3}$ ]]; then break;
		else echo -e "$IYellow \n [!!] Dirección IPv4 incorrecta $End"; continue; fi 
	done


	sudo sed -i.bak -e "s|;http_addr =|http_addr = $ipGrafana|"  /usr/share/grafana/conf/defaults.ini
	sudo sed -i.bak -e "s|;http_addr =|http_addr = $ipGrafana|"  /etc/grafana/grafana.ini


	echo  -e "$IGreen [i] 1: Abrir  http://localhost:30000 en tu navegador
     2: Login  admin/admin
     3: Cambiar password
     4: Click en el icono de configuración y hacer click en Add data Source
     5: Seleccionar Prometheus
     6: Configurar nombre prometheus (ojo las mayusculas son importantes)
     7: Configurar URL http://localhost:9090
     8: Click Save & Test
     9: Click Create + icon > Import
     10: Añadir dashboard e introducir id: 11074
     11: Click boton Load
     12: Configurar data Prometheu como fuente
     13: Click boton import $End"

    while true; do
	    read -p " [*] Seleccione <y> cuando haya terminado la configuración para continuar con la siguiente configuración: " respuesta
		if [[ $respuesta =~ ^[Yy]$ ]]; then
			break
		fi
	done

     echo ""

    sudo systemctl enable grafana-server.service
	sudo systemctl restart grafana-server.service
	echo  -e "$IGreen [i] : Abrir  http://$ipGrafana:30000 en tu navegador $End"

     echo  -e "$IGreen [i] 1: Click en create y
     2: Click en el icono + y a continuación en Import
     3: Copia y añade la siguiente configuración de archivo .json
     4: Click boton import $End"
 	
 	while true; do
    	read -p " [*] Seleccione <y> para mostrar la configuración que tiene que copiar e importar: " respuesta
		if [[ $respuesta =~ ^[Yy]$ ]]; then
			break
		fi
	done

     echo -e '
{
  "annotations": {
    "list": [
      {
        "builtIn": 1,
        "datasource": "-- Grafana --",
        "enable": true,
        "hide": true,
        "iconColor": "rgba(0, 211, 255, 1)",
        "name": "Annotations & Alerts",
        "type": "dashboard"
      }
    ]
  },
  "editable": true,
  "gnetId": null,
  "graphTooltip": 0,
  "id": 1,
  "links": [],
  "panels": [
    {
      "datasource": "prometheus",
      "description": "",
      "fieldConfig": {
        "defaults": {
          "custom": {},
          "decimals": 2,
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "purple",
                "value": null
              }
            ]
          },
          "unit": "d"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 5,
        "w": 6,
        "x": 0,
        "y": 0
      },
      "id": 18,
      "options": {
        "colorMode": "value",
        "graphMode": "area",
        "justifyMode": "auto",
        "orientation": "auto",
        "reduceOptions": {
          "calcs": [
            "mean"
          ],
          "fields": "",
          "values": false
        }
      },
      "pluginVersion": "7.0.3",
      "targets": [
        {
          "expr": "(cardano_node_Forge_metrics_remainingKESPeriods_int * 6 / 24 / 6)",
          "instant": true,
          "interval": "",
          "legendFormat": "Days till renew",
          "refId": "A"
        }
      ],
      "timeFrom": null,
      "timeShift": null,
      "title": "Key evolution renew left",
      "type": "stat"
    },
    {
      "datasource": "prometheus",
      "fieldConfig": {
        "defaults": {
          "custom": {},
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "red",
                "value": null
              },
              {
                "color": "#EAB839",
                "value": 12
              },
              {
                "color": "green",
                "value": 24
              }
            ]
          }
        },
        "overrides": []
      },
      "gridPos": {
        "h": 5,
        "w": 5,
        "x": 6,
        "y": 0
      },
      "id": 12,
      "options": {
        "colorMode": "value",
        "graphMode": "area",
        "justifyMode": "auto",
        "orientation": "auto",
        "reduceOptions": {
          "calcs": [
            "mean"
          ],
          "fields": "",
          "values": false
        }
      },
      "pluginVersion": "7.0.3",
      "targets": [
        {
          "expr": "cardano_node_Forge_metrics_remainingKESPeriods_int",
          "instant": true,
          "interval": "",
          "legendFormat": "KES Remaining",
          "refId": "A"
        }
      ],
      "timeFrom": null,
      "timeShift": null,
      "title": "KES remaining",
      "type": "stat"
    },
    {
      "datasource": "prometheus",
      "description": "",
      "fieldConfig": {
        "defaults": {
          "custom": {
            "align": null
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "yellow",
                "value": 460
              },
              {
                "color": "red",
                "value": 500
              }
            ]
          }
        },
        "overrides": []
      },
      "gridPos": {
        "h": 5,
        "w": 6,
        "x": 11,
        "y": 0
      },
      "id": 2,
      "options": {
        "colorMode": "value",
        "graphMode": "area",
        "justifyMode": "auto",
        "orientation": "auto",
        "reduceOptions": {
          "calcs": [
            "mean"
          ],
          "fields": "",
          "values": false
        }
      },
      "pluginVersion": "7.0.3",
      "targets": [
        {
          "expr": "cardano_node_Forge_metrics_operationalCertificateExpiryKESPeriod_int",
          "format": "time_series",
          "instant": true,
          "interval": "",
          "legendFormat": "KES Expiry",
          "refId": "A"
        },
        {
          "expr": "cardano_node_Forge_metrics_currentKESPeriod_int",
          "instant": true,
          "interval": "",
          "legendFormat": "KES current",
          "refId": "B"
        }
      ],
      "timeFrom": null,
      "timeShift": null,
      "title": "KES Perioden",
      "type": "stat"
    },
    {
      "datasource": "prometheus",
      "description": "",
      "fieldConfig": {
        "defaults": {
          "custom": {
            "align": null
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              }
            ]
          }
        },
        "overrides": []
      },
      "gridPos": {
        "h": 5,
        "w": 6,
        "x": 0,
        "y": 5
      },
      "id": 10,
      "options": {
        "colorMode": "value",
        "graphMode": "area",
        "justifyMode": "auto",
        "orientation": "auto",
        "reduceOptions": {
          "calcs": [
            "mean"
          ],
          "fields": "",
          "values": false
        }
      },
      "pluginVersion": "7.0.3",
      "targets": [
        {
          "expr": "cardano_node_ChainDB_metrics_slotNum_int",
          "instant": true,
          "interval": "",
          "legendFormat": "SlotNo",
          "refId": "A"
        }
      ],
      "timeFrom": null,
      "timeShift": null,
      "title": "Slot",
      "type": "stat"
    },
    {
      "datasource": "prometheus",
      "description": "",
      "fieldConfig": {
        "defaults": {
          "custom": {
            "align": null
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "red",
                "value": 80
              }
            ]
          }
        },
        "overrides": []
      },
      "gridPos": {
        "h": 5,
        "w": 5,
        "x": 6,
        "y": 5
      },
      "id": 8,
      "options": {
        "colorMode": "value",
        "graphMode": "area",
        "justifyMode": "auto",
        "orientation": "auto",
        "reduceOptions": {
          "calcs": [
            "mean"
          ],
          "fields": "",
          "values": false
        }
      },
      "pluginVersion": "7.0.3",
      "targets": [
        {
          "expr": "cardano_node_ChainDB_metrics_epoch_int",
          "format": "time_series",
          "instant": true,
          "interval": "",
          "legendFormat": "Epoch",
          "refId": "A"
        }
      ],
      "timeFrom": null,
      "timeShift": null,
      "title": "Epoch",
      "type": "stat"
    },
    {
      "datasource": "prometheus",
      "description": "",
      "fieldConfig": {
        "defaults": {
          "custom": {},
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              }
            ]
          }
        },
        "overrides": []
      },
      "gridPos": {
        "h": 5,
        "w": 6,
        "x": 11,
        "y": 5
      },
      "id": 16,
      "options": {
        "colorMode": "value",
        "graphMode": "area",
        "justifyMode": "auto",
        "orientation": "auto",
        "reduceOptions": {
          "calcs": [
            "mean"
          ],
          "fields": "",
          "values": false
        }
      },
      "pluginVersion": "7.0.3",
      "targets": [
        {
          "expr": "cardano_node_ChainDB_metrics_blockNum_int",
          "instant": true,
          "interval": "",
          "legendFormat": "Block Height",
          "refId": "A"
        }
      ],
      "timeFrom": null,
      "timeShift": null,
      "title": "Block Height",
      "type": "stat"
    },
    {
      "aliasColors": {},
      "bars": false,
      "dashLength": 10,
      "dashes": false,
      "datasource": "prometheus",
      "description": "",
      "fieldConfig": {
        "defaults": {
          "custom": {
            "align": null
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "red",
                "value": 80
              }
            ]
          }
        },
        "overrides": []
      },
      "fill": 1,
      "fillGradient": 0,
      "gridPos": {
        "h": 9,
        "w": 9,
        "x": 0,
        "y": 10
      },
      "hiddenSeries": false,
      "id": 6,
      "legend": {
        "avg": false,
        "current": false,
        "max": false,
        "min": false,
        "show": true,
        "total": false,
        "values": false
      },
      "lines": true,
      "linewidth": 1,
      "nullPointMode": "null",
      "options": {
        "dataLinks": []
      },
      "percentage": false,
      "pluginVersion": "7.0.3",
      "pointradius": 2,
      "points": false,
      "renderer": "flot",
      "seriesOverrides": [],
      "spaceLength": 10,
      "stack": false,
      "steppedLine": false,
      "targets": [
        {
          "expr": "cardano_node_ChainDB_metrics_slotInEpoch_int",
          "interval": "",
          "legendFormat": "Slot in Epoch",
          "refId": "B"
        }
      ],
      "thresholds": [],
      "timeFrom": null,
      "timeRegions": [],
      "timeShift": null,
      "title": "Slot in Epoch",
      "tooltip": {
        "shared": true,
        "sort": 0,
        "value_type": "individual"
      },
      "type": "graph",
      "xaxis": {
        "buckets": null,
        "mode": "time",
        "name": null,
        "show": true,
        "values": []
      },
      "yaxes": [
        {
          "format": "short",
          "label": null,
          "logBase": 1,
          "max": null,
          "min": null,
          "show": true
        },
        {
          "format": "short",
          "label": null,
          "logBase": 1,
          "max": null,
          "min": null,
          "show": true
        }
      ],
      "yaxis": {
        "align": false,
        "alignLevel": null
      }
    },
    {
      "aliasColors": {},
      "bars": true,
      "dashLength": 10,
      "dashes": false,
      "datasource": "prometheus",
      "description": "",
      "fieldConfig": {
        "defaults": {
          "custom": {
            "align": null
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "red",
                "value": 80
              }
            ]
          }
        },
        "overrides": []
      },
      "fill": 1,
      "fillGradient": 4,
      "gridPos": {
        "h": 9,
        "w": 8,
        "x": 9,
        "y": 10
      },
      "hiddenSeries": false,
      "id": 20,
      "legend": {
        "avg": false,
        "current": false,
        "max": false,
        "min": false,
        "show": false,
        "total": false,
        "values": false
      },
      "lines": true,
      "linewidth": 1,
      "nullPointMode": "null",
      "options": {
        "dataLinks": []
      },
      "percentage": false,
      "pluginVersion": "7.0.3",
      "pointradius": 2,
      "points": false,
      "renderer": "flot",
      "seriesOverrides": [],
      "spaceLength": 10,
      "stack": false,
      "steppedLine": false,
      "targets": [
        {
          "expr": "cardano_node_Forge_metrics_nodeIsLeader_int",
          "interval": "",
          "legendFormat": "Node is leader",
          "refId": "A"
        }
      ],
      "thresholds": [],
      "timeFrom": null,
      "timeRegions": [],
      "timeShift": null,
      "title": "Node is Block Leader",
      "tooltip": {
        "shared": true,
        "sort": 0,
        "value_type": "individual"
      },
      "type": "graph",
      "xaxis": {
        "buckets": null,
        "mode": "time",
        "name": null,
        "show": true,
        "values": []
      },
      "yaxes": [
        {
          "decimals": null,
          "format": "none",
          "label": "Slot",
          "logBase": 1,
          "max": null,
          "min": null,
          "show": true
        },
        {
          "format": "short",
          "label": null,
          "logBase": 1,
          "max": null,
          "min": null,
          "show": true
        }
      ],
      "yaxis": {
        "align": false,
        "alignLevel": null
      }
    },
    {
      "aliasColors": {},
      "bars": false,
      "dashLength": 10,
      "dashes": false,
      "datasource": "prometheus",
      "description": "",
      "fieldConfig": {
        "defaults": {
          "custom": {}
        },
        "overrides": []
      },
      "fill": 1,
      "fillGradient": 0,
      "gridPos": {
        "h": 6,
        "w": 9,
        "x": 0,
        "y": 19
      },
      "hiddenSeries": false,
      "id": 14,
      "legend": {
        "avg": false,
        "current": false,
        "max": false,
        "min": false,
        "show": false,
        "total": false,
        "values": false
      },
      "lines": true,
      "linewidth": 1,
      "nullPointMode": "null",
      "options": {
        "dataLinks": []
      },
      "percentage": false,
      "pointradius": 2,
      "points": false,
      "renderer": "flot",
      "seriesOverrides": [],
      "spaceLength": 10,
      "stack": false,
      "steppedLine": false,
      "targets": [
        {
          "expr": "cardano_node_metrics_mempoolBytes_int / 1024",
          "interval": "",
          "intervalFactor": 1,
          "legendFormat": "Memory KB",
          "refId": "A"
        }
      ],
      "thresholds": [],
      "timeFrom": null,
      "timeRegions": [],
      "timeShift": null,
      "title": "Memory Pool",
      "tooltip": {
        "shared": true,
        "sort": 0,
        "value_type": "individual"
      },
      "type": "graph",
      "xaxis": {
        "buckets": null,
        "mode": "time",
        "name": null,
        "show": true,
        "values": []
      },
      "yaxes": [
        {
          "format": "KBs",
          "label": null,
          "logBase": 1,
          "max": null,
          "min": null,
          "show": true
        },
        {
          "format": "short",
          "label": null,
          "logBase": 1,
          "max": null,
          "min": null,
          "show": true
        }
      ],
      "yaxis": {
        "align": false,
        "alignLevel": null
      }
    },
    {
      "datasource": "prometheus",
      "description": "",
      "fieldConfig": {
        "defaults": {
          "custom": {},
          "decimals": 2,
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              }
            ]
          },
          "unit": "dthms"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 6,
        "w": 8,
        "x": 9,
        "y": 19
      },
      "id": 4,
      "options": {
        "colorMode": "value",
        "graphMode": "area",
        "justifyMode": "auto",
        "orientation": "auto",
        "reduceOptions": {
          "calcs": [
            "last"
          ],
          "fields": "",
          "values": false
        }
      },
      "pluginVersion": "7.0.3",
      "targets": [
        {
          "expr": "cardano_node_metrics_upTime_ns / (1000000000)",
          "format": "time_series",
          "instant": true,
          "interval": "",
          "intervalFactor": 1,
          "legendFormat": "Server Uptime",
          "refId": "A"
        }
      ],
      "timeFrom": null,
      "timeShift": null,
      "title": "Block-Producer Uptime",
      "type": "stat"
    }
  ],
  "refresh": "5s",
  "schemaVersion": 25,
  "style": "dark",
  "tags": [],
  "templating": {
    "list": []
  },
  "time": {
    "from": "now-24h",
    "to": "now"
  },
  "timepicker": {
    "refresh_intervals": [
      "10s",
      "30s",
      "1m",
      "5m",
      "15m",
      "30m",
      "1h",
      "2h",
      "1d"
    ]
  },
  "timezone": "",
  "title": "Cardano Node",
  "uid": "bTDYKJZMk",
  "version": 1
}"'

	sudo grafana-cli admin reset-admin-password $pass
	rm ~/.history

	sudo grafana-cli plugins install grafana-clock-panel

}

informacionKeys(){

	echo -e "$IGreen \n [*] Generando archivo $fileInformacionKeys, aqui se explica para que se utiliza cada key y certificado $End" 
	echo -e "  Keys cold: par de claves que nos asigna un identificador de stake pool y que nos permite generar nuevos certificados $cert_issue_op." > $fileInformacionKeys
	echo -e "  Las keys cold se crearán y almacenarán en un equipo sin conexión y mucho menos en la computadora que ejecuta el nodo" >> $fileInformacionKeys
	echo -e "  No almacene las keys cold en su servidor o en cualquier computadora con acceso a Internet. El mejor lugar para sus keys cold es un USB SEGURO u otro DISPOSITIVO EXTERNO SEGURO" >> $fileInformacionKeys
	echo -e "	 NodeId: es el identificador dentro del protocolo blockchain (la billetera delegará a su grupo de estaca a través de este NodeId) " >> $fileInformacionKeys
	echo -e "	 $cert_PoolCold_Counter: Certificado que permite generar el nuevo certificado $cert_issue_op para cada período KES, este certificado lleva la cuenta de las veces que nuestro stake pool ha estado operativo \n" >> $fileInformacionKeys
	echo -e "  keys KES: par de claves que se utilizan para firma el bloque, estas claves deben ser renovadas periodicamente sengún el kesperiod, esto nos protege de hackers ya que de esta forma se impide firmar bloques antiguos \n" >> $fileInformacionKeys
	echo -e "  $cert_issue_op: identifica a las keys KES y acredita hasta que perido de tiempo las keys KES son validas, este certificado otorga que nuestro stake pool esta operativo." >> $fileInformacionKeys
	echo -e "  Antes de que caduque las antiguas keys KES se debe crear un nuevo certificado $cert_issue_op utilizando un par de keys KES nuevas generadas recientemente. \n" >> $fileInformacionKeys
	echo -e "  keys VRF: par de claves utilizadas para participar en la loteria, para ser elegido lider de slot \n" >> $fileInformacionKeys
	echo -e "  $cert_stake: certifica que disponemos una billetera de recompensas \n" >> $fileInformacionKeys
	echo -e "  $cert_pledge: certifica que disponemos de los fondos asignados al pledge \n" >> $fileInformacionKeys
	echo -e "  $cert_pool: Certificado de registro del stake pool para que el nodo se convierta en un nodo stake pool \n" >> $fileInformacionKeys

}

obtenerAyuda(){

	echo -e "$IGreen \n [i] Ejecutar las opciones 0, 1, 2, 3, 4, 5, 6, 8, 9 y 19, 28 en la máquina que vayas a instalar nodos relays $End" 
	echo -e "$IGreen \n [i] Ejemplo [0-35]: 8 1 2 3 4 5 6 8 9 19 28 $End" 
	echo -e "$IGreen \n [i] Ejecutar las opciones 0, 1, 2, 3, 4, 7, 8, 9, 10, 11, 12, 14, 15, 16, 17, 18, 28 en la maquinas que vayas a instalar el nodo block producer $End" 
	echo -e "$IGreen \n [i] Ejemplo [0-35]: 0 1 2 3 4 7 8 9 10 11 12 13 14 15 16 17 18 28  $End" 
	echo -e "$IGreen \n [i] Ejecutar las opciones de 0 a 20 y 28 si vas a instalar los nodos relyas y el nodo block producer en la misma máquina $End" 
	echo -e "$IGreen \n [i] Ejemplo [0-35]: 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20  $End" 
	echo -e "$IGreen \n [i] Ejecutar las opciones de 0 a 20 y de 28 a 34 si vas a instalar nodos relays, nodo producer y monitorización en la misma máquina $End" 
	echo -e "$IGreen \n [i] Ejemplo [0-35]: 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 28 29 30 31 32 33 34 $End" 
	echo -e "$IGreen \n [i] Ejecutar las opciones 29 30 31 32 33 34 para el servidor de monitorización  $End" 
	echo -e "$IGreen \n [i] Ejemplo [0-35]: 29 30 31 32 33 34 $End" 
	exit 0

}

#################################################
#				Elegir Opcion					#
#################################################

elegirOpcion(){

	listOpciones=("Instalar programas: net-tools, mlocate tmux, htop, git, tree, curl, openssh, fail2ban, wget, Knockd, tcpdump, gnupg2 bc"  "Instalar dependencias" "Instalar Libsodium" "Instalar GHC" "Instalar Cabal" "Descargar Files Config, Genesis, Topology" "Instalar Cardano-cli y Cardano-node" "Actualizar Cardano-node y Cardano-cli")
	listOpciones+=("Configurar topologia nodos relays" "Configurar topologia Block Producer" "Crear script para iniciar los nodos" "Iniciar Nodos" "Calcular Kes period y parametros protocol" "Generar Keys Pool, cold, kes, vrf, operational certificate")
	listOpciones+=("Generar Keys Address" "Solicitar Faucet"  "Consultar saldo" "Consultar saldo de dirección concreta" "Crear script nodo block producer" "Registrar stake address" "Registrar stake pool" "Reclamar stake pool" "Descargar script get_buddies" "Cifrar keys Pool y keys address" "Descifrar keys Pool y keys address")
	listOpciones+=("Consultar Recompensas" "Renovar certificado kes period" "Cambiar Pledge Fee y Margin" "Actualizar Metadata" "Actualizar IPs hostname Pool" "Enviar ADAs" "Reclamar Recompensas" "Retirar StakePool" "Consultar Retiro StakePool" "Iniciar Stake Pool de forma automática con daemon cuando el sistema se reinicia" )
	listOpciones+=("Instalar prometheus" "Instalar Node Exporter" "Instalar grafana" "Configurar prometheus.yml" "Configurar Grafana"  "Configurar Node Exporter" "Ayuda")

	while true
		do
			c=0
			echo ""
			oldIFS=$IFS
			IFS=""
			for program in ${listOpciones[@]}
				do
					printf " %s %s: %s\n" " " "$c" "$program" 
					((c++)) 
				done 
			
			((c--)) 
			echo ""
			IFS=$oldIFS
			read -a optionsopciones -p " [*] Elige una o más opciones [0-$c]: "
			EligeOpcion=()
			IFS=""

			for opcion in ${optionsopciones[@]}
			do
				case ${listOpciones[$opcion]} in
					${listOpciones[-1]})
						EligeOpcion+="(${listOpciones[opcion]})"
						break ;;
					${listOpciones[$opcion]}) 
						if [ -z ${listOpciones[$opcion]} ]; then
							echo -e "$IYellow \n [!!] Opción Invalida $End"
							echo -e "$IYellow [!!] Introduce las opciones de la siguiente forma: 1 3 $End"
							error=1
							break
						else
							EligeOpcion+="(${listOpciones[$opcion]})"
						fi ;;
				esac
			done
			if [ -z $error ]
			then
				IFS=$oldIFS
				break
			else
				unset error
			fi
		done
}


#################################################
#				Ejecutar Opción  				#
#################################################

ejecutarOpcion(){

	opciones=$@
	IFS="()"
	for i in ${opciones[@]}
		do			
			case $i in
				"Instalar programas: "*) 
					echo -e "\n [*] $i"
					Programas=("net-tools" "mlocate" "tmux" "htop" "git" "tree" "curl" "openssh-server" "fail2ban" "knockd" "wget" "tcpdump" "gnupg2" "bc" "tcptraceroute" "secure-delete" "iproute2" "")  
					instalarProgramas $
				;;
				"Instalar dependencias") 
					echo -e "\n [*] $i"
					Programas=("python3" "libsodium-dev" "build-essential" "pkg-config" "libffi-dev" "libgmp-dev" "libssl-dev" "libtinfo-dev" "systemd" "libsystemd-dev" "zlib1g-dev" "yarn" "make" "g++" "jq" "libncursesw5"  "gnupg" "aptitude" "libtool" "autoconf" "automake" ) 
					instalarProgramas 
				;;
				"Instalar Libsodium")
					echo -e "\n [*] $i"
					Programas=("Libsodium") 
					instalarProgramas 
				;;
				"Instalar GHC")
					echo -e "\n [*] $i"
					Programas=("GHC") 
					instalarProgramas 
				;;
				"Instalar Cabal")
					echo -e "\n [*] $i"
					Programas=("Cabal") 
					instalarProgramas 
				;;
				"Descargar Files "*)
					echo -e "\n [*] $i"
					DecargarAchivosJson 
				;;
				"Instalar Cardano-cli y Cardano-node")
					echo -e "\n [*] $i"
					Programas=("cardano-cli-cardano-node") 
					instalarProgramas 
				;;
				"Actualizar Cardano-node y Cardano-cli")
					echo -e "\n [*] $i"
					Programas=("Actualizar-Cardano-Node-y-Cardano-CLI")
					instalarProgramas
					DecargarAchivosJson
				;;
				"Configurar topologia nodos relays")
					echo -e "\n [*] $i"
					DecargarAchivosJson
					registros=("noActualizarDatos")
					checkDatosNodo 
					configTopoRealys
					unset registros
				;;
				"Configurar topologia Block Producer")
					echo -e "\n [*] $i"
					DecargarAchivosJson
					registros=("noActualizarDatos")
					checkDatosNodo 
					configTopoblockProducer
					unset registros
				;;
				"Crear script para iniciar los nodos")
					echo -e "\n [*] $i"
					scriptIniciarNodos
				;;
				"Iniciar Nodos")
					echo -e "\n [*] $i"
					iniciarNodos
					sleep 5
				;;
				"Calcular Kes period y parametros protocol")
					echo -e "\n [*] $i"
					checkSynBlockchainCardano
					calcularKesPeriod
					parametrosProtocolo
				;;
				"Generar Keys Pool"*)
					echo -e "\n [*] $i"
					checkSynBlockchainCardano
					calcularKesPeriod
					generarColdKeys
					generarVRFKeys
					generarKESKeys
					generarOperationalCert
				;;
				"Generar Keys Address"*)
					echo -e "\n [*] $i"
					checkSynBlockchainCardano
					keysPayment
					keysStaking
					addressPayment
					addressStaking
					addressBase
				;;
				"Solicitar Faucet")
					echo -e "\n [*] $i"
					checkSynBlockchainCardano
					faucet
				;;
				"Consultar saldo")
					echo -e "\n [*] $i"
					checkSynBlockchainCardano
					registros=("saldo")
					consultarSaldo
				;;
				"Consultar saldo "*)
					echo -e "\n [*] $i"
					checkSynBlockchainCardano
					direccion
					registros=("direccion")
					consultarSaldo
				;;
				"Crear script nodo block producer")
					echo -e "\n [*] $i"
					nodoblock=("block")
					scriptIniciarNodos
				;;

				"Registrar stake address")
					echo -e "\n [*] $i"
					checkSynBlockchainCardano
					certificadoStake
					parametrosProtocolo
					registros=("stake")
					consultarSaldo
					crearTransaccion
					calcularTransaccionFee
					construirTransaccion
					firmarTransaccion
					enviarTransaccion
					unset registros
				;;
				"Registrar stake pool")
					echo -e "\n [*] $i"
					checkSynBlockchainCardano
					metadataPool
					generarMetaHash
					registros=("stakePool")
					crearCertificadoPool
					crearCertificadoDelegacion
					consultarSaldo
					crearTransaccion
					calcularTransaccionFee
					construirTransaccion
					firmarTransaccion
					enviarTransaccion
					unset registros
				;;
				"Reclamar stake pool")
					echo -e "\n [*] $i"
					checkSynBlockchainCardano
					reclamarStakePool
				;;
				"Descargar script get_buddies")
					echo -e "\n [*] $i"
					descargarGetbuddies
				;;
				"Iniciar Stake Pool"*)
					echo -e "\n [*] $i"
					scriptStopPool
					daemonNode
				;;
				"Consultar Recompensas")
					echo -e "\n [*] $i"
					checkSynBlockchainCardano
					ConsultarRecompensas
				;;
				"Cambiar Pledge Fee y Margin")
					echo -e "\n [*] $i"
					checkSynBlockchainCardano
					registros=("pledge")
					crearCertificadoPool
					crearCertificadoDelegacion
					consultarSaldo
					crearTransaccion
					calcularTransaccionFee
					construirTransaccion
					firmarTransaccion
					enviarTransaccion
					unset registros
				;;
				"Actualizar Metadata")
					echo -e "\n [*] $i"
					checkSynBlockchainCardano
					metadataPool
					generarMetaHash
					registros=("metadataUpdate")
					crearCertificadoPool
					crearCertificadoDelegacion
					consultarSaldo
					crearTransaccion
					calcularTransaccionFee
					construirTransaccion
					firmarTransaccion
					enviarTransaccion
					unset registros
				;;
				"Actualizar IPs hostname Pool")
					echo -e "\n [*] $i"
					checkSynBlockchainCardano
					registros=("actualizarDatos")
					checkDatosNodo
					configTopoRealys
					configTopoblockProducer
					metadataPool
					generarMetaHash
					unset registros
					registros=("metadataUpdate")
					crearCertificadoPool
					crearCertificadoDelegacion
					consultarSaldo
					crearTransaccion
					calcularTransaccionFee
					construirTransaccion
					firmarTransaccion
					enviarTransaccion
					unset registros
				;;
				"Renovar certificado kes period")
					echo -e "\n [*] $i"
					checkSynBlockchainCardano
					calcularKesPeriod
					generarKESKeys
					generarOperationalCert

				;;
				"Enviar ADAs")
					echo -e "\n [*] $i"
					checkSynBlockchainCardano
					EnviarADas
					registros=("EnviarAdas")
					consultarSaldo
					crearTransaccion
					calcularTransaccionFee
					construirTransaccion
					firmarTransaccion
					enviarTransaccion
					consultarSaldo
					unset registros
				;;
				"Reclamar Recompensas")
					echo -e "\n [*] $i"
					checkSynBlockchainCardano
					ConsultarRecompensas
					registros=("Recompensas")
					consultarSaldo
					crearTransaccion
					calcularTransaccionFee
					construirTransaccion
					firmarTransaccion
					enviarTransaccion
					consultarSaldo
					unset registros
				;;
				"Retirar StakePool")
					echo -e "\n [*] $i"
					checkSynBlockchainCardano
					certificadoRetirarStakePool
					registros=("retirarPool")
					consultarSaldo
					crearTransaccion
					calcularTransaccionFee
					construirTransaccion
					firmarTransaccion
					enviarTransaccion
					unset registros
				;;
				"Consultar Retiro StakePool")
					echo -e "\n [*] $i"
					checkSynBlockchainCardano
					consultarRetiroPool
				;;
				"Instalar prometheus")
					echo -e "\n [*] $i"
					Programas=("prometheus") 
					instalarProgramas 
				;;
				"Instalar Node Exporter")
					echo -e "\n [*] $i"
					Programas=("prometheus-node-exporter") 
					instalarProgramas 
				;;
				"Instalar grafana")
					echo -e "\n [*] $i"
					Programas=("Instalar-gafana") 
					instalarProgramas 
				;;
				"Cifrar keys Pool y keys address")
					echo -e "\n [*] $i"
					cifrarDescifrar=("addressKeys" "cifrar" "poolKeys" "cifrar" )
					cifrarDescifrarArchivos
					informacionKeys
				;;
				"Descifrar keys Pool y keys address")
					echo -e "\n [*] $i"
					cifrarDescifrar=("poolKeys" "descifrar" "addressKeys" "descifrar")
					cifrarDescifrarArchivos
				;;
				"Configurar prometheus.yml")
					echo -e "\n [*] $i"
					echo " [i] En construccion"
					ConfigurarPrometheus
				;;
				"Configurar Grafana")
					echo -e "\n [*] $i"
					ConfigurarGrafana
				;;
				"Configurar Node Exporter")
					echo -e "\n [*] $i"
					ConfigurarNodeExporter
				;;
				"Ayuda")
					echo -e "\n [*] $i"
					obtenerAyuda
				;;

			esac
			IFS=$oldIFS
		done


}


#################################################
#					MENU					    #
#################################################


OS_ID=$(grep -i ^id_like= /etc/os-release | cut -d= -f 2)

if [ -z "${OS_ID##*debian*}" ]; then

	declare -A datosPool

	#Variables por defecto
	#ipTopoBlockPriv="127.0.0.1"
	ipTopoBlockPub="0.0.0.0"
	ipTopoRelayPub="0.0.0.0"

	while true; do
		read -p " [?] Quieres crear un nodo en la red mainnet o la red testnet [mainnet/testnet]: " respuesta
		if [[ "${respuesta}" == "mainnet" ]]; then 

			dirCardanoNode="$HOME/cardano-node"
			dirNodos="$HOME/cardano-my-node"
			dirRelay="$HOME/cardano-my-node/relay_"
			dirBlock="$HOME/cardano-my-node/block_producer"

			fileShelleyConfig="mainnet-config.json"
			fileShelleyGenesis="mainnet-shelley-genesis.json"
			fileShelleyGenesisByron="mainnet-byron-genesis.json"
			fileShelleytopology="mainnet-topology.json"
			fileShelleydbSyn="mainnet-db-sync-config.json"
			fileShelleyresConfig="rest-config.json"


			IPIOHK="relays-new.cardano-mainnet.iohk.io"
			PortIOHK="3001"
			magig_Number=764824073
			filesJson="mainnet-"

			fileIniciarRelay=IniciarRelay_
			fileIniciarBlock=IniciarBlock

			fileIniciarNodos='iniciarNodos'
			fileStopNodos='stopNodos'
			fileAutoIniciarNodos="cardano-stakepool.service"

			longdDireccionPayment=58
			longDireccionBase=103

			break

		elif [[ "${respuesta}" == "testnet" ]]; then 

			dirCardanoNode="$HOME/cardano-node"
			dirNodos="$HOME/testnet_cardano_my_node"
			dirRelay="$HOME/testnet_cardano_my_node/relay_"
			dirBlock="$HOME/testnet_cardano_my_node/block_producer"

			fileShelleyConfig="testnet-config.json"
			fileShelleyGenesis="testnet-shelley-genesis.json"
			fileShelleyGenesisByron="testnet-byron-genesis.json"
			fileShelleytopology="testnet-topology.json"
			fileShelleydbSyn="testnet-db-sync-config.json"
			fileShelleyresConfig="rest-config.json"


			IPIOHK="relays-new.cardano-testnet.iohkdev.io"
			PortIOHK="3001"
			magig_Number=1097911063
			filesJson="testnet-"

			fileIniciarRelay=testnet_IniciarRelay_
			fileIniciarBlock=testnet_IniciarBlock

			fileIniciarNodos='testnet_iniciarNodos'
			fileStopNodos='testnet_stopNodos'
			fileAutoIniciarNodos="testnet_cardano-stakepool.service"

			webFaucet="https://faucet.shelley-testnet.dev.cardano.org/send-money"
			longdDireccionPayment=63
			longDireccionBase=108

			break
		
		else echo -e "$IYellow \n [!!] Dato incorrecto, introduce mainnet o testnet $End"; continue; fi
	done

	echo -e "$IGreen [i] Comprobando últimos archivos .json ... $End"

	numBuild=$(curl https://hydra.iohk.io/job/Cardano/iohk-nix/cardano-deployment/latest-finished/download/1/index.html 2> /dev/null | grep -e "build" | sed 's/.*build\/\([0-9]*\)\/download.*/\1/g')

	webIOHKfilesJson="https://hydra.iohk.io/build/$numBuild/download/1"

	dirKeysPool="keys_Pool"
	dirAddressKeys="address_Keys"
	dirRegistarStakeAddress="Registro_Stake_Address"
	
	
	nameIOHK="Relays_IOHK"


	filedatosPool='datosPool.txt'
	fileInformacionKeys='informacion_key.txt'


	fileTransaccionFee="transFee"
	fileTransaccion="tx.raw"
	fileTransaccionTemporal="tx.tmp"
	fileFirmaTransaccion="tx.signed"

	fileMetadataPool="poolMetaData.json"
	fileMetaHashPool="poolMetaDataHash.txt"
	fileRegisterPool="registerPool"
	
	filestakepoolid="stakepoolid.txt"
	filestakepoolidHex="stakepoolidHex.txt"
	fileGetBuddies="get_buddies.sh"

	filePT_TOPOLOGY_FILE=\"topologia-amigos.json\"

	fileLedger="ledger-state.json"

	urlBuddies="https://raw.githubusercontent.com/papacarp/pooltool.io/master/buddies"



	keyPoolCold_Vkey="cold.vkey"
	keyPoolCold_Skey="cold.skey"
	
	keyVRF_Vkey="vrf.vkey"
	keyVRF_Skey="vrf.skey"

	keyKES_Vkey="kes.vkey"
	keyKES_Skey="kes.skey"

	keyPayment_Vkey="payment.vkey"
	keyPayment_Skey="payment.skey"

	keyStaking_Vkey="stake.vkey"
	keyStaking_Skey="stake.skey"

	addressPayment="payment.addr"
	addressStaking="staking.addr"
	addressBase="base.addr"


	cert_issue_op="kes_op.cert"
	cert_PoolCold_Counter="cold.counter"
	cert_stake="staking.cert"
	cert_pledge="pledge.cert"
	cert_pool="pool.cert"
	cert_Retirar_Pool="pool.dereg"

	protocolParameters="protocol_Parameters.json"

	if [ -f "${dirNodos}/$filedatosPool" ]; then
		. ${dirNodos}/$filedatosPool
	fi

	if [ -f "${dirNodos}/$filedatosPool" ]; then
		. ${dirNodos}/$filedatosPool
	fi
	activarInternet
	elegirOpcion
	ejecutarOpcion ${EligeOpcion[@]}
else
	echo -e "$IRed [!!!] Este Script solo soporta distribuciones debian $End"
	exit 1
fi
