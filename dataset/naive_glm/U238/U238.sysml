package HeatingPadSystem {
    import ISQ::*;
    import ScalarValues::*;

    // ===== Value Types with Units =====
    attribute def TemperatureValue :> Real { unit '°C'; }
    attribute def VoltageValue :> Real { unit 'V'; }
    attribute def CurrentValue :> Real { unit 'A'; }
    attribute def PowerValue :> Real { unit 'W'; }
    attribute def TimeValue :> Real { unit 'min'; }
    attribute def DutyCycle :> Real { unit '%'; min 0; max 100; }

    // ===== Item Types =====
    item def ACPower {
        attribute voltage : VoltageValue = 120;
        attribute frequency : Real = 60 [Hz];
    }
    item def DCPower {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
    }
    item def HeatFlux {
        attribute power : PowerValue;
    }
    item def TempReading {
        attribute value : TemperatureValue;
    }
    item def HeatLevelCmd {
        attribute level : HeatLevel;
    }
    enum def HeatLevel { off, low, medium, high; }

    // ===== Requirements =====
    requirement def TherapeuticHeatingRequirement {
    subject pad : HeatingPad;
    objective "Provide controlled and safe heat for pain relief, muscle relaxation, and general comfort.";
    }

    requirement def PowerConversionRequirement {
    subject ps : PowerSupply;
    requirement "Convert high voltage AC to low-voltage DC.";
    requirement "Output voltage shall be 12 V DC ±0.5 V.";
    requirement "Output current capacity shall be at least 3 A.";
    }

    requirement def UserInterfaceRequirement {
    subject ui : UserInterface;
    requirement "Shall allow selection of heat levels: off, low, medium, high.";
    requirement "May display current temperature.";
    }

    requirement def ControlRequirement {
    subject cu : ControllerUnit;
    requirement "Shall receive desired heat level from user interface.";
    requirement "Shall continuously monitor pad temperature.";
    requirement "Shall manage power to heating element based on feedback.";
    requirement "Shall maintain target temperature within ±1°C.";
    }

    requirement def SafetyRequirement {
    subject sc : SafetyCircuit;
    requirement "Shall independently monitor temperature.";
    requirement "Shall shut down heating element if temperature exceeds 60°C.";
    requirement "Shall auto-shutoff after 60 minutes of continuous use.";
    requirement "Shall be independent of controller unit.";
    }

    requirement def HeatingElementRequirement {
    subject he : HeatingElement;
    requirement "Shall convert electricity into heat.";
    requirement "Maximum power shall be 30 W.";
    }

    // ===== Port Definitions =====
    port def ACPowerPort { in item ac : ACPower; }
    port def DCPowerPort { out item dc : DCPower; }
    port def DCPowerInPort { in item dc : DCPower; }
    port def HeatLevelPort { out item cmd : HeatLevelCmd; }
    port def HeatLevelInPort { in item cmd : HeatLevelCmd; }
    port def TempSensorPort { out item reading : TempReading; }
    port def TempSensorInPort { in item reading : TempReading; }
    port def PowerControlPort { out attribute duty : DutyCycle; }
    port def PowerControlInPort { in attribute duty : DutyCycle; }
    port def SafetyShutdownPort { out attribute shutdown : Boolean; }
    port def SafetyShutdownInPort { in attribute shutdown : Boolean; }
    port def HeatOutputPort { out item heat : HeatFlux; }

    // ===== Parts =====
    part def PowerSupply {
    port acIn : ACPowerPort;
    port dcOut : DCPowerPort;
    attribute outputVoltage : VoltageValue = 12;
    attribute maxCurrent : CurrentValue = 3;
    satisfy PowerConversionRequirement by ps;
    }

    part def UserInterface {
    port levelOut : HeatLevelPort;
    attribute selectedLevel : HeatLevel = off;
    attribute displayTemp : TemperatureValue;
    satisfy UserInterfaceRequirement by ui;
    action def selectLevel {
    in level : HeatLevel;
    out cmd : HeatLevelCmd;
    }
    }

    part def TemperatureSensor {
    port tempOut : TempSensorPort;
    attribute measuredTemp : TemperatureValue;
    attribute accuracy : TemperatureValue = 0.5;
    action def sense {
    out reading : TempReading;
    }
    }

    part def HeatingElement {
    port powerIn : DCPowerInPort;
    port controlIn : PowerControlInPort;
    port safetyIn : SafetyShutdownInPort;
    port heatOut : HeatOutputPort;
    attribute maxPower : PowerValue = 30;
    attribute currentDuty : DutyCycle = 0;
    attribute enabled : Boolean = true;
    satisfy HeatingElementRequirement by he;
    action def generateHeat {
    in duty : DutyCycle;
    out heat : HeatFlux;
    }
    }

    part def SafetyCircuit {
    port tempIn : TempSensorInPort;
    port shutdownOut : SafetyShutdownPort;
    attribute maxSafeTemp : TemperatureValue = 60;
    attribute autoShutoffTime : TimeValue = 60;
    attribute elapsed : TimeValue = 0;
    attribute tripped : Boolean = false;
    satisfy SafetyRequirement by sc;
    action def monitorSafety {
    in reading : TempReading;
    out shutdown : Boolean;
    }
    }

    part def ControllerUnit {
    port levelIn : HeatLevelInPort;
    port tempIn : TempSensorInPort;
    port powerControlOut : PowerControlPort;
    attribute targetTemp : TemperatureValue;
    attribute tolerance : TemperatureValue = 1;
    attribute currentTemp : TemperatureValue;
    attribute currentLevel : HeatLevel = off;
    satisfy ControlRequirement by cu;
    state def ControllerStates {
    entry; then Off;
    state Off {
    entry { currentLevel = off; }
    }
    state Heating {
    entry { /* apply full power */ }
    }
    state Maintaining {
    entry { /* cycle power */ }
    }
    state Cooling {
    entry { /* cut power */ }
    }
    transition off_to_heating
    from Off to Heating
    when currentLevel != off;
    transition heating_to_maintaining
    from Heating to Maintaining
    when currentTemp >= targetTemp - tolerance;
    transition maintaining_to_cooling
    from Maintaining to Cooling
    when currentTemp > targetTemp + tolerance;
    transition cooling_to_maintaining
    from Cooling to Maintaining
    when currentTemp <= targetTemp + tolerance;
    transition any_to_off
    from Heating, Maintaining, Cooling to Off
    when currentLevel == off;
    }
    }

    part def FabricCover {
    attribute material : String = "soft fleece";
    attribute thermalConductivity : Real = 0.04;
    attribute washable : Boolean = true;
    }

    // ===== Top-level System =====
    part def HeatingPad {
    satisfy TherapeuticHeatingRequirement by pad;
    attribute def TargetTemps {
    attribute off : TemperatureValue = 25;
    attribute low : TemperatureValue = 38;
    attribute medium : TemperatureValue = 43;
    attribute high : TemperatureValue = 48;
    }
    part powerSupply : PowerSupply {
    port acIn redefines ACPowerPort.ac;
    port dcOut redefines DCPowerPort.dc;
    }
    part userInterface : UserInterface {
    port levelOut redefines HeatLevelPort.cmd;
    }
    part tempSensor : TemperatureSensor {
    port tempOut redefines TempSensorPort.reading;
    }
    part heatingElement : HeatingElement {
    port powerIn redefines DCPowerInPort.dc;
    port controlIn redefines PowerControlInPort.duty;
    port safetyIn redefines SafetyShutdownInPort.shutdown;
    port heatOut redefines HeatOutputPort.heat;
    }
    part safetyCircuit : SafetyCircuit {
    port tempIn redefines TempSensorInPort.reading;
    port shutdownOut redefines SafetyShutdownPort.shutdown;
    }
    part controller : ControllerUnit {
    port levelIn redefines HeatLevelInPort.cmd;
    port tempIn redefines TempSensorInPort.reading;
    port powerControlOut redefines PowerControlPort.duty;
    }
    part fabricCover : FabricCover;
    // Connections
    connection powerConn : DCPower connect powerSupply.dcOut to heatingElement.powerIn;
    connection levelConn : HeatLevelCmd connect userInterface.levelOut to controller.levelIn;
    connection tempConn : TempReading connect tempSensor.tempOut to controller.tempIn;
    connection tempSafetyConn : TempReading connect tempSensor.tempOut to safetyCircuit.tempIn;
    connection controlConn : DutyCycle connect controller.powerControlOut to heatingElement.controlIn;
    connection safetyConn : Boolean connect safetyCircuit.shutdownOut to heatingElement.safetyIn;
    }
}
