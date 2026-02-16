package OlfactometerSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def OdorantConcentration :> ISQ::DimensionOneValue;
    attribute def FlowRate :> ISQ::VolumeFlowRateValue;
    attribute def PressureValue :> ISQ::PressureValue;
    attribute def TemperatureValue :> ISQ::ThermodynamicTemperatureValue;
    attribute def HumidityValue :> ISQ::DimensionOneValue;
    
    attribute def StimulusParameters {
        attribute odorantID : String;
        attribute targetConcentration : OdorantConcentration;
        attribute duration : ISQ::DurationValue;
        attribute flowRate : FlowRate;
    }
    
    attribute def CalibrationRecord {
        attribute odorantID : String;
        attribute dilutionFactors : Real[*];
        attribute measuredConcentrations : OdorantConcentration[*];
        attribute timestamp : String;
    }
    
    item def OdorantStream {
        attribute flowRate : FlowRate;
        attribute concentration : OdorantConcentration;
        attribute temperature : TemperatureValue;
        attribute pressure : PressureValue;
    }
    
    item def CarrierAirStream {
        attribute flowRate : FlowRate;
        attribute temperature : TemperatureValue;
        attribute pressure : PressureValue;
        attribute humidity : HumidityValue;
    }
    
    port def OdorantPort {
        out item stream : OdorantStream;
    }
    
    port def CarrierAirPort {
        out item stream : CarrierAirStream;
    }
    
    port def MixedStreamPort {
        out item stream : OdorantStream;
    }
    
    port def ControlCommandPort {
        in attribute command : StimulusParameters;
        out attribute status : String;
    }
    
    port def SensorPort {
        in item stream : OdorantStream;
        out attribute measurement : OdorantConcentration;
    }
    
    part def OdorantReservoir {
        attribute odorantType : String;
        attribute capacity : ISQ::VolumeValue;
        attribute currentLevel : ISQ::VolumeValue;
        attribute vaporPressure : PressureValue;
        port outlet : OdorantPort;
    }
    
    part def MassFlowController {
        attribute maxFlowRate : FlowRate;
        attribute setpoint : FlowRate;
        attribute actualFlow : FlowRate;
        attribute accuracy : Real;
        port inlet : OdorantPort;
        port outlet : OdorantPort;
    }
    
    part def AirSupply {
        attribute outputPressure : PressureValue;
        attribute maxFlowRate : FlowRate;
        attribute filtrationLevel : Real;
        port outlet : CarrierAirPort;
    }
    
    part def HumidityController {
        attribute targetHumidity : HumidityValue;
        attribute currentHumidity : HumidityValue;
        port inlet : CarrierAirPort;
        port outlet : CarrierAirPort;
    }
    
    part def MixingManifold {
        attribute volume : ISQ::VolumeValue;
        attribute mixingEfficiency : Real;
        attribute residenceTime : ISQ::DurationValue;
        port odorantInlet : OdorantPort;
        port carrierInlet : CarrierAirPort;
        port mixedOutlet : MixedStreamPort;
    }
    
    part def ConcentrationSensor {
        attribute sensitivity : OdorantConcentration;
        attribute responseTime : ISQ::DurationValue;
        attribute accuracy : Real;
        port sensing : SensorPort;
    }
    
    part def TemperatureController {
        attribute targetTemperature : TemperatureValue;
        attribute currentTemperature : TemperatureValue;
        attribute heatingPower : ISQ::PowerValue;
    }
    
    part def ControlComputer {
        attribute calibrationData : CalibrationRecord[*];
        attribute activeProtocol : String;
        port commandInterface : ControlCommandPort;
    }
    
    action def ComputeDilutionRatio {
        in targetConcentration : OdorantConcentration;
        in sourceConcentration : OdorantConcentration;
        in totalFlowRate : FlowRate;
        out odorantFlowRate : FlowRate;
        out carrierFlowRate : FlowRate;
    }
    
    action def SetFlowControllers {
        in odorantFlow : FlowRate;
        in carrierFlow : FlowRate;
        out odorantSetpoint : FlowRate;
        out carrierSetpoint : FlowRate;
    }
    
    action def MixStreams {
        in odorantStream : OdorantStream;
        in carrierStream : CarrierAirStream;
        in manifoldVolume : ISQ::VolumeValue;
        out mixedStream : OdorantStream;
    }
    
    action def MeasureConcentration {
        in inputStream : OdorantStream;
        out measuredConcentration : OdorantConcentration;
        out measurementError : Real;
    }
    
    action def AdjustFlowRates {
        in targetConcentration : OdorantConcentration;
        in measuredConcentration : OdorantConcentration;
        in currentOdorantFlow : FlowRate;
        out adjustedOdorantFlow : FlowRate;
    }
    
    action def PurgeSystem {
        in purgeFlowRate : FlowRate;
        in purgeDuration : ISQ::DurationValue;
        out systemClean : Boolean;
    }
    
    action def DeliverOdorantStimulus {
        in stimulusParams : StimulusParameters;
        out actualConcentration : OdorantConcentration;
        out deliveryComplete : Boolean;
        
        first start;
        then merge controlLoop;
        
        action validateParameters {
            in params = stimulusParams;
            out validatedParams : StimulusParameters;
        }
        
        then action computeFlows : ComputeDilutionRatio {
            in targetConcentration = validateParameters.validatedParams.targetConcentration;
            in sourceConcentration = 1.0;
            in totalFlowRate = validateParameters.validatedParams.flowRate;
            out odorantFlowRate;
            out carrierFlowRate;
        }
        
        then action setControllers : SetFlowControllers {
            in odorantFlow = computeFlows.odorantFlowRate;
            in carrierFlow = computeFlows.carrierFlowRate;
            out odorantSetpoint;
            out carrierSetpoint;
        }
        
        then action stabilize {
            in stabilizationTime : ISQ::DurationValue = 2.0;
        }
        
        then action mixOdorant : MixStreams {
            in odorantStream;
            in carrierStream;
            in manifoldVolume = 0.0005;
            out mixedStream;
        }
        
        then action measureOutput : MeasureConcentration {
            in inputStream = mixOdorant.mixedStream;
            out measuredConcentration;
            out measurementError;
        }
        
        then decide;
            if measureOutput.measurementError > 0.05 then correctFlow;
            if measureOutput.measurementError <= 0.05 then deliverStimulus;
        
        action correctFlow : AdjustFlowRates {
            in targetConcentration = validateParameters.validatedParams.targetConcentration;
            in measuredConcentration = measureOutput.measuredConcentration;
            in currentOdorantFlow = computeFlows.odorantFlowRate;
            out adjustedOdorantFlow;
        }
        then controlLoop;
        
        action deliverStimulus {
            in concentration = measureOutput.measuredConcentration;
            in deliveryDuration = validateParameters.validatedParams.duration;
            out delivered : Boolean;
        }
        
        then action checkDuration {
            in elapsedTime : ISQ::DurationValue;
            in targetDuration = validateParameters.validatedParams.duration;
            out durationMet : Boolean;
        }
        
        then decide;
            if checkDuration.durationMet == false then controlLoop;
            if checkDuration.durationMet == true then terminateDelivery;
        
        action terminateDelivery {
            out finalConcentration = measureOutput.measuredConcentration;
        }
        
        then action purge : PurgeSystem {
            in purgeFlowRate = 1000.0;
            in purgeDuration = 5.0;
            out systemClean;
        }
        
        then done;
    }
    
    part def Olfactometer {
        attribute systemID : String;
        attribute numberOfChannels : Integer;
        
        port systemControl : ControlCommandPort;
        port stimulusOutput : MixedStreamPort;
        
        part odorantReservoirs : OdorantReservoir[4];
        part odorantMFCs : MassFlowController[4];
        part cleanAirSupply : AirSupply;
        part carrierMFC : MassFlowController;
        part humidityControl : HumidityController;
        part temperatureControl : TemperatureController;
        part mixingManifold : MixingManifold;
        part concentrationSensor : ConcentrationSensor;
        part controlComputer : ControlComputer;
    }
    
    part olfactometer : Olfactometer {
        attribute systemID = "OLFAC-001";
        attribute numberOfChannels = 4;
        
        part redefines odorantReservoirs : OdorantReservoir[4] {
            attribute capacity = 1000.0;
            attribute currentLevel = 800.0;
        }
        
        part redefines odorantMFCs : MassFlowController[4] {
            attribute maxFlowRate = 200.0;
            attribute accuracy = 0.01;
        }
        
        part redefines cleanAirSupply : AirSupply {
            attribute outputPressure = 150000.0;
            attribute maxFlowRate = 5000.0;
            attribute filtrationLevel = 0.9999;
        }
        
        part redefines carrierMFC : MassFlowController {
            attribute maxFlowRate = 5000.0;
            attribute accuracy = 0.01;
        }
        
        part redefines humidityControl : HumidityController {
            attribute targetHumidity = 0.50;
        }
        
        part redefines temperatureControl : TemperatureController {
            attribute targetTemperature = 298.15;
            attribute heatingPower = 100.0;
        }
        
        part redefines mixingManifold : MixingManifold {
            attribute volume = 0.0005;
            attribute mixingEfficiency = 0.98;
            attribute residenceTime = 0.5;
        }
        
        part redefines concentrationSensor : ConcentrationSensor {
            attribute sensitivity = 0.0001;
            attribute responseTime = 0.1;
            attribute accuracy = 0.02;
        }
        
        part redefines controlComputer : ControlComputer {
            attribute activeProtocol = "StandardDelivery";
        }
        
        connect odorantReservoirs#(1)::outlet to odorantMFCs#(1)::inlet;
        connect odorantReservoirs#(2)::outlet to odorantMFCs#(2)::inlet;
        connect odorantReservoirs#(3)::outlet to odorantMFCs#(3)::inlet;
        connect odorantReservoirs#(4)::outlet to odorantMFCs#(4)::inlet;
        
        connect odorantMFCs#(1)::outlet to mixingManifold.odorantInlet;
        
        connect cleanAirSupply.outlet to humidityControl.inlet;
        connect humidityControl.outlet to carrierMFC.inlet;
        connect carrierMFC.outlet to mixingManifold.carrierInlet;
        
        connect mixingManifold.mixedOutlet to concentrationSensor.sensing;
        connect mixingManifold.mixedOutlet to stimulusOutput;
        
        perform action deliverStimulus : DeliverOdorantStimulus {
            in stimulusParams;
            out actualConcentration;
            out deliveryComplete;
        }
    }
    
    requirement def <'REQ-OLF-001'> PrimaryFunctionRequirement {
        doc /* The olfactometer system shall deliver precise, controlled odorant stimuli 
                at specified concentrations to subjects for olfactory perception research 
                and clinical assessment. */
        
        subject olfactometer : Olfactometer;
        
        require concentrationControlReq : ConcentrationControlRequirement;
        require temporalControlReq : TemporalControlRequirement;
        require environmentalControlReq : EnvironmentalControlRequirement;
        require systemStabilityReq : SystemStabilityRequirement;
    }
    
    requirement def ConcentrationControlRequirement {
        doc /* The system shall maintain delivered odorant concentration within ±3% 
                of the target concentration during stimulus presentation. */
    }
    
    requirement def TemporalControlRequirement {
        doc /* The system shall achieve stimulus onset and offset with temporal 
                precision better than 50 milliseconds. */
    }
    
    requirement def EnvironmentalControlRequirement {
        doc /* The system shall maintain temperature at 25°C ±0.5°C and relative 
                humidity at 50% ±3% during all operations. */
    }
    
    requirement def SystemStabilityRequirement {
        doc /* The system shall achieve stable concentration output within 2 seconds 
                of flow rate changes and maintain stability for stimulus durations 
                up to 60 seconds. */
    }
    
    requirement primaryFunction : PrimaryFunctionRequirement {
        assume constraint operatingConditions {
            doc /* Odorant reservoirs contain sufficient material, compressed air 
                    supply is available at specified pressure, and environmental 
                    conditions are within operating range. */
        }
        
        satisfy concentrationControlReq by olfactometer.concentrationSensor;
        satisfy temporalControlReq by olfactometer.deliverStimulus;
        satisfy environmentalControlReq by olfactometer.temperatureControl;
        satisfy environmentalControlReq by olfactometer.humidityControl;
        satisfy systemStabilityReq by olfactometer.mixingManifold;
    }
}
