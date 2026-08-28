package NanomaterialSensorSystem {
    private import SI::*;
    private import ISQ::*;
    private import ScalarValues::*;
    
    attribute def ConcentrationValue :> ScalarValues::Real {
        doc /* Gas concentration in parts per million (ppm). */
    }
    attribute def ResistanceValue :> ISQ::resistance;
    attribute def VoltageValue :> ISQ::electricPotential;
    attribute def TimeValue :> ISQ::time;
    attribute def LengthValue :> ISQ::length;
    attribute def FrequencyValue :> ISQ::frequency;
    
    item def TargetGas {
        attribute name : ScalarValues::String;
        attribute concentration : ConcentrationValue;
    }
    item def ExposureSignal;
    item def MeasurementTrigger;
    item def PurgeSignal;
    item def PurgeComplete;
    
    action def AdsorbGas {
        in gas : TargetGas;
        in baselineRes : ResistanceValue;
        out currentRes : ResistanceValue;
        out deltaRes : ResistanceValue;
    }
    
    action def DesorbGas {
        in currentRes : ResistanceValue;
        out restoredRes : ResistanceValue;
    }
    
    action def AmplifySignal {
        in rawResistance : ResistanceValue;
        in gain : ScalarValues::Real;
        out amplifiedSignal : ScalarValues::Real;
    }
    
    action def FilterSignal {
        in amplifiedSignal : ScalarValues::Real;
        in cutoff : FrequencyValue;
        out filteredSignal : ScalarValues::Real;
    }
    
    action def CalculateConcentration {
        in filteredSignal : ScalarValues::Real;
        out gasConcentration : ConcentrationValue;
    }
    
    action def ProcessSignal {
        in rawSignal : ResistanceValue;
        in procGain : ScalarValues::Real;
        in procCutoff : FrequencyValue;
        out resultConcentration : ConcentrationValue;
        
        action amplify : AmplifySignal {
            in rawResistance = rawSignal;
            in gain = procGain;
        }
        action filterSignal : FilterSignal {
            in cutoff = procCutoff;
        }
        action calculate : CalculateConcentration {
            out gasConcentration = resultConcentration;
        }
        flow amplify.amplifiedSignal to filterSignal.amplifiedSignal;
        flow filterSignal.filteredSignal to calculate.filteredSignal;
        first start;
        then amplify;
        then filterSignal;
        then calculate;
    }
    
    action def RegulateVoltage {
        in inputV : VoltageValue;
        out outputV : VoltageValue;
    }
    
    part def NanoparticleLayer {
        attribute particleSize : LengthValue;
        attribute baselineResistance : ResistanceValue;
        attribute currentResistance : ResistanceValue;
        attribute resistanceDelta : ResistanceValue;
        attribute minParticleSize : LengthValue = 10.0e-9 * m;
        attribute maxParticleSize : LengthValue = 50.0e-9 * m;
        constraint particleSizeConstraint {
            particleSize >= minParticleSize and particleSize <= maxParticleSize
        }
        
        port def LayerPowerPort {
            in voltage : VoltageValue;
        }
        port def LayerSignalPort {
            out rawSignal : ResistanceValue;
        }
        port def GasExposurePort {
            in gas : TargetGas;
        }
        
        port powerIn : LayerPowerPort;
        port signalOut : LayerSignalPort;
        port gasIn : GasExposurePort;
        
        perform adsorb : AdsorbGas {
            in gas = gasIn.gas;
            in baselineRes = baselineResistance;
            out currentRes = currentResistance;
            out deltaRes = resistanceDelta;
        }
        
        perform desorb : DesorbGas {
            in currentRes = currentResistance;
            out restoredRes = currentResistance;
        }
    }
    
    part def SignalProcessor {
        attribute gain : ScalarValues::Real;
        attribute filterCutoff : FrequencyValue;
        attribute noiseThreshold : ResistanceValue;
        
        port def ProcessorPowerPort {
            in voltage : VoltageValue;
        }
        port def ProcessorInputPort {
            in rawSignal : ResistanceValue;
        }
        port def ProcessorOutputPort {
            out gasConcentration : ConcentrationValue;
        }
        
        port powerIn : ProcessorPowerPort;
        port signalIn : ProcessorInputPort;
        port signalOut : ProcessorOutputPort;
        
        perform process : ProcessSignal {
            in rawSignal = signalIn.rawSignal;
            in procGain = gain;
            in procCutoff = filterCutoff;
            out resultConcentration = signalOut.gasConcentration;
        }
    }
    
    part def PowerManagementModule {
        attribute inputVoltage : VoltageValue;
        attribute outputVoltage : VoltageValue;
        attribute maxOutputVoltage : VoltageValue = 5.0 * V;
        
        port def PowerInputPort {
            in voltage : VoltageValue;
        }
        port def PowerOutputPort {
            out voltage : VoltageValue;
        }
        
        port powerIn : PowerInputPort;
        port powerOut : PowerOutputPort;
        
        bind inputVoltage = powerIn.voltage;
        bind outputVoltage = powerOut.voltage;
        
        perform regulate : RegulateVoltage {
            in inputV = inputVoltage;
            out outputV = outputVoltage;
        }
        
        constraint voltageLimitConstraint {
            outputVoltage <= maxOutputVoltage
        }
    }
    
    state def SensingState {
        doc /* Sensing cycle state machine for the nanomaterial sensor. */
        entry;
        then baseline;
        
        state baseline {
            doc /* Sensor is in clean air, resistance is at baseline. */
        }
        
        transition baseline_to_adsorbing
            first baseline
            accept ExposureSignal
            then adsorbing;
        
        state adsorbing {
            doc /* Gas molecules accumulate on nanoparticle surface, causing resistance change. */
        }
        
        transition adsorbing_to_measuring
            first adsorbing
            accept MeasurementTrigger
            then measuring;
        
        state measuring {
            doc /* Signal processor amplifies, filters, and calculates gas concentration. */
        }
        
        transition measuring_to_purging
            first measuring
            accept PurgeSignal
            then purging;
        
        state purging {
            doc /* Clean air flow removes gas molecules, returning resistance to baseline. */
        }
        
        transition purging_to_baseline
            first purging
            accept PurgeComplete
            then baseline;
    }
    
    part def SensorSystem {
        part nanoparticleLayer : NanoparticleLayer;
        part signalProcessor : SignalProcessor;
        part powerModule : PowerManagementModule;
        
        port def SystemPowerPort {
            in voltage : VoltageValue;
        }
        port def SystemGasPort {
            in gas : TargetGas;
        }
        port def SystemOutputPort {
            out gasConcentration : ConcentrationValue;
        }
        
        port systemPowerIn : SystemPowerPort;
        port systemGasIn : SystemGasPort;
        port systemConcentrationOut : SystemOutputPort;
        
        connect systemPowerIn to powerModule.powerIn;
        connect powerModule.powerOut to nanoparticleLayer.powerIn;
        connect powerModule.powerOut to signalProcessor.powerIn;
        connect systemGasIn to nanoparticleLayer.gasIn;
        connect nanoparticleLayer.signalOut to signalProcessor.signalIn;
        connect signalProcessor.signalOut to systemConcentrationOut;
        
        exhibit state sensingState : SensingState;
    }
    
    requirement def SensingRequirement {
        subject sensorSystem : SensorSystem;
    }
    
    requirement def DetectionThresholdRequirement :> SensingRequirement {
        doc /* The sensor must detect gas concentrations as low as 1 ppm. */
        attribute actualDetectionLimit : ConcentrationValue;
        attribute requiredDetectionLimit : ConcentrationValue = 1.0;
        require constraint { actualDetectionLimit <= requiredDetectionLimit }
    }
    
    requirement def ResponseTimeRequirement :> SensingRequirement {
        doc /* The sensor must provide a response within 30 seconds of exposure. */
        attribute actualResponseTime : TimeValue;
        attribute requiredResponseTime : TimeValue = 30.0 * s;
        require constraint { actualResponseTime <= requiredResponseTime }
    }
    
    requirement def PowerSafetyRequirement :> SensingRequirement {
        doc /* The power module output voltage must not exceed 5V to protect components. */
        attribute actualOutputVoltage : VoltageValue;
        attribute maxAllowedVoltage : VoltageValue = 5.0 * V;
        require constraint { actualOutputVoltage <= maxAllowedVoltage }
    }
    
    requirement def ParticleSizeRequirement :> SensingRequirement {
        doc /* Nanoparticle size must be between 10 and 50 nanometers. */
        attribute minParticleSize : LengthValue = 10.0e-9 * m;
        attribute maxParticleSize : LengthValue = 50.0e-9 * m;
        attribute actualParticleSize : LengthValue;
        require constraint { actualParticleSize >= minParticleSize and actualParticleSize <= maxParticleSize }
    }
    
    analysis def SensorPerformanceAnalysis {
        subject sensorSystem : SensorSystem;
        requirement detectionThresholdRequirement : DetectionThresholdRequirement;
        requirement responseTimeRequirement : ResponseTimeRequirement;
        requirement powerSafetyRequirement : PowerSafetyRequirement;
        requirement particleSizeRequirement : ParticleSizeRequirement;
        return detectedConcentration : ConcentrationValue;
        return responseTime : TimeValue;
        objective sensorAnalysisObjective {
            doc /* This analysis verifies that the sensor meets detection threshold, response time, power safety, and particle size requirements. */
        }
    }
}
