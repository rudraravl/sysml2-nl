package ECMO_System {

    // ==================== UNITS ====================
    unit mmHg;
    unit mL_per_min;
    unit L_per_min;
    unit degC;
    unit rpm;
    unit percent;

    // ==================== VALUE TYPES ====================
    attribute def PressureValue {
        value : Real;
        unit : mmHg;
    }
    attribute def BloodFlowRateValue {
        value : Real;
        unit : mL_per_min;
    }
    attribute def O2FlowRateValue {
        value : Real;
        unit : L_per_min;
    }
    attribute def TemperatureValue {
        value : Real;
        unit : degC;
    }
    attribute def PumpSpeedValue {
        value : Real;
        unit : rpm;
    }
    attribute def SaturationValue {
        value : Real;
        unit : percent;
    }

    // ==================== ITEMS ====================
    item def Blood;
    item def DeoxygenatedBlood :> Blood;
    item def OxygenatedBlood :> Blood;
    item def Oxygen;
    item def WasteGas;
    item def Saline;

    // ==================== PORTS ====================
    port def BloodInPort {
        in item blood : Blood;
        attribute pressure : PressureValue;
    }
    port def BloodOutPort {
        out item blood : Blood;
        attribute pressure : PressureValue;
    }
    port def OxygenInPort {
        in item oxygen : Oxygen;
    }
    port def OxygenOutPort {
        out item oxygen : Oxygen;
    }
    port def WasteGasOutPort {
        out item wasteGas : WasteGas;
    }
    port def VentOutPort {
        out item ventedBlood : Blood;
    }
    port def SignalOutPort {
        out attribute signal : Real;
    }
    port def SignalInPort {
        in attribute signal : Real;
    }
    port def ControlOutPort {
        out attribute command : Real;
    }
    port def ControlInPort {
        in attribute command : Real;
    }

    // ==================== CONNECTION DEFINITIONS ====================
    connection def BloodConnection {
        end source : BloodOutPort;
        end target : BloodInPort;
        item blood : Blood;
    }
    connection def OxygenConnection {
        end source : OxygenOutPort;
        end target : OxygenInPort;
        item oxygen : Oxygen;
    }
    connection def SignalConnection {
        end source : SignalOutPort;
        end target : SignalInPort;
        attribute signal : Real;
    }
    connection def ControlConnection {
        end source : ControlOutPort;
        end target : ControlInPort;
        attribute command : Real;
    }

    // ==================== BLOOD PUMP ====================
    part def BloodPump {
        port bloodIn : BloodInPort;
        port bloodOut : BloodOutPort;
        port controlIn : ControlInPort;

        attribute targetFlowRate : BloodFlowRateValue;
        attribute pumpSpeed : PumpSpeedValue;
        attribute currentFlowRate : BloodFlowRateValue;

        action def PumpOperation {
            in blood : Blood;
            out pumpedBlood : Blood;
        }
        action pump : PumpOperation {
            in blood @ bloodIn;
            out pumpedBlood @ bloodOut;
        }

        stateMachine PumpStates {
            state stopped;
            state running;
            transition stopped -> running on start;
            transition running -> stopped on stop;
            transition running -> running on adjustSpeed;
        }
    }

    // ==================== HOLLOW FIBER MEMBRANE ====================
    part def HollowFiberMembrane {
        port bloodIn : BloodInPort;
        port bloodOut : BloodOutPort;
        port oxygenIn : OxygenInPort;
        port wasteOut : WasteGasOutPort;

        attribute oxygenTransferEfficiency : SaturationValue;
        attribute co2RemovalRate : BloodFlowRateValue;
        attribute membraneSurfaceArea : Real;

        action def GasExchange {
            in deoxygenatedBlood : DeoxygenatedBlood;
            in oxygen : Oxygen;
            out oxygenatedBlood : OxygenatedBlood;
            out wasteGas : WasteGas;
        }
        action gasExchange : GasExchange {
            in deoxygenatedBlood @ bloodIn;
            in oxygen @ oxygenIn;
            out oxygenatedBlood @ bloodOut;
            out wasteGas @ wasteOut;
        }

        stateMachine MembraneStates {
            state inactive;
            state active;
            transition inactive -> active on bloodFlowDetected;
            transition active -> inactive on bloodFlowStopped;
        }
    }

    // ==================== HEAT EXCHANGER ====================
    part def HeatExchanger {
        port bloodIn : BloodInPort;
        port bloodOut : BloodOutPort;

        attribute targetTemperature : TemperatureValue;
        attribute currentTemperature : TemperatureValue;
        attribute heatingPower : Real;

        action def RegulateTemperature {
            in blood : Blood;
            out regulatedBlood : Blood;
        }
        action regulateTemperature : RegulateTemperature {
            in blood @ bloodIn;
            out regulatedBlood @ bloodOut;
        }

        stateMachine ExchangerStates {
            state idle;
            state heating;
            state cooling;
            state stable;
            transition idle -> heating on start;
            transition heating -> stable when currentTemperature.value >= targetTemperature.value;
            transition cooling -> stable when currentTemperature.value <= targetTemperature.value;
            transition stable -> heating when currentTemperature.value < targetTemperature.value;
            transition stable -> cooling when currentTemperature.value > targetTemperature.value;
        }
    }

    // ==================== GAS FLOW REGULATOR ====================
    part def GasFlowRegulator {
        port oxygenOut : OxygenOutPort;
        port controlIn : ControlInPort;

        attribute flowRate : O2FlowRateValue;
        attribute targetFlowRate : O2FlowRateValue;

        action def RegulateOxygen {
            out oxygen : Oxygen;
        }
        action regulateOxygen : RegulateOxygen {
            out oxygen @ oxygenOut;
        }

        stateMachine RegulatorStates {
            state idle;
            state regulating;
            transition idle -> regulating on start;
            transition regulating -> idle on stop;
            transition regulating -> regulating on adjustFlow;
        }
    }

    // ==================== SAFETY VALVE ====================
    part def SafetyValve {
        port bloodIn : BloodInPort;
        port bloodOut : BloodOutPort;
        port ventPort : VentOutPort;

        attribute thresholdPressure : PressureValue;
        attribute currentPressure : PressureValue;
        attribute isOpen : Boolean;

        action def ReleasePressure {
            out ventedBlood : Blood;
        }
        action releasePressure : ReleasePressure {
            out ventedBlood @ ventPort;
        }

        stateMachine ValveStates {
            state closed {
                doc /* Valve is closed, blood flows through normally. */;
            }
            state open {
                doc /* Valve is open, venting excess pressure. */;
            }
            transition closed -> open when currentPressure.value > thresholdPressure.value;
            transition open -> closed when currentPressure.value <= thresholdPressure.value;
        }
    }

    // ==================== SENSORS ====================
    part def OxygenSaturationSensor {
        port bloodIn : BloodInPort;
        port signalOut : SignalOutPort;

        attribute saturation : SaturationValue;

        action def MeasureSaturation {
            in blood : Blood;
            out measurement : Real;
        }
        action measure : MeasureSaturation {
            in blood @ bloodIn;
            out measurement @ signalOut;
        }

        stateMachine SensorStates {
            state idle;
            state measuring;
            transition idle -> measuring on start;
            transition measuring -> idle on stop;
        }
    }

    part def PressureSensor {
        port bloodIn : BloodInPort;
        port signalOut : SignalOutPort;

        attribute pressure : PressureValue;

        action def MeasurePressure {
            in blood : Blood;
            out measurement : Real;
        }
        action measure : MeasurePressure {
            in blood @ bloodIn;
            out measurement @ signalOut;
        }

        stateMachine SensorStates {
            state idle;
            state measuring;
            transition idle -> measuring on start;
            transition measuring -> idle on stop;
        }
    }

    part def TemperatureSensor {
        port bloodIn : BloodInPort;
        port signalOut : SignalOutPort;

        attribute temperature : TemperatureValue;

        action def MeasureTemperature {
            in blood : Blood;
            out measurement : Real;
        }
        action measure : MeasureTemperature {
            in blood @ bloodIn;
            out measurement @ signalOut;
        }

        stateMachine SensorStates {
            state idle;
            state measuring;
            transition idle -> measuring on start;
            transition measuring -> idle on stop;
        }
    }

    part def FlowRateSensor {
        port bloodIn : BloodInPort;
        port signalOut : SignalOutPort;

        attribute flowRate : BloodFlowRateValue;

        action def MeasureFlowRate {
            in blood : Blood;
            out measurement : Real;
        }
        action measure : MeasureFlowRate {
            in blood @ bloodIn;
            out measurement @ signalOut;
        }

        stateMachine SensorStates {
            state idle;
            state measuring;
            transition idle -> measuring on start;
            transition measuring -> idle on stop;
        }
    }

    // ==================== ALARM SYSTEM ====================
    part def AlarmSystem {
        port controlIn : ControlInPort;

        attribute lowO2AlarmActive : Boolean;
        attribute highPressureAlarmActive : Boolean;
        attribute temperatureAlarmActive : Boolean;
        attribute alarmSeverity : Real;

        action def TriggerAlarm {
            in command : Real;
        }
        action triggerAlarm : TriggerAlarm {
            in command @ controlIn;
        }

        stateMachine AlarmStates {
            state silent;
            state lowO2Warning;
            state highPressureWarning;
            state temperatureWarning;
            state criticalAlarm;
            transition silent -> lowO2Warning on lowO2Detected;
            transition silent -> highPressureWarning on highPressureDetected;
            transition silent -> temperatureWarning on temperatureAnomalyDetected;
            transition lowO2Warning -> silent on alarmReset;
            transition highPressureWarning -> silent on alarmReset;
            transition temperatureWarning -> silent on alarmReset;
            transition lowO2Warning -> criticalAlarm on conditionWorsens;
            transition highPressureWarning -> criticalAlarm on conditionWorsens;
            transition temperatureWarning -> criticalAlarm on conditionWorsens;
            transition criticalAlarm -> silent on reset;
        }
    }

    // ==================== CONTROL MODULE ====================
    part def ControlModule {
        port saturationIn : SignalInPort;
        port pressureIn : SignalInPort;
        port temperatureIn : SignalInPort;
        port flowIn : SignalInPort;
        port pumpControlOut : ControlOutPort;
        port gasControlOut : ControlOutPort;
        port alarmControlOut : ControlOutPort;

        attribute targetSaturation : SaturationValue;
        attribute targetPressure : PressureValue;
        attribute targetTemperature : TemperatureValue;
        attribute targetFlowRate : BloodFlowRateValue;
        attribute currentSaturation : SaturationValue;
        attribute currentPressure : PressureValue;
        attribute currentTemperature : TemperatureValue;
        attribute currentFlowRate : BloodFlowRateValue;
        attribute lowO2Threshold : SaturationValue;
        attribute highPressureThreshold : PressureValue;
        attribute highTempThreshold : TemperatureValue;

        action def AdjustPumpSpeed {
            in currentSaturation : Real;
            in currentFlowRate : Real;
            out pumpSpeedCommand : Real;
        }
        action def AdjustOxygenFlow {
            in currentSaturation : Real;
            out gasFlowCommand : Real;
        }
        action def EvaluateAlarms {
            in currentSaturation : Real;
            in currentPressure : Real;
            in currentTemperature : Real;
            out alarmCommand : Real;
        }
        action adjustPumpSpeed : AdjustPumpSpeed;
        action adjustOxygenFlow : AdjustOxygenFlow;
        action evaluateAlarms : EvaluateAlarms;

        stateMachine OperatingStates {
            state standby {
                doc /* System is initialized and waiting for operator commands. */;
            }
            state priming {
                doc /* Circuit is being filled with saline to remove air bubbles. */;
            }
            state operating {
                doc /* System is actively processing blood — gas exchange, heating, and monitoring. */;
            }
            state emergencyShutdown {
                doc /* Immediate stop of all actuators. Pump halts, gas flow stops, alarms activated. */;
            }
            transition standby -> priming on startPriming;
            transition priming -> operating when primingComplete;
            transition operating -> standby on normalStop;
            transition standby -> emergencyShutdown on emergencyStop;
            transition priming -> emergencyShutdown on emergencyStop;
            transition operating -> emergencyShutdown on emergencyStop;
            transition emergencyShutdown -> standby on reset;
        }
    }

    // ==================== PATIENT CONTEXT ====================
    part def Patient {
        port venousOut : BloodOutPort;
        port arterialIn : BloodInPort;
        attribute bodyTemperature : TemperatureValue;
        attribute venousSaturation : SaturationValue;
        attribute arterialSaturation : SaturationValue;
    }

    // ==================== TOP-LEVEL ECMO SYSTEM ====================
    part def ECMO {
        part patient : Patient;
        part bloodPump : BloodPump;
        part heatExchanger : HeatExchanger;
        part membrane : HollowFiberMembrane;
        part gasRegulator : GasFlowRegulator;
        part safetyValve : SafetyValve;
        part saturationSensor : OxygenSaturationSensor;
        part pressureSensor : PressureSensor;
        part temperatureSensor : TemperatureSensor;
        part flowSensor : FlowRateSensor;
        part alarm : AlarmSystem;
        part controlModule : ControlModule;

        // ---- Blood circuit connections (main flow path) ----
        connection patientVenousToPump : BloodConnection
            connect patient.venousOut to bloodPump.bloodIn;
        connection pumpToHeatExchanger : BloodConnection
            connect bloodPump.bloodOut to heatExchanger.bloodIn;
        connection heatExchangerToSafetyValve : BloodConnection
            connect heatExchanger.bloodOut to safetyValve.bloodIn;
        connection safetyValveToMembrane : BloodConnection
            connect safetyValve.bloodOut to membrane.bloodIn;
        connection membraneToPatient : BloodConnection
            connect membrane.bloodOut to patient.arterialIn;

        // ---- Gas circuit connections ----
        connection gasToMembrane : OxygenConnection
            connect gasRegulator.oxygenOut to membrane.oxygenIn;

        // ---- Sensor sampling connections (blood to sensors) ----
        connection pumpToFlowSensor : BloodConnection
            connect bloodPump.bloodOut to flowSensor.bloodIn;
        connection pumpToSaturationSensor : BloodConnection
            connect bloodPump.bloodOut to saturationSensor.bloodIn;
        connection safetyValveToPressureSensor : BloodConnection
            connect safetyValve.bloodOut to pressureSensor.bloodIn;
        connection heatExchangerToTemperatureSensor : BloodConnection
            connect heatExchanger.bloodOut to temperatureSensor.bloodIn;

        // ---- Signal connections (sensors to control module) ----
        connection saturationSignal : SignalConnection
            connect saturationSensor.signalOut to controlModule.saturationIn;
        connection pressureSignal : SignalConnection
            connect pressureSensor.signalOut to controlModule.pressureIn;
        connection temperatureSignal : SignalConnection
            connect temperatureSensor.signalOut to controlModule.temperatureIn;
        connection flowSignal : SignalConnection
            connect flowSensor.signalOut to controlModule.flowIn;

        // ---- Control connections (control module to actuators) ----
        connection pumpControl : ControlConnection
            connect controlModule.pumpControlOut to bloodPump.controlIn;
        connection gasControl : ControlConnection
            connect controlModule.gasControlOut to gasRegulator.controlIn;
        connection alarmControl : ControlConnection
            connect controlModule.alarmControlOut to alarm.controlIn;

        // ---- System-level state machine ----
        stateMachine SystemStates {
            state standby {
                doc /* System initialized but not processing blood. Awaiting operator commands. */;
            }
            state priming {
                doc /* Circuit is filled with saline solution to remove all air before patient connection. */;
            }
            state operating {
                doc /* Active blood processing: pump running, gas exchange ongoing, all sensors monitoring. */;
            }
            state emergencyShutdown {
                doc /* Immediate shutdown: pump halted, gas flow stopped, alarms triggered. */;
            }
            transition standby -> priming on startPriming;
            transition priming -> operating when primingComplete;
            transition operating -> standby on normalStop;
            transition standby -> emergencyShutdown on emergencyStop;
            transition priming -> emergencyShutdown on emergencyStop;
            transition operating -> emergencyShutdown on emergencyStop;
            transition emergencyShutdown -> standby on reset;
        }
    }

    // ==================== REQUIREMENTS ====================

    requirement def GasExchangeRequirement {
        doc /* The system shall enrich venous blood with oxygen and remove carbon dioxide via the hollow fiber membrane. */;
        subject system : ECMO;
        attribute minO2Saturation : Real = 95;
        attribute minCO2Removal : Real = 200;
        require system.controlModule.targetSaturation.value >= minO2Saturation;
        require system.membrane.co2RemovalRate.value >= minCO2Removal;
    }

    requirement def FlowControlRequirement {
        doc /* The blood pump shall maintain a precisely controlled blood flow rate within therapeutic range. */;
        subject system : ECMO;
        attribute minFlowRate : Real = 2000;
        attribute maxFlowRate : Real = 5000;
        require system.bloodPump.currentFlowRate.value >= minFlowRate;
        require system.bloodPump.currentFlowRate.value <= maxFlowRate;
    }

    requirement def TemperatureRegulationRequirement {
        doc /* The heat exchanger shall regulate blood temperature to safe body temperature range. */;
        subject system : ECMO;
        attribute minBodyTemp : Real = 36;
        attribute maxBodyTemp : Real = 38;
        require system.heatExchanger.currentTemperature.value >= minBodyTemp;
        require system.heatExchanger.currentTemperature.value <= maxBodyTemp;
    }

    requirement def PressureSafetyRequirement {
        doc /* The safety valve shall release pressure when it exceeds the critical threshold to protect the patient. */;
        subject system : ECMO;
        attribute criticalPressure : Real = 350;
        require system.safetyValve.thresholdPressure.value <= criticalPressure;
        require system.safetyValve.currentPressure.value <= system.safetyValve.thresholdPressure.value;
    }

    requirement def AlarmRequirement {
        doc /* The control module shall trigger alarms for low oxygen saturation, high pressure, or temperature anomalies. */;
        subject system : ECMO;
        attribute lowO2AlarmThreshold : Real = 90;
        attribute highPressureAlarmThreshold : Real = 400;
        attribute highTempAlarmThreshold : Real = 39;
        require system.controlModule.lowO2Threshold.value <= lowO2AlarmThreshold;
        require system.controlModule.highPressureThreshold.value <= highPressureAlarmThreshold;
        require system.controlModule.highTempThreshold.value <= highTempAlarmThreshold;
    }

    requirement def StateTransitionRequirement {
        doc /* The system shall operate through Standby, Priming, Operating, and Emergency Shutdown states with proper transitions. It starts in Standby, must go through Priming before Operating, and can be stopped normally or shut down immediately in an emergency. */;
        subject system : ECMO;
        attribute hasStandbyState : Boolean = true;
        attribute hasPrimingState : Boolean = true;
        attribute hasOperatingState : Boolean = true;
        attribute hasEmergencyShutdownState : Boolean = true;
        require hasStandbyState;
        require hasPrimingState;
        require hasOperatingState;
        require hasEmergencyShutdownState;
    }

    requirement def PrimingRequirement {
        doc /* The system shall fill the circuit with saline solution during Priming to remove all air before entering Operating state. */;
        subject system : ECMO;
        attribute primingComplete : Boolean;
        require primingComplete;
    }

    requirement def EmergencyStopRequirement {
        doc /* The system shall allow immediate emergency shutdown from any state, stopping the pump and gas flow and activating alarms. */;
        subject system : ECMO;
        attribute emergencyStopAvailable : Boolean = true;
        require emergencyStopAvailable;
    }

    requirement ECMO_System_Requirements {
        doc /* The ECMO system shall provide safe and effective extracorporeal membrane oxygenation for patients with severe respiratory failure. */;
        subject system : ECMO;
        satisfy gasExchange : GasExchangeRequirement;
        satisfy flowControl : FlowControlRequirement;
        satisfy temperatureRegulation : TemperatureRegulationRequirement;
        satisfy pressureSafety : PressureSafetyRequirement;
        satisfy alarms : AlarmRequirement;
        satisfy stateTransitions : StateTransitionRequirement;
        satisfy priming : PrimingRequirement;
        satisfy emergencyStop : EmergencyStopRequirement;
    }

    // ==================== INSTANTIATION ====================
    part ecmoSystem : ECMO {
        doc /* Instance of the ECMO system for patient treatment. */;
    }
}
