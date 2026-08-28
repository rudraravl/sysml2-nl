package CardiopulmonaryBypass {

    import ScalarValues::*;

    //=========================================================================
    // VALUE TYPES
    //=========================================================================

    value def FlowRate = Real {
        doc "Blood flow rate in milliliters per minute";
    }

    value def PressureValue = Real {
        doc "Pressure in millimeters of mercury (mmHg)";
    }

    value def TemperatureValue = Real {
        doc "Temperature in degrees Celsius";
    }

    value def VolumeValue = Real {
        doc "Volume in milliliters";
    }

    value def SaturationValue = Real {
        doc "Oxygen saturation as a percentage";
    }

    value def SpeedValue = Real {
        doc "Rotational speed in revolutions per minute";
    }

    value def GasFlowValue = Real {
        doc "Gas flow rate in liters per minute";
    }

    value def LengthValue = Real {
        doc "Length in millimeters";
    }

    value def AreaValue = Real {
        doc "Surface area in square meters";
    }

    //=========================================================================
    // ITEM TYPES
    //=========================================================================

    item def Blood {
        attribute temperature : TemperatureValue;
        attribute pressure : PressureValue;
        attribute oxygenSaturation : SaturationValue;
        attribute bubbleCount : Integer;
        attribute particulateCount : Integer;
    }

    item def GasSupply {
        attribute oxygenFraction : Real;
        attribute flowRate : GasFlowValue;
    }

    item def FlowSignal {
        attribute value : FlowRate;
    }

    item def PressureSignal {
        attribute value : PressureValue;
    }

    item def TemperatureSignal {
        attribute value : TemperatureValue;
    }

    item def SaturationSignal {
        attribute value : SaturationValue;
    }

    item def LevelSignal {
        attribute value : VolumeValue;
    }

    item def AlarmEvent {
        attribute severity : String;
        attribute message : String;
    }

    item def PumpControlCmd {
        attribute speed : SpeedValue;
    }

    item def TemperatureControlCmd {
        attribute target : TemperatureValue;
    }

    item def GasControlCmd {
        attribute oxygenFlow : GasFlowValue;
    }

    //=========================================================================
    // PORT DEFINITIONS
    //=========================================================================

    port def BloodInPort {
        in item blood : Blood;
    }

    port def BloodOutPort {
        out item blood : Blood;
    }

    port def GasInPort {
        in item gas : GasSupply;
    }

    port def GasOutPort {
        out item gas : GasSupply;
    }

    port def FlowOutputPort {
        out item signal : FlowSignal;
    }

    port def FlowInputPort {
        in item signal : FlowSignal;
    }

    port def PressureOutputPort {
        out item signal : PressureSignal;
    }

    port def PressureInputPort {
        in item signal : PressureSignal;
    }

    port def TemperatureOutputPort {
        out item signal : TemperatureSignal;
    }

    port def TemperatureInputPort {
        in item signal : TemperatureSignal;
    }

    port def SaturationOutputPort {
        out item signal : SaturationSignal;
    }

    port def SaturationInputPort {
        in item signal : SaturationSignal;
    }

    port def LevelOutputPort {
        out item signal : LevelSignal;
    }

    port def LevelInputPort {
        in item signal : LevelSignal;
    }

    port def AlarmOutputPort {
        out item alarm : AlarmEvent;
    }

    port def PumpCmdOutputPort {
        out item cmd : PumpControlCmd;
    }

    port def PumpCmdInputPort {
        in item cmd : PumpControlCmd;
    }

    port def TemperatureCmdOutputPort {
        out item cmd : TemperatureControlCmd;
    }

    port def TemperatureCmdInputPort {
        in item cmd : TemperatureControlCmd;
    }

    port def GasCmdOutputPort {
        out item cmd : GasControlCmd;
    }

    port def GasCmdInputPort {
        in item cmd : GasControlCmd;
    }

    //=========================================================================
    // ACTION DEFINITIONS
    //=========================================================================

    action def DrainBlood {
        in bloodIn : Blood;
        out bloodOut : Blood;
    }

    action def CollectBlood {
        in bloodIn : Blood;
        out bloodOut : Blood;
    }

    action def PumpBlood {
        in bloodIn : Blood;
        out bloodOut : Blood;
    }

    action def OxygenateBlood {
        in bloodIn : Blood;
        in gas : GasSupply;
        out bloodOut : Blood;
    }

    action def ExchangeHeat {
        in bloodIn : Blood;
        out bloodOut : Blood;
    }

    action def FilterBlood {
        in bloodIn : Blood;
        out bloodOut : Blood;
    }

    action def ReturnBlood {
        in bloodIn : Blood;
        out bloodOut : Blood;
    }

    //=========================================================================
    // COMPONENT PART DEFINITIONS
    //=========================================================================

    part def VenousCannula {
        doc "Tube that drains deoxygenated blood from the patient's major veins.";
        attribute cannulaDiameter : LengthValue;
        attribute cannulaLength : LengthValue;
        port inlet : BloodInPort;
        port outlet : BloodOutPort;
        action drain : DrainBlood;
    }

    part def VenousReservoir {
        doc "Collects venous blood and acts as a buffer during bypass.";
        attribute capacity : VolumeValue;
        attribute currentLevel : VolumeValue;
        port inlet : BloodInPort;
        port outlet : BloodOutPort;
        port levelOutput : LevelOutputPort;
        action collect : CollectBlood;
    }

    part def RollerPump {
        doc "Propels blood through the CPB circuit, serving as the artificial heart.";
        attribute maxSpeed : SpeedValue;
        attribute currentSpeed : SpeedValue;
        port inlet : BloodInPort;
        port outlet : BloodOutPort;
        port cmdInput : PumpCmdInputPort;
        port flowOutput : FlowOutputPort;
        action pump : PumpBlood;
    }

    part def MembraneOxygenator {
        doc "Artificial lung that performs gas exchange: adds oxygen and removes carbon dioxide.";
        attribute membraneArea : AreaValue;
        attribute gasTransferEfficiency : Real;
        port inlet : BloodInPort;
        port outlet : BloodOutPort;
        port gasIn : GasInPort;
        port satOutput : SaturationOutputPort;
        port cmdInput : GasCmdInputPort;
        action oxygenate : OxygenateBlood;
    }

    part def HeatExchanger {
        doc "Precisely controls blood temperature for cooling or warming.";
        attribute minTemp : TemperatureValue;
        attribute maxTemp : TemperatureValue;
        attribute targetTemp : TemperatureValue;
        port inlet : BloodInPort;
        port outlet : BloodOutPort;
        port tempOutput : TemperatureOutputPort;
        port cmdInput : TemperatureCmdInputPort;
        action exchange : ExchangeHeat;
    }

    part def ArterialLineFilter {
        doc "Captures and removes air bubbles, clots, and particulates from the blood.";
        attribute poreSize : LengthValue;
        port inlet : BloodInPort;
        port outlet : BloodOutPort;
        port pressureOutput : PressureOutputPort;
        action filter : FilterBlood;
    }

    part def ArterialCannula {
        doc "Returns oxygenated, temperature-controlled blood to the patient's arterial system.";
        attribute cannulaDiameter : LengthValue;
        attribute cannulaLength : LengthValue;
        port inlet : BloodInPort;
        port outlet : BloodOutPort;
        action returnBlood : ReturnBlood;
    }

    part def GasSupplyUnit {
        doc "Provides oxygen and other gases to the membrane oxygenator.";
        attribute oxygenFraction : Real;
        attribute flowRate : GasFlowValue;
        port outlet : GasOutPort;
    }

    //=========================================================================
    // BYPASS CONTROLLER
    //=========================================================================

    part def BypassController {
        doc "Perfusionist control console that manages all CPB operations and monitors sensors.";

        attribute setPumpSpeed : SpeedValue;
        attribute setTargetTemp : TemperatureValue;
        attribute setOxygenFlow : GasFlowValue;

        attribute flowLowLimit : FlowRate;
        attribute flowHighLimit : FlowRate;
        attribute pressureHighLimit : PressureValue;
        attribute tempLowLimit : TemperatureValue;
        attribute tempHighLimit : TemperatureValue;
        attribute satLowLimit : SaturationValue;
        attribute levelLowLimit : VolumeValue;

        attribute alarmActive : Boolean;
        attribute emergencyStopRequested : Boolean;

        port flowInput : FlowInputPort;
        port pressureInput : PressureInputPort;
        port tempInput : TemperatureInputPort;
        port satInput : SaturationInputPort;
        port levelInput : LevelInputPort;
        port alarmOutput : AlarmOutputPort;
        port pumpCmdOutput : PumpCmdOutputPort;
        port tempCmdOutput : TemperatureCmdOutputPort;
        port gasCmdOutput : GasCmdOutputPort;

        state machine operatingStates {
            state Idle;
            state Priming;
            state Starting;
            state Running;
            state Paused;
            state AlarmActive;
            state EmergencyStop;

            transition from Idle to Priming when startPriming;
            transition from Priming to Starting when primingComplete;
            transition from Starting to Running when bypassEstablished;
            transition from Running to Paused when pauseRequested;
            transition from Paused to Running when resumeRequested;
            transition from Running to AlarmActive when alarmCondition;
            transition from AlarmActive to Running when alarmCleared;
            transition from Running to EmergencyStop when emergencyStopRequested;
            transition from AlarmActive to EmergencyStop when emergencyStopRequested;
            transition from Paused to EmergencyStop when emergencyStopRequested;
            transition from EmergencyStop to Idle when systemReset;
        }
    }

    //=========================================================================
    // CPB SYSTEM
    //=========================================================================

    part def CPBMachine {
        doc "Cardiopulmonary Bypass (CPB) system, a heart-lung machine for open-heart surgery.";

        part venousCannula : VenousCannula {
            attribute cannulaDiameter = 8.0;
            attribute cannulaLength = 500.0;
        }

        part venousReservoir : VenousReservoir {
            attribute capacity = 4000.0;
            attribute currentLevel = 0.0;
        }

        part rollerPump : RollerPump {
            attribute maxSpeed = 300.0;
            attribute currentSpeed = 0.0;
        }

        part membraneOxygenator : MembraneOxygenator {
            attribute membraneArea = 2.5;
            attribute gasTransferEfficiency = 0.95;
        }

        part heatExchanger : HeatExchanger {
            attribute minTemp = 18.0;
            attribute maxTemp = 38.0;
            attribute targetTemp = 37.0;
        }

        part arterialFilter : ArterialLineFilter {
            attribute poreSize = 0.040;
        }

        part arterialCannula : ArterialCannula {
            attribute cannulaDiameter = 6.0;
            attribute cannulaLength = 300.0;
        }

        part gasSupply : GasSupplyUnit {
            attribute oxygenFraction = 1.0;
            attribute flowRate = 5.0;
        }

        part controller : BypassController {
            attribute setPumpSpeed = 150.0;
            attribute setTargetTemp = 37.0;
            attribute setOxygenFlow = 5.0;
            attribute flowLowLimit = 200.0;
            attribute flowHighLimit = 5000.0;
            attribute pressureHighLimit = 300.0;
            attribute tempLowLimit = 18.0;
            attribute tempHighLimit = 38.0;
            attribute satLowLimit = 95.0;
            attribute levelLowLimit = 200.0;
            attribute alarmActive = false;
            attribute emergencyStopRequested = false;
        }

        // Blood flow connections
        connection connect venousCannula.outlet to venousReservoir.inlet;
        connection connect venousReservoir.outlet to rollerPump.inlet;
        connection connect rollerPump.outlet to membraneOxygenator.inlet;
        connection connect membraneOxygenator.outlet to heatExchanger.inlet;
        connection connect heatExchanger.outlet to arterialFilter.inlet;
        connection connect arterialFilter.outlet to arterialCannula.inlet;

        // Gas supply connection
        connection connect gasSupply.outlet to membraneOxygenator.gasIn;

        // Sensor signal connections
        connection connect venousReservoir.levelOutput to controller.levelInput;
        connection connect rollerPump.flowOutput to controller.flowInput;
        connection connect membraneOxygenator.satOutput to controller.satInput;
        connection connect heatExchanger.tempOutput to controller.tempInput;
        connection connect arterialFilter.pressureOutput to controller.pressureInput;

        // Control command connections
        connection connect controller.pumpCmdOutput to rollerPump.cmdInput;
        connection connect controller.tempCmdOutput to heatExchanger.cmdInput;
        connection connect controller.gasCmdOutput to membraneOxygenator.cmdInput;
    }

    //=========================================================================
    // REQUIREMENTS
    //=========================================================================

    requirement def SafeFlowRateReq {
        doc "The CPB system shall maintain blood flow rate within 200 to 5000 mL/min during active bypass.";
        subject cpb : CPBMachine;
        objective {
            constraint { 200.0 <= cpb.controller.flowInput.signal.value and cpb.controller.flowInput.signal.value <= 5000.0 }
        }
    }

    requirement def SafePressureReq {
        doc "The CPB system shall maintain arterial line pressure below 300 mmHg.";
        subject cpb : CPBMachine;
        objective {
            constraint { cpb.controller.pressureInput.signal.value <= 300.0 }
        }
    }

    requirement def SafeTemperatureReq {
        doc "The CPB system shall maintain blood temperature between 18 and 38 degrees Celsius.";
        subject cpb : CPBMachine;
        objective {
            constraint { 18.0 <= cpb.controller.tempInput.signal.value and cpb.controller.tempInput.signal.value <= 38.0 }
        }
    }

    requirement def AdequateOxygenationReq {
        doc "The CPB system shall maintain blood oxygen saturation above 95 percent.";
        subject cpb : CPBMachine;
        objective {
            constraint { cpb.controller.satInput.signal.value >= 95.0 }
        }
    }

    requirement def ReservoirLevelReq {
        doc "The CPB system shall maintain venous reservoir level above 200 mL to prevent air entrainment.";
        subject cpb : CPBMachine;
        objective {
            constraint { cpb.controller.levelInput.signal.value >= 200.0 }
        }
    }

    requirement def AlarmOnDeviationReq {
        doc "The CPB controller shall trigger an alarm when any monitored parameter deviates from its safe operating range.";
        subject cpb : CPBMachine;
        objective {
            doc "If any sensor reading exceeds its alarm threshold, the alarm shall activate and alert the medical team.";
        }
    }

    requirement def BubbleRemovalReq {
        doc "The arterial line filter shall remove all air bubbles and particulates larger than 40 micrometers.";
        subject cpb : CPBMachine;
        objective {
            constraint { cpb.arterialFilter.poreSize <= 0.040 }
        }
    }

    requirement def EmergencyStopReq {
        doc "The CPB system shall provide an emergency stop capability that immediately halts the roller pump.";
        subject cpb : CPBMachine;
        objective {
            doc "When emergency stop is activated, pump speed shall be reduced to zero and the system shall enter EmergencyStop state.";
        }
    }

    requirement def ContinuousMonitoringReq {
        doc "The CPB system shall continuously monitor blood flow rate, arterial pressure, blood temperature, oxygen saturation, and reservoir level.";
        subject cpb : CPBMachine;
        objective {
            doc "All sensors shall provide real-time readings to the bypass controller throughout the bypass procedure.";
        }
    }

    requirement def BypassCircuitReq {
        doc "The CPB system shall route blood from venous cannula through reservoir, pump, oxygenator, heat exchanger, and arterial filter to arterial cannula.";
        subject cpb : CPBMachine;
        objective {
            doc "The blood circuit shall maintain a continuous, sealed path from venous return to arterial return with no interruptions.";
        }
    }

    requirement def GasExchangeReq {
        doc "The membrane oxygenator shall add oxygen to and remove carbon dioxide from the blood during bypass.";
        subject cpb : CPBMachine;
        objective {
            constraint { cpb.membraneOxygenator.gasTransferEfficiency >= 0.90 }
        }
    }

    requirement def TemperatureControlReq {
        doc "The heat exchanger shall be capable of cooling blood to 18 degrees Celsius and warming blood to 38 degrees Celsius.";
        subject cpb : CPBMachine;
        objective {
            constraint { cpb.heatExchanger.minTemp <= 18.0 and cpb.heatExchanger.maxTemp >= 38.0 }
        }
    }

    requirement def PrimingProcedureReq {
        doc "The CPB system shall be primed with fluid before initiating bypass to remove all air from the circuit.";
        subject cpb : CPBMachine;
        objective {
            doc "The controller state machine shall require a Priming state transition before entering Running state.";
        }
    }
}
