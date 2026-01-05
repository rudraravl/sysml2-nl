package OptodeOxygenSensingSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def OxygenConcentrationValue :> ISQ::AmountOfSubstanceConcentrationValue;
    attribute def WavelengthValue :> ISQ::LengthValue;
    attribute def OpticalPowerValue :> ISQ::PowerValue;
    attribute def IntensityValue :> ISQ::LuminousIntensityValue;
    attribute def DecayTimeValue :> ISQ::TimeValue;
    attribute def TemperatureValue :> ISQ::ThermodynamicTemperatureValue;
    attribute def PressureValue :> ISQ::PressureValue;
    
    item def ExcitationLight {
        attribute wavelength : WavelengthValue;
        attribute power : OpticalPowerValue;
    }
    
    item def FluorescenceEmission {
        attribute wavelength : WavelengthValue;
        attribute intensity : IntensityValue;
        attribute decayTime : DecayTimeValue;
    }
    
    item def OxygenReading {
        attribute concentration : OxygenConcentrationValue;
        attribute temperature : TemperatureValue;
        attribute pressure : PressureValue;
        attribute timestamp : ISQ::TimeValue;
        attribute quality : Real;
    }
    
    port def OpticalExcitationPort {
        out item excitation : ExcitationLight;
    }
    
    port def OpticalEmissionPort {
        in item emission : FluorescenceEmission;
    }
    
    port def DataOutputPort {
        out item reading : OxygenReading;
    }
    
    port def PowerInputPort {
        in item power : ISQ::PowerValue;
    }
    
    port def SampleInterfacePort {
        attribute exposedToSample : Boolean;
    }
    
    part def LEDExcitationSource {
        attribute nominalWavelength : WavelengthValue;
        attribute outputPower : OpticalPowerValue;
        attribute pulseWidth : ISQ::TimeValue;
        
        port powerIn : PowerInputPort;
        port opticalOut : OpticalExcitationPort;
        
        action generateExcitation {
            in powerLevel : ISQ::PowerValue;
            in pulseDuration : ISQ::TimeValue;
            out excitationLight : ExcitationLight;
        }
    }
    
    part def OpticalFiber {
        attribute fiberLength : ISQ::LengthValue;
        attribute coreRadius : ISQ::LengthValue;
        attribute transmissionEfficiency : Real;
        attribute numericalAperture : Real;
        
        port inputPort : OpticalExcitationPort;
        port outputPort : OpticalExcitationPort;
        
        action transmitLight {
            in inputLight : ExcitationLight;
            out outputLight : ExcitationLight;
        }
    }
    
    part def FluorescentIndicator {
        attribute dyeType : String;
        attribute baselineLifetime : DecayTimeValue;
        attribute quenchingConstant : Real;
        attribute sensitivityRange : OxygenConcentrationValue[2];
        
        port opticalInput : OpticalExcitationPort;
        port opticalOutput : OpticalEmissionPort;
        port sampleInterface : SampleInterfacePort;
        
        action respondToExcitation {
            in excitation : ExcitationLight;
            in oxygenLevel : OxygenConcentrationValue;
            in temperature : TemperatureValue;
            out fluorescence : FluorescenceEmission;
        }
    }
    
    part def Photodetector {
        attribute detectorType : String;
        attribute sensitivity : Real;
        attribute responseTime : ISQ::TimeValue;
        attribute spectralRange : WavelengthValue[2];
        
        port powerIn : PowerInputPort;
        port opticalIn : OpticalEmissionPort;
        
        action detectFluorescence {
            in emission : FluorescenceEmission;
            out intensity : IntensityValue;
            out decayTime : DecayTimeValue;
        }
    }
    
    part def SignalProcessingUnit {
        attribute calibrationCoefficients : Real[*];
        attribute temperatureCompensation : Boolean;
        attribute pressureCompensation : Boolean;
        
        port powerIn : PowerInputPort;
        
        action calculateOxygenConcentration {
            in decayTime : DecayTimeValue;
            in intensity : IntensityValue;
            in temperature : TemperatureValue;
            in pressure : PressureValue;
            in baselineLifetime : DecayTimeValue;
            out concentration : OxygenConcentrationValue;
        }
        
        action applyCalibration {
            in rawConcentration : OxygenConcentrationValue;
            in environmentalFactors : Real[*];
            out calibratedConcentration : OxygenConcentrationValue;
        }
    }
    
    part def TemperatureSensor {
        attribute accuracy : TemperatureValue;
        attribute range : TemperatureValue[2];
        
        port powerIn : PowerInputPort;
        
        action measureTemperature {
            out temperature : TemperatureValue;
        }
    }
    
    part def PressureSensor {
        attribute accuracy : PressureValue;
        attribute range : PressureValue[2];
        
        port powerIn : PowerInputPort;
        
        action measurePressure {
            out pressure : PressureValue;
        }
    }
    
    part def DataInterface {
        attribute protocol : String;
        attribute updateRate : ISQ::FrequencyValue;
        
        port powerIn : PowerInputPort;
        port dataOut : DataOutputPort;
        
        action transmitReading {
            in reading : OxygenReading;
        }
    }
    
    part def PowerSupply {
        attribute voltage : ISQ::ElectricPotentialValue;
        attribute capacity : ISQ::EnergyValue;
        attribute batteryLevel : Real;
        
        action distributePower {
            out powerOutput : ISQ::PowerValue;
        }
    }
    
    action def EmitExcitation {
        in powerLevel : ISQ::PowerValue;
        out excitation : ExcitationLight;
    }
    
    action def DeliverExcitation {
        in excitation : ExcitationLight;
        out deliveredExcitation : ExcitationLight;
    }
    
    action def GenerateFluorescence {
        in excitation : ExcitationLight;
        in oxygenLevel : OxygenConcentrationValue;
        in temperature : TemperatureValue;
        out fluorescence : FluorescenceEmission;
    }
    
    action def CollectEmission {
        in fluorescence : FluorescenceEmission;
        out collectedEmission : FluorescenceEmission;
    }
    
    action def DetectSignal {
        in emission : FluorescenceEmission;
        out intensity : IntensityValue;
        out decayTime : DecayTimeValue;
    }
    
    action def ComputeConcentration {
        in decayTime : DecayTimeValue;
        in intensity : IntensityValue;
        in temperature : TemperatureValue;
        in pressure : PressureValue;
        out rawConcentration : OxygenConcentrationValue;
    }
    
    action def CalibrateResult {
        in rawConcentration : OxygenConcentrationValue;
        in temperature : TemperatureValue;
        in pressure : PressureValue;
        out calibratedConcentration : OxygenConcentrationValue;
    }
    
    action def OutputReading {
        in concentration : OxygenConcentrationValue;
        in temperature : TemperatureValue;
        in pressure : PressureValue;
        out reading : OxygenReading;
    }
    
    action def MeasureDissolvedOxygen {
        out finalReading : OxygenReading;
        
        first start;
        
        then action measureTemp {
            out temperature : TemperatureValue;
        }
        
        then action measurePress {
            out pressure : PressureValue;
        }
        
        then action emitExcitation : EmitExcitation {
            in powerLevel : ISQ::PowerValue;
            out excitation : ExcitationLight;
        }
        
        flow emitExcitation.excitation to deliverExcitation.excitation;
        
        then action deliverExcitation : DeliverExcitation {
            in excitation : ExcitationLight;
            out deliveredExcitation : ExcitationLight;
        }
        
        flow deliverExcitation.deliveredExcitation to generateFluorescence.excitation;
        
        then action generateFluorescence : GenerateFluorescence {
            in excitation : ExcitationLight;
            in oxygenLevel : OxygenConcentrationValue;
            in temperature = measureTemp.temperature;
            out fluorescence : FluorescenceEmission;
        }
        
        flow generateFluorescence.fluorescence to collectEmission.fluorescence;
        
        then action collectEmission : CollectEmission {
            in fluorescence : FluorescenceEmission;
            out collectedEmission : FluorescenceEmission;
        }
        
        flow collectEmission.collectedEmission to detectSignal.emission;
        
        then action detectSignal : DetectSignal {
            in emission : FluorescenceEmission;
            out intensity : IntensityValue;
            out decayTime : DecayTimeValue;
        }
        
        flow detectSignal.decayTime to computeConcentration.decayTime;
        flow detectSignal.intensity to computeConcentration.intensity;
        
        then action computeConcentration : ComputeConcentration {
            in decayTime : DecayTimeValue;
            in intensity : IntensityValue;
            in temperature = measureTemp.temperature;
            in pressure = measurePress.pressure;
            out rawConcentration : OxygenConcentrationValue;
        }
        
        flow computeConcentration.rawConcentration to calibrateResult.rawConcentration;
        
        then action calibrateResult : CalibrateResult {
            in rawConcentration : OxygenConcentrationValue;
            in temperature = measureTemp.temperature;
            in pressure = measurePress.pressure;
            out calibratedConcentration : OxygenConcentrationValue;
        }
        
        flow calibrateResult.calibratedConcentration to outputReading.concentration;
        
        then action outputReading : OutputReading {
            in concentration : OxygenConcentrationValue;
            in temperature = measureTemp.temperature;
            in pressure = measurePress.pressure;
            out reading : OxygenReading;
        }
        
        then assign finalReading := outputReading.reading;
        then done;
    }
    
    part def OptodeSensor {
        doc /* 
            Optical oxygen sensor that measures dissolved oxygen concentration
            using fluorescence quenching principles. The sensor excites a 
            fluorescent dye with light and measures the oxygen-dependent 
            quenching of fluorescence emission lifetime.
        */
        
        part excitationSource : LEDExcitationSource {
            attribute nominalWavelength = 470.0 [SI::nm];
            attribute outputPower = 0.010 [SI::W];
            attribute pulseWidth = 1.0e-4 [SI::s];
        }
        
        part deliveryFiber : OpticalFiber {
            attribute fiberLength = 2.0 [SI::m];
            attribute coreRadius = 6.25e-5 [SI::m];
            attribute transmissionEfficiency = 0.90;
            attribute numericalAperture = 0.275;
        }
        
        part sensingElement : FluorescentIndicator {
            attribute dyeType = "Ruthenium Complex";
            attribute baselineLifetime = 5.0e-6 [SI::s];
            attribute quenchingConstant = 0.18;
        }
        
        part collectionFiber : OpticalFiber {
            attribute fiberLength = 2.0 [SI::m];
            attribute coreRadius = 6.25e-5 [SI::m];
            attribute transmissionEfficiency = 0.88;
            attribute numericalAperture = 0.275;
        }
        
        part detector : Photodetector {
            attribute detectorType = "Silicon Photodiode";
            attribute sensitivity = 0.95;
            attribute responseTime = 5.0e-7 [SI::s];
        }
        
        part processor : SignalProcessingUnit {
            attribute temperatureCompensation = true;
            attribute pressureCompensation = true;
        }
        
        part tempSensor : TemperatureSensor {
            attribute accuracy = 0.1 [SI::K];
        }
        
        part pressureSensor : PressureSensor {
            attribute accuracy = 1000.0 [SI::Pa];
        }
        
        part dataInterface : DataInterface {
            attribute protocol = "RS-485";
            attribute updateRate = 1.0 [SI::Hz];
        }
        
        part powerSupply : PowerSupply {
            attribute voltage = 12.0 [SI::V];
            attribute capacity = 180000.0 [SI::J];
            attribute batteryLevel = 1.0;
        }
        
        port measurementOutput : DataOutputPort;
        port sampleAccess : SampleInterfacePort;
        
        connect powerSupply to excitationSource.powerIn;
        connect powerSupply to detector.powerIn;
        connect powerSupply to processor.powerIn;
        connect powerSupply to tempSensor.powerIn;
        connect powerSupply to pressureSensor.powerIn;
        connect powerSupply to dataInterface.powerIn;
        
        connect excitationSource.opticalOut to deliveryFiber.inputPort;
        connect deliveryFiber.outputPort to sensingElement.opticalInput;
        connect sensingElement.opticalOutput to collectionFiber.inputPort;
        connect collectionFiber.outputPort to detector.opticalIn;
        connect dataInterface.dataOut to measurementOutput;
        connect sampleAccess to sensingElement.sampleInterface;
        
        perform action measureOxygen[*] ordered references MeasureDissolvedOxygen;
        
        part excitationSource {
            perform measureOxygen.emitExcitation;
        }
        
        part deliveryFiber {
            perform measureOxygen.deliverExcitation;
        }
        
        part sensingElement {
            perform measureOxygen.generateFluorescence;
        }
        
        part collectionFiber {
            perform measureOxygen.collectEmission;
        }
        
        part detector {
            perform measureOxygen.detectSignal;
        }
        
        part processor {
            perform measureOxygen.computeConcentration;
            perform measureOxygen.calibrateResult;
        }
        
        part tempSensor {
            perform measureOxygen.measureTemp;
        }
        
        part pressureSensor {
            perform measureOxygen.measurePress;
        }
        
        part dataInterface {
            perform measureOxygen.outputReading;
        }
    }
    
    requirement def MeasurementAccuracyRequirement {
        doc /* 
            The optode sensor shall measure dissolved oxygen concentration
            with an accuracy of ±2% of reading or ±0.1 mg/L, whichever is greater,
            across the full measurement range.
        */
        attribute maxError : OxygenConcentrationValue;
        attribute measurementRange : OxygenConcentrationValue[2];
    }
    
    requirement def ResponseTimeRequirement {
        doc /* 
            The sensor shall achieve 90% of final reading within 30 seconds
            for step changes in oxygen concentration.
        */
        attribute t90ResponseTime : ISQ::TimeValue;
    }
    
    requirement def OperatingRangeRequirement {
        doc /* 
            The sensor shall operate over dissolved oxygen concentrations
            from 0 to 20 mg/L, temperatures from 0 to 50°C, and pressures
            from 0.5 to 2.0 bar.
        */
        attribute oxygenRange : OxygenConcentrationValue[2];
        attribute temperatureRange : TemperatureValue[2];
        attribute pressureRange : PressureValue[2];
    }
    
    requirement def StabilityRequirement {
        doc /* 
            The sensor shall maintain calibration drift of less than 1% per month
            under continuous operation.
        */
        attribute maxDriftRate : Real;
    }
    
    requirement <'REQ-001'> measurementAccuracy : MeasurementAccuracyRequirement {
        subject sensor : OptodeSensor;
    }
    
    requirement <'REQ-002'> responseTime : ResponseTimeRequirement {
        subject sensor : OptodeSensor;
        attribute t90ResponseTime = 30.0 [SI::s];
    }
    
    requirement <'REQ-003'> operatingRange : OperatingRangeRequirement {
        subject sensor : OptodeSensor;
    }
    
    requirement <'REQ-004'> stability : StabilityRequirement {
        subject sensor : OptodeSensor;
        attribute maxDriftRate = 0.01;
    }
    
    requirement <'REQ-SYS-001'> primaryFunction {
        doc /* 
            The optode system shall continuously measure dissolved oxygen concentration
            in aqueous samples using fluorescence quenching principles, providing
            accurate, real-time oxygen readings compensated for temperature and pressure.
        */
        
        subject optode : OptodeSensor;
        
        assume constraint sampleContact {
            doc /* The sensing element must be in contact with the sample medium. */
        }
        
        require measurementAccuracy;
        require responseTime;
        require operatingRange;
        require stability;
    }
}
