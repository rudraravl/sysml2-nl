package MetalDetectorSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    item def ElectromagneticField {
        attribute frequency :> ISQ::frequency;
        attribute amplitude :> ISQ::electricPotential;
    }
    item def DistortedSignal {
        attribute amplitude :> ISQ::electricPotential;
        attribute phase :> ISQ::planeAngle;
    }
    item def ProcessedSignal {
        attribute metalType : MetalType;
        attribute depth :> ISQ::length;
        attribute confidence : Real;
    }

    enum def MetalType {
        ferrous;
        nonFerrous;
        stainlessSteel;
    }
    enum def AlertLevel {
        low;
        medium;
        high;
    }
    attribute def SensitivityLevel :> Real;
    attribute def BatteryLevel :> Real;
    attribute def OperatingTemp;
    attribute def OperatingDuration;

    attribute def PowerOnSignal;
    attribute def PowerOffSignal;
    attribute def StartScanSignal;
    attribute def StopScanSignal;
    attribute def SensitivityAdjustSignal {
        attribute sensitivity : SensitivityLevel;
    }
    attribute def TargetDetectedSignal {
        attribute confidence : Real;
    }
    attribute def StrongSignalSignal {
        attribute alertLevel : AlertLevel;
    }

    port def FieldPort {
        out field : ElectromagneticField;
    }
    port def DistortedSignalPort {
        out distortedSignal : DistortedSignal;
    }
    port def ProcessedSignalPort {
        out processedSignal : ProcessedSignal;
    }
    port def AlertPort {
        out alertLevel : AlertLevel;
        out audioFreq :> ISQ::frequency;
        out visualState : Boolean;
    }
    port def ControlPort {
        in powerOn : PowerOnSignal;
        in powerOff : PowerOffSignal;
        in startScan : StartScanSignal;
        in stopScan : StopScanSignal;
        in sensitivityAdjust : SensitivityAdjustSignal;
    }
    port def PowerPort {
        out voltage :> ISQ::electricPotential;
        out current :> ISQ::electricCurrent;
    }
    port def BatteryMonitorPort {
        out batteryLevel : BatteryLevel;
    }

    action def GenerateField {
        out field : ElectromagneticField;
    }
    action def DetectDisturbance {
        in field : ElectromagneticField;
        out distortedSignal : DistortedSignal;
    }
    action def ProcessSignal {
        in distortedSignal : DistortedSignal;
        in sensitivity : SensitivityLevel;
        out processedSignal : ProcessedSignal;
    }
    action def AlertUser {
        in processedSignal : ProcessedSignal;
        out alertLevel : AlertLevel;
        out audioFreq :> ISQ::frequency;
        out visualState : Boolean;
    }
    action def ManageOperation;
    action def SupplyPower;
    action def MonitorBattery {
        out batteryLevel : BatteryLevel;
    }

    part def TransmitterCoil {
        port fieldPort : FieldPort;
        port powerIn : PowerPort;
        perform action generateField : GenerateField;
    }
    part def ReceiverCoil {
        port fieldInPort : FieldPort;
        port signalOutPort : DistortedSignalPort;
        port powerIn : PowerPort;
        perform action detectDisturbance : DetectDisturbance;
    }
    part def SignalProcessingUnit {
        port signalInPort : DistortedSignalPort;
        port signalOutPort : ProcessedSignalPort;
        port controlInPort : ControlPort;
        port powerIn : PowerPort;
        attribute sensitivity : SensitivityLevel;
        attribute metalType : MetalType;
        attribute depth :> ISQ::length;
        attribute confidence : Real;
        perform action processSignal : ProcessSignal;
    }
    part def AlertingSubsystem {
        port signalInPort : ProcessedSignalPort;
        port alertOutPort : AlertPort;
        port powerIn : PowerPort;
        perform action alertUser : AlertUser;
    }
    part def ControlModule {
        port controlOutPort : ControlPort;
        port powerIn : PowerPort;
        port batteryMonitorIn : BatteryMonitorPort;
        attribute powerState : Boolean;
        attribute sensitivitySetting : SensitivityLevel;
        perform action manageOperation : ManageOperation;
    }
    part def PowerManagementUnit {
        port powerOutPort : PowerPort;
        port batteryMonitorOut : BatteryMonitorPort;
        port controlIn : ControlPort;
        attribute batteryLevel : BatteryLevel;
        attribute totalOperatingTime : Real;
        perform action supplyPower : SupplyPower;
        perform action monitorBattery : MonitorBattery;
        part battery : Battery;
    }
    part def Battery {
        attribute capacity :> ISQ::energy;
        attribute nominalVoltage :> ISQ::electricPotential;
    }

    part def MetalDetector {
        attribute operatingTemp : Real;
        attribute operatingDuration : Real;
        attribute sensitivity : SensitivityLevel;
        
        part transmitterCoil : TransmitterCoil;
        part receiverCoil : ReceiverCoil;
        part signalProcessingUnit : SignalProcessingUnit;
        part alertingSubsystem : AlertingSubsystem;
        part controlModule : ControlModule;
        part powerManagementUnit : PowerManagementUnit;
        
        connect powerManagementUnit.powerOutPort to transmitterCoil.powerIn;
        connect powerManagementUnit.powerOutPort to receiverCoil.powerIn;
        connect powerManagementUnit.powerOutPort to signalProcessingUnit.powerIn;
        connect powerManagementUnit.powerOutPort to alertingSubsystem.powerIn;
        connect powerManagementUnit.powerOutPort to controlModule.powerIn;
        connect powerManagementUnit.batteryMonitorOut to controlModule.batteryMonitorIn;
        connect controlModule.controlOutPort to signalProcessingUnit.controlInPort;
        connect controlModule.controlOutPort to powerManagementUnit.controlIn;
        connect transmitterCoil.fieldPort to receiverCoil.fieldInPort;
        connect receiverCoil.signalOutPort to signalProcessingUnit.signalInPort;
        connect signalProcessingUnit.signalOutPort to alertingSubsystem.signalInPort;
        
        action scan {
            action generateField : GenerateField;
            action detectDisturbance : DetectDisturbance;
            action processSignal : ProcessSignal;
            action alertUser : AlertUser;

            flow generateField.field to detectDisturbance.field;
            flow detectDisturbance.distortedSignal to processSignal.distortedSignal;
            flow processSignal.processedSignal to alertUser.processedSignal;
        }
        
        perform action scan;
        
        state detectorStates {
            entry; then powerOff;
            state powerOff;
            accept PowerOnSignal then standby;
            state standby;
            accept StartScanSignal then activeScanning;
            accept PowerOffSignal then powerOff;
            state activeScanning {
                entry; then searching;
                state searching;
                accept TargetDetectedSignal
                    if signalProcessingUnit.confidence > 0.5
                    then targetAcquired;
                state targetAcquired;
                accept StrongSignalSignal
                    if signalProcessingUnit.confidence > 0.8
                    then alerting;
                accept TargetDetectedSignal
                    if signalProcessingUnit.confidence <= 0.5
                    then searching;
                state alerting {
                    do action alertUser;
                }
                accept StrongSignalSignal
                    if signalProcessingUnit.confidence <= 0.8
                    then targetAcquired;
            }
            transition first activeScanning accept StopScanSignal then standby;
            accept PowerOffSignal then powerOff;
        }
        
        exhibit state detectorStates;
    }

    requirement def OperationalDurationRequirement {
        doc /* The system shall operate for over 15 hours on a single charge. */
        subject detector : MetalDetector;
        attribute minDuration : Real = 15;
        constraint { detector.operatingDuration >= minDuration }
    }
    requirement def EnvironmentalRobustnessRequirement {
        doc /* The system shall operate in a wide range of environmental conditions. */
        subject detector : MetalDetector;
        attribute operatingTempMin : Real = -20;
        attribute operatingTempMax : Real = 60;
        constraint {
            detector.operatingTemp >= operatingTempMin
            and detector.operatingTemp <= operatingTempMax
        }
    }
    requirement def MetalClassificationRequirement {
        doc /* The system shall classify detected metals as ferrous, non-ferrous, or stainless steel. */
        subject processor : SignalProcessingUnit;
        constraint {
            processor.metalType == MetalType::ferrous
            or processor.metalType == MetalType::nonFerrous
            or processor.metalType == MetalType::stainlessSteel
        }
    }
    requirement def DetectionConfidenceRequirement {
        doc /* The system shall calculate a confidence level for each detection. */
        subject processor : SignalProcessingUnit;
        attribute minConfidence : Real = 0.5;
        constraint { processor.confidence >= minConfidence }
    }

    part detector : MetalDetector {
        assert constraint {
            powerManagementUnit.batteryLevel > 0.0
        }
        assert constraint {
            operatingDuration >= 15
        }
        assert constraint {
            operatingTemp >= -20 and operatingTemp <= 60
        }
    }

    requirement operationalDuration : OperationalDurationRequirement {
        subject detector : MetalDetector = detector;
    }
    requirement environmentalRobustness : EnvironmentalRobustnessRequirement {
        subject detector : MetalDetector = detector;
    }
    requirement metalClassification : MetalClassificationRequirement {
        subject processor : SignalProcessingUnit = detector.signalProcessingUnit;
    }
    requirement detectionConfidence : DetectionConfidenceRequirement {
        subject processor : SignalProcessingUnit = detector.signalProcessingUnit;
    }
}
