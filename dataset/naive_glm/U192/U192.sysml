package CranialDrillSystem {

    import ScalarValues::*;

    // ===== Units =====
    unit mm;
    unit mL;
    unit mm_per_s;
    unit degC;
    unit Nm;
    unit rpm;
    unit mL_per_min;
    unit W;
    unit V;
    unit A;
    unit s;

    // ===== Value Types =====
    value type Depth :> Real { unit mm; }
    value type Volume :> Real { unit mL; }
    value type PenetrationRate :> Real { unit mm_per_s; }
    value type Temperature :> Real { unit degC; }
    value type Torque :> Real { unit Nm; }
    value type RotationalSpeed :> Real { unit rpm; }
    value type CoolantFlowRate :> Real { unit mL_per_min; }
    value type Power :> Real { unit W; }
    value type Voltage :> Real { unit V; }
    value type Current :> Real { unit A; }
    value type Duration :> Real { unit s; }

    // ===== Items =====
    item def SterileCoolant;
    item def OperatorInput;
    item def SafetyAlert;

    // ===== Enumerations =====
    enum def AlertLevel {
        normal;
        warning;
        critical;
    }

    enum def SystemPhase {
        standby;
        preparation;
        activeDrilling;
        retraction;
        emergencyShutdown;
    }

    // ===== Port Definitions =====
    port def MechanicalDrivePort {
        out speed : RotationalSpeed;
        out torque : Torque;
    }

    port def CoolantFlowPort {
        out flowRate : CoolantFlowRate;
        item out coolant : SterileCoolant;
    }

    port def CommandPort {
        in operatorInput : OperatorInput;
    }

    port def DepthDataPort {
        out depth : Depth;
    }

    port def TemperatureDataPort {
        out temperature : Temperature;
    }

    port def TorqueDataPort {
        out torque : Torque;
    }

    port def PowerPort {
        out voltage : Voltage;
        out current : Current;
    }

    port def SafetyAlertPort {
        out alert : SafetyAlert;
        out alertLevel : AlertLevel;
    }

    // ===== Component Part Definitions =====

    part def ElectricMotor {
        attribute ratedSpeed : RotationalSpeed = 40000 [rpm];
        attribute ratedPower : Power = 120 [W];
        attribute currentSpeed : RotationalSpeed = 0 [rpm];
        attribute currentTorque : Torque = 0 [Nm];

        port speedCommandIn : ~MechanicalDrivePort;
        port driveOut : MechanicalDrivePort;
        port powerIn : ~PowerPort;

        action def Rotate {
            in commandedSpeed : RotationalSpeed;
            out actualSpeed : RotationalSpeed;
            out actualTorque : Torque;
        }
    }

    part def SpeedController {
        attribute minSpeed : RotationalSpeed = 0 [rpm];
        attribute maxSpeed : RotationalSpeed = 40000 [rpm];
        attribute currentCommandedSpeed : RotationalSpeed = 0 [rpm];
        attribute overrideActive : Boolean = false;

        port targetSpeedIn : ~MechanicalDrivePort;
        port torqueFeedback : ~TorqueDataPort;
        port motorCommand : MechanicalDrivePort;
        port overrideIn : ~MechanicalDrivePort;

        action def RegulateSpeed {
            in targetSpeed : RotationalSpeed;
            in torqueFeedback : Torque;
            in overrideSpeed : RotationalSpeed;
            in overrideActive : Boolean;
            out commandedSpeed : RotationalSpeed;
        }
    }

    part def DrillBitAssembly {
        attribute diameter : Depth = 3 [mm];
        attribute maxOperatingDepth : Depth = 25 [mm];
        attribute material : String = "Medical-grade Tungsten Carbide";
        attribute currentPenetration : Depth = 0 [mm];

        port driveIn : ~MechanicalDrivePort;
        port coolantIn : ~CoolantFlowPort;
        port cuttingTip : CoolantFlowPort;

        action def Cut {
            in speed : RotationalSpeed;
            in torque : Torque;
            in coolantFlow : CoolantFlowRate;
            out penetrationRate : PenetrationRate;
            out heatGenerated : Temperature;
        }
    }

    part def IrrigationPump {
        attribute maxFlowRate : CoolantFlowRate = 50 [mL_per_min];
        attribute currentFlowRate : CoolantFlowRate = 0 [mL_per_min];
        attribute overrideActive : Boolean = false;

        port flowCommandIn : ~CoolantFlowPort;
        port overrideCommandIn : ~CoolantFlowPort;
        port intake : ~CoolantFlowPort;
        port output : CoolantFlowPort;

        action def Pump {
            in commandedFlow : CoolantFlowRate;
            in overrideFlow : CoolantFlowRate;
            in overrideActive : Boolean;
            out actualFlow : CoolantFlowRate;
        }
    }

    part def CoolantReservoir {
        attribute capacity : Volume = 500 [mL];
        attribute currentLevel : Volume = 500 [mL];
        attribute lowLevelThreshold : Volume = 50 [mL];

        port coolantOut : CoolantFlowPort;

        action def SupplyCoolant {
            out coolant : SterileCoolant;
            out remainingLevel : Volume;
        }
    }

    part def DepthSensor {
        attribute accuracy : Depth = 0.01 [mm];
        attribute currentDepth : Depth = 0 [mm];

        port dataOut : DepthDataPort;

        action def MeasureDepth {
            in physicalPosition : Depth;
            out measuredDepth : Depth;
        }
    }

    part def TemperatureSensor {
        attribute accuracy : Temperature = 0.1 [degC];
        attribute maxRange : Temperature = 100 [degC];
        attribute currentTemperature : Temperature = 20 [degC];

        port dataOut : TemperatureDataPort;

        action def MeasureTemperature {
            in siteTemperature : Temperature;
            out measuredTemperature : Temperature;
        }
    }

    part def TorqueSensor {
        attribute accuracy : Torque = 0.005 [Nm];
        attribute maxRange : Torque = 5 [Nm];
        attribute currentTorque : Torque = 0 [Nm];

        port dataOut : TorqueDataPort;

        action def MeasureTorque {
            in appliedTorque : Torque;
            out measuredTorque : Torque;
        }
    }

    part def CentralControlProcessor {
        attribute targetDepth : Depth = 0 [mm];
        attribute currentDepth : Depth = 0 [mm];
        attribute currentTemperature : Temperature = 20 [degC];
        attribute currentTorque : Torque = 0 [Nm];
        attribute commandedSpeed : RotationalSpeed = 0 [rpm];
        attribute commandedCoolantFlow : CoolantFlowRate = 0 [mL_per_min];
        attribute systemPhase : SystemPhase = SystemPhase::standby;

        attribute commandReceived : Boolean = false;
        attribute sensorsValid : Boolean = false;
        attribute targetDepthReached : Boolean = false;
        attribute retractionComplete : Boolean = false;
        attribute safetyCritical : Boolean = false;
        attribute systemReset : Boolean = false;

        port operatorCommand : CommandPort;
        port depthInput : ~DepthDataPort;
        port tempInput : ~TemperatureDataPort;
        port torqueInput : ~TorqueDataPort;
        port speedCommandOut : MechanicalDrivePort;
        port coolantCommandOut : CoolantFlowPort;
        port safetyAlertIn : ~SafetyAlertPort;

        action def ProcessOperatorCommand {
            in input : OperatorInput;
            out target : Depth;
            out speedCommand : RotationalSpeed;
        }

        action def CoordinateDrilling {
            in depth : Depth;
            in temperature : Temperature;
            in torque : Torque;
            in target : Depth;
            out speedCommand : RotationalSpeed;
            out coolantCommand : CoolantFlowRate;
        }

        action def RetractDrill {
            out speedCommand : RotationalSpeed;
            out coolantCommand : CoolantFlowRate;
        }

        state machine ControlStateMachine {
            state standby;
            state preparation;
            state activeDrilling;
            state retraction;
            state emergencyShutdown;

            transition from standby to preparation when commandReceived;
            transition from preparation to activeDrilling when sensorsValid;
            transition from activeDrilling to retraction when targetDepthReached;
            transition from retraction to standby when retractionComplete;
            transition from activeDrilling to emergencyShutdown when safetyCritical;
            transition from preparation to emergencyShutdown when safetyCritical;
            transition from emergencyShutdown to standby when systemReset;
        }
    }

    part def SafetyInterlockSystem {
        attribute maxSafeDepth : Depth = 25 [mm];
        attribute maxSafeTemperature : Temperature = 40 [degC];
        attribute maxSafeTorque : Torque = 2 [Nm];
        attribute monitoring : Boolean = true;
        attribute currentAlertLevel : AlertLevel = AlertLevel::normal;

        attribute depthWarning : Boolean = false;
        attribute tempWarning : Boolean = false;
        attribute torqueWarning : Boolean = false;
        attribute limitExceeded : Boolean = false;
        attribute conditionsNormalized : Boolean = false;
        attribute conditionsWorsen : Boolean = false;
        attribute systemReset : Boolean = false;

        port depthMonitor : ~DepthDataPort;
        port tempMonitor : ~TemperatureDataPort;
        port torqueMonitor : ~TorqueDataPort;
        port alertOut : SafetyAlertPort;
        port motorOverride : MechanicalDrivePort;
        port coolantOverride : CoolantFlowPort;

        action def EvaluateSafety {
            in depth : Depth;
            in temperature : Temperature;
            in torque : Torque;
            out alert : SafetyAlert;
            out alertLevel : AlertLevel;
        }

        action def TriggerProtectiveAction {
            in alertLevel : AlertLevel;
            out reduceSpeed : Boolean;
            out increaseCoolant : Boolean;
            out emergencyStop : Boolean;
        }

        state machine InterlockStateMachine {
            state monitoring;
            state warning;
            state protectiveAction;
            state shutdown;

            transition from monitoring to warning when depthWarning or tempWarning or torqueWarning;
            transition from warning to monitoring when conditionsNormalized;
            transition from warning to protectiveAction when limitExceeded;
            transition from protectiveAction to monitoring when conditionsNormalized;
            transition from protectiveAction to shutdown when conditionsWorsen;
            transition from shutdown to monitoring when systemReset;
        }
    }

    // ===== System Assembly =====

    part def CranialDrill {
        attribute systemId : String;
        attribute modelNumber : String = "ND-2024";
        attribute firmwareVersion : String = "1.0.0";

        port externalPower : PowerPort;
        port operatorInterface : CommandPort;

        part motor : ElectricMotor;
        part speedController : SpeedController;
        part drillBit : DrillBitAssembly;
        part pump : IrrigationPump;
        part reservoir : CoolantReservoir;
        part depthSensor : DepthSensor;
        part tempSensor : TemperatureSensor;
        part torqueSensor : TorqueSensor;
        part controlProcessor : CentralControlProcessor;
        part safetyInterlock : SafetyInterlockSystem;

        connection powerConn connect externalPower to motor.powerIn;
        connection speedCmd connect controlProcessor.speedCommandOut to speedController.targetSpeedIn;
        connection motorCmd connect speedController.motorCommand to motor.speedCommandIn;
        connection driveConn connect motor.driveOut to drillBit.driveIn;
        connection coolantSupply connect reservoir.coolantOut to pump.intake;
        connection coolantDelivery connect pump.output to drillBit.coolantIn;
        connection tipCoolant connect drillBit.coolantIn to drillBit.cuttingTip;
        connection depthData connect depthSensor.dataOut to controlProcessor.depthInput;
        connection tempData connect tempSensor.dataOut to controlProcessor.tempInput;
        connection torqueData connect torqueSensor.dataOut to controlProcessor.torqueInput;
        connection depthMon connect depthSensor.dataOut to safetyInterlock.depthMonitor;
        connection tempMon connect tempSensor.dataOut to safetyInterlock.tempMonitor;
        connection torqueMon connect torqueSensor.dataOut to safetyInterlock.torqueMonitor;
        connection alertConn connect safetyInterlock.alertOut to controlProcessor.safetyAlertIn;
        connection speedOverride connect safetyInterlock.motorOverride to speedController.overrideIn;
        connection coolantOverrideConn connect safetyInterlock.coolantOverride to pump.overrideCommandIn;
        connection operatorConn connect operatorInterface to controlProcessor.operatorCommand;
    }

    // ===== Requirements =====

    requirement def ThermalSafetyRequirement {
        doc /* The system shall prevent thermal damage to bone and underlying neural tissues
             by maintaining drilling site temperature below safe limits. */
        attribute maxBoneTemperature : Temperature = 40 [degC];
        subject drill : CranialDrill;
        require drill.safetyInterlock.maxSafeTemperature <= maxBoneTemperature;
    }

    requirement def DepthControlRequirement {
        doc /* The system shall achieve the operator-specified target drilling depth
             with high accuracy and without exceeding safe depth limits. */
        attribute maxSafeDepth : Depth = 25 [mm];
        attribute depthAccuracy : Depth = 0.1 [mm];
        subject drill : CranialDrill;
        require drill.depthSensor.accuracy <= depthAccuracy;
        require drill.safetyInterlock.maxSafeDepth <= maxSafeDepth;
    }

    requirement def IrrigationRequirement {
        doc /* The system shall deliver a continuous flow of sterile coolant to the
             drilling tip throughout the active drilling phase. */
        attribute minFlowRate : CoolantFlowRate = 10 [mL_per_min];
        subject drill : CranialDrill;
        require drill.pump.maxFlowRate >= minFlowRate;
    }

    requirement def TorqueSafetyRequirement {
        doc /* The system shall detect excessive torque indicating bit binding or
             density changes and trigger appropriate protective actions. */
        attribute maxTorque : Torque = 2 [Nm];
        subject drill : CranialDrill;
        require drill.safetyInterlock.maxSafeTorque <= maxTorque;
    }

    requirement def EmergencyShutdownRequirement {
        doc /* The system shall initiate emergency shutdown when any safety limit
             for depth, temperature, or torque is exceeded. */
        subject drill : CranialDrill;
        require drill.safetyInterlock.maxSafeDepth <= 25 [mm];
        require drill.safetyInterlock.maxSafeTemperature <= 40 [degC];
        require drill.safetyInterlock.maxSafeTorque <= 2 [Nm];
    }

    requirement def StateTransitionRequirement {
        doc /* The system shall operate through distinct phases: standby, preparation,
             active drilling, controlled retraction, and emergency shutdown. */
        subject drill : CranialDrill;
        require drill.controlProcessor.systemPhase == SystemPhase::standby or
                drill.controlProcessor.systemPhase == SystemPhase::preparation or
                drill.controlProcessor.systemPhase == SystemPhase::activeDrilling or
                drill.controlProcessor.systemPhase == SystemPhase::retraction or
                drill.controlProcessor.systemPhase == SystemPhase::emergencyShutdown;
    }

    // ===== Requirement Usages and Satisfaction =====

    part cranialDrillSystem : CranialDrill;

    requirement thermalSafetyReq : ThermalSafetyRequirement;
    requirement depthControlReq : DepthControlRequirement;
    requirement irrigationReq : IrrigationRequirement;
    requirement torqueSafetyReq : TorqueSafetyRequirement;
    requirement emergencyShutdownReq : EmergencyShutdownRequirement;
    requirement stateTransitionReq : StateTransitionRequirement;

    satisfy thermalSafetyReq by cranialDrillSystem;
    satisfy depthControlReq by cranialDrillSystem;
    satisfy irrigationReq by cranialDrillSystem;
    satisfy torqueSafetyReq by cranialDrillSystem;
    satisfy emergencyShutdownReq by cranialDrillSystem;
    satisfy stateTransitionReq by cranialDrillSystem;
}
