package VariableReluctanceSensingUnit {
    import ScalarValues::*;
    import ISQ::*;
    
    attribute def RotationStart;
    attribute def RotationStop;
    attribute def SignalAnomaly;
    attribute def ResetCommand;
    
    attribute def RotationalSpeed :> ScalarValues::Real;
    attribute def Voltage :> ScalarValues::Real;
    attribute def Frequency :> ScalarValues::Real;
    attribute def AirGap :> ISQ::length;
    attribute def MagneticFluxDensity :> ScalarValues::Real;
    attribute def DutyCycle :> ScalarValues::Real;
    
    item def AnalogVoltageSignal {
        attribute amplitude : Voltage;
        attribute frequency : Frequency;
    }
    
    item def DigitalSquareWave {
        attribute frequency : Frequency;
        attribute dutyCycle : DutyCycle;
    }
    
    item def MagneticField {
        attribute fluxDensity : MagneticFluxDensity;
    }
    
    port def AnalogSignalPort {
        out signal : AnalogVoltageSignal;
    }
    
    port def DigitalSignalPort {
        out signal : DigitalSquareWave;
    }
    
    port def PowerPort {
        in supplyVoltage : Voltage;
    }
    
    port def MagneticInterfacePort {
        inout field : MagneticField;
    }
    
    action def InduceVoltage {
        in targetSpeed : RotationalSpeed;
        in toothCount : Integer;
        out inducedVoltage : Voltage;
        out signalFrequency : Frequency;
    }
    
    action def AmplifySignal {
        in rawVoltage : Voltage;
        in gain : ScalarValues::Real;
        out amplifiedVoltage : Voltage;
    }
    
    action def FilterNoise {
        in inputVoltage : Voltage;
        in cutoffFrequency : Frequency;
        out filteredVoltage : Voltage;
    }
    
    action def ConvertToDigital {
        in analogVoltage : Voltage;
        in thresholdHigh : Voltage;
        in thresholdLow : Voltage;
        out digitalSignal : Boolean;
        out outputFrequency : Frequency;
    }
    
    action def CalculateSpeed {
        in frequency : Frequency;
        in toothCount : Integer;
        out speed : RotationalSpeed;
    }
    
    state def SensorStates {
        entry; then idle;
        state idle;
        transition idle_to_sensing
            first idle
            accept RotationStart
            then sensing;
        state sensing;
        transition sensing_to_idle
            first sensing
            accept RotationStop
            then idle;
        transition sensing_to_fault
            first sensing
            accept SignalAnomaly
            then fault;
        state fault;
        transition fault_to_idle
            first fault
            accept ResetCommand
            then idle;
    }
    
    state def SystemStates {
        entry; then idle;
        state idle;
        transition idle_to_sensing
            first idle
            accept RotationStart
            then sensing;
        state sensing;
        transition sensing_to_idle
            first sensing
            accept RotationStop
            then idle;
        transition sensing_to_fault
            first sensing
            accept SignalAnomaly
            then fault;
        state fault;
        transition fault_to_idle
            first fault
            accept ResetCommand
            then idle;
    }
    
    part def PermanentMagnet {
        attribute fieldStrength : MagneticFluxDensity;
        port magnetPort : MagneticInterfacePort;
    }
    
    part def PickupCoil {
        attribute numberOfTurns : Integer;
        port coilPort : MagneticInterfacePort;
        port signalOut : AnalogSignalPort;
        perform action induceVoltage : InduceVoltage;
    }
    
    part def ToothedTarget {
        attribute toothCount : Integer;
        attribute material : String;
        attribute rotationalSpeed : RotationalSpeed;
        port targetPort : MagneticInterfacePort;
    }
    
    part def VariableReluctanceSensor {
        attribute airGap : AirGap;
        port analogOut : AnalogSignalPort;
        port targetInterface : MagneticInterfacePort;
        
        part permanentMagnet : PermanentMagnet;
        part pickupCoil : PickupCoil;
        
        interface internalMagneticInterface
            connect permanentMagnet.magnetPort to pickupCoil.coilPort;
        
        bind analogOut = pickupCoil.signalOut;
        
        exhibit state sensorStates : SensorStates;
    }
    
    part def Amplifier {
        attribute gain : ScalarValues::Real;
        port inputPort : AnalogSignalPort;
        port outputPort : AnalogSignalPort;
        perform action amplify : AmplifySignal;
    }
    
    part def LowPassFilter {
        attribute cutoffFrequency : Frequency;
        port inputPort : AnalogSignalPort;
        port outputPort : AnalogSignalPort;
        perform action noiseFilter : FilterNoise;
    }
    
    part def SchmittTrigger {
        attribute thresholdHigh : Voltage;
        attribute thresholdLow : Voltage;
        port inputPort : AnalogSignalPort;
        port outputPort : DigitalSignalPort;
        perform action convert : ConvertToDigital;
    }
    
    part def SignalConditioningUnit {
        port analogIn : AnalogSignalPort;
        port digitalOut : DigitalSignalPort;
        port powerIn : PowerPort;
        
        part amplifier : Amplifier;
        part lowPassFilter : LowPassFilter;
        part comparator : SchmittTrigger;
        
        interface ampToFilterInterface
            connect amplifier.outputPort to lowPassFilter.inputPort;
        interface filterToCompInterface
            connect lowPassFilter.outputPort to comparator.inputPort;
        
        bind analogIn = amplifier.inputPort;
        bind digitalOut = comparator.outputPort;
    }
    
    part def ElectronicControlUnit {
        port digitalIn : DigitalSignalPort;
        port powerOut : PowerPort;
        perform action calculateSpeed : CalculateSpeed;
    }
    
    part def VariableReluctanceSensingSystem {
        attribute maxSpeed : RotationalSpeed = 6000;
        attribute minAirGap : AirGap = 0.5;
        attribute maxAirGap : AirGap = 2.0;
        
        port systemOutput : DigitalSignalPort;
        port systemPower : PowerPort;
        
        part target : ToothedTarget;
        part sensor : VariableReluctanceSensor;
        part conditioner : SignalConditioningUnit;
        part ecu : ElectronicControlUnit;
        
        interface sensorToConditionerInterface connect sensor.analogOut to conditioner.analogIn {
            flow analogSignalFlow of AnalogVoltageSignal
                from sensor.analogOut.signal to conditioner.analogIn.signal;
        }
        
        interface conditionerToEcuInterface connect conditioner.digitalOut to ecu.digitalIn {
            flow digitalSignalFlow of DigitalSquareWave
                from conditioner.digitalOut.signal to ecu.digitalIn.signal;
        }
        
        interface sensorToTargetInterface connect sensor.targetInterface to target.targetPort;
        
        interface powerInterface connect ecu.powerOut to conditioner.powerIn;
        
        bind systemOutput = conditioner.digitalOut;
        
        assert constraint validAirGap {
            sensor.airGap >= minAirGap & sensor.airGap <= maxAirGap
        }
        
        assert constraint speedRange {
            target.rotationalSpeed <= maxSpeed
        }
        
        exhibit state systemStates : SystemStates;
    }
    
    requirement def MaxSpeedRequirement {
        doc /* The system shall measure rotational speeds up to 6000 RPM. */
        attribute maxSpeed : RotationalSpeed = 6000;
    }
    
    requirement def AirGapRequirement {
        doc /* The sensor shall operate within an air gap between 0.5 mm and 2.0 mm. */
        attribute minGap : AirGap = 0.5;
        attribute maxGap : AirGap = 2.0;
    }
    
    requirement def SignalIntegrityRequirement {
        doc /* The signal conditioner shall output a clean digital square wave with less than 1% jitter. */
        attribute maxJitter : ScalarValues::Real = 0.01;
    }
    
    requirement def FaultDetectionRequirement {
        doc /* The system shall detect signal anomalies and transition to a fault state. */
    }
    
    part vrSensingSystem : VariableReluctanceSensingSystem {
        part :>> sensor {
            attribute :>> airGap = 1.0;
        }
        part :>> target {
            attribute :>> toothCount = 60;
            attribute :>> rotationalSpeed = 3000;
        }
        satisfy maxSpeedReq : MaxSpeedRequirement;
        satisfy airGapReq : AirGapRequirement;
        satisfy signalIntegrityReq : SignalIntegrityRequirement;
        satisfy faultDetectionReq : FaultDetectionRequirement;
    }
}
