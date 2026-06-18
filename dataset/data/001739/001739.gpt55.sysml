package AlHassanInspiredTechnologySystem {
    import ScalarValues::*;

    attribute def Length_m :> Real {
        attribute unitSymbol : String = "m";
    }

    attribute def Volume_L :> Real {
        attribute unitSymbol : String = "L";
    }

    attribute def FlowRate_L_per_min :> Real {
        attribute unitSymbol : String = "L/min";
    }

    attribute def Pressure_kPa :> Real {
        attribute unitSymbol : String = "kPa";
    }

    attribute def Temperature_C :> Real {
        attribute unitSymbol : String = "degC";
    }

    attribute def Mass_kg :> Real {
        attribute unitSymbol : String = "kg";
    }

    attribute def Angle_deg :> Real {
        attribute unitSymbol : String = "deg";
    }

    attribute def AngularSpeed_rpm :> Real {
        attribute unitSymbol : String = "rpm";
    }

    attribute def Voltage_V :> Real {
        attribute unitSymbol : String = "V";
    }

    attribute def Current_A :> Real {
        attribute unitSymbol : String = "A";
    }

    attribute def Power_W :> Real {
        attribute unitSymbol : String = "W";
    }

    attribute def Time_s :> Real {
        attribute unitSymbol : String = "s";
    }

    attribute def Accuracy_percent :> Real {
        attribute unitSymbol : String = "%";
    }

    attribute def Count :> Integer {
        attribute unitSymbol : String = "count";
    }

    item def Water {
        attribute volume : Volume_L;
        attribute temperature : Temperature_C;
        attribute particulateLoad : Real;
    }

    item def ElectricalEnergy {
        attribute voltage : Voltage_V;
        attribute current : Current_A;
        attribute power : Power_W;
    }

    item def ControlMessage {
        attribute messageId : Count;
        attribute commandName : String;
        attribute value : Real;
        attribute timeStamp : Time_s;
    }

    item def InterpretationContent {
        attribute title : String;
        attribute scholarReferenced : String;
        attribute historicalTheme : String;
        attribute summaryText : String;
        attribute duration : Time_s;
    }

    item def Rotation {
        attribute shaftAngle : Angle_deg;
        attribute shaftSpeed : AngularSpeed_rpm;
        attribute torqueEstimate : Real;
    }

    item def VisitorInput {
        attribute selectedMode : String;
        attribute requestedLanguage : String;
        attribute requestedDuration : Time_s;
    }

    item def HealthReport {
        attribute levelSensorHealthy : Boolean;
        attribute valveHealthy : Boolean;
        attribute pumpHealthy : Boolean;
        attribute leakDetected : Boolean;
        attribute safeToOperate : Boolean;
    }

    port def WaterPort {
        inout item water : Water;
        attribute nominalPressure : Pressure_kPa;
        attribute nominalFlowRate : FlowRate_L_per_min;
    }

    port def ElectricalPort {
        in item energy : ElectricalEnergy;
        attribute ratedVoltage : Voltage_V;
        attribute maxCurrent : Current_A;
    }

    port def DataPort {
        inout item message : ControlMessage;
        attribute updatePeriod : Time_s;
    }

    port def MechanicalRotationPort {
        inout item rotation : Rotation;
        attribute nominalSpeed : AngularSpeed_rpm;
    }

    port def ContentPort {
        out item content : InterpretationContent;
        attribute channelName : String;
    }

    port def VisitorInterfacePort {
        in item input : VisitorInput;
        out item content : InterpretationContent;
    }

    port def HealthPort {
        out item report : HealthReport;
        attribute reportPeriod : Time_s;
    }

    constraint def FlowAccuracyConstraint {
        in commandedFlow : FlowRate_L_per_min;
        in measuredFlow : FlowRate_L_per_min;
        in allowableError : Accuracy_percent;
        require constraint {
            measuredFlow >= commandedFlow * (1.0 - allowableError / 100.0) and
            measuredFlow <= commandedFlow * (1.0 + allowableError / 100.0)
        }
    }

    constraint def SafeReservoirLevelConstraint {
        in level : Length_m;
        in minimumLevel : Length_m;
        in maximumLevel : Length_m;
        require constraint {
            level >= minimumLevel and level <= maximumLevel
        }
    }

    constraint def LowVoltageControlConstraint {
        in voltage : Voltage_V;
        require constraint {
            voltage <= 24.0
        }
    }

    action def InitializeDemonstrator {
        in selectedLanguage : String;
        in targetDuration : Time_s;
        out initialized : Boolean;
        out initialContent : InterpretationContent;
    }

    action def FillReservoir {
        in desiredVolume : Volume_L;
        in currentVolume : Volume_L;
        out pumpCommand : ControlMessage;
        out filled : Boolean;
    }

    action def RegulateWaterFlow {
        in targetFlow : FlowRate_L_per_min;
        in measuredFlow : FlowRate_L_per_min;
        in waterLevel : Length_m;
        out valveCommand : ControlMessage;
        out regulated : Boolean;
    }

    action def ConvertFlowToMotion {
        in flow : FlowRate_L_per_min;
        in floatPosition : Length_m;
        out rotation : Rotation;
        out hourIndex : Count;
    }

    action def PresentHistoricalNarrative {
        in modeName : String;
        in language : String;
        out content : InterpretationContent;
        out completed : Boolean;
    }

    action def PerformHealthCheck {
        in reservoirLevel : Length_m;
        in measuredFlow : FlowRate_L_per_min;
        in supplyVoltage : Voltage_V;
        out report : HealthReport;
    }

    action def EnterSafeShutdown {
        in reason : String;
        out valveCloseCommand : ControlMessage;
        out pumpStopCommand : ControlMessage;
        out safe : Boolean;
    }

    state def DemonstratorLifecycle {
        entry action InitializeDemonstrator;

        state PoweredOff;
        state Standby;
        state Filling;
        state CalibratingFlow;
        state Demonstrating;
        state Interpreting;
        state FaultDetected;
        state SafeShutdown;

        transition initial then PoweredOff;

        transition PowerOn {
            first PoweredOff;
            then Standby;
        }

        transition BeginFilling {
            first Standby;
            then Filling;
        }

        transition ReservoirReady {
            first Filling;
            then CalibratingFlow;
        }

        transition FlowStable {
            first CalibratingFlow;
            then Demonstrating;
        }

        transition NarrativeRequested {
            first Demonstrating;
            then Interpreting;
        }

        transition NarrativeComplete {
            first Interpreting;
            then Demonstrating;
        }

        transition DemonstrationComplete {
            first Demonstrating;
            then Standby;
        }

        transition HealthFaultFromFilling {
            first Filling;
            then FaultDetected;
        }

        transition HealthFaultFromCalibrating {
            first CalibratingFlow;
            then FaultDetected;
        }

        transition HealthFaultFromDemonstrating {
            first Demonstrating;
            then FaultDetected;
        }

        transition SecureSystem {
            first FaultDetected;
            then SafeShutdown;
        }

        transition ResetAfterShutdown {
            first SafeShutdown;
            then Standby;
        }

        transition PowerOffFromStandby {
            first Standby;
            then PoweredOff;
        }
    }

    part def Reservoir {
        attribute capacity : Volume_L = 40.0;
        attribute normalFillVolume : Volume_L = 32.0;
        attribute minimumOperatingLevel : Length_m = 0.18;
        attribute maximumOperatingLevel : Length_m = 0.72;
        attribute currentLevel : Length_m;
        attribute emptyMass : Mass_kg = 9.5;

        port fillInlet : WaterPort {
            attribute nominalPressure = 120.0;
            attribute nominalFlowRate = 8.0;
        }

        port regulatedOutlet : WaterPort {
            attribute nominalPressure = 18.0;
            attribute nominalFlowRate = 1.6;
        }

        port levelData : DataPort {
            attribute updatePeriod = 0.5;
        }

        port healthOut : HealthPort {
            attribute reportPeriod = 1.0;
        }

        constraint safeLevel : SafeReservoirLevelConstraint {
            in level = currentLevel;
            in minimumLevel = minimumOperatingLevel;
            in maximumLevel = maximumOperatingLevel;
        }
    }

    part def RecirculationPump {
        attribute ratedFlow : FlowRate_L_per_min = 10.0;
        attribute ratedPower : Power_W = 45.0;
        attribute maxHeadPressure : Pressure_kPa = 160.0;
        attribute dryRunProtected : Boolean = true;

        port powerIn : ElectricalPort {
            attribute ratedVoltage = 24.0;
            attribute maxCurrent = 3.0;
        }

        port waterIn : WaterPort {
            attribute nominalPressure = 20.0;
            attribute nominalFlowRate = 8.0;
        }

        port waterOut : WaterPort {
            attribute nominalPressure = 120.0;
            attribute nominalFlowRate = 8.0;
        }

        port commandIn : DataPort {
            attribute updatePeriod = 0.2;
        }

        port healthOut : HealthPort {
            attribute reportPeriod = 1.0;
        }
    }

    part def FlowRegulator {
        attribute targetFlow : FlowRate_L_per_min = 1.2;
        attribute measuredFlow : FlowRate_L_per_min;
        attribute allowableFlowError : Accuracy_percent = 5.0;
        attribute valveOpening : Accuracy_percent;
        attribute responseTime : Time_s = 2.0;

        port waterIn : WaterPort {
            attribute nominalPressure = 18.0;
            attribute nominalFlowRate = 1.2;
        }

        port waterOut : WaterPort {
            attribute nominalPressure = 12.0;
            attribute nominalFlowRate = 1.2;
        }

        port commandIn : DataPort {
            attribute updatePeriod = 0.2;
        }

        port measurementOut : DataPort {
            attribute updatePeriod = 0.2;
        }

        port healthOut : HealthPort {
            attribute reportPeriod = 1.0;
        }

        constraint flowAccuracy : FlowAccuracyConstraint {
            in commandedFlow = targetFlow;
            in measuredFlow = measuredFlow;
            in allowableError = allowableFlowError;
        }
    }

    part def FloatChamber {
        attribute chamberVolume : Volume_L = 8.0;
        attribute operatingDepth : Length_m = 0.45;
        attribute floatTravel : Length_m = 0.36;
        attribute floatMass : Mass_kg = 0.42;
        attribute floatPosition : Length_m;

        port inlet : WaterPort {
            attribute nominalPressure = 12.0;
            attribute nominalFlowRate = 1.2;
        }

        port outlet : WaterPort {
            attribute nominalPressure = 10.0;
            attribute nominalFlowRate = 1.2;
        }

        port motionOutput : MechanicalRotationPort {
            attribute nominalSpeed = 1.0;
        }

        port positionData : DataPort {
            attribute updatePeriod = 0.5;
        }
    }

    part def SiphonResetModule {
        attribute triggerLevel : Length_m = 0.42;
        attribute resetTime : Time_s = 18.0;
        attribute dischargeFlow : FlowRate_L_per_min = 6.0;

        port chamberIn : WaterPort {
            attribute nominalPressure = 10.0;
            attribute nominalFlowRate = 6.0;
        }

        port drainOut : WaterPort {
            attribute nominalPressure = 8.0;
            attribute nominalFlowRate = 6.0;
        }

        port statusOut : DataPort {
            attribute updatePeriod = 0.5;
        }
    }

    part def GearTrain {
        attribute inputSpeed : AngularSpeed_rpm;
        attribute outputSpeed : AngularSpeed_rpm;
        attribute gearRatio : Real = 60.0;
        attribute backlashAngle : Angle_deg = 1.5;

        port inputShaft : MechanicalRotationPort {
            attribute nominalSpeed = 1.0;
        }

        port displayShaft : MechanicalRotationPort {
            attribute nominalSpeed = 0.0167;
        }

        port automatonShaft : MechanicalRotationPort {
            attribute nominalSpeed = 0.25;
        }
    }

    part def TimeDisplay {
        attribute dialDiameter : Length_m = 0.75;
        attribute indicatedHour : Count;
        attribute indicatedMinute : Count;
        attribute displayAccuracy : Accuracy_percent = 3.0;

        port driveInput : MechanicalRotationPort {
            attribute nominalSpeed = 0.0167;
        }

        port contentOut : ContentPort {
            attribute channelName = "visible dial and hour markers";
        }
    }

    part def AutomatonFigure {
        attribute figureName : String = "scribe indicator";
        attribute gestureAngle : Angle_deg = 42.0;
        attribute gestureDuration : Time_s = 7.0;
        attribute materialMass : Mass_kg = 1.8;

        port driveInput : MechanicalRotationPort {
            attribute nominalSpeed = 0.25;
        }

        port contentOut : ContentPort {
            attribute channelName = "mechanical gesture";
        }
    }

    part def InterpretationConsole {
        attribute supportedLanguages : String = "Arabic, English, French";
        attribute defaultLanguage : String = "English";
        attribute sessionDuration : Time_s = 240.0;
        attribute highLevelFunctionStatement : String =
            "The system demonstrates water-regulated timekeeping and mechanical automation inspired by the technological heritage studied and described by Ahmad Y. al-Hassan.";

        port visitorInterface : VisitorInterfacePort;

        port contentIn : ContentPort {
            attribute channelName = "demonstrator content";
        }

        port commandOut : DataPort {
            attribute updatePeriod = 0.5;
        }
    }

    part def SupervisoryController {
        attribute processorVoltage : Voltage_V = 24.0;
        attribute controlCycle : Time_s = 0.2;
        attribute selectedMode : String = "guided demonstration";
        attribute commandedFlow : FlowRate_L_per_min = 1.2;
        attribute safeStateActive : Boolean = false;

        port powerIn : ElectricalPort {
            attribute ratedVoltage = 24.0;
            attribute maxCurrent = 1.5;
        }

        port reservoirDataIn : DataPort {
            attribute updatePeriod = 0.5;
        }

        port flowDataIn : DataPort {
            attribute updatePeriod = 0.2;
        }

        port chamberDataIn : DataPort {
            attribute updatePeriod = 0.5;
        }

        port pumpCommandOut : DataPort {
            attribute updatePeriod = 0.2;
        }

        port valveCommandOut : DataPort {
            attribute updatePeriod = 0.2;
        }

        port consoleCommandIn : DataPort {
            attribute updatePeriod = 0.5;
        }

        port healthIn : HealthPort {
            attribute reportPeriod = 1.0;
        }

        constraint lowVoltage : LowVoltageControlConstraint {
            in voltage = processorVoltage;
        }

        state lifecycle : DemonstratorLifecycle;
    }

    part def PowerSupply {
        attribute inputVoltage : Voltage_V = 230.0;
        attribute outputVoltage : Voltage_V = 24.0;
        attribute maximumPower : Power_W = 120.0;
        attribute isolatedOutput : Boolean = true;

        port controllerPower : ElectricalPort {
            attribute ratedVoltage = 24.0;
            attribute maxCurrent = 1.5;
        }

        port pumpPower : ElectricalPort {
            attribute ratedVoltage = 24.0;
            attribute maxCurrent = 3.0;
        }
    }

    part def LeakContainmentTray {
        attribute trayCapacity : Volume_L = 12.0;
        attribute leakDetected : Boolean = false;
        attribute drainClosed : Boolean = true;

        port leakSensorData : DataPort {
            attribute updatePeriod = 0.5;
        }

        port healthOut : HealthPort {
            attribute reportPeriod = 1.0;
        }
    }

    part def AlHassanWaterAutomataDemonstrator {
        attribute systemName : String = "Ahmad Y. al-Hassan Inspired Water Automata Demonstrator";
        attribute scholarlyBasis : String =
            "Ahmad Y. al-Hassan's studies of Arabic-Islamic engineering, water-raising devices, automatic machines, and historical technology.";
        attribute primaryFunction : String =
            "Provide a high-level, observable demonstration of water-flow regulation converting hydraulic behavior into time indication, mechanical motion, and educational interpretation.";
        attribute installedMass : Mass_kg = 86.0;
        attribute nominalDemonstrationDuration : Time_s = 240.0;
        attribute nominalFlowSetPoint : FlowRate_L_per_min = 1.2;
        attribute safeForPublicOperation : Boolean = true;

        part reservoir : Reservoir;
        part pump : RecirculationPump;
        part regulator : FlowRegulator;
        part floatChamber : FloatChamber;
        part siphon : SiphonResetModule;
        part gearTrain : GearTrain;
        part display : TimeDisplay;
        part automaton : AutomatonFigure;
        part console : InterpretationConsole;
        part controller : SupervisoryController;
        part powerSupply : PowerSupply;
        part containment : LeakContainmentTray;

        port visitorInterface : VisitorInterfacePort;
        port facilityPower : ElectricalPort {
            attribute ratedVoltage = 230.0;
            attribute maxCurrent = 1.0;
        }

        port publicContent : ContentPort {
            attribute channelName = "public high-level function presentation";
        }

        connect facilityPower to powerSupply.controllerPower;
        connect powerSupply.pumpPower to pump.powerIn;
        connect powerSupply.controllerPower to controller.powerIn;

        connect pump.waterOut to reservoir.fillInlet;
        connect reservoir.regulatedOutlet to regulator.waterIn;
        connect regulator.waterOut to floatChamber.inlet;
        connect floatChamber.outlet to siphon.chamberIn;
        connect siphon.drainOut to pump.waterIn;

        connect floatChamber.motionOutput to gearTrain.inputShaft;
        connect gearTrain.displayShaft to display.driveInput;
        connect gearTrain.automatonShaft to automaton.driveInput;

        connect reservoir.levelData to controller.reservoirDataIn;
        connect regulator.measurementOut to controller.flowDataIn;
        connect floatChamber.positionData to controller.chamberDataIn;
        connect controller.pumpCommandOut to pump.commandIn;
        connect controller.valveCommandOut to regulator.commandIn;
        connect console.commandOut to controller.consoleCommandIn;
        connect visitorInterface to console.visitorInterface;
        connect display.contentOut to console.contentIn;
        connect automaton.contentOut to publicContent;

        connect reservoir.healthOut to controller.healthIn;
        connect pump.healthOut to controller.healthIn;
        connect regulator.healthOut to controller.healthIn;
        connect containment.healthOut to controller.healthIn;

        perform action InitializeDemonstrator {
            in selectedLanguage = console.defaultLanguage;
            in targetDuration = nominalDemonstrationDuration;
        }

        perform action FillReservoir {
            in desiredVolume = reservoir.normalFillVolume;
            in currentVolume = reservoir.currentLevel;
        }

        perform action RegulateWaterFlow {
            in targetFlow = nominalFlowSetPoint;
            in measuredFlow = regulator.measuredFlow;
            in waterLevel = reservoir.currentLevel;
        }

        perform action ConvertFlowToMotion {
            in flow = regulator.measuredFlow;
            in floatPosition = floatChamber.floatPosition;
        }

        perform action PresentHistoricalNarrative {
            in modeName = controller.selectedMode;
            in language = console.defaultLanguage;
        }

        perform action PerformHealthCheck {
            in reservoirLevel = reservoir.currentLevel;
            in measuredFlow = regulator.measuredFlow;
            in supplyVoltage = controller.processorVoltage;
        }

        perform action EnterSafeShutdown {
            in reason = "unsafe hydraulic, electrical, or visitor-facing condition";
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject system : AlHassanWaterAutomataDemonstrator;
        attribute requiredStatement : String =
            "The system shall define a high-level Ahmad Y. al-Hassan inspired technology demonstrator whose primary function is to show how regulated water flow can produce time indication, mechanical automation, and historical interpretation.";
        require constraint {
            system.safeForPublicOperation == true
        }
    }

    requirement def HistoricalBasisRequirement {
        subject system : AlHassanWaterAutomataDemonstrator;
        attribute requiredScholar : String = "Ahmad Y. al-Hassan";
        attribute requiredTheme : String = "Arabic-Islamic engineering heritage, water devices, and automata";
        require constraint {
            system.scholarlyBasis != ""
        }
    }

    requirement def PublicDemonstrationRequirement {
        subject system : AlHassanWaterAutomataDemonstrator;
        attribute minimumDuration : Time_s = 180.0;
        attribute maximumDuration : Time_s = 300.0;
        require constraint {
            system.nominalDemonstrationDuration >= minimumDuration and
            system.nominalDemonstrationDuration <= maximumDuration
        }
    }

    requirement def HydraulicRegulationRequirement {
        subject system : AlHassanWaterAutomataDemonstrator;
        attribute nominalFlow : FlowRate_L_per_min = 1.2;
        attribute allowedError : Accuracy_percent = 5.0;
        require constraint {
            system.regulator.targetFlow == nominalFlow and
            system.regulator.allowableFlowError <= allowedError
        }
    }

    requirement def LowVoltagePublicSafetyRequirement {
        subject system : AlHassanWaterAutomataDemonstrator;
        attribute maximumAccessibleVoltage : Voltage_V = 24.0;
        require constraint {
            system.controller.processorVoltage <= maximumAccessibleVoltage and
            system.powerSupply.outputVoltage <= maximumAccessibleVoltage
        }
    }

    requirement def ContainmentRequirement {
        subject system : AlHassanWaterAutomataDemonstrator;
        attribute minimumContainmentVolume : Volume_L = 10.0;
        require constraint {
            system.containment.trayCapacity >= minimumContainmentVolume
        }
    }

    requirement def InterpretiveContentRequirement {
        subject system : AlHassanWaterAutomataDemonstrator;
        attribute requiredFunctionText : String =
            "regulated water flow produces visible time indication and mechanical action";
        require constraint {
            system.console.sessionDuration > 0.0
        }
    }

    part alHassanInspiredDemonstrator : AlHassanWaterAutomataDemonstrator;

    requirement primaryFunction : PrimaryFunctionRequirement {
        subject system = alHassanInspiredDemonstrator;
    }

    requirement historicalBasis : HistoricalBasisRequirement {
        subject system = alHassanInspiredDemonstrator;
    }

    requirement publicDemonstration : PublicDemonstrationRequirement {
        subject system = alHassanInspiredDemonstrator;
    }

    requirement hydraulicRegulation : HydraulicRegulationRequirement {
        subject system = alHassanInspiredDemonstrator;
    }

    requirement lowVoltageSafety : LowVoltagePublicSafetyRequirement {
        subject system = alHassanInspiredDemonstrator;
    }

    requirement containment : ContainmentRequirement {
        subject system = alHassanInspiredDemonstrator;
    }

    requirement interpretiveContent : InterpretiveContentRequirement {
        subject system = alHassanInspiredDemonstrator;
    }

    satisfy primaryFunction by alHassanInspiredDemonstrator;
    satisfy historicalBasis by alHassanInspiredDemonstrator;
    satisfy publicDemonstration by alHassanInspiredDemonstrator;
    satisfy hydraulicRegulation by alHassanInspiredDemonstrator;
    satisfy lowVoltageSafety by alHassanInspiredDemonstrator;
    satisfy containment by alHassanInspiredDemonstrator;
    satisfy interpretiveContent by alHassanInspiredDemonstrator;
}
