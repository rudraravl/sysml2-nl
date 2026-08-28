package IndustrialProcessingMachineModel {
    private import ScalarValues::*;
    private import ISQ::*;

    // ===== Value Type Definitions =====
    attribute def RotationalSpeed :> ISQ::AngularVelocityValue;
    attribute def MaterialFeedRate :> ISQ::MassFlowRateValue;
    attribute def CoolantFlowRate :> ISQ::VolumeFlowRateValue;
    attribute def CorePower :> ISQ::PowerValue;
    attribute def CoreTemperature :> ISQ::TemperatureValue;
    attribute def CollectorCapacity :> ISQ::MassValue;
    attribute def ProcessDuration :> ISQ::TimeValue;
    attribute def QualityGrade :> Integer;

    // ===== Item Definitions =====
    item def RawMaterial;
    item def RefinedProduct;
    item def CoolantFluid;
    item def ElectricalEnergy;

    // ===== Signal Definitions =====
    attribute def StartCommand;
    attribute def StopCommand;
    attribute def ResetCommand;
    attribute def JobCompleteSignal;
    attribute def OverheatDetected;
    attribute def PowerFaultDetected;
    attribute def CollectorFullSignal;
    attribute def WarmupCompleteSignal;
    attribute def CooldownCompleteSignal;

    // ===== Port Definitions =====
    port def MaterialOutPort { out item material : RawMaterial; }
    port def MaterialInPort { in item material : RawMaterial; }
    port def ProductOutPort { out item product : RefinedProduct; }
    port def ProductInPort { in item product : RefinedProduct; }
    port def CoolantOutPort { out item coolant : CoolantFluid; }
    port def CoolantInPort { in item coolant : CoolantFluid; }
    port def PowerOutPort { out item energy : ElectricalEnergy; }
    port def PowerInPort { in item energy : ElectricalEnergy; }
    port def CommandOutPort { out attribute command; }
    port def CommandInPort { in attribute command; }
    port def CoreStatusOutPort {
        out attribute temperature : CoreTemperature;
        out attribute speed : RotationalSpeed;
        out attribute power : CorePower;
    }
    port def CoreStatusInPort {
        in attribute temperature : CoreTemperature;
        in attribute speed : RotationalSpeed;
        in attribute power : CorePower;
    }
    port def FeederStatusOutPort { out attribute feedRate : MaterialFeedRate; }
    port def FeederStatusInPort { in attribute feedRate : MaterialFeedRate; }
    port def CoolingStatusOutPort { out attribute flowRate : CoolantFlowRate; }
    port def CoolingStatusInPort { in attribute flowRate : CoolantFlowRate; }
    port def CollectorStatusOutPort { out attribute mass : CollectorCapacity; }
    port def CollectorStatusInPort { in attribute mass : CollectorCapacity; }
    port def PSUStatusOutPort { out attribute power : CorePower; }
    port def PSUStatusInPort { in attribute power : CorePower; }

    // ===== Action Definitions =====
    action def SupplyRawMaterial {
        out material : RawMaterial;
        attribute rate : MaterialFeedRate;
    }
    action def TransformMaterial {
        in material : RawMaterial;
        out product : RefinedProduct;
    }
    action def SupplyElectricalPower {
        out energy : ElectricalEnergy;
        attribute level : CorePower;
    }
    action def CirculateCoolant {
        in returnFluid : CoolantFluid;
        out supplyFluid : CoolantFluid;
        attribute rate : CoolantFlowRate;
    }
    action def CollectProduct {
        in product : RefinedProduct;
        attribute totalCollected : CollectorCapacity;
    }
    action def MonitorVitals {
        out speed : RotationalSpeed;
        out temperature : CoreTemperature;
        out powerConsumption : CorePower;
    }
    action def AdjustParameters {
        in currentSpeed : RotationalSpeed;
        in currentTemp : CoreTemperature;
        in currentPower : CorePower;
        out feedRateCmd : MaterialFeedRate;
        out coolantCmd : CoolantFlowRate;
        out powerCmd : CorePower;
    }
    action def ControlLoop {
        loop action controlCycle {
            action monitor : MonitorVitals {
                out speed;
                out temperature;
                out powerConsumption;
            }
            then action adjust : AdjustParameters {
                in currentSpeed = monitor.speed;
                in currentTemp = monitor.temperature;
                in currentPower = monitor.powerConsumption;
                out feedRateCmd;
                out coolantCmd;
                out powerCmd;
            }
        }
    }
    action def WarmUpSequence;
    action def CooldownSequence;
    action def PerformEmergencyShutdown;
    action def ProcessOperation {
        perform action controlLoop : ControlLoop;
        perform action monitor : MonitorVitals;
    }

    // ===== Part Definitions =====
    part def MaterialFeeder {
        port materialOut : MaterialOutPort;
        port commandIn : CommandInPort;
        port statusOut : FeederStatusOutPort;
        attribute feedRate : MaterialFeedRate;
        perform action supply : SupplyRawMaterial;
    }

    part def ProcessingCore {
        port materialIn : MaterialInPort;
        port productOut : ProductOutPort;
        port coolantIntake : CoolantInPort;
        port coolantOutflow : CoolantOutPort;
        port powerInput : PowerInPort;
        port commandIn : CommandInPort;
        port statusOut : CoreStatusOutPort;
        attribute currentTemperature : CoreTemperature;
        attribute operatingSpeed : RotationalSpeed;
        attribute powerConsumption : CorePower;
        attribute maxSafeTemp : CoreTemperature;
        attribute optimalTemp : CoreTemperature;
        perform action transform : TransformMaterial;
    }

    part def PowerSupplyUnit {
        port powerOut : PowerOutPort;
        port commandIn : CommandInPort;
        port statusOut : PSUStatusOutPort;
        attribute outputPower : CorePower;
        perform action supply : SupplyElectricalPower;
    }

    part def CoolingSystem {
        port coolantOut : CoolantOutPort;
        port coolantReturn : CoolantInPort;
        port commandIn : CommandInPort;
        port statusOut : CoolingStatusOutPort;
        attribute flowRate : CoolantFlowRate;
        perform action circulate : CirculateCoolant;
    }

    part def ProductCollector {
        port productIn : ProductInPort;
        port commandIn : CommandInPort;
        port statusOut : CollectorStatusOutPort;
        attribute currentMass : CollectorCapacity;
        attribute maxCapacity : CollectorCapacity;
        perform action collect : CollectProduct;
    }

    part def ControlSystem {
        port commandOut : CommandOutPort;
        port coreStatusIn : CoreStatusInPort;
        port feederStatusIn : FeederStatusInPort;
        port coolingStatusIn : CoolingStatusInPort;
        port collectorStatusIn : CollectorStatusInPort;
        port psuStatusIn : PSUStatusInPort;
        attribute targetSpeed : RotationalSpeed;
        attribute targetTemp : CoreTemperature;
        attribute maxOperatingTemp : CoreTemperature;
        perform action monitor : MonitorVitals;
        perform action adjust : AdjustParameters;
        perform action controlLoop : ControlLoop;
        perform action emergencyShutdown : PerformEmergencyShutdown;
    }

    // ===== Action Usages =====
    action warmUp : WarmUpSequence;
    action coolDown : CooldownSequence;
    action emergencyStop : PerformEmergencyShutdown;
    action monitorVitals : MonitorVitals;
    action controlLoopAction : ControlLoop;
    action processOperation : ProcessOperation;

    // ===== System Integration =====
    part industrialMachine {
        part feeder : MaterialFeeder;
        part core : ProcessingCore;
        part psu : PowerSupplyUnit;
        part cooling : CoolingSystem;
        part collector : ProductCollector;
        part controller : ControlSystem;

        // Material flow
        connect feeder.materialOut to core.materialIn;
        connect core.productOut to collector.productIn;

        // Power distribution
        connect psu.powerOut to core.powerInput;

        // Coolant circulation
        connect cooling.coolantOut to core.coolantIntake;
        connect core.coolantOutflow to cooling.coolantReturn;

        // Control signal distribution
        connect controller.commandOut to feeder.commandIn;
        connect controller.commandOut to core.commandIn;
        connect controller.commandOut to psu.commandIn;
        connect controller.commandOut to cooling.commandIn;
        connect controller.commandOut to collector.commandIn;

        // Status feedback aggregation
        connect core.statusOut to controller.coreStatusIn;
        connect feeder.statusOut to controller.feederStatusIn;
        connect cooling.statusOut to controller.coolingStatusIn;
        connect collector.statusOut to controller.collectorStatusIn;
        connect psu.statusOut to controller.psuStatusIn;

        // Machine lifecycle state machine
        state lifecycle {
            entry; then offline;

            state offline {
                doc /* All subsystems powered down; machine is in a safe, idle state. */
            }

            accept StartCommand
                if core.currentTemperature < core.maxSafeTemp
                then startup;

            state startup {
                doc /* Controlled warmup sequence to reach optimal operating temperature. */
                do warmUp;
            }

            accept WarmupCompleteSignal
                if core.currentTemperature >= core.optimalTemp
                then processing;

            state processing {
                doc /* Main processing state: continuous material transformation with active control loop. */
                do processOperation;
            }

            accept StopCommand then shutdown;
            accept JobCompleteSignal then shutdown;
            accept OverheatDetected then emergency;
            accept PowerFaultDetected then emergency;

            state shutdown {
                doc /* Managed shutdown and cooldown sequence to return to a safe offline state. */
                do coolDown;
            }

            accept CooldownCompleteSignal
                if core.currentTemperature <= core.maxSafeTemp
                then offline;

            state emergency {
                doc /* Emergency shutdown: all processing immediately halted, maximum cooling applied. */
                entry emergencyStop;
            }

            accept ResetCommand then offline;
        }
    }

    // ===== Requirement Definitions =====
    requirement def ContinuousProcessingReq {
        doc /* The machine shall continuously transform raw material into a refined, high-quality product. */
        attribute processingRate : MaterialFeedRate;
        attribute minProcessingRate : MaterialFeedRate;
        require constraint { processingRate >= minProcessingRate }
    }

    requirement def TemperatureSafetyReq {
        doc /* The cooling system shall maintain the processing core below the maximum safe operating temperature. */
        attribute coreTemp : CoreTemperature;
        attribute maxSafe : CoreTemperature;
        require constraint { coreTemp <= maxSafe }
    }

    requirement def StartupSequenceReq {
        doc /* The machine shall perform a controlled startup, warming to optimal operating temperature before processing. */
        attribute startupTime : ProcessDuration;
        attribute maxStartupTime : ProcessDuration;
        require constraint { startupTime <= maxStartupTime }
    }

    requirement def CooldownSequenceReq {
        doc /* The machine shall undergo a managed shutdown and cooldown before returning to a safe offline state. */
        attribute cooldownTime : ProcessDuration;
        attribute maxCooldownTime : ProcessDuration;
        require constraint { cooldownTime <= maxCooldownTime }
    }

    requirement def EmergencyShutdownReq {
        doc /* The control system shall trigger emergency shutdown upon detecting overheating or power failure. */
        attribute faultDetected : Boolean;
        attribute emergencyTriggered : Boolean;
        require constraint { faultDetected implies emergencyTriggered }
    }

    requirement def ControlLoopReq {
        doc /* The control system shall continuously monitor vital signs and adjust operating parameters in a closed control loop. */
        attribute monitoringActive : Boolean;
        require constraint { monitoringActive == true }
    }

    requirement def CollectorCapacityReq {
        doc /* The product collector shall hold product up to its maximum capacity before requiring emptying. */
        attribute collectedMass : CollectorCapacity;
        attribute capacity : CollectorCapacity;
        require constraint { collectedMass <= capacity }
    }

    requirement def PowerSupplySufficiencyReq {
        doc /* The power supply shall provide sufficient high-voltage electrical power for the transformation. */
        attribute suppliedPower : CorePower;
        attribute requiredPower : CorePower;
        require constraint { suppliedPower >= requiredPower }
    }

    requirement def FeedRateControlReq {
        doc /* The material feeder shall supply raw material at a controlled and consistent rate. */
        attribute actualFeedRate : MaterialFeedRate;
        attribute targetFeedRate : MaterialFeedRate;
        require constraint { actualFeedRate >= targetFeedRate - 0.1 and actualFeedRate <= targetFeedRate + 0.1 }
    }

    requirement def ProductQualityReq {
        doc /* The processing core shall produce a refined, high-quality product from the raw material. */
        attribute qualityGrade : QualityGrade;
        attribute minQualityGrade : QualityGrade;
        require constraint { qualityGrade >= minQualityGrade }
    }

    // ===== Requirement Usages =====
    requirement continuousProcessingRequirement : ContinuousProcessingReq;
    requirement temperatureSafetyRequirement : TemperatureSafetyReq;
    requirement startupSequenceRequirement : StartupSequenceReq;
    requirement cooldownSequenceRequirement : CooldownSequenceReq;
    requirement emergencyShutdownRequirement : EmergencyShutdownReq;
    requirement controlLoopRequirement : ControlLoopReq;
    requirement collectorCapacityRequirement : CollectorCapacityReq;
    requirement powerSupplySufficiencyRequirement : PowerSupplySufficiencyReq;
    requirement feedRateControlRequirement : FeedRateControlReq;
    requirement productQualityRequirement : ProductQualityReq;
}
