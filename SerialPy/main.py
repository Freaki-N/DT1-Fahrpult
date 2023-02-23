import serial, pyautogui, time

##############################################          
# Diese Skript wandelt die Befehle vom ESP32 #
# in Tastaturevents um. Programmiert für das #
# U-Bahn Berlin AddOn für TrainZ             #
##############################################

PORT = "COM3"
BAUDRATE = "9600"

runbutton = 0
reverser = 0
brakelever = 0
tuerfreigabeLinks = 0
tuerfreigabeRechts = 0
tuerenSchliessen = 0
hupe = 0
federspEin = 0
federspLoesen = 0
innenlautspr = 0
aussenlautspr = 0
automatEin = 0
automatAus = 0
umformerEin = 0
umformerAus = 0
stromabnehmerAn = 0
stromabnehmerAb = 0
schienenbremse = 0

runbuttonSim = 0
reverserSim = 0
brakeleverSim = 0
tuerfreigabeLinksSim = 0
tuerfreigabeRechtsSim = 0
tuerenSchliessenSim = 0
hupeSim = 0
federspEinSim = 0
federspLoesenSim = 0
innenlautsprSim = 0
aussenlautsprSim = 0
automatEinSim = 0
automatAusSim = 0
umformerEinSim = 0
umformerAusSim = 0
stromabnehmerAnSim = 0
stromabnehmerAbSim = 0
schienenbremseSim = 0

timer_tuerfreigabe = -1

global conn

def run():
    global conn
    conn = serial.Serial(port=PORT,baudrate=BAUDRATE,parity=serial.PARITY_NONE,stopbits=serial.STOPBITS_ONE,bytesize=serial.EIGHTBITS,timeout=0.25)
    print("connected to: " + conn.portstr)
    conn.write(b"cp_Umschalthebel_A=1;\n")
    conn.write(b"Gruenschleife_Links_A=1;\n")
    conn.write(b"Gruenschleife_Rechts_A=1;\n")
    conn.write(b"gb_Fahrstromautomat_aus_A=0;\n")
    conn.write(b"master=TrainZ;\n")
    
    while True:
        loop()
        try:
            lineRaw = conn.readline()
            if lineRaw:
                line = (lineRaw.decode())[:-2]
                #print(line)
                lineSplit = str(line).split(";")
                #print(lineSplit)
                for i in lineSplit:
                    if(len(i) > 0):
                        iSplit = i.split("=")
                        #print(iSplit)
                        if len(iSplit) == 2:
                            newData(iSplit[0], iSplit[1])
        except:
            #print("Error while Reading Serial!")
            pass
            
def loop():
    global runbutton
    global reverser
    global brakelever
    global tuerfreigabeLinks
    global tuerfreigabeRechts
    global tuerenSchliessen
    global hupe 
    global federspEin
    global federspLoesen
    global innenlautspr 
    global aussenlautspr
    global automatEin
    global automatAus
    global umformerEin
    global umformerAus
    global stromabnehmerAn
    global stromabnehmerAb
    global schienenbremse

    global runbuttonSim
    global reverserSim
    global brakeleverSim
    global tuerfreigabeLinksSim
    global tuerfreigabeRechtsSim
    global tuerenSchliessenSim
    global hupeSim 
    global federspEinSim
    global federspLoesenSim
    global innenlautsprSim 
    global aussenlautsprSim
    global automatEinSim
    global automatAusSim
    global umformerEinSim
    global umformerAusSim
    global stromabnehmerAnSim
    global stromabnehmerAbSim
    global schienenbremseSim
    
    global timer_tuerfreigabe
    
   # if brakeleverSim >= 6:
     #   if brakelever < brakeleverSim:
     #       pyautogui.press('num6')
       #     brakeleverSim = 2           
        #    time.sleep(10/1000)    
    #else: 
    if brakelever < brakeleverSim:
        pyautogui.press('num9') 
        brakeleverSim = 1  
        time.sleep(1/1000)            
     
    while brakelever > brakeleverSim:
       pyautogui.press('num3') 
       brakeleverSim = brakeleverSim + 1
       time.sleep(1/1000)
       
    if brakeleverSim == 1:
        if runbutton != runbuttonSim:
            pyautogui.press("space") 
            runbuttonSim = runbutton 
    else:       
        if runbuttonSim == 1:
            pyautogui.press("space") 
            runbuttonSim = 0 
        
    if runbutton == 1:
        while reverser > reverserSim:
            pyautogui.press('num8') 
            reverserSim = reverserSim + 1
            time.sleep(1/1000)  

        while reverser < reverserSim:
            pyautogui.press('num2') 
            reverserSim = reverserSim - 1
            time.sleep(1/1000)  
      
    if tuerfreigabeLinks != tuerfreigabeLinksSim:
        if tuerfreigabeLinks == 1:
            pyautogui.press("a") 
            conn.write(b"Gruenschleife_Links_A=0;\n")
        tuerfreigabeLinksSim = tuerfreigabeLinks
    
    if tuerfreigabeRechts != tuerfreigabeRechtsSim:
        if tuerfreigabeRechts == 1:
            pyautogui.press("d") 
            conn.write(b"Gruenschleife_Rechts_A=0;\n")
        tuerfreigabeRechtsSim = tuerfreigabeRechts
    
    if tuerenSchliessen != tuerenSchliessenSim:
        if tuerenSchliessen == 1:
            pyautogui.press("s")    
            timer_tuerfreigabe = time.time()
        tuerenSchliessenSim = tuerenSchliessen 

    if timer_tuerfreigabe != -1 and time.time()-timer_tuerfreigabe > 5:
        timer_tuerfreigabe = -1
        conn.write(b"Gruenschleife_Links_A=1;\n")
        conn.write(b"Gruenschleife_Rechts_A=1;\n")
      
    if hupe == 1:
       pyautogui.press("o") 
       
    if hupe != hupeSim:
        if hupe == 1:
            pyautogui.keyDown("o") 
        else:
            pyautogui.keyUp("o") 
        hupeSim = hupe

    if federspEin != federspEinSim:
        if federspEin == 1:
            pyautogui.keyDown("5") 
        else:
            pyautogui.keyUp("5") 
        federspEinSim = federspEin

    if federspLoesen != federspLoesenSim:
        if federspLoesen == 1:
            pyautogui.keyDown("f1") 
        else:
            pyautogui.keyUp("f1") 
        federspLoesenSim = federspLoesen
        
    if innenlautspr != innenlautsprSim:
        if innenlautspr == 1:
            pyautogui.keyDown("y")
        else:
            pyautogui.keyUp("y")
        innenlautsprSim = innenlautspr
        
    if aussenlautspr != aussenlautsprSim:
        if aussenlautspr == 1:
            pyautogui.keyDown("x") 
        else:
            pyautogui.keyUp("x")
        aussenlautsprSim = aussenlautspr
    
    if schienenbremse != schienenbremseSim:
        if brakeleverSim == 6:
            if schienenbremse == 1:
                pyautogui.keyDown("space") 
            else:
                pyautogui.keyUp("space")
            schienenbremseSim = schienenbremse
         
        if schienenbremseSim == 1:
            pyautogui.keyUp("space")
            schienenbremseSim = 0
    
    if umformerAus != umformerAusSim:
        if umformerAus == 1:
            pyautogui.keyDown("left") 
        else:
            pyautogui.keyUp("left")
        umformerAusSim = umformerAus
    
    if umformerEin != umformerEinSim:
        if umformerEin == 1:
            pyautogui.keyDown("right") 
        else:
            pyautogui.keyUp("right")
        umformerEinSim = umformerEin
    
    if automatEin != automatEinSim:
        if automatEin == 1:
            pyautogui.keyDown("up") 
        else:
            pyautogui.keyUp("up")
        automatEinSim = automatEin 
    
    if automatAus != automatAusSim:
        if automatAus == 1:
            pyautogui.keyDown("down") 
        else:
            pyautogui.keyUp("down")
        automatAusSim = automatAus
     
    if stromabnehmerAb != stromabnehmerAbSim:
        if stromabnehmerAb == 1:
            pyautogui.keyDown("pageup") 
        else:
            pyautogui.keyUp("pageup")
        stromabnehmerAbSim = stromabnehmerAb
    
    if stromabnehmerAn != stromabnehmerAnSim:
        if stromabnehmerAn == 1:
            pyautogui.keyDown("pagedown") 
        else:
            pyautogui.keyUp("pagedown")
        stromabnehmerAnSim = stromabnehmerAn

        
def newData(id, value):
    global runbutton
    global reverser
    global brakelever
    global tuerfreigabeLinks
    global tuerfreigabeRechts
    global tuerenSchliessen
    global hupe 
    global federspEin
    global federspLoesen
    global innenlautspr 
    global aussenlautspr
    global automatEin
    global automatAus
    global umformerEin
    global umformerAus
    global stromabnehmerAn
    global stromabnehmerAb
    global schienenbremse
    
    print("New Data: " + id + ", " + value)
    if id == "HoldToRun":
        runbutton = int(value)
    if id == "BrakeLever":
        brakelever = int(value)
    elif id == "Reverser":
        reverser = int(value)
        if reverser > 3:
            reverser = 5
    elif id == "TuerfreigabeLinks":
        tuerfreigabeLinks = int(value)
    elif id == "TuerfreigabeRechts":
        tuerfreigabeRechts = int(value)
    elif id == "TuerenSchliessen":
        tuerenSchliessen = int(value)
    elif id == "ClientRequest":
        conn.write(b"MasterActive=1;\n")
    elif id == "Hupe":
        hupe = int(value)
    elif id == "FederspeicherbremseEin":
        federspEin = int(value)
    elif id == "FederspeicherbremseLoesen":
        federspLoesen = int(value)
    elif id == "Aussenlautsprecher":
        aussenlautspr = int(value)     
    elif id == "Innenlautsprecher":
        innenlautspr = int(value)
    elif id == "RailBrake":
        schienenbremse = int(value)
    elif id == "UmformerEin":
        umformerEin = int(value)
    elif id == "UmformerAus":
        umformerAus = int(value)
    elif id == "AutomatEin":
        automatEin = int(value)
    elif id == "AutomatAus":
        automatAus = int(value)
    elif id == "PantographAn":
        stromabnehmerAn = int(value)
    elif id == "PantographAb":
        stromabnehmerAb = int(value)
    
if __name__ == "__main__":
    run()