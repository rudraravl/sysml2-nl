package 'Cranial Drill System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def OperatorCommand;
    attribute def EmergencyStop;
    attribute def DepthTarget;
    attribute def SafetyAlert;
    
    item def ElectricalPower {
        attribute voltage : ISQ::VoltageValue;
        attribute current : ISQ::ElectricCurrentValue;
    }
    
    item def MechanicalDrive {
        attribute speed : ISQ::AngularVelocityValue;
        attribute torque : ISQ::TorqueValue;
    }
    
    item def CoolantFlow {
        attribute flowRate : ISQ::VolumeFlowRateValue;
        attribute temperature : ISQ::ThermodynamicTemperatureValue;
        attribute pressure : ISQ::PressureValue;
    }
    
    port def PowerPort {
        in item electricalPower : ElectricalPower;
    }
    
    port def DrivePort {
        out item mechanicalDrive : MechanicalDrive;
    }
    
    port def CoolantPort {
        in item coolantSupply : CoolantFlow;
        out item coolantReturn : CoolantFlow;
    }
    
    port def SensorPort {
        out depth : ISQ::LengthValue;
        out temperature : ISQ::ThermodynamicTemperatureValue;
        out torque : ISQ::TorqueValue;
    }
    
    port def ControlPort {
        in command : OperatorCommand;
        in targetDepth : DepthTarget;
        in emergencyStop : EmergencyStop;
        out status : SafetyAlert;
    }
    
    part def ElectricMotor {
        port powerInput : PowerPort;
        port driveOutput : DrivePort;
        
        attribute ratedPower : ISQ::PowerValue;
        attribute maxSpeed : ISQ::AngularVelocityValue;
        attribute efficiency : Real;
        
        action def GenerateTorque {
            in powerSupply : ElectricalPower;
            in commandedSpeed : ISQ::AngularVelocityValue;
            out outputTorque : ISQ::TorqueValue;
            out outputSpeed : ISQ::AngularVelocityValue;
        }
    }
    
    part def SpeedController {
        port controlInput : ControlPort;
        port motorDrive : DrivePort;
        
        attribute targetSpeed : ISQ::AngularVelocityValue;
        attribute speedTolerance : Real;
        
        action def RegulateSpeed {
            in desiredSpeed : ISQ::AngularVelocityValue;
            in actualSpeed : ISQ::AngularVelocityValue;
            out adjustedPower : ElectricalPower;
        }
    }
    
    part def DrillBitAssembly {
        port mechanicalInput : DrivePort;
        port coolantInterface : CoolantPort;
        
        attribute bitDiameter : ISQ::LengthValue;
        attribute bitMaterial : String;
        attribute cuttingEdges : Integer;
        attribute currentDepth : ISQ::LengthValue;
        
        action def PenetrateBone {
            in appliedTorque : ISQ::TorqueValue;
            in rotationSpeed : ISQ::AngularVelocityValue;
            in coolantFlow : CoolantFlow;
            out penetrationRate : ISQ::SpeedValue;
            out generatedHeat : ISQ::PowerValue;
        }
    }
    
    part def DepthSensor {
        port sensorOutput : SensorPort;
        
        attribute resolution : ISQ::LengthValue;
        attribute accuracy : ISQ::LengthValue;
        attribute measurementRange : ISQ::LengthValue;
        
        action def MeasureDepth {
            out measuredDepth : ISQ::LengthValue;
            out depthRate : ISQ::SpeedValue;
        }
    }
    
    part def TemperatureSensor {
        port sensorOutput : SensorPort;
        
        attribute responseTime : ISQ::DurationValue;
        attribute temperatureRange : ISQ::ThermodynamicTemperatureValue[2];
        
        action def MonitorTemperature {
            out boneTemp : ISQ::ThermodynamicTemperatureValue;
            out tempRate : Real;
        }
    }
    
    part def TorqueSensor {
        port sensorOutput : SensorPort;
        
        attribute maxTorque : ISQ::TorqueValue;
        attribute sensitivity : Real;
        
        action def MeasureTorque {
            out appliedTorque : ISQ::TorqueValue;
            out torqueVariation : Real;
        }
    }
    
    part def IrrigationSystem {
        port coolantSupply : CoolantPort;
        port coolantDelivery : CoolantPort;
        
        attribute pumpCapacity : ISQ::VolumeFlowRateValue;
        attribute reservoirVolume : ISQ::VolumeValue;
        attribute operatingPressure : ISQ::PressureValue;
        
        action def DeliverCoolant {
            in requiredFlowRate : ISQ::VolumeFlowRateValue;
            in targetTemperature : ISQ::ThermodynamicTemperatureValue;
            out deliveredFlow : CoolantFlow;
        }
    }
    
    part def SafetyInterlockSystem {
        port sensorInputs : SensorPort;
        port controlOutput : ControlPort;
        
        attribute maxDepthLimit : ISQ::LengthValue;
        attribute maxTemperatureLimit : ISQ::ThermodynamicTemperatureValue;
        attribute maxTorqueLimit : ISQ::TorqueValue;
        
        action def EvaluateSafety {
            in currentDepth : ISQ::LengthValue;
            in currentTemperature : ISQ::ThermodynamicTemperatureValue;
            in currentTorque : ISQ::TorqueValue;
            in targetDepth : DepthTarget;
            out safetyStatus : SafetyAlert;
            out shutdownRequired : Boolean;
        }
    }
    
    part def ControlProcessor {
        port operatorInterface : ControlPort;
        port safetyInterface : ControlPort;
        port motorControl : ControlPort;
        port sensorInterface : SensorPort;
        
        attribute operatingMode : String;
        attribute targetDepth : ISQ::LengthValue;
        attribute targetSpeed : ISQ::AngularVelocityValue;
        
        action def CoordinateOperation {
            in operatorCmd : OperatorCommand;
            in safetyStatus : SafetyAlert;
            in sensorData : SensorPort;
            out motorCommand : ISQ::AngularVelocityValue;
            out coolantCommand : ISQ::VolumeFlowRateValue;
        }
    }
    
    part def CranialDrillSystem {
        doc /* 
         * A precision neurosurgical instrument system designed to create controlled 
         * openings in cranial bone tissue. The system integrates high-speed rotational 
         * drilling with continuous irrigation cooling and multi-sensor safety monitoring 
         * to enable safe access to intracranial structures while preventing thermal 
         * damage to bone and underlying neural tissue.
         */
        
        part motor : ElectricMotor {
            attribute :>> ratedPower = 150.0 [SI::W];
            attribute :>> maxSpeed = 8377.58 [SI::'rad/s'];
            attribute :>> efficiency = 0.85;
        }
        
        part speedControl : SpeedController {
            attribute :>> targetSpeed = 4188.79 [SI::'rad/s'];
            attribute :>> speedTolerance = 0.05;
        }
        
        part drillBit : DrillBitAssembly {
            attribute :>> bitDiameter = 0.014 [SI::m];
            attribute :>> bitMaterial = "Medical Grade Stainless Steel";
            attribute :>> cuttingEdges = 4;
        }
        
        part depthSensor : DepthSensor {
            attribute :>> resolution = 0.00001 [SI::m];
            attribute :>> accuracy = 0.00005 [SI::m];
            attribute :>> measurementRange = 0.05 [SI::m];
        }
        
        part tempSensor : TemperatureSensor {
            attribute :>> responseTime = 0.1 [SI::s];
        }
        
        part torqueSensor : TorqueSensor {
            attribute :>> maxTorque = 0.5 [SI::'N*m'];
            attribute :>> sensitivity = 0.001;
        }
        
        part irrigation : IrrigationSystem {
            attribute :>> pumpCapacity = 1.667e-6 [SI::'m^3/s'];
            attribute :>> reservoirVolume = 0.0005 [SI::'m^3'];
            attribute :>> operatingPressure = 200000.0 [SI::Pa];
        }
        
        part safetyInterlock : SafetyInterlockSystem {
            attribute :>> maxDepthLimit = 0.03 [SI::m];
            attribute :>> maxTemperatureLimit = 320.15 [SI::K];
            attribute :>> maxTorqueLimit = 0.4 [SI::'N*m'];
        }
        
        part controller : ControlProcessor {
            attribute :>> operatingMode = "Precision";
            attribute :>> targetDepth = 0.015 [SI::m];
            attribute :>> targetSpeed = 4188.79 [SI::'rad/s'];
        }
        
        port externalPower : PowerPort;
        port coolantSupply : CoolantPort;
        port operatorControl : ControlPort;
        
        connect externalPower to motor.powerInput;
        connect motor.driveOutput to drillBit.mechanicalInput;
        connect coolantSupply to irrigation.coolantSupply;
        connect irrigation.coolantDelivery to drillBit.coolantInterface;
        connect depthSensor.sensorOutput to controller.sensorInterface;
        connect tempSensor.sensorOutput to controller.sensorInterface;
        connect torqueSensor.sensorOutput to controller.sensorInterface;
        connect controller.sensorInterface to safetyInterlock.sensorInputs;
        connect safetyInterlock.controlOutput to controller.safetyInterface;
        connect operatorControl to controller.operatorInterface;
        connect controller.motorControl to speedControl.controlInput;
        connect speedControl.motorDrive to motor.driveOutput;
        
        perform action executeDrillingProcedure;
    }
    
    action def MonitorDrillingProgress {
        in currentDepth : ISQ::LengthValue;
        in targetDepth : ISQ::LengthValue;
        in currentTemp : ISQ::ThermodynamicTemperatureValue;
        in currentTorque : ISQ::TorqueValue;
        out depthAchieved : Boolean;
        out withinSafeLimits : Boolean;
    }
    
    action def AdjustDrillingParameters {
        in sensorFeedback : SensorPort;
        in safetyStatus : SafetyAlert;
        out adjustedSpeed : ISQ::AngularVelocityValue;
        out adjustedCoolant : ISQ::VolumeFlowRateValue;
    }
    
    action def InitiateCooling {
        in operatingSpeed : ISQ::AngularVelocityValue;
        in ambientTemp : ISQ::ThermodynamicTemperatureValue;
        out coolantFlowRate : ISQ::VolumeFlowRateValue;
    }
    
    action def PerformEmergencyShutdown {
        out motorStop : Boolean;
        out coolantMaintain : Boolean;
        out alertOperator : SafetyAlert;
    }
    
    action executeDrillingProcedure {
        doc /* 
         * Primary drilling operation coordinating motor control, depth monitoring,
         * temperature regulation, and safety interlocks to achieve controlled
         * bone penetration.
         */
        
        first start;
        
        then action systemInitialization {
            doc /* Verify all subsystems operational and safety interlocks functional */
        }
        
        then accept operatorStart : OperatorCommand;
        
        then action initCooling : InitiateCooling {
            in operatingSpeed : ISQ::AngularVelocityValue;
            in ambientTemp : ISQ::ThermodynamicTemperatureValue;
            out coolantFlowRate : ISQ::VolumeFlowRateValue;
        }
        
        then merge drillingLoop;
        
        then action monitorProgress : MonitorDrillingProgress {
            in currentDepth : ISQ::LengthValue;
            in targetDepth : ISQ::LengthValue;
            in currentTemp : ISQ::ThermodynamicTemperatureValue;
            in currentTorque : ISQ::TorqueValue;
            out depthAchieved : Boolean;
            out withinSafeLimits : Boolean;
        }
        
        then decide safetyEvaluation;
            if not monitorProgress.withinSafeLimits then emergencyShutdown;
            if monitorProgress.depthAchieved then normalCompletion;
            if monitorProgress.withinSafeLimits and not monitorProgress.depthAchieved then continueDrilling;
        
        action continueDrilling {
            action adjustParams : AdjustDrillingParameters {
                in sensorFeedback : SensorPort;
                in safetyStatus : SafetyAlert;
                out adjustedSpeed : ISQ::AngularVelocityValue;
                out adjustedCoolant : ISQ::VolumeFlowRateValue;
            }
        }
        then drillingLoop;
        
        action emergencyShutdown : PerformEmergencyShutdown {
            out motorStop : Boolean;
            out coolantMaintain : Boolean;
            out alertOperator : SafetyAlert;
        }
        then done;
        
        action normalCompletion {
            doc /* Controlled deceleration and retraction with continued cooling */
        }
        then done;
    }
    
    state def DrillingOperationStates {
        entry; then standby;
        
        state standby {
            doc /* System powered, all subsystems initialized, awaiting operator command */
        }
        accept OperatorCommand
        then positioning;
        
        state positioning {
            doc /* Drill bit positioned at cranial entry point, final safety checks */
            do action verifyAlignment;
            do action confirmTargetDepth;
        }
        if alignmentConfirmed then activeDrilling;
        
        state activeDrilling {
            doc /* Motor engaged, coolant flowing, active bone penetration in progress */
            
            do action executeDrillingProcedure;
            
            if targetDepthReached then retraction;
            if temperatureExceeded then thermalProtection;
            if torqueExceeded then mechanicalProtection;
            accept EmergencyStop then emergencyHalt;
        }
        
        state retraction {
            doc /* Target depth achieved, controlled withdrawal with continued cooling */
            
            do action retractDrillBit;
            do action maintainCooling;
        }
        if retractionComplete then standby;
        
        state thermalProtection {
            doc /* Temperature limit approached, reduce speed and increase cooling */
            
            if temperatureNormalized then activeDrilling;
            if temperatureCritical then emergencyHalt;
        }
        
        state mechanicalProtection {
            doc /* Excessive torque detected, possible bit binding or breakthrough */
            
            accept OperatorCommand then standby;
        }
        
        state emergencyHalt {
            doc /* Immediate cessation of drilling, maintain cooling, alert operator */
            
            do action performEmergencyShutdown;
        }
        accept OperatorCommand then standby;
    }
    
    requirement <'CR-001'> primaryFunctionRequirement {
        doc /* 
         * The cranial drill system shall create precise, controlled openings in 
         * cranial bone tissue to enable neurosurgical access to intracranial 
         * structures while maintaining bone and tissue integrity through continuous 
         * monitoring and active thermal management.
         */
        
        subject drillSystem : CranialDrillSystem;
        
        require constraint precisionControl {
            doc /* Drilling depth shall be controlled to within ±0.1 mm of target depth */
        }
        
        require constraint thermalProtection {
            doc /* Bone temperature shall not exceed 47°C during drilling operations */
        }
        
        require constraint speedRegulation {
            doc /* Rotational speed shall be maintained within ±5% of commanded speed */
        }
    }
    
    requirement <'CR-002'> safetyRequirement {
        doc /* 
         * The system shall incorporate multiple independent safety mechanisms to 
         * prevent unintended tissue damage and ensure controlled operation.
         */
        
        require constraint depthInterlock {
            doc /* System shall automatically halt drilling when target depth is reached */
        }
        
        require constraint temperatureInterlock {
            doc /* System shall reduce speed or halt if temperature exceeds 45°C */
        }
        
        require constraint torqueInterlock {
            doc /* System shall halt if torque exceeds 110% of nominal operating torque */
        }
        
        require constraint emergencyStopResponse {
            doc /* Emergency stop shall halt motor within 0.5 seconds while maintaining cooling */
        }
    }
    
    requirement <'CR-003'> irrigationRequirement {
        doc /* 
         * The system shall provide continuous irrigation cooling throughout drilling 
         * operations to prevent thermal necrosis of bone and neural tissue.
         */
        
        require constraint flowRateControl {
            doc /* Coolant flow rate shall be maintained between 30-80 mL/min during drilling */
        }
        
        require constraint automaticActivation {
            doc /* Irrigation shall activate automatically when motor speed exceeds threshold */
        }
        
        require constraint postDrillingCooling {
            doc /* Irrigation shall continue for minimum 10 seconds after drilling cessation */
        }
    }
    
    requirement <'CR-004'> performanceRequirement {
        doc /* 
         * The system shall provide controlled, precise drilling performance suitable 
         * for neurosurgical cranial access procedures.
         */
        
        require constraint speedRange {
            doc /* Rotational speed shall be adjustable across wide operating range */
        }
        
        require constraint depthAccuracy {
            doc /* Depth measurement accuracy shall be ±0.05 mm over 0-50 mm range */
        }
        
        require constraint vibrationLimit {
            doc /* Lateral vibration amplitude shall not exceed 0.02 mm during operation */
        }
        
        require constraint torqueConsistency {
            doc /* Torque variation shall not exceed ±10% across operating speed range */
        }
    }
    
    part cranialDrillInstance : CranialDrillSystem {
        satisfy primaryFunctionRequirement by drillBit, depthSensor, irrigation, controller;
        satisfy safetyRequirement by safetyInterlock, controller;
        satisfy irrigationRequirement by irrigation, controller;
        satisfy performanceRequirement by motor, speedControl, depthSensor, torqueSensor;
    }
}
