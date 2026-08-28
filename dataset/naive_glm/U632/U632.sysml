package CeilometerSystem {
    import ScalarValues::*;
    
    attribute def Length :> Real { unit 'm'; }
    attribute def Duration :> Real { unit 's'; }
    attribute def Power :> Real { unit 'W'; }
    attribute def Irradiance :> Real { unit 'W/m^2'; }
    attribute def DateTime :> String;
    attribute def Confidence :> Real { unit '1'; min = 0; max = 1; }
    
    item def LaserPulse {
        attribute power : Power;
        attribute duration : Duration;
        attribute wavelength : Length;
    }
    
    item def ScatteredLight {
        attribute intensity : Irradiance;
        attribute timeOfFlight : Duration;
    }
    
    item def CloudMeasurement {
        attribute height : Length;
        attribute timestamp : DateTime;
        attribute confidence : Confidence;
    }
    
    part def LaserTransmitter {
        out port emittedPulse : LaserPulse;
        
        action emitPulse {
            out pulse : LaserPulse;
        }
    }
    
    part def OpticalReceiver {
        in port incomingLight : ScatteredLight;
        out port detectedSignal : ScatteredLight;
        
        action detectLight {
            in light : ScatteredLight;
            out signal : ScatteredLight;
        }
    }
    
    part def SignalProcessor {
        in port receivedSignal : ScatteredLight;
        out port measurementOut : CloudMeasurement;
        
        attribute speedOfLight : Real = 299792458 { unit 'm/s'; }
        
        action processSignal {
            in signal : ScatteredLight;
            out measurement : CloudMeasurement;
        }
    }
    
    part def Sky {
        in port emittedPulse : LaserPulse;
        out port scatteredLight : ScatteredLight;
    }
    
    part def Ceilometer {
        in port commandPort : String;
        out port cloudData : CloudMeasurement;
        
        attribute measurementInterval : Duration = 15 [s];
        
        part laserTransmitter : LaserTransmitter;
        part opticalReceiver : OpticalReceiver;
        part signalProcessor : SignalProcessor;
        part sky : Sky;
        
        connection txToSky connect laserTransmitter.emittedPulse to sky.emittedPulse;
        connection skyToRx connect sky.scatteredLight to opticalReceiver.incomingLight;
        connection rxToProc connect opticalReceiver.detectedSignal to signalProcessor.receivedSignal;
        connection procToOut connect signalProcessor.measurementOut to cloudData;
        
        attribute command : String;
        attribute warmupTimer : Duration;
        attribute faultDetected : Boolean;
        attribute diagnosticsPassed : Boolean;
        
        state machine CeilometerStates {
            state standby;
            state warmup;
            state active;
            state fault;
            
            transition initial to standby;
            transition standby to warmup when { command == "activate" }
            transition warmup to active when { warmupTimer >= 30 [s] }
            transition active to fault when { faultDetected == true }
            transition fault to standby when { command == "reset" }
            transition fault to active when { diagnosticsPassed == true }
            
            state active {
                entry { /* start continuous measurements */ }
                do { /* perform measurement cycle */ }
            }
        }
    }
    
    requirement def MeasurementRangeRequirement {
        doc "The Ceilometer shall measure cloud base height up to 7500 meters.";
        attribute maxRange : Length = 7500 [m];
        subject ceilometer : Ceilometer;
        require constraint { ceilometer.cloudData.height <= maxRange }
    }
    
    requirement def AccuracyRequirement {
        doc "The Ceilometer shall measure cloud base height with an accuracy of +/- 10 meters.";
        attribute maxError : Length = 10 [m];
        subject ceilometer : Ceilometer;
        require constraint { /* accuracy constraint */ }
    }
    
    requirement def UpdateRateRequirement {
        doc "The Ceilometer shall update cloud height measurements at least every 15 seconds.";
        attribute minUpdateInterval : Duration = 15 [s];
        subject ceilometer : Ceilometer;
        require constraint { ceilometer.measurementInterval <= minUpdateInterval }
    }
    
    requirement spec CeilometerRequirements {
        requirement rangeReq : MeasurementRangeRequirement;
        requirement accuracyReq : AccuracyRequirement;
        requirement updateRateReq : UpdateRateRequirement;
    }
}
