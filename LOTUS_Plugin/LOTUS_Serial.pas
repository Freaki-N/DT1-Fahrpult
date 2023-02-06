library LOTUS_Serial;

{$mode objfpc}{$H+}

uses
  Classes,
  SysUtils,
  Dialogs,
  serial,
  Crt;

//Klasse TValueNode zum Speichern der Variablen von LOTUS
type
  TValueNode = class
  private
    value: single;
    name: string;
    _stateChanged: boolean;
    _sendToClient: boolean;

  public
    constructor Create(n: string; s: boolean);

    procedure setValue(v: single);
    function getValue(): single;
    function getId(): string;
    function sendToClient(): boolean;
    function stateChanged(): boolean;
  end;

//Methoden und Konstruktor der Klasse TValueNode
constructor TValueNode.Create(n: string; s: boolean);
begin
  name := n;
  value := 0.0;
  _stateChanged := false;
  _sendToClient := s;
end;

procedure TValueNode.setValue(v: single);
begin
  _stateChanged := value <> v;
  value := v;
end;

function TValueNode.getValue(): single;
begin
  result := value;
  _stateChanged := false;
end;

function TValueNode.getId(): string;
begin
  result := name;
end;

function TValueNode.sendToClient(): boolean;
begin
  result := _sendToClient;
end;

function TValueNode.stateChanged(): boolean;
begin
    result := _stateChanged;
    _stateChanged := false;
end;

//Globale Variablen
VAR Datei: Text;
    pfad: String;
    receivedString: String;

    VehicleName: String;

    BrakeLever: integer;
    Reverser: integer;
    HoldToRun: boolean;
    RunButton: boolean;

    schienenbremse: boolean;
    stoprequest: boolean;
    FederspeicherbremseEin: boolean;
    FederspeicherbremseLoesen: boolean;
    PantographAuf: boolean;
    PantographAb: boolean;
    UmformerEin: boolean;
    UmformerAus: boolean;
    AutomatEin: boolean;
    AutomatAus: boolean;
    ZugbeleuchtungEin: boolean;
    ZugbeleuchtungAus: boolean;
    Hupe: boolean;
    TuerenSchliessen: boolean;
    TuerfreigabeRechts: boolean;
    TuerfreigabeLinks: boolean;
    heizscheibe: boolean;
    Aussenlautsprecher: boolean;
    Innenlautsprecher: boolean;
    Funkdurchsage: boolean;
    BeleuchtungPult: boolean;
    BeleuchtungKabine: boolean;
    notrufAusschalten: boolean;
    notrufBeantworten: boolean;
    weicheVorneStellen: boolean;
    weicheHintenStellen: boolean;
    weichensteuerungLinks: boolean;
    weichensteuerungGerade: boolean;
    weichensteuerungRechts: boolean;

    ZugbeleuchtungAutomatik: boolean;
    reverserPlus: boolean;
    ReverserMinus: boolean;

    stateReverser: integer;

    bCockpitActive: boolean;

    throttleBefore: single;
    viewBefore: single;
    vMax_Reverser: single;
    v_Reverser_shut: single;
    throttle: single;


    lastTimeAllDataSent: TDateTime;
    isConnected: boolean;
    init_timestamp: AnsiString;

    serPort: integer;
    conn: LongInt;
    status       : LongInt;

    varsFloat: array of TValueNode;
    taktBlink: boolean;

//Konstanten
const
  MASTER = 'LOTUS_Serial_Plugin';
  VERSION = '1.0.0';

//Prozedur zum Schreiben von Text in die Logfile
procedure WriteLog(text: string);
var
   logTime: String;
begin
  DateTimeToString(logTime, 'hh:nn:ss', Time);
  Append(Datei);
  WriteLn(Datei, logTime + ' - ' + text);
  close(Datei);
end;

//String nach Boolean konvertieren
function valueStrToBool(value: String): boolean;
begin
   if (value = '1') or (value = 'true') then result := true else result := false;
end;

//Prozedur fuegt Objekte der Klasse TValueNode am ende des Arrays varsFloat eine
procedure addToVarsFloat(n: TValueNode);
begin
  SetLength(varsFloat, Length(varsFloat)+1);
  varsFloat[Length(varsFloat)-1] := n;
end;

//Funktion sucht aus dem Array varsFloat das Objekt mit der uebergenenen ID
function getVarFloatObjById(id: String): TValueNode;
var
  i: integer;
begin
  for i := 0 to Length(varsFloat)-1 do
  begin
    if (varsFloat[i].getId() = id) then
    begin
      result := varsFloat[i];
      break;
    end;
  end;
end;

//Funktion gibt den Value des zur ID zugehoerigen Objektes zurueck
function getVarFloatValueById(id: String): single;
begin
  result := getVarFloatObjById(id).getValue();
end;

//Prozedur zum Verbindungsaufbau mit dem Mikrocontroller
procedure connect();
var
   portName: String;
   init_text: String;
   writecount: integer;
   flags: TSerialFlags;
begin
  //Portnamen speichern
  portName := 'COM' + IntToStr(serPort) + ':';
  WriteLog('Port:  ' + portName);

  //Oeffnen der Verbindung zum angegebenen Port und setzen der Paramter
  conn := SerOpen(portName);
  flags := [];
  SerSetParams(conn,9600,8,NoneParity,1,flags);

  //Init-Datensaetze master, version und init_timestamp an den Mikrocontroller senden
  DateTimeToString(init_timestamp, 'yyyy-mm-dd_hh:nn:ss', Now);
  init_text := 'master=' + master + ';version=' + version + ';init_timestamp=' + init_timestamp + ';' +#13+#10;
  writecount := length(init_text);
  status := SerWrite(conn, init_text[1], writecount );

  //Status in der Logfile ausgeben
  WriteLog('Status: '+ IntToStr(status));

  //Setzen der Variable isConnected
  if status > 0 then isConnected := true
  else
  begin
    isConnected := false;
    WriteLog('Keine Verbindung!');
  end;
end;

//Prozedur zum senden von Datensaetzen an den Mikrocontroller
procedure sendData(send_text: String);
var
   writecount: integer;
   data: String;
begin
   //modifzieren und senden des uebergebenen Strings
   data:=send_text +#13+#10;
   writecount := length(data);
   status := SerWrite(conn, data[1], writecount );

   if not status > 0 then
   begin
     WriteLog('Senden nicht moeglich!');
     connect;
   end;
end;

//Prozedur zum Senden von Float-Datensaetzen an den Mikrocontroller
procedure sendFloat(_id: String; _value: single);
begin
  sendData(_id + '=' + StringReplace(FloatToStr(_value), ',', '.', [rfReplaceAll]) + ';');
end;

//Prozedur sendet alle Werte in varsFloat an den Mikrocontroller
procedure sendAllValues();
var
   send_text: string;
   i: integer;
begin
  send_text := '';

  for i := 0 to Length(varsFloat)-1 do
  begin
    send_text := send_text + varsFloat[i].getId() + '=' + FloatToStr(varsFloat[i].getValue()) + ';'
  end;

  sendData(send_text);
end;

//Prozedur setzt die entsprechenden Variablen, die vom Mikrocontroller empfangen wurden
procedure setData(id, value: String);
begin
   try
     case id of
        'RailBrake': schienenbremse := valueStrToBool(value);
        'StopRequest': stoprequest := valueStrToBool(value);
        'BrakeLever': BrakeLever := StrToInt(value);
        'Reverser':
          begin
            Reverser := StrToInt(value);
            //Setzen der Zielgeschwindigkeits in Abhaenigkeit des Geschwindigkeitsvorwahlhebels
            case Reverser of
               -1: begin vMax_Reverser := 10; v_Reverser_shut := 8; throttle := 0.5; end;
               0: begin vMax_Reverser := 0; v_Reverser_shut := 0; throttle := 0; end;
               1: begin vMax_Reverser := 2; v_Reverser_shut := 1.5; throttle := 0.2; end;
               2: begin vMax_Reverser := 15; v_Reverser_shut := 12; throttle := 0.5; end;
               3: begin vMax_Reverser := 25; v_Reverser_shut := 22; throttle := 0.8; end;
               4: begin vMax_Reverser := 82; v_Reverser_shut := 80; throttle := 1; end;
            end;
          end;
        'HoldToRun': HoldToRun := valueStrToBool(value);
        'RunButton': RunButton := valueStrToBool(value);
        'FederspeicherbremseEin': FederspeicherbremseEin := valueStrToBool(value);
        'FederspeicherbremseLoesen': FederspeicherbremseLoesen := valueStrToBool(value);
        'PantographAn': PantographAuf := valueStrToBool(value);
        'PantographAb': PantographAb := valueStrToBool(value);
        'UmformerEin': UmformerEin := valueStrToBool(value);
        'UmformerAus': UmformerAus := valueStrToBool(value);
        'AutomatEin': AutomatEin := valueStrToBool(value);
        'AutomatAus': AutomatAus := valueStrToBool(value);
        'ZugbeleuchtungEin': begin ZugbeleuchtungEin := valueStrToBool(value); ZugbeleuchtungAutomatik := false; end;
        'ZugbeleuchtungAus': begin ZugbeleuchtungAus := valueStrToBool(value); ZugbeleuchtungAutomatik := true; end;
        'Hupe': Hupe := valueStrToBool(value);
        'TuerenSchliessen': TuerenSchliessen:= valueStrToBool(value);
        'TuerfreigabeRechts': begin TuerfreigabeRechts := valueStrToBool(value); end;
        'TuerfreigabeLinks': begin TuerfreigabeLinks := valueStrToBool(value); end;
        'Aussenlautsprecher': Aussenlautsprecher := valueStrToBool(value);
        'Innenlautsprecher': Innenlautsprecher := valueStrToBool(value);
        'Funkdurchsage': Funkdurchsage := valueStrToBool(value);
        'BeleuchtungPult': BeleuchtungPult := valueStrToBool(value);
        'BeleuchtungKabine': BeleuchtungKabine := valueStrToBool(value);
        'Heizscheibe': heizscheibe := valueStrToBool(value);
        'NotrufAusschalten': notrufAusschalten := valueStrToBool(value);
        'NotrufBeantworten': notrufBeantworten := valueStrToBool(value);
        'WeicheVorneStellen': weicheVorneStellen := valueStrToBool(value);
        'WeicheHintenStellen': weicheHintenStellen := valueStrToBool(value);
        'WeichensteuerungLinks': weichensteuerungLinks := valueStrToBool(value);
        'WeichensteuerungGerade': weichensteuerungGerade := valueStrToBool(value);
        'WeichensteuerungRechts': weichensteuerungRechts := valueStrToBool(value);
        'ClientRequest': if value = '1' then sendData('MasterActive=1;');
        'GetAllValuesRequest': if value = '1' then sendAllValues();
     end;
   except
     WriteLog('Fehler: Prozedur setData()')
   end;
end;

//Prozedur wird bei Start des Plugins aufgerufen
procedure PluginStart(AOwner: TComponent); stdcall;
begin
     //Lofile leeren
     pfad := 'logfile.txt';
     Assign(Datei, pfad);
     Rewrite(Datei);
     Write(Datei, '');
     Close(Datei);
     WriteLog('PluginStart');

     //Variablen initialsieren
     status := -1;
     isConnected := false;

     ZugbeleuchtungAutomatik := true;
     bCockpitActive := false;

     serPort := 3;
     receivedString := '';

     //Hinzufuegen der Objekte zum Array varsFloat
     addToVarsFloat(TValueNode.Create('v_ground', false));
     addToVarsFloat(TValueNode.Create('a_ground', false));
     addToVarsFloat(TValueNode.Create('EnvirBrightness', false));
     addToVarsFloat(TValueNode.Create('A_LM_DoorsClosed', false));
     addToVarsFloat(TValueNode.Create('A_LM_Warnblinken', false));
     addToVarsFloat(TValueNode.Create('A_LM_Hauptschalter', false));
     addToVarsFloat(TValueNode.Create('A_LM_Schienenbremse', false));
     addToVarsFloat(TValueNode.Create('A_LM_haltewunsch', false));
     addToVarsFloat(TValueNode.Create('cp_Umschalthebel_A', true));
     addToVarsFloat(TValueNode.Create('cp_Umschalthebel_B', true));
     addToVarsFloat(TValueNode.Create('gb_Schlupf', true));
     addToVarsFloat(TValueNode.Create('gb_Fahrstromautomat_aus_A', true));
     addToVarsFloat(TValueNode.Create('gb_Fahrstromautomat_aus_B', true));
     addToVarsFloat(TValueNode.Create('gb_Federspeicher_A', true));
     addToVarsFloat(TValueNode.Create('gb_Federspeicher_B', true));
     addToVarsFloat(TValueNode.Create('gb_Sicherheitsschleife_A', true));
     addToVarsFloat(TValueNode.Create('gb_Sicherheitsschleife_A', true));
     addToVarsFloat(TValueNode.Create('gb_Tuerseitenwahl_Links', false));
     addToVarsFloat(TValueNode.Create('gb_Tuerseitenwahl_Rechts', false));
     addToVarsFloat(TValueNode.Create('gb_Abfahrt_A', false));
     addToVarsFloat(TValueNode.Create('gb_Abfahrt_B', false));
     addToVarsFloat(TValueNode.Create('Batteriespannung', false));
     addToVarsFloat(TValueNode.Create('gb_Fahrt_A', false));
     addToVarsFloat(TValueNode.Create('gb_Fahrt_B', false));
     addToVarsFloat(TValueNode.Create('gb_haltewunsch_A', true));
     addToVarsFloat(TValueNode.Create('gb_haltewunsch_B', true));
     addToVarsFloat(TValueNode.Create('gb_Fahrgastwunsch_A', true));
     addToVarsFloat(TValueNode.Create('gb_Fahrgastwunsch_B', true));
     addToVarsFloat(TValueNode.Create('LM_A_Automat', true));
     addToVarsFloat(TValueNode.Create('LM_B_Automat', true));
     addToVarsFloat(TValueNode.Create('LM_A_Links', false));
     addToVarsFloat(TValueNode.Create('LM_B_Links', false));
     addToVarsFloat(TValueNode.Create('LM_A_Rechts', false));
     addToVarsFloat(TValueNode.Create('LM_B_Rechts', false));
     addToVarsFloat(TValueNode.Create('LM_A_Abfart', false));
     addToVarsFloat(TValueNode.Create('LM_B_Abfart', false));
     addToVarsFloat(TValueNode.Create('LM_A_haltewunsch', true));
     addToVarsFloat(TValueNode.Create('LM_B_haltewunsch', true));
     addToVarsFloat(TValueNode.Create('LM_A_Haltebremse', true));
     addToVarsFloat(TValueNode.Create('LM_B_Haltebremse', true));
     addToVarsFloat(TValueNode.Create('LM_A_Stoerzapfen', true));
     addToVarsFloat(TValueNode.Create('LM_B_Stoerzapfen', true));
     addToVarsFloat(TValueNode.Create('AV_A_Sw_Betriebsartenwahl', true));
     addToVarsFloat(TValueNode.Create('AV_B_Sw_Betriebsartenwahl', true));
     addToVarsFloat(TValueNode.Create('gb_Tachobeleuchtung_A', true));
     addToVarsFloat(TValueNode.Create('gb_Tachobeleuchtung_B', true));

     //Verbindungsaufbau zum Mikrocontroller und die Werte aller Variablen senden
     connect();
     sendAllValues();
end;

//Prozedur wird beim Beenden des Plugins aufgerufen
procedure PluginFinalize; stdcall;
begin
  WriteLog('PluginFinalize');

  //Serielle Schnittstelle schliessen
  SerSync(conn);
  SerFlushOutput(conn);
  SerClose(conn);
end;

//Prozedur empfaengt Float-variablen vom Simulator
procedure ReceiveVarFloat(varindex: word; value: single); stdcall;
var
   hour, min, sec, msec: word;
   elemA, elemB: TValueNode;
   _id, _cockpit: String;
begin
  try
    //v_ground an ESP32 senden, falls Aenderung groesser als 0.2
    if (varsFloat[varindex].getId() = 'v_ground') then
    begin
      if (varsFloat[varindex].getValue()-0.20 >= value) or (varsFloat[varindex].getValue()+0.20 <= value) then
      begin
        varsFloat[varindex].setValue(value);
        sendData(varsFloat[varindex].getId() + '=' + StringReplace(FloatToStr(value), ',', '.', [rfReplaceAll]) + ';');
      end;
      exit;
    end;
  except
    WriteLog('Error while Reading var: ' + IntToStr(varindex));
  end;

  //zugehoerige ID zur Variable
  _id := varsFloat[varindex].getId();

  if (_id = 'Batteriespannung') or (_id = 'gb_Tachobeleuchtung_A') or (_id = 'gb_Tachobeleuchtung_B') or (_id = 'gb_Federspeicher_A') or (_id = 'gb_Federspeicher_B') or (_id = 'gb_Sicherheitsschleife_A') or (_id = 'gb_Sicherheitsschleife_A') or (_id = 'gb_Fahrstromautomat_aus_B') or (_id = 'gb_Fahrstromautomat_aus_A') or (_id = 'gb_Abfahrt_A') or (_id = 'gb_Abfahrt_B') or (_id = 'gb_Schlupf') or (_id = 'gb_Tuerseitenwahl_Links') or (_id = 'gb_Tuerseitenwahl_Rechts') or (_id = 'LM_A_Abfart') or (_id = 'LM_B_Abfart') then
  begin
     if ((varsFloat[varindex].getValue() >= 0.5) <> (value >= 0.5)) then
     begin
          if value >= 0.5 then sendData(varsFloat[varindex].getId() + '=' + '1' + ';')
          else sendData(varsFloat[varindex].getId() + '=' + '0' + ';');
     end;
     if value >= 0.5 then varsFloat[varindex].setValue(1)
     else varsFloat[varindex].setValue(0);

    //Falls LM Abfahrtssignal
    if(_id = 'gb_Abfahrt_A') or (_id = 'gb_Fahrt_A') or (_id = 'LM_A_Abfart') or (_id  = 'gb_Abfahrt_B') or (_id  = 'gb_Fahrt_B') or (_id = 'LM_B_Abfart') then
    begin
      //Fahrerstand des LMs bestimmen
      if(_id = 'gb_Abfahrt_A') or (_id = 'gb_Fahrt_A') or (_id = 'LM_A_Abfart') then _cockpit := 'A'
      else _cockpit := 'B';

      //Werte der LMs zur Tuerseitenwahl bekommen
      if vehicleName = 'B100S_Serie1-3' then
      begin
        elemA := getVarFloatObjById('LM_A_Rechts');
        elemB := getVarFloatObjById('LM_A_Links');
      end
      else
      begin
        elemA := getVarFloatObjById('gb_Tuerseitenwahl_Rechts');
        elemB := getVarFloatObjById('gb_Tuerseitenwahl_Links');
      end;

      //falls sich der Zustand geaendert hat
      if(varsFloat[varindex].stateChanged()) or (elemA.stateChanged()) or (elemB.stateChanged()) then
      begin
        if varsFloat[varindex].getValue() >= 0.5 then
        begin //falls Abfahrtsignal aktiv Gruenschleife beider Seiten auf 1
          sendData('Gruenschleife_Rechts_' + _cockpit + '=1;');
          sendData('Gruenschleife_Links_' + _cockpit + '=1;');
        end
        else
        begin
          //falls Abfahrtsignal nicht aktiv Gruenschleife in Abhängigkeit der Tuerseitenwahl setzen
          if ((elemA.getValue() >= 0.5) and (_cockpit = 'A')) or ((elemB.getValue() >= 0.5) and (_cockpit = 'B')) then
            sendData('Gruenschleife_Rechts_' + _cockpit + '=0;')
          else
            sendData('Gruenschleife_Rechts_' + _cockpit + '=1;');

          if ((elemB.getValue() >= 0.5) and (_cockpit = 'A')) or ((elemA.getValue() >= 0.5) and (_cockpit = 'B')) then
            sendData('Gruenschleife_Links_' + _cockpit + '=0;')
          else
            sendData('Gruenschleife_Links_' + _cockpit + '=1;');
        end;
      end;
    end;
    exit;
  end;

  //Wert des Objketes setzen und an den ESP32 senden, falls der Wert sich veraendert hat
  varsFloat[varindex].setValue(value);
  if(varsFloat[varindex].sendToClient()) and (varsFloat[varindex].stateChanged()) then sendFloat(varsFloat[varindex].getId(), value);

  //Falls Timmer von v_ground abgelaufen (500ms) Wert an ESP32 senden
  if (varsFloat[varindex].getId() = 'v_ground') then
  begin
    DecodeTime(time-lastTimeAllDataSent, hour, min, sec, msec );

    if (hour > 0) or (min > 0) or (sec > 0) or (msec > 500) then
    begin
      sendFloat(varsFloat[varindex].getId(), value);
      varsFloat[varindex].setValue(value);
      lastTimeAllDataSent := time;
    end;
  end;

end;

//Prozedur wird beim Betreten eines Fahrzeugs ausgeloest
procedure OnConnectingVehicle(name: shortstring); stdcall;
begin
     vehicleName := name;
     WriteLog('ConnectingVehicle: ' + vehicleName);
     sendData('OnConnectingVehicle=1');
     sendData('vehicle_name=' + vehicleName);
     sendAllValues();
end;

//Prozedur wird beim Verlassen eines Fahrzeugs ausgeloest
procedure OnUnconnectingVehicle; stdcall;
begin
     WriteLog('UnonnectingVehicle');
     sendData('OnUnconnectingVehicle=1');
     sendAllValues();
end;

//Prozedur zum empfangen von Daten über die serielle Schnittstelle
procedure receiveSerial();
var
   data: string;
   i: integer;
   endReceiving: boolean;
   charSer: char;
   foundEqualsSign: boolean;
   foundSemicolon: boolean;
   id, value: String;
begin
   //Variablen initialisieren
   charSer := #0;
   endReceiving := false;
   data := '';
   foundSemicolon := false;

   while (Length(receivedString)<100) and (status>=0) and not (endReceiving) do begin
      status:= SerRead(conn, charSer, 1);//Naechstes Char empfangen

      if (charSer=#13) or (charSer=#0) or (charSer='') then endReceiving := true;
      if (charSer=';') then foundSemicolon := true;

      if (status>0) and not (endReceiving) and not (foundSemicolon) then
      begin
         //empfangenen String um charComIn erweitern
         receivedString:=receivedString+charSer;
      end;

      if endReceiving then break; //Schleife abbrechen, wenn das Char #13, #0 oder '' ist
      if foundSemicolon then
      begin //empfangenen String speichern und Schleife abbrechen, falls char ';' ist
         data := receivedString;
         receivedString := '';
         break;
      end;

      charSer := #0;
   end;

   //Datensatz parsen
   if (data <> '') then begin
     id := '';
     value := '';
     foundEqualsSign := false;

     for i := 1 to Length(data) do
     begin //Alle chars des Strings durchlaufen
          if data[i] = '=' then foundEqualsSign := true else
          begin //id und value zusammensetzen
             if (foundEqualsSign) then value := value + data[i] else id := id + data[i];
          end;
     end;
     //setData() mit empfangener ID und Wert aufrufen
     setData(id, value);
  end;
  data := '';
end;

//Uebergeben der Button-Events an den Simulator
function SetButton(eventindex: word): boolean;
begin
  //Methode receiveSerial aufrufen, um Datensaetze zu empfangen
  receiveSerial();

  result := false;

  if eventindex = 0 then taktBlink := not taktBlink;

  //result je nach eventindex setzen
  case eventindex of
    0: result := schienenbremse;
    1: result := stoprequest;
    2: result := HoldToRun;
    3: result := RunButton;
    4: result := (Reverser = 0);
    5: result := (Reverser = -1);
    6: result := (Reverser >= 1);
    7: result := false;
    8: result := FederspeicherbremseEin;
    9: result := FederspeicherbremseLoesen;
    10: result := false;
    11: result := UmformerEin;
    12: result := UmformerEin;
    13: result := UmformerAus;
    14: result := AutomatEin;
    15: result := AutomatAus;
    16: result := PantographAuf;
    17: result := PantographAb;
    18: result := false;
    19: result := false;
    20: result := false;
    21: result := false;
    22: result := (ZugbeleuchtungAutomatik) and (getVarFloatObjById('EnvirBrightness').getValue() > 0.5) and taktBlink;
    23: result := false;
    24: result := (ZugbeleuchtungAutomatik = false) and (getVarFloatObjById('EnvirBrightness').getValue() <= 0.5) and taktBlink;
    25: result := false;
    26: result := Hupe;
    27: result := false;
    28: result := TuerfreigabeLinks;
    29: result := TuerfreigabeRechts;
    30: result := TuerenSchliessen;
    31: result := false;
    32: result := false;
    33: result := TuerfreigabeLinks;
    34: result := TuerfreigabeRechts;
    35: result := false;
    36: result := false;
    37: result := (BrakeLever = 8);
    38: begin
      if vehicleName = 'B100S_Serie1-3' then exit;
      if Reverser = 0 then stateReverser := 0
      else if Reverser >= 1 then stateReverser := 2
      else stateReverser := -1;

      result := false;

      //Steuerung des Richtungswenders
      if ((not bCockpitActive) and (getVarFloatValueById('cp_Umschalthebel_A') < stateReverser)) or ((bCockpitActive) and (getVarFloatValueById('cp_Umschalthebel_B') < stateReverser)) then
      begin
        if reverserPlus then
        begin
          result := true;
          reverserPlus := false
        end
        else
        begin
           result := false;
           reverserPlus := true;
        end;
      end;
    end;
    39: begin
      if vehicleName = 'B100S_Serie1-3' then exit;
      if Reverser = 0 then stateReverser := 0
      else if Reverser >= 1 then stateReverser := 2
      else stateReverser := -1;

      result := false;

      //Steuerung des Richtungswenders
      if ((not bCockpitActive) and (getVarFloatValueById('cp_Umschalthebel_A') > stateReverser)) or ((bCockpitActive) and (getVarFloatValueById('cp_Umschalthebel_B') > stateReverser)) then
      begin
        if reverserPlus then
        begin
          result := true;
          reverserPlus := false;
        end
        else
        begin
           result := false;
           reverserPlus := true;
        end;
      end;
    end;
    40: result := UmformerAus and not bCockpitActive;
    41: result := UmformerAus and bCockpitActive;
    42: begin result := UmformerEin and not bCockpitActive; end;
    43: begin result := UmformerEin and bCockpitActive; end;
    44: result := false;
    45: result := false;
    46: result := false;
    47: result := false;
    48: result := false;
    49: result := false;
    50: result := heizscheibe and not bCockpitActive;
    51: result := heizscheibe and bCockpitActive;
    52: result := ZugbeleuchtungEin;
    53: result := ZugbeleuchtungAus;
    54: result := weicheVorneStellen;
    55: result := AutomatAus and not bCockpitActive;
    56: result := AutomatAus and bCockpitActive;
    57: result := AutomatEin and not bCockpitActive;
    58: result := AutomatEin and bCockpitActive;
    59: result := PantographAb and not bCockpitActive;
    60: result := PantographAb and bCockpitActive;
    61: result := PantographAuf and not bCockpitActive;
    62: result := PantographAuf and bCockpitActive;
    63: result := TuerenSchliessen and not bCockpitActive;
    64: result := TuerenSchliessen and bCockpitActive;
    65: result := TuerfreigabeLinks and not bCockpitActive;
    66: result := TuerfreigabeLinks and bCockpitActive;
    67: result := TuerfreigabeRechts and not bCockpitActive;
    68: result := TuerfreigabeRechts and bCockpitActive;
    69: result := (TuerfreigabeLinks or TuerfreigabeRechts) and not bCockpitActive;
    70: result := (TuerfreigabeLinks or TuerfreigabeRechts) and bCockpitActive;
    71: result := ((TuerenSchliessen and (getVarFloatValueById('gb_Abfahrt_A') <= 0.5) and (getVarFloatObjById('gb_Tuerseitenwahl_Rechts').getValue() >= 0.5)) or (TuerfreigabeRechts and (getVarFloatValueById('gb_Abfahrt_A') >= 0.5))) and not bCockpitActive;
    72: result := ((TuerenSchliessen and (getVarFloatValueById('gb_Abfahrt_B') <= 0.5) and (getVarFloatObjById('gb_Tuerseitenwahl_Links').getValue() >= 0.5)) or (TuerfreigabeRechts and (getVarFloatValueById('gb_Abfahrt_B') >= 0.5))) and bCockpitActive;
    73: result := ZugbeleuchtungEin;
    74: result := ZugbeleuchtungAus;
    75: result := UmformerEin;
    76: result := UmformerEin;
    77: result := UmformerAus;
    78: result := PantographAuf;
    79: result := PantographAb;
    80: result := TuerfreigabeRechts or TuerfreigabeLinks;
    81: result := AutomatEin;
    82: result := AutomatAus;
    83: result := false;//(BrakeLever = 1) and taktBlink; //BrakeLever <= 1;
    84: result := (TuerfreigabeRechts or TuerfreigabeLinks) and bCockpitActive;
    85: result := (TuerfreigabeRechts or TuerfreigabeLinks) and not bCockpitActive;
    86: result := false;
    87: result := false;
    88: result := false;
    89: result := weicheHintenStellen;
    90: result := UmformerEin;
    91: result := UmformerAus;
    92: result := weichensteuerungLinks;
    93: result := weichensteuerungGerade;
    94: result := weichensteuerungRechts;
    95: result := false;
    96: result := false;
    97: result := false;
    98: result := false;
    99: result := false;
    100: result := false;
    101: result := Aussenlautsprecher;
    102:
    begin
         //Steuerung der Sichperspektive
         result := false;
         if (bCockpitActive) and (Aussenlautsprecher) then
         begin
           viewBefore := 1;
           result := true;
         end
         else if (bCockpitActive) and (viewBefore = 1) then
         begin
           bCockpitActive := false;
           viewBefore := 0;
         end;
    end;
    103:
    begin
         //Steuerung der Sichperspektive
         result := false;
         if (not bCockpitActive) and (Aussenlautsprecher) then
         begin
           viewBefore := 1;
           result := true;
         end
         else if (not bCockpitActive) and (viewBefore = 1) then
         begin
           bCockpitActive := true;
           viewBefore := 0;
         end;
    end;
    104: result := Innenlautsprecher and bCockpitActive;
    105: result := Innenlautsprecher and not bCockpitActive;
    106: result := (TuerfreigabeRechts or TuerfreigabeLinks);
  end;
end;

//uebergeben der Gamecontroller-Achsen an den Simulator
function SetFloat(eventindex: word): single;
var
  v_kmh: single;
begin
  case eventindex of
    0: begin
       //Wert je nach Stellung des Bremshebels zurueckgeben
       case BrakeLever of
           0: result := 0.55; //Stellung 0
           1: begin
                if RunButton then
                begin
                  v_kmh := getVarFloatValueById('v_ground') * 3.6; //aktuelle Geschwindigkeit

                  if v_kmh < 0 then v_kmh := v_kmh * -1; //Betrag der Geschwindigkeit

                  if v_kmh > vMax_Reverser then
                  begin //Nullstellung zurueckgeben, falls v hoeher als vMax_Reverser
                    result := 0.5;
                    throttleBefore := 1;
                  end
                  else if v_kmh < v_Reverser_shut then
                  begin //Fahrtstellung zurueckgeben, falls v hoeher als v_Reverser_shut
                    result := 0.5+(throttle*0.5);
                    throttleBefore := 0;
                  end
                  else
                  begin //sonst Fahrtstellung zurueckgeben, falls Fahrtaster vorher nicht gedrueckt
                    if throttleBefore = 1 then result := 0.5
                    else result := 0.5+(throttle*0.5);
                  end;
                end
                else
                begin
                  //Nullstellung zurueckgeben, falls der Fahrtaster nicht gedrueckt ist
                  result := 0.5;
                  throttleBefore := 0;
                end;
              end; //Stellung Fahren
           2: result := 0.35; //Stellung E1
           3: result := 0.3; //Stellung E2
           4: result := 0.25; //Stellung E3
           5: result := 0.2; //Stellung E4
           6: result := 0.15; //Stellung E4L
           7: result := 0.1; //Stellung VB
           8: result := 0; //Stellung SB
         end;
       end;
  end;
end;

//Oeffentliche Methoden exportieren
exports
       OnConnectingVehicle,
       OnUnconnectingVehicle,
       ReceiveVarFloat,
       SetButton,
       SetFloat,
       PluginStart,
       PluginFinalize;
end.
