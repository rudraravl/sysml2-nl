package 'Power Transmission System' {
    private import ISQ::*;
    private import SI::W;
    private import SI::V;
    private import SI::A;
    private import SI::Hz;
    private import SI::m;
    private import SI::s;
    private import ScalarValues::*;
    
    attribute def FaultCleared;
    attribute def TripSignal;
    
    item def Electricity {
        attribute power : PowerValue;
        attribute voltage : ElectricPotentialValue;
        attribute current : ElectricCurrentValue;
        attribute frequency : FrequencyValue;
    }
    
    port def PowerOutPort {
        out electricity : Electricity;
    }
    
    port def PowerInPort {
        in electricity : Electricity;
    }
    
    port def MeasurementPort {
        out voltage : ElectricPotentialValue;
        out current : ElectricCurrentValue;
    }
    
    port def TripPort {
        out signal : TripSignal;
    }
    
    action def GeneratePower {
        out electricity : Electricity;
    }
    
    action def StepUpVoltage {
        in electricityIn : Electricity;
        out electricityOut : Electricity;
    }
    
    action def TransmitPower {
        in electricityIn : Electricity;
        out electricityOut : Electricity;
    }
    
    action def StepDownVoltage {
        in electricityIn : Electricity;
        out electricityOut : Electricity;
    }
    
    action def DistributePower {
        in electricityIn : Electricity;
        out electricityOut : Electricity[8];
    }
    
    action def IsolateFault {
        out trip : TripSignal;
    }
    
    part def PowerPlant {
        attribute generatedPower : PowerValue = 800000000 [W];
        attribute generatedVoltage : ElectricPotentialValue = 22000 [V];
        attribute frequency : FrequencyValue = 60 [Hz];
        out powerOut : PowerOutPort;
        perform action generate : GeneratePower;
        bind generate.electricity = powerOut.electricity;
    }
    
    part def StepUpTransformer {
        in powerIn : PowerInPort;
        out powerOut : PowerOutPort;
        attribute inputVoltage : ElectricPotentialValue = 22000 [V];
        attribute outputVoltage : ElectricPotentialValue = 345000 [V];
        perform action stepUp : StepUpVoltage;
        bind powerIn.electricity = stepUp.electricityIn;
        bind stepUp.electricityOut = powerOut.electricity;
    }
    
    part def TransmissionLine {
        in powerIn : PowerInPort;
        out powerOut : PowerOutPort;
        out measurement : MeasurementPort;
        attribute length : LengthValue = 250000 [m];
        attribute resistance : Real;
        attribute powerLoss : PowerValue;
        perform action transmit : TransmitPower;
        bind powerIn.electricity = transmit.electricityIn;
        bind transmit.electricityOut = powerOut.electricity;
    }
    
    part def StepDownTransformer {
        in powerIn : PowerInPort;
        out powerOut : PowerOutPort;
        attribute inputVoltage : ElectricPotentialValue = 345000 [V];
        attribute outputVoltage : ElectricPotentialValue = 34500 [V];
        perform action stepDown : StepDownVoltage;
        bind powerIn.electricity = stepDown.electricityIn;
        bind stepDown.electricityOut = powerOut.electricity;
    }
    
    part def DistributionSubstation {
        in powerIn : PowerInPort;
        out feeders : PowerOutPort[8];
        attribute outputVoltage : ElectricPotentialValue = 34500 [V];
        perform action distribute : DistributePower;
        bind powerIn.electricity = distribute.electricityIn;
        bind distribute.electricityOut = feeders.electricity;
    }
    
    part def ProtectionSystem {
        in monitorPort : MeasurementPort;
        out tripPort : TripPort;
        attribute thresholdVoltage : ElectricPotentialValue = 300000 [V];
        attribute thresholdCurrent : ElectricCurrentValue = 10000 [A];
        attribute responseTime : DurationValue = 0.08 [s];
        
        exhibit state protectionStates {
            entry; then normal;
            state normal;
            accept when monitorPort.voltage < thresholdVoltage or monitorPort.current > thresholdCurrent
                then faultIsolation;
            state faultIsolation {
                do send new TripSignal() to tripPort;
            }
            accept FaultCleared
                then normal;
        }
    }
    
    requirement def TransmissionEfficiency {
        /* The system shall efficiently move electricity from generation to distribution over a significant distance. */
    }
    
    requirement def FaultResponse {
        /* The protection system shall detect and isolate a fault within 80 milliseconds. */
        attribute responseTime : DurationValue = 0.08 [s];
    }
    
    part powerTransmissionSystem {
        part powerPlant : PowerPlant;
        part stepUpTransformer : StepUpTransformer;
        part transmissionLine : TransmissionLine;
        part stepDownTransformer : StepDownTransformer;
        part distributionSubstation : DistributionSubstation;
        part protectionSystem : ProtectionSystem;
        
        flow powerPlant.powerOut.electricity 
            to stepUpTransformer.powerIn.electricity;
        flow stepUpTransformer.powerOut.electricity 
            to transmissionLine.powerIn.electricity;
        flow transmissionLine.powerOut.electricity 
            to stepDownTransformer.powerIn.electricity;
        flow stepDownTransformer.powerOut.electricity 
            to distributionSubstation.powerIn.electricity;
            
        flow transmissionLine.measurement.voltage 
            to protectionSystem.monitorPort.voltage;
        flow transmissionLine.measurement.current 
            to protectionSystem.monitorPort.current;
            
        requirement transmissionEfficiency : TransmissionEfficiency;
        requirement faultResponse : FaultResponse;
    }
}
