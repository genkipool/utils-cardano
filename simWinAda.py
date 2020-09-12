#!/usr/bin/env python3
# -*- coding: utf-8 -*-

__author__   = 'LRB85'
__date__     = '12/06/2020'
__version__  = "0"

"""
Script para calcular la mejor estrategia para delegar en Cardano.
Ojo, este script no muestra las ganancias reales de la mainnet de cardano, aunque pudieran ser aproximadas.
"""
import random

class bcolors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKGREEN = '\033[93m'
    AMARILLO = "\033[1;33m"
    WARNING = '\033[0;30;41m'
    FAIL = '\033[0;31m'
    ENDC = '\033[1;m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'

def errores(error):

	print(bcolors.FAIL, "[!]", error, bcolors.ENDC)


def converAmoney(convert):

	money = '{:,.8f}'.format(convert)
	return money

def estrategia():


	while True:
		estrategias = {"adaInicial": "Cuántas ADAS quieres delegar: ", "numPool": "En cuantos pools quieres delegar: ", "delegarAda": "Quieres delegar la misma cantidad de ADAs en los diferentes pools [y/n]: ", 
		"intCompu": "Quieres delegar las recompensas obtenidas [y/n]: ", "epoca": "Cuántos días dura una epoca: ", "años": "Durante cuántos años quieres delegar: ", "moneda": "Quieres Euros o Dolares [€/$]: ", 
		"precio": "Cúal es el precio de ADA: ", "reducir": "Quieres que las recompensas se reduzcan segun van pasando los años [y/n]: "}

		try:
			for estrategia in estrategias:
				if "Quieres" in estrategias[estrategia]:
					estrategias[estrategia] = input(" [?] " + estrategias[estrategia])
				else:
					estrategias[estrategia] = float(input(" [?] " + estrategias[estrategia]))
					
			break

		except Exception as e:
			errores(e)	

	return estrategias
	
def checkEstrategia(getEstrategias):

	while True:
		try:
			adaInPool = {}

			for numpool in range(1, int(getEstrategias["numPool"]) +1):
				if getEstrategias["delegarAda"].lower() == "y":
						adaInPool["pool_" + str(numpool)] = getEstrategias["adaInicial"]/int(getEstrategias["numPool"])
				else:
					adaInPool["pool_" + str(numpool)] = float(input(" [?] Cuántos ADAs quieres delegar en el pool " + str(numpool) + ": "))

			if getEstrategias["delegarAda"].lower() != "y":
				if not getEstrategias["adaInicial"] == sum(adaInPool.values()):
					errores( "La suma de ADAs a delegar entre los diferentes pools no coincide con el ADA total " + str(sum(adaInPool.values())) + "/" + str(getEstrategias["adaInicial"])) 
					continue
		
			break

		except Exception as e:
			errores(e)	

	return adaInPool



def ganancias(getEstrategias, getadaInPool):

	ganancias = {"adaTotal": getEstrategias["adaInicial"]}
	recomPool = {}
	lotPorc = {}
	epoca = 0
	dia = 0
	totalEpoca = (365/int(getEstrategias["epoca"]))*int(getEstrategias["años"])
	
	
	endPorc = 0.028

	while epoca < int(totalEpoca):
		recomPool = recomPool.fromkeys(recomPool, 0)
		for block in range(1, int(getEstrategias["epoca"]) +1):
			dia += 1
			for pool in getadaInPool:
				recompensa = round(random.uniform(0, endPorc), 3) # porcentaje de recompensa del ADA delegado
				if pool in recomPool:
					recomPool[pool] += (getadaInPool[pool] *recompensa)/100
				else:
					recomPool[pool] = (getadaInPool[pool] *recompensa)/100

				lotPorc[pool] = (recomPool[pool]*100)/getadaInPool[pool]
	
		epoca += 1
		ganancias["epoca_" + str(epoca)] = sum(recomPool.values())
		

		if getEstrategias["intCompu"].lower()  == "y":
			delegado = ganancias["adaTotal"]
			for pool in getadaInPool:
				getadaInPool[pool] += recomPool[pool]
				ganancias["adaTotal"] += recomPool[pool]

		else:
			delegado = getEstrategias["adaInicial"] 	
			ganancias["adaTotal"] = getEstrategias["adaInicial"] +	ganancias["epoca_" + str(epoca)] 
			

		if getEstrategias["reducir"].lower()  == "y" and dia% 365 == 0:
			endPorc -= 0.003
			if endPorc <= 0.002:
				endPorc = 0.002

		adaTotal = ganancias["adaTotal"]
		precioAda = getEstrategias["precio"]
		moneda = getEstrategias["moneda"]
		gananciasEpoca = ganancias["epoca_" + str(epoca)]


		print("\n  [*] Epoca: %d/%d " %(epoca, totalEpoca))
		print("  [*] ADA: %s/%s A --> %s/%s %s" %(converAmoney(adaTotal), converAmoney(delegado), converAmoney(adaTotal*precioAda), converAmoney(delegado*precioAda), moneda))
		for pool in getadaInPool:
			if getEstrategias["intCompu"].lower()  == "y":
				print("  [*] %s: %s/%s A --> %s %s -- %f %%" %(pool, converAmoney(getadaInPool[pool]), converAmoney(getadaInPool[pool]-recomPool[pool]), converAmoney(getadaInPool[pool]*precioAda), moneda, lotPorc[pool]))
			else:
				print("  [*] %s: %s/%s A --> %s %s -- %f %%" %(pool, converAmoney(getadaInPool[pool]+recomPool[pool]), converAmoney(getadaInPool[pool]), converAmoney(getadaInPool[pool]*precioAda), moneda, lotPorc[pool]))
		print("  [*] Gananancias Epoca: %s A --> %s %s -- %f %%" %(converAmoney(gananciasEpoca), converAmoney(gananciasEpoca*precioAda), moneda, sum(lotPorc.values())))

	return ganancias

def estadisticas(getEstrategias, getadaInPool, getGanancias):

	print("\n")
	print(" -------------------------------------------------" )
	print(" |            ESTADISTICAS                       |" )
	print(" -------------------------------------------------" )

	adaInicial = getEstrategias["adaInicial"]
	precioAda = getEstrategias["precio"]
	moneda = getEstrategias["moneda"]
	años = getEstrategias["años"]
	recompensaAda = sum(getGanancias.values())-getGanancias["adaTotal"]
	recompensaEuro = (sum(getGanancias.values())-getGanancias["adaTotal"])*precioAda
	adaGanado = recompensaAda + adaInicial

	print("  [*] Has delegado %s A --> %s %s" %(converAmoney(adaInicial), converAmoney(adaInicial*precioAda), moneda))
	print("  [*] En %d años has conseguido una recompensa de %s A --> %s %s" %(años, converAmoney(recompensaAda),converAmoney(recompensaEuro), moneda))
	print("  [*] Has obtenido un beneficio dirario del %f %%"  %(((recompensaAda/(365*años))*100)/adaInicial))
	print("  [*] Has obtenido un beneficio mensual del %f %%"   %(((recompensaAda/(12*años))*100)/adaInicial))
	print("  [*] Has obtenido un beneficio anual del %f %%" %(((recompensaAda/años)*100)/adaInicial))
	print("  [*] Has multiplicado tus ADAs x%f" %(adaGanado/adaInicial))

	print("\n  [*] En %d años has conseguido un total de %s A --> %s %s \n" %(años, converAmoney(adaGanado), converAmoney(adaGanado*precioAda), moneda))


if __name__ == '__main__':

	while True:
		try:
			getEstrategias = estrategia()
			getadaInPool = checkEstrategia(getEstrategias)
			getGanancias = ganancias(getEstrategias, getadaInPool)
			estadisticas(getEstrategias, getadaInPool, getGanancias)
		except KeyboardInterrupt:
			print( "\n [!] Cerrando Script \n")
			break
	exit(1)

