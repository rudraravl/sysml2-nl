package LaserTriangulationDistanceSensor {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def ValidityIndicator;
    
    item def TriggerCommand {
        attribute requestTime : ISQ::TimeValue;
    }
    
    item def DistanceReport {
        attribute measuredDistance : ISQ::LengthValue;
        attribute measurementValid : ValidityIndicator;
        attribute reportTime : ISQ::TimeValue;
    }
    
    item def OpticalSignal {
        attribute intensity : ISQ::LuminousIntensityValue;
    }
    
    item def AngleMeasurement {
        attribute detectionAngle : ISQ::PlaneAngleValue;
    }
    
    port def PowerPort {
        attribute voltage : ISQ::ElectricPotentialValue;
    }
    
    port def CommandPort {
        item trigger : TriggerCommand;
    }
    
    port def DataPort {
        item report : DistanceReport;
    }
    
    port def OpticalPort {
        item signal : OpticalSignal;
    }
    
    port def AnglePort {
        item angle : AngleMeasurement;
    }
    
    part def LaserEmitterModule {
        attribute emissionWavelength : ISQ::LengthValue;
        attribute opticalPower : ISQ::PowerValue;
        
        port laserOutput : OpticalPort;
    }
    
    part def PhotodetectorAssembly {
        attribute mountingPosition : ISQ::LengthValue;
        attribute detectionSensitivity : ISQ::PowerValue;
        
        port lightInput : OpticalPort;
        port dataOutput : OpticalPort;
    }
    
    action def ComputeReflectionAngle {
        in attribute detectorOffset : ISQ::LengthValue;
        in attribute signalIntensity : ISQ::LuminousIntensityValue;
        out attribute calculatedAngle : ISQ::PlaneAngleValue;
    }
    
    action def PerformTriangulation {
        in attribute firstAngle : ISQ::PlaneAngleValue;
        in attribute secondAngle : ISQ::PlaneAngleValue;
        in attribute baselineSeparation : ISQ::LengthValue;
        out attribute targetDistance : ISQ::LengthValue;
    }
    
    action def ValidateDistanceReading {
        in attribute distanceValue : ISQ::LengthValue;
        in attribute minimumBound : ISQ::LengthValue;
        in attribute maximumBound : ISQ::LengthValue;
        in attribute precisionThreshold : ISQ::LengthValue;
        out attribute isValid : ValidityIndicator;
    }
    
    action def ExecuteCompleteMeasurement {
        in attribute detectorBaseline : ISQ::LengthValue;
        in attribute lowerRangeLimit : ISQ::LengthValue;
        in attribute upperRangeLimit : ISQ::LengthValue;
        in attribute accuracyTarget : ISQ::LengthValue;
        out attribute finalDistance : ISQ::LengthValue;
        out attribute finalValidity : ValidityIndicator;
        
        private attribute angle1 : ISQ::PlaneAngleValue;
        private attribute angle2 : ISQ::PlaneAngleValue;
        private attribute computedDistance : ISQ::LengthValue;
        private attribute validityFlag : ValidityIndicator;
        
        first start;
        
        then action emissionStep;
        
        then action receptionStep {
            out attribute detector1Intensity : ISQ::LuminousIntensityValue;
            out attribute detector2Intensity : ISQ::LuminousIntensityValue;
        }
        
        then action angleCalc1 : ComputeReflectionAngle {
            in detectorOffset = 0.0[SI::m];
            in signalIntensity = receptionStep.detector1Intensity;
            out calculatedAngle;
        }
        
        then assign angle1 := angleCalc1.calculatedAngle;
        
        then action angleCalc2 : ComputeReflectionAngle {
            in detectorOffset = detectorBaseline;
            in signalIntensity = receptionStep.detector2Intensity;
            out calculatedAngle;
        }
        
        then assign angle2 := angleCalc2.calculatedAngle;
        
        then action distanceCalc : PerformTriangulation {
            in firstAngle = angle1;
            in secondAngle = angle2;
            in baselineSeparation = detectorBaseline;
            out targetDistance;
        }
        
        then assign computedDistance := distanceCalc.targetDistance;
        
        then action validation : ValidateDistanceReading {
            in distanceValue = computedDistance;
            in minimumBound = lowerRangeLimit;
            in maximumBound = upperRangeLimit;
            in precisionThreshold = accuracyTarget;
            out isValid;
        }
        
        then assign validityFlag := validation.isValid;
        then assign finalDistance := computedDistance;
        then assign finalValidity := validityFlag;
    }
    
    state def SensorOperationalStates {
        state standby;
        then state ready;
        then state acquiring;
        then state computing;
        then state transmitting;
    }
    
    part def TriangulationSensorUnit {
        attribute baselineDistance : ISQ::LengthValue;
        attribute minimumMeasurableDistance : ISQ::LengthValue;
        attribute maximumMeasurableDistance : ISQ::LengthValue;
        attribute specifiedAccuracy : ISQ::LengthValue;
        attribute measurementRate : ISQ::FrequencyValue;
        attribute requiredSupplyVoltage : ISQ::ElectricPotentialValue;
        
        port powerInput : PowerPort;
        port triggerInput : CommandPort;
        port dataOutput : DataPort;
        
        part laserSource : LaserEmitterModule {
            :>> emissionWavelength = 650e-9[SI::m];
            :>> opticalPower = 5e-3[SI::W];
        }
        
        part firstPhotodetector : PhotodetectorAssembly {
            :>> mountingPosition = 0.0[SI::m];
            :>> detectionSensitivity = 1e-3[SI::W];
        }
        
        part secondPhotodetector : PhotodetectorAssembly {
            :>> mountingPosition = baselineDistance;
            :>> detectionSensitivity = 1e-3[SI::W];
        }
        
        part angleProcessor1 {
            port signalInput : OpticalPort;
            port angleOutput : AnglePort;
            action processAngle : ComputeReflectionAngle;
        }
        
        part angleProcessor2 {
            port signalInput : OpticalPort;
            port angleOutput : AnglePort;
            action processAngle : ComputeReflectionAngle;
        }
        
        part centralComputer {
            port angle1Input : AnglePort;
            port angle2Input : AnglePort;
            port distanceOutput : DataPort;
            
            action computeDistance : PerformTriangulation {
                in :>> baselineSeparation = baselineDistance;
            }
            
            action validateResult : ValidateDistanceReading {
                in :>> minimumBound = minimumMeasurableDistance;
                in :>> maximumBound = maximumMeasurableDistance;
                in :>> precisionThreshold = specifiedAccuracy;
            }
        }
        
        connect firstPhotodetector.dataOutput to angleProcessor1.signalInput;
        connect secondPhotodetector.dataOutput to angleProcessor2.signalInput;
        connect angleProcessor1.angleOutput to centralComputer.angle1Input;
        connect angleProcessor2.angleOutput to centralComputer.angle2Input;
        connect centralComputer.distanceOutput to dataOutput;
        
        exhibit state operationMode : SensorOperationalStates;
        
        perform action fullMeasurementSequence : ExecuteCompleteMeasurement {
            in :>> detectorBaseline = baselineDistance;
            in :>> lowerRangeLimit = minimumMeasurableDistance;
            in :>> upperRangeLimit = maximumMeasurableDistance;
            in :>> accuracyTarget = specifiedAccuracy;
            out :>> finalDistance;
            out :>> finalValidity;
        }
    }
    
    part def ExternalControlInterface {
        port powerOut : PowerPort;
        port commandOut : CommandPort;
        port dataIn : DataPort;
    }
    
    requirement def RangeLimitsRequirement {
        doc /* The sensor shall measure distances from 10 cm to 10 meters. */
        
        subject sensor : TriangulationSensorUnit;
        
        require constraint {
            sensor.minimumMeasurableDistance == 0.1[SI::m] and
            sensor.maximumMeasurableDistance == 10.0[SI::m]
        }
    }
    
    requirement def PrecisionRequirement {
        doc /* The sensor shall achieve 1 millimeter measurement accuracy. */
        
        subject sensor : TriangulationSensorUnit;
        
        require constraint {
            sensor.specifiedAccuracy == 0.001[SI::m]
        }
    }
    
    requirement def UpdateFrequencyRequirement {
        doc /* The sensor shall deliver measurements at 50 Hz rate. */
        
        subject sensor : TriangulationSensorUnit;
        
        require constraint {
            sensor.measurementRate == 50.0[SI::Hz]
        }
    }
    
    requirement def VoltageSupplyRequirement {
        doc /* The sensor shall operate on 5 volt power supply. */
        
        subject sensor : TriangulationSensorUnit;
        
        require constraint {
            sensor.requiredSupplyVoltage == 5.0[SI::V]
        }
    }
    
    requirement def DetectorSpacingRequirement {
        doc /* The photodetectors shall be mounted 12 cm apart. */
        
        subject sensor : TriangulationSensorUnit;
        
        require constraint {
            sensor.baselineDistance == 0.12[SI::m]
        }
    }
    
    part sensorModule : TriangulationSensorUnit {
        :>> baselineDistance = 0.12[SI::m];
        :>> minimumMeasurableDistance = 0.1[SI::m];
        :>> maximumMeasurableDistance = 10.0[SI::m];
        :>> specifiedAccuracy = 0.001[SI::m];
        :>> measurementRate = 50.0[SI::Hz];
        :>> requiredSupplyVoltage = 5.0[SI::V];
    }
    
    requirement rangeLimits : RangeLimitsRequirement {
        :>> subject = sensorModule;
    }
    
    requirement precision : PrecisionRequirement {
        :>> subject = sensorModule;
    }
    
    requirement updateFreq : UpdateFrequencyRequirement {
        :>> subject = sensorModule;
    }
    
    requirement voltageSupply : VoltageSupplyRequirement {
        :>> subject = sensorModule;
    }
    
    requirement detectorSpacing : DetectorSpacingRequirement {
        :>> subject = sensorModule;
    }
    
    satisfy rangeLimits by sensorModule;
    satisfy precision by sensorModule;
    satisfy updateFreq by sensorModule;
    satisfy voltageSupply by sensorModule;
    satisfy detectorSpacing by sensorModule;
    
    part externalController : ExternalControlInterface;
    
    connect externalController.powerOut to sensorModule.powerInput;
    connect externalController.commandOut to sensorModule.triggerInput;
    connect sensorModule.dataOutput to externalController.dataIn;
}
