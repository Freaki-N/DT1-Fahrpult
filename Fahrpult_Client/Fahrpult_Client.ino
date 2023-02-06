//Variablen
String veh_number;
String veh_name;
String master;

boolean federspeicherbremseAngelegt = true;
boolean timer_federspeicherbremse_active;
boolean cockpitActiveBefore;
boolean connection = false;
boolean requested_answer = false;

int time_last_message;
int timer_federspeicherbremse;
int notrufAusschaltenBefore;
int notrufBeantwortenBefore;
int timer_blink;
int value_blink;

float v_ground;
float v_ground_kmh;
float EnvirBrightness;
float batteriespannung;
float metersNotbremse;

//Stellung Bremshebel u. Geschwindigkeitsvorwahlhebel
int brakelever_state = -1;
int brakelever_analog = 4095;
int reverser = -2;

int brakelever_analog_last_send = brakelever_analog;

//Variablen fuer die Weichensteuerung
boolean timer_weichensteuerung_active;
boolean resetWeiche;
boolean sentWeichensteuerung;

int timer_weichensteuerung;

//PIN-Belegungen
const int PIN_OUTPUT_DS = 27;
const int PIN_OUTPUT_STCP = 12;
const int PIN_OUTPUT_SHCP = 14;

const int PIN_INPUT_PL = 32;
const int PIN_INPUT_CP = 33;
const int PIN_INPUT_CE = 26;
const int PIN_INPUT_Q7 = 25;

const int PIN_TACHO = 13;
const int PIN_BREMSHEBEL_POTI = 34;

//Konstanten
const int TIME_FEDERSPEICHERBREMSE = 2500; //Zeit zum Anlegen u. Loesen d. Federspbr.
const int TIME_WEICHENSTEUERUNG = 1500;
const int TACHO_FACTOR = 3910/80;
const int METERS_NOTBREMSE = 25; //Aktivierung der Notbremsueberbrueckung

//Leuchtmelder
int LM_Gruenschleife_Links;
int LM_Tueren_frei_Links; //Unbenutzt
int LM_Federspeicher_Ein;
int LM_Federspeicher_loesen;
int LM_Tueren_frei_Rechts; //Unbenutzt
int LM_Gruenschleife_Rechts;

int LM_Gleitschutz;
int LM_Heizungsluefter;
int LM_Umformer;
int LM_Fahr_Bremssteuerung;
int LM_Heizscheibe;
int LM_Stellungskontrolle;
int LM_Einschaltverbot;

int LM_Notbremse_ausgeloest; //Unbenutzt
int LM_Notbremse_ueberbrueckt; 
int LM_Notruf; //Unbenutzt

int LM_Streckensignal; //Unbenutzt
int LM_Zwangsbremse; //Unbenutzt

int OUT_Voltmeter;
int OUT_Power_Suply;
int OUT_Beleuchtung_Hintergrund;
int OUT_Mikrofon;

int LM_Betriebsbereit; //Unbenutzt
int LM_Tacho_Beleuchtung;

int LM_PZB_85; //Unbenutzt
int LM_PZB_70; //Unbenutzt
int LM_PZB_55; //Unbenutzt
int LM_PZB_Bef40; //Unbenutzt
int LM_PZB_500Hz; //Unbenutzt
int LM_PZB_1000Hz; //Unbenutzt

int PZB_85; //Unbenutzt
int PZB_70; //Unbenutzt
int PZB_55; //Unbenutzt
int PZB_Bef40; //Unbenutzt
int PZB_500Hz; //Unbenutzt
int PZB_1000Hz; //Unbenutzt

boolean cockpit_a_active = true;
boolean cockpit_b_active = false;

//Klasse InputNode zum Speichern von Eingabedaten 
class InputNode{
  private:
    String id; //ID der Eingabe
    int value; //Aktueller Wert der Eingabe
    int valueBefore; //Vorheriger Wert der Eingabe
    boolean sendValue; //Wert direkt ueber Serial versenden 
    boolean isInverted; //Wert invertiert

  public:
    //Konstruktoren
    InputNode(){
      id = "null";
      value = 0;
      valueBefore = 0;
      sendValue = false;
      isInverted = false;
    }

    InputNode(String _id, boolean _sendValue, boolean _inv){
      id = _id;
      value = 0;
      valueBefore = 0;
      sendValue = _sendValue;
      isInverted = _inv;
    }

    //Getter und Setter
    int getValue(){
      if(isInverted){
        if(value == 0){
          return 1; 
        }else{
          return 0;
        }
      }else{
        return value;
      }
    }

    void setValue(int _value){
      valueBefore = value;
      value = _value;
    }

    boolean getSendValue(){
      return sendValue;
    }

    boolean stateChanged(){
      return value != valueBefore;
    }

    String getId(){
      return id;
    }
};

//Array zum Speichern der Ausgabebits
const int outputLength = 24;
int outputBytes[outputLength];

//Array zum Speichern der Eingabebits
const int inputLength = 40;
InputNode inputValues[inputLength];

int curIndex = 0; //speichert den naechsten freien Index in 'inputValues'
void addToInput(InputNode n){
  inputValues[curIndex] = n; //neuen InputNode zu 'inputValues' hinzufuegen
  curIndex = curIndex+1; //naechsten freien um eins erhoehen 
}

void setup() {
  //pinModes setzen
  pinMode(PIN_OUTPUT_DS, OUTPUT);
  pinMode(PIN_OUTPUT_STCP, OUTPUT);
  pinMode(PIN_OUTPUT_SHCP, OUTPUT);

  pinMode(PIN_INPUT_PL, OUTPUT);
  pinMode(PIN_INPUT_CP, OUTPUT);
  pinMode(PIN_INPUT_CE, OUTPUT);
  pinMode(PIN_INPUT_Q7, INPUT_PULLDOWN);

  //Serielle Schnittstelle initialisieren
  Serial.begin(9600);

  //PWM-Pin vorbereiten
  ledcAttachPin(PIN_TACHO, 1); //PIN_TACHO zum Kanal 1 hinzufuegen
  ledcSetup(1, 12000 ,12); //PWM-Frequenz auf 12 kHz mit 12-Bit Aufloesung setzen

  //InputNode-Objekte zum Array inputValues hinzufuegen
  addToInput(InputNode("RunButton", true, false));
  addToInput(InputNode("Schnellbremse", false, false));
  addToInput(InputNode("HoldToRun", true, true));
  addToInput(InputNode("Reverser_P_Sh", false, false));
  addToInput(InputNode("Reverser_S-P_Sh", false, false));
  addToInput(InputNode("Reverser_R-P_Sh", false, false));
  addToInput(InputNode("Reverser_K-P_Sh", false, false));
  addToInput(InputNode("BL_E1-E4L", false, false));
  addToInput(InputNode("BL_E2-E4L", false, false));
  addToInput(InputNode("BL_E3-E4L", false, false));
  addToInput(InputNode("BL_E4-E4L", false, false));
  addToInput(InputNode("BL_B0", false, false));
  addToInput(InputNode("RailBrake", true, false));
  addToInput(InputNode("Reverser_Rueckwaerts", false, false));
  addToInput(InputNode("BL_E4L", false, false));
  addToInput(InputNode("Schluesselschalter", false, false));
  addToInput(InputNode("AutomatAus", true, false));
  addToInput(InputNode("FederspeicherbremseEin", true, false));
  addToInput(InputNode("FederspeicherbremseLoesen", true, false));
  addToInput(InputNode("PantographAn", true, false));
  addToInput(InputNode("PantographAb", true, false));
  addToInput(InputNode("TuerfreigabeLinks", true, false));
  addToInput(InputNode("AutomatEin", true, false));
  addToInput(InputNode("TuerfreigabeRechts", true, false));
  addToInput(InputNode("TuerenSchliessen", true, false));
  addToInput(InputNode("Hupe", true, false));
  addToInput(InputNode("Heizscheibe", true, false));
  addToInput(InputNode("BeleuchtungKabine", true, false));
  addToInput(InputNode("UmformerAus", true, false));
  addToInput(InputNode("ZugbeleuchtungAus", true, false));
  addToInput(InputNode("UmformerEin", true, false));
  addToInput(InputNode("ZugbeleuchtungEin", true, false));
  addToInput(InputNode("BeleuchtungPult", true, false));
  addToInput(InputNode("Funkdurchsage", true, false));
  addToInput(InputNode("Aussenlautsprecher", true, false));
  addToInput(InputNode("Innenlautsprecher", true, false));
  addToInput(InputNode("NotrufAusschalten", true, false));
  addToInput(InputNode("NotrufBeantworten", true, false));
  addToInput(InputNode("", false, false));
  addToInput(InputNode("", false, false));
  
  OUT_Power_Suply = 1;
  metersNotbremse = METERS_NOTBREMSE;
}

void readShiftRegisterInput(){
  digitalWrite(PIN_INPUT_CE, HIGH); //Verschieben der Bits verbieten
  digitalWrite(PIN_INPUT_PL, LOW); //Laden der Bits in das Schieberegister
  delayMicroseconds(5);
  digitalWrite(PIN_INPUT_PL, HIGH); //Zuruecksetzten des Pins PL fuer den naechsten Durchlauf
  digitalWrite(PIN_INPUT_CE, LOW); //Verschieben der Bits durch Pin CP erlauben

  //for-Schleife zum Verschieben und speichern aller Bits
  String bits = "";
  for(int i = inputLength-1; i >= 0; i--){
    int value = digitalRead(PIN_INPUT_Q7); //Lesen des Zustands an Pin Q7
    inputValues[i].setValue(value); //Setzen des Wertes im Eingabe-Array
    bits = bits + String(value);

    digitalWrite(PIN_INPUT_CP, HIGH); //Verschieben der Bits um eine Stelle
    delayMicroseconds(5);
    digitalWrite(PIN_INPUT_CP, LOW); //Zuruecksetzten des Pins CP fuer den naechsten Durchlauf
  }
  //Serial.println("Bits: " + bits);
}

int getInputValueById(String id){
  //durchgehen aller in 'inputValues' gespeicherten Objekte
  for(int i = 0; i < inputLength; i++) {
    //Ueberpruefen, ob die ID des aktuellen Objekts mit der gesuchten ID uebereinstimmt
    if(inputValues[i].getId() == id){
      return inputValues[i].getValue(); //Zurueckgeben des Wertes des Objekts
    }
  }
  return -1; //-1 zurueckgeben, falls keine uebereinstimmende ID gefunden wurde
}

int invertValue(int v){
  //Methode invertiert int Werte von 0 zu 1 und von 1 zu 0
  if(v==0){
    return 1;
  }else{
    return 0;
  }
}

void setData(String id, String value) {
  //Methode zum Verarbeiten der Datensaetze, die von Serial empfangen werden.
  time_last_message = millis(); //Speichern der Zeit des letzten Datensatzes
  requested_answer = false;

  //Setzen der jeweiligen Variablen, die zum Datensatz gehoeren
  if (id == "MasterActive") {
    if(value == "1"){
      connection = true;
    }else{
      connection = false;
    }
  }
  if (id == "veh_name") {
    veh_name = value;
  }
  if (id == "master") {
    master = value;
  }
  if (id == "v_ground") {
    v_ground = value.toFloat();
    if(v_ground < 0){
      v_ground = v_ground * -1;
    }
    v_ground_kmh = v_ground * 3.6;
  }
  if (id == "veh_number") {
    veh_number = value.toFloat();
  }
  if (id == "EnvirBrightness") {
    EnvirBrightness = value.toFloat();
  }
  if (id == "OnUnconnectingVehicle" && value == "1") {
    connection = false;
  }
  if (id == "Gruenschleife_Links_A"  && cockpit_a_active) {
    LM_Gruenschleife_Links = (int)value.toFloat();
  }
  if (id == "Gruenschleife_Links_B"  && cockpit_b_active) {
    LM_Gruenschleife_Links= (int)value.toFloat();
  }
  if (id == "Gruenschleife_Rechts_A"  && cockpit_a_active) {
    LM_Gruenschleife_Rechts = (int)value.toFloat();
  }
  if (id == "Gruenschleife_Rechts_B"  && cockpit_b_active) {
    LM_Gruenschleife_Rechts = (int)value.toFloat();
  }
  if (id == "gb_Fahrstromautomat_aus_A" && cockpit_a_active){
    LM_Umformer = (int)value.toFloat();
  }
  if (id == "gb_Fahrstromautomat_aus_B" && cockpit_b_active){
    LM_Umformer = (int)value.toFloat();
  }
  if (id == "LM_A_Automat" && cockpit_a_active){
    LM_Umformer = (int)value.toFloat();
  }
  if (id == "LM_B_Automat" && cockpit_b_active){
    LM_Umformer = (int)value.toFloat();
  }
  if ((id == "gb_Sicherheitsschleife_A" || id == "LM_A_Stoerzapfen") && cockpit_a_active){
    LM_Fahr_Bremssteuerung = (int)value.toFloat();
  }
  if ((id == "gb_Sicherheitsschleife_B" || id == "LM_B_Stoerzapfen") && cockpit_b_active){
    LM_Fahr_Bremssteuerung = (int)value.toFloat();
  }
  if ((id == "gb_Haltewunsch_A" || id == "LM_A_haltewunsch") && cockpit_a_active){
    LM_Heizungsluefter = (int)value.toFloat();
  }
  if ((id == "gb_Haltewunsch_B" || id == "LM_B_haltewunsch") && cockpit_b_active){
    LM_Heizungsluefter = (int)value.toFloat();
  }
  if (id == "gb_Tachobeleuchtung_A" && cockpit_a_active){
    LM_Tacho_Beleuchtung = (int)value.toFloat();
  }
  if (id == "gb_Tachobeleuchtung_B" && cockpit_b_active){
    LM_Tacho_Beleuchtung = (int)value.toFloat();
  }
  if (id == "gb_Schlupf"){
    LM_Gleitschutz = (int)value.toFloat();
  }
  if (id == "Batteriespannung"){
    batteriespannung = value.toFloat();
  }
  if (id == "FP_POWER"){
    OUT_Power_Suply = (int)value.toFloat();
  }
  if (id == "PZB_85"){
    PZB_85 = (int)value.toFloat();
  }
  if (id == "PZB_70"){
    PZB_70 = (int)value.toFloat();
  }
  if (id == "PZB_55"){
    PZB_55 = (int)value.toFloat();
  }
  if (id == "PZB_Bef40"){
    PZB_Bef40 = (int)value.toFloat();
  }
  if (id == "PZB_500Hz"){
    PZB_500Hz = (int)value.toFloat();
  }
  if (id == "PZB_1000Hz"){
    PZB_1000Hz = (int)value.toFloat();
  }
  if (id == "cp_Umschalthebel_A"){
    //Falls der Richtungswender in Cockpit A in einer anderen Stellung als "0" ist: Cockpit A aktivieren
    if(value != "0"){
      cockpit_a_active = true;
    }else{
      cockpit_a_active = false;
    }
  }
  if (id == "cp_Umschalthebel_B"){
    //Falls der Richtungswender in Cockpit B in einer anderen Stellung als "0" ist: Cockpit B aktivieren
    if(value != "0"){
      cockpit_b_active = true;
    }else{
      cockpit_b_active = false;
    }
  }

  if (id == "AV_A_Sw_Betriebsartenwahl"){
    //Falls der Richtungswender in Cockpit A in einer anderen Stellung als "0" ist: Cockpit A aktivieren
    if(value != "0"){
      cockpit_a_active = true;
      LM_Tacho_Beleuchtung = 1;
    }else{
      cockpit_a_active = false;
      LM_Tacho_Beleuchtung = 0;
    }
  }
  if (id == "AV_B_Sw_Betriebsartenwahl"){
    //Falls der Richtungswender in Cockpit B in einer anderen Stellung als "0" ist: Cockpit B aktivieren
    if(value != "0"){
      cockpit_b_active = true;
      LM_Tacho_Beleuchtung = 1;
    }else{
      cockpit_b_active = false;
      LM_Tacho_Beleuchtung = 0;
    }
  }
}

boolean FloatToBool(float v){
  //Float nach Bool konvertieren
  return v >= 0.5;
}

void receiveData() {
  //Methode liest die aus der Seriellen Schnittstelle kommenden Daten
  String receivedString;
  
  while (Serial.available() > 0) { //Wiederhole Vorgang, solange Serielle Daten verfuegbar sind
    receivedString = Serial.readStringUntil('\n'); //Empfangenen String bis zu einem Zeilenumbruch lesen
    String newString = "";
    for (int i = 0; i < receivedString.length(); i++) {//Alle Zeichen des Strings durchgehen
      if (receivedString.charAt(i) != ';') {
        newString = newString + receivedString.charAt(i); //Neuen Datensatz um ein Char erweitern
      } else {
        //Falls Semicolon gefunden neuen Datensatz parsen
        String id;
        String value;
        for (int iN = 0; iN < newString.length(); iN++) {
          //Position des '=' suchen
          if (newString.charAt(iN) == '=') {
            id = newString.substring(0, iN); //Vorderen Teil als ID speichern
            value = newString.substring(iN + 1); //Vorderen Teil als Wert speichern
            setData(id, value); //ID und Wert der Methode setData uebergeben
          }
        }
        newString = "";
      }
    }
  }
}

int getBrakeLeverState() {
  /* Methode ermittelt die Stellung des Bremshebels  
   *  
   * Rueckgabewerte:   
   * 0 - 0    
   * 1 - Fahren   
   * 2 - E1   
   * 3 - E2    
   * 4 - E3   
   * 5 - E4    
   * 6 - E4L    
   * 7 - VB    
   * 8 - Schnellbremse */

  if (getInputValueById("BL_B0")) {
    return 0;
  } else if (getInputValueById("Schnellbremse")) {
    return 8;
  }

  if (getInputValueById("BL_E4L")) {
    return 6;
  } else if (getInputValueById("BL_E4-E4L")) {
    return 5;
  } else if (getInputValueById("BL_E3-E4L")) {
    return 4;
  } else if (getInputValueById("BL_E2-E4L")) {
    return 3;
  } else if (getInputValueById("BL_E1-E4L")) {
    return 2;
  }

  if(brakelever_state >= 5 || brakelever_analog < 2000){
    return 7;
  } else {
    return 1;
  }
}

int getReverserState() {
  /* Methode ermittelt die Stellung des Bremshebels  
   * 
   * Rueckgabewerte:
   * -1 - R (Rueckwaerts)
   * 0 - 0
   * 1 - K (Vorwaerts)
   * 2 - R (Vorwaerts)
   * 3 - S (Vorwaerts)
   * 4 - P-Sh*/

  if (getInputValueById("Reverser_Rueckwaerts")) {
    return -1;
  }

  if (getInputValueById("Reverser_P_Sh")) {
    return 4;
  } else if (getInputValueById("Reverser_S-P_Sh")) {
    return 3;
  } else if (getInputValueById("Reverser_R-P_Sh")) {
    return 2;
  } else if (getInputValueById("Reverser_K-P_Sh")) {
    return 1;
  }

  return 0;
}

boolean checkAndSend() {
  //Durchlauf aller in 'inputValues' gespeicherten Objekte
  for(int i = 0; i < inputLength; i++) {
    InputNode node = inputValues[i];
    if(node.stateChanged() && node.getSendValue()){//Falls der Zustand der Eingabe sich geaendert hat und die Eingae versendet werden soll
      if(node.getId() != "RunButton" || !federspeicherbremseAngelegt){//Falls die ID nicht der Fahrtaster ist oder die Federspeicherbremse nicht angelegt ist
        sendValue(node.getId(), String(node.getValue())); //Datensatz ueber Serial versenden
      }
    }
  }
}

void shiftOutput(){
  //Initialisieren des Output-Array
  int outputBytesArr[] = {OUT_Power_Suply, OUT_Voltmeter, LM_Fahr_Bremssteuerung, LM_Heizungsluefter, LM_Federspeicher_Ein, LM_Federspeicher_loesen, LM_Gleitschutz, LM_Umformer, 
                          LM_Stellungskontrolle, LM_Gruenschleife_Links, LM_Gruenschleife_Rechts, LM_Heizscheibe, LM_Einschaltverbot, LM_Notbremse_ueberbrueckt, OUT_Mikrofon, OUT_Beleuchtung_Hintergrund,
                          LM_PZB_85, LM_PZB_70, LM_PZB_55, LM_PZB_Bef40, LM_PZB_500Hz, LM_PZB_1000Hz, 0, LM_Tacho_Beleuchtung};

  //Alle Bits durchlaufen
  for(int i = outputLength-1; i >= 0; i--){
    digitalWrite(PIN_OUTPUT_SHCP, LOW);
    digitalWrite(PIN_OUTPUT_DS, invertValue(outputBytesArr[i])); //Bit ueber den DS eingeben
    digitalWrite(PIN_OUTPUT_SHCP, HIGH);//Bits im Schieberegister um eine Stelle verschieben
  }

  //Bits in das Ausgaberegister kopieren
  digitalWrite(PIN_OUTPUT_STCP, HIGH);
  delay(20);
  digitalWrite(PIN_OUTPUT_STCP, LOW);
}

//Methode liest die Eingaben und sendet sie bei aenderungen an das Plugin
void readInput(){
  readShiftRegisterInput();
  checkAndSend();

  if (brakelever_state != getBrakeLeverState()) {
    brakelever_state = getBrakeLeverState();
    sendValue("BrakeLever", String(brakelever_state));
  }

  if(reverser != getReverserState()){
    reverser = getReverserState();
    sendValue("Reverser", String(reverser));
  }  
}

int timegap = 0;

//boolean in int konvertieren
int boolToInt(boolean _arg){ 
  if(_arg){
    return 1;
  }else{
    return 0;
  }
}

//Methode sendet einen Datensatz an das Plugin
void sendValue(String id, String value){
  if(master == "LOTUS_Serial_Plugin"){
    Serial.print(id + "=" + value + ";");
  }else{
    Serial.println(id + "=" + value + ";");
  }
}

void weichensteuerung(){
   //Zuruecksetzen der Weichensteuerung
   if(resetWeiche){
    resetWeiche = false;  
    sendValue("WeicheVorneStellen", "0");
    sendValue("WeicheHintenStellen", "0");
  }

  //Falls NotrufAusschalten oder NottrufBeantworten gedrueckt
  if(getInputValueById("NotrufAusschalten") || getInputValueById("NotrufBeantworten")){
    //Timer der Weichensteuerung aktivieren
    if(!timer_weichensteuerung_active){
      timer_weichensteuerung = millis();
      timer_weichensteuerung_active = true;
      sentWeichensteuerung = false;
    }  

    
    if(millis()-timer_weichensteuerung >= TIME_WEICHENSTEUERUNG){
      //Wenn Timer abgelaufen und Weichensteuerung noch nicht versendet: Weichenstellbefehl fuer IBIS versenden
      if(!sentWeichensteuerung){
        if(getInputValueById("NotrufAusschalten") && getInputValueById("NotrufBeantworten")){
          sendValue("WeichensteuerungGerade", "1");
        }else if(getInputValueById("NotrufAusschalten")){
          sendValue("WeichensteuerungLinks", "1");
        }else if(getInputValueById("NotrufBeantworten")){
          sendValue("WeichensteuerungRechts", "1");
        } 
        sentWeichensteuerung = true;
      }
    }
  }else if(notrufAusschaltenBefore || notrufBeantwortenBefore){
    //Falls NotrufAusschalten oder NottrufBeantworten gedrueckt waren

    timer_weichensteuerung_active = false;//Timer deaktivieren
   
    if(millis()-timer_weichensteuerung < TIME_WEICHENSTEUERUNG){
      //Weiche je nach gedruecktem Knopf stellen
      if(notrufAusschaltenBefore && notrufBeantwortenBefore){
      }else if(notrufAusschaltenBefore){
        sendValue("WeicheHintenStellen", "1");
      }else if(notrufBeantwortenBefore){
        sendValue("WeicheVorneStellen", "1");
      }
      resetWeiche = true; //Weichensteuerung im naechsten Durchlauf zuruecksetzen
    }else{
      //Weichensteuerung fuer IBIS zuruecksetzen
      sendValue("WeichensteuerungRechts", "0");
      sendValue("WeichensteuerungGerade", "0");
      sendValue("WeichensteuerungLinks", "0");
    }
    sentWeichensteuerung = false;
  }

  //Vorherige Werte setzen
  notrufAusschaltenBefore = getInputValueById("NotrufAusschalten");
  notrufBeantwortenBefore = getInputValueById("NotrufBeantworten");
}

int getLMStatus(int state){
  if(state == 2){
    return value_blink;  
  }else if(state == 3){
    return invertValue(value_blink);
  }else{
    return state;
  }
}

void loop() {
  int time_start_loop = millis();//Startzeit des Loops speichern
  
  int analogValue = analogRead(PIN_BREMSHEBEL_POTI); 
  if((analogValue > brakelever_analog_last_send+20 || analogValue < brakelever_analog_last_send-20 || analogValue == 0 || analogValue == 4095) && analogValue != brakelever_analog_last_send){
    sendValue("ba", String(analogValue));
    brakelever_analog_last_send = analogValue;
  }
  brakelever_analog = analogValue;
 
  
  //Methodenaufrufe fuer Schieberegister und Serielle Schnittstelle
  receiveData();
  readInput();
  shiftOutput();


  if(millis()-time_last_message >= 5000 && !requested_answer){
    //Falls der letzte Datensatz vom Plugin vor ueber 5000ms kam, abfrage, ob Plugin noch aktiv
    sendValue("ClientRequest", "1");
    requested_answer = true;
  }else if (millis()-time_last_message >= 7000 && requested_answer) {
    //Falls nach 7000ms noch keine Antwort kommt Verbindungsvariable auf false
    connection = false;
  }

  //Wert fuer Tacho-PWM aus Geschwindigkeit bestimmen und Pin beschreiben
  int value_tacho = v_ground_kmh*TACHO_FACTOR;
  ledcWrite(1, value_tacho);

  //Meter bis zur Aktivierung der Notbremsueberbrueckung verringern
  metersNotbremse = metersNotbremse - ((v_ground_kmh/3.6) * (timegap/1000.0));

  
  if(timer_federspeicherbremse_active){
    //Timer der Federspbr. verringern, falls Timer aktiv
    timer_federspeicherbremse = timer_federspeicherbremse - timegap;

    if(timer_federspeicherbremse <= 0){
      //Falls der Timer der Federspeicherbremse abgelaufen ist: Zustand der Federspbr. invertieren
      federspeicherbremseAngelegt = !federspeicherbremseAngelegt;
      timer_federspeicherbremse_active = false;
    }
  }

  if(getInputValueById("FederspeicherbremseEin")){  
    //Falls Federspeicherbremse ein gedrueckt wird
    if(!timer_federspeicherbremse_active && !federspeicherbremseAngelegt){
      //Timer zum Aktivieren der Federspbr. starten, falls Federspbr. noch nicht aktiv
      timer_federspeicherbremse = TIME_FEDERSPEICHERBREMSE;
      timer_federspeicherbremse_active = true;
    }
  }

  if(getInputValueById("FederspeicherbremseLoesen")){
    //Falls Federspeicherbremse loesen gedrueckt wird
    if(!timer_federspeicherbremse_active && federspeicherbremseAngelegt){
      //Timer zum loesen der Federspbr. starten, falls Federspbr. noch nicht geloest
      timer_federspeicherbremse = TIME_FEDERSPEICHERBREMSE;
      timer_federspeicherbremse_active = true;
    }
  }

  LM_Heizscheibe = getInputValueById("Heizscheibe");

  //Falls Gruenschleife nicht aktiv, wegzaehler fuer Notbremsueberbrueckung zuruecksetzen
  if(LM_Gruenschleife_Rechts == 0 || LM_Gruenschleife_Links == 0){
    metersNotbremse = METERS_NOTBREMSE;
  }

  //Fallsfuer Notbremsueberbrueckung nicht abgelaufen LM_Notbremse_ueberbrueckt auf 0  
  if(metersNotbremse > 0){
    LM_Notbremse_ueberbrueckt = 0;
  }else{
    LM_Notbremse_ueberbrueckt = 1;
  }

  if(millis()-timer_blink > 500){
    timer_blink = millis();
    if(value_blink == 1){
      value_blink = 0;
    }else{
      value_blink = 1;
    }
  }

  LM_PZB_85 = getLMStatus(PZB_85);
   LM_PZB_70 = getLMStatus(PZB_70);
   LM_PZB_55 = getLMStatus(PZB_55);
   LM_PZB_Bef40 = getLMStatus(PZB_Bef40);
   LM_PZB_500Hz = getLMStatus(PZB_500Hz);
   LM_PZB_1000Hz = getLMStatus(PZB_1000Hz);
  
  
  if(connection && (cockpit_a_active || cockpit_b_active)){
    weichensteuerung();
    
    //Werte der LMs setzen, falls Verbindung und Fahrerstand aktiviert
    LM_Federspeicher_loesen = !boolToInt(federspeicherbremseAngelegt);
    LM_Federspeicher_Ein = boolToInt(federspeicherbremseAngelegt);
    LM_Einschaltverbot = 0;
    LM_Tacho_Beleuchtung = getInputValueById("BeleuchtungPult");
    OUT_Voltmeter = 1;

    if(master == "TrainZ"){
      if(getInputValueById("ZugbeleuchtungEin")){
        LM_Tacho_Beleuchtung = 1;
      }else if(getInputValueById("ZugbeleuchtungAus")){
        LM_Tacho_Beleuchtung = 0;
      }
    }else{
      
    }
        
    if(!federspeicherbremseAngelegt){
      if(master == "TrainZ"){
        LM_Stellungskontrolle = getInputValueById("HoldToRun");
      }else{
        LM_Stellungskontrolle = getInputValueById("RunButton");
      }   
    }else{
      LM_Stellungskontrolle = 0;
    } 
    
    if(!cockpitActiveBefore){
      LM_Umformer = 1;
      cockpitActiveBefore = true;
    }
  }else{
    //LMs ausschalten, falls keine Verbindung vorliegt oder kein Cockpit aktiv ist
    LM_Stellungskontrolle = 0;
    LM_Heizscheibe = 0;
    LM_Notbremse_ueberbrueckt = 0;
    LM_Gruenschleife_Links = 0;
    LM_Gruenschleife_Rechts = 0;
    LM_Fahr_Bremssteuerung = 0;
    LM_Federspeicher_Ein = 0;
    LM_Federspeicher_loesen = 0;
    LM_Umformer = 0;
    LM_Gleitschutz = 0;
    LM_Heizungsluefter = 0; 
    LM_Tacho_Beleuchtung = 0;
    OUT_Voltmeter = 0;
    
    if(connection){
      LM_Einschaltverbot = 0;
      cockpitActiveBefore = false;
    }else{
      LM_Einschaltverbot = 1; 
    }
    federspeicherbremseAngelegt = true;
    OUT_Voltmeter = 0;
  }
  OUT_Beleuchtung_Hintergrund = getInputValueById("BeleuchtungKabine") || getInputValueById("BeleuchtungPult");
  OUT_Mikrofon = getInputValueById("Innenlautsprecher") || getInputValueById("Aussenlautsprecher") || getInputValueById("Funkdurchsage");

  //Loop pausieren, falls der letzte Durchlauf weniger als 100ms zurueckliegt
  while(true){
    if(millis()-time_start_loop >= 100){
      break;
    }
  }
  
  //Verstrichene Zeit zwischen den Loops setzen
  timegap = millis()-time_start_loop;
}
