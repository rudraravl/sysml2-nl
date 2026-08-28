package 'Stud Finder System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def PowerOnSignal;
    attribute def CalibrationCompleteSignal;
    attribute def StudDetectedSignal;
    attribute def LowBatterySignal;
    
    item def WallMaterial {
        attribute density : ScalarValues::Real;
        attribute thickness : ISQ::LengthValue;
    }
    
    item def SensorReading {
        attribute densityValue : ScalarValues::Real;
        attribute position : ISQ::LengthValue;
        attribute timestamp : ScalarValues::Real;
    }
    
    item def FilteredReading {
        attribute densityValue : ScalarValues::Real;
        attribute deltaFromBaseline : ScalarValues::Real;
        attribute position : ISQ::LengthValue;
    }
    
    item def DetectionResult {
        attribute studPresent : ScalarValues::Boolean;
        attribute edgeDetected : ScalarValues::Boolean;
        attribute centerDetected : ScalarValues::Boolean;
        attribute confidence : ScalarValues::Real;
    }
    
    part def BatteryPack {
        attribute nominalVoltage : ScalarValues::Real = 9.0;
        attribute chargeLevel : ScalarValues::Real = 100.0;
        
        action discharge {
            in currentDrain : ScalarValues::Real;
            assign chargeLevel := chargeLevel - currentDrain;
        }
        
        state batteryStates {
            entry; then full;
            
            state full;
            if chargeLevel < 75.0 then partial;
            
            state partial;
            if chargeLevel < 25.0 then low;
            
            state low;
            if chargeLevel < 5.0 then depleted;
            
            state depleted;
        }
    }
    
    part def CapacitiveSensor {
        attribute currentReading : ScalarValues::Real;
        attribute sampleRate : ScalarValues::Real = 100.0;
        
        out port sensorOutput : SensorReading;
        
        action measureDensity {
            in wall : WallMaterial;
            out reading : SensorReading;
            assign reading.densityValue := wall.density;
            assign reading.timestamp := 0.0;
        }
    }
    
    part def SignalProcessor {
        attribute baselineDensity : ScalarValues::Real := 0.0;
        attribute detectionThreshold : ScalarValues::Real = 0.15;
        attribute centerThreshold : ScalarValues::Real = 0.30;
        
        in port sensorInput : SensorReading;
        out port detectionOutput : DetectionResult;
        
        action filterReading {
            in raw : SensorReading;
            out filtered : FilteredReading;
            assign filtered.densityValue := raw.densityValue;
            assign filtered.deltaFromBaseline := raw.densityValue - baselineDensity;
            assign filtered.position := raw.position;
        }
        
        action establishBaseline {
            in reading : SensorReading;
            assign baselineDensity := reading.densityValue;
        }
        
        action detectStud {
            in filtered : FilteredReading;
            out result : DetectionResult;
            assign result.studPresent := filtered.deltaFromBaseline >= detectionThreshold;
            assign result.edgeDetected := filtered.deltaFromBaseline >= detectionThreshold;
            assign result.centerDetected := filtered.deltaFromBaseline >= centerThreshold;
            assign result.confidence := filtered.deltaFromBaseline;
        }
    }
    
    part def VisualIndicator {
        attribute ledCount : ScalarValues::Integer = 5;
        attribute activeLeds : ScalarValues::Integer := 0;
        attribute brightness : ScalarValues::Real := 0.0;
        
        in port detectionInput : DetectionResult;
        
        action illuminate {
            in result : DetectionResult;
            assign activeLeds := 5;
            assign brightness := result.confidence;
        }
        
        action clear {
            assign activeLeds := 0;
            assign brightness := 0.0;
        }
    }
    
    part def AudioIndicator {
        attribute beepFrequency : ScalarValues::Real = 2500.0;
        attribute isActive : ScalarValues::Boolean := false;
        attribute beepRate : ScalarValues::Real := 0.0;
        
        in port detectionInput : DetectionResult;
        
        action beep {
            in detected : ScalarValues::Boolean;
            in confidence : ScalarValues::Real;
            assign isActive := detected;
            assign beepRate := confidence * 10.0;
        }
        
        action silence {
            assign isActive := false;
            assign beepRate := 0.0;
        }
    }
    
    action def CalibrateDevice {
        in finder : StudFinder;
        in wall : WallMaterial;
        out baselineEstablished : ScalarValues::Boolean;
        
        action measure {
            in sensor : CapacitiveSensor;
            in wall : WallMaterial;
            out reading : SensorReading;
            perform sensor.measureDensity(wall, reading);
        }
        
        action setBaseline {
            in processor : SignalProcessor;
            in reading : SensorReading;
            perform processor.establishBaseline(reading);
            assign baselineEstablished := true;
        }
        
        first measure then setBaseline;
    }
    
    action def ScanForStud {
        in finder : StudFinder;
        in wall : WallMaterial;
        out result : DetectionResult;
        
        action measure {
            in sensor : CapacitiveSensor;
            in wall : WallMaterial;
            out reading : SensorReading;
            perform sensor.measureDensity(wall, reading);
        }
        
        action filter {
            in raw : SensorReading;
            in processor : SignalProcessor;
            out filtered : FilteredReading;
            perform processor.filterReading(raw, filtered);
        }
        
        action detect {
            in filtered : FilteredReading;
            in processor : SignalProcessor;
            out detectResult : DetectionResult;
            perform processor.detectStud(filtered, detectResult);
        }
        
        first measure then filter then detect;
    }
    
    part def StudFinder {
        attribute maxDetectionDepth : ISQ::LengthValue;
        attribute locationAccuracy : ISQ::LengthValue;
        attribute isCalibrated : ScalarValues::Boolean := false;
        
        part battery : BatteryPack;
        part sensor : CapacitiveSensor;
        part processor : SignalProcessor;
        part visual : VisualIndicator;
        part audio : AudioIndicator;
        
        connect sensor.sensorOutput to processor.sensorInput;
        connect processor.detectionOutput to visual.detectionInput;
        connect processor.detectionOutput to audio.detectionInput;
        
        state operationalStates {
            in device : StudFinder;
            
            entry; then off;
            
            state off;
            accept PowerOnSignal
                then calibrating;
            
            state calibrating {
                entry assign device.isCalibrated := false;
                do action calibrate : CalibrateDevice;
            }
            accept CalibrationCompleteSignal
                if device.isCalibrated
                then scanning;
            
            state scanning {
                do action scan : ScanForStud;
            }
            accept StudDetectedSignal
                then alerting;
            
            state alerting;
            then scanning;
            
            accept LowBatterySignal
                then lowPower;
            
            state lowPower {
                do action reducedScan : ScanForStud;
            }
        }
    }
    
    requirement def DetectionDepthRequirement {
        doc /* The stud finder shall detect studs through wall material up to 38mm thickness */
        subject finder : StudFinder;
        require constraint {
            finder.maxDetectionDepth >= 38.0
        }
    }
    
    requirement def LocationAccuracyRequirement {
        doc /* The stud finder shall locate studs within 13mm accuracy */
        subject finder : StudFinder;
        require constraint {
            finder.locationAccuracy <= 13.0
        }
    }
    
    requirement def CalibrationRequirement {
        doc /* The stud finder shall be calibrated before scanning */
        subject finder : StudFinder;
        require constraint {
            finder.isCalibrated == true
        }
    }
    
    requirement def PowerRequirement {
        doc /* The stud finder shall operate on 9V battery power */
        subject finder : StudFinder;
        require constraint {
            finder.battery.nominalVoltage == 9.0
        }
    }
    
    part handheldStudFinder : StudFinder {
        :>> maxDetectionDepth = 38.0;
        :>> locationAccuracy = 13.0;
        
        part :>> battery {
            :>> nominalVoltage = 9.0;
            :>> chargeLevel = 100.0;
        }
        
        part :>> sensor {
            :>> sampleRate = 100.0;
        }
        
        part :>> processor {
            :>> detectionThreshold = 0.15;
            :>> centerThreshold = 0.30;
        }
        
        part :>> visual {
            :>> ledCount = 5;
        }
        
        part :>> audio {
            :>> beepFrequency = 2500.0;
        }
        
        satisfy depthReq : DetectionDepthRequirement by handheldStudFinder;
        satisfy accuracyReq : LocationAccuracyRequirement by handheldStudFinder;
        satisfy calibrationReq : CalibrationRequirement by handheldStudFinder;
        satisfy powerReq : PowerRequirement by handheldStudFinder;
    }
    
    action operateStudFinder {
        in device : StudFinder = handheldStudFinder;
        in testWall : WallMaterial;
        
        action powerOn {
            send PowerOnSignal() to device.operationalStates;
        }
        
        action performCalibration : CalibrateDevice {
            in :>> finder = device;
            in :>> wall = testWall;
            out :>> baselineEstablished;
        }
        
        action performScan : ScanForStud {
            in :>> finder = device;
            in :>> wall = testWall;
            out :>> result;
        }
        
        first powerOn then performCalibration then performScan;
    }
}
