package CeilometerSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def CloudBaseHeight :> ISQ::LengthValue;
    attribute def LaserPulseEnergy :> ISQ::EnergyValue;
    attribute def BackscatterIntensity :> ISQ::PowerValue;
    attribute def VerticalVisibility :> ISQ::LengthValue;
    attribute def TimeOfFlight :> ISQ::TimeValue;
    attribute def CommandSignal;
    
    item def LaserPulse {
        attribute wavelength : ISQ::LengthValue;
        attribute energy : LaserPulseEnergy;
        attribute emissionTime : ISQ::TimeValue;
    }
    
    item def BackscatterSignal {
        attribute intensity : BackscatterIntensity;
        attribute returnTime : ISQ::TimeValue;
        attribute altitude : CloudBaseHeight;
    }
    
    item def CloudMeasurement {
        attribute baseHeight : CloudBaseHeight;
        attribute verticalVisibility : VerticalVisibility;
        attribute timestamp : ISQ::TimeValue;
        attribute confidence : Real;
    }
    
    port def LaserOutputPort {
        out item pulse : LaserPulse;
    }
    
    port def DetectorInputPort {
        in item signal : BackscatterSignal;
    }
    
    port def MeasurementDataPort {
        out item measurement : CloudMeasurement;
    }
    
    part def LaserTransmitter {
        attribute wavelength : ISQ::LengthValue;
        attribute pulseRate : ISQ::FrequencyValue;
        attribute power : ISQ::PowerValue;
        
        port laserOut : LaserOutputPort;
        
        action emitPulse {
            out pulse : LaserPulse;
        }
    }
    
    part def OpticalReceiver {
        attribute sensitivity : BackscatterIntensity;
        attribute aperture : ISQ::AreaValue;
        
        port detectorIn : DetectorInputPort;
        
        action detectSignal {
            in signal : BackscatterSignal;
            out detectedSignal : BackscatterSignal;
        }
    }
    
    part def SignalProcessor {
        attribute samplingRate : ISQ::FrequencyValue;
        attribute resolution : ISQ::LengthValue;
        
        action analyzeBackscatter {
            in signal : BackscatterSignal;
            out cloudData : CloudMeasurement;
        }
        
        action computeCloudBase {
            in timeOfFlight : TimeOfFlight;
            in speedOfLight : ISQ::SpeedValue;
            out height : CloudBaseHeight;
        }
    }
    
    action def TransmitLaserPulse {
        in power : ISQ::PowerValue;
        out pulse : LaserPulse;
    }
    
    action def DetectBackscatter {
        in emittedPulse : LaserPulse;
        out returnSignal : BackscatterSignal;
    }
    
    action def ProcessSignal {
        in signal : BackscatterSignal;
        out measurement : CloudMeasurement;
    }
    
    action def MeasureCloudBase {
        in attribute maxRange : CloudBaseHeight;
        in attribute measurementInterval : ISQ::TimeValue;
        out attribute measurements : CloudMeasurement[*] := ();
        
        private attribute currentMeasurement : CloudMeasurement;
        
        first start;
        then merge continueMeasuring;
        
        then action transmit : TransmitLaserPulse {
            in power = 1.5[SI::W] * 1.0e-3;
            out pulse : LaserPulse;
        }
        
        then action detect : DetectBackscatter {
            in emittedPulse = transmit.pulse;
            out returnSignal : BackscatterSignal;
        }
        
        then action process : ProcessSignal {
            in signal = detect.returnSignal;
            out measurement : CloudMeasurement;
        }
        
        then assign currentMeasurement := process.measurement;
        then assign measurements := measurements#(1..measurements#size, currentMeasurement);
        
        then decide;
            if currentMeasurement.baseHeight < maxRange then continueMeasuring;
            if currentMeasurement.baseHeight >= maxRange then done;
    }
    
    state def CeilometerStates {
        entry; then standby;
        
        state standby {
            entry assign operatingMode := false;
        }
        
        transition standby_to_warmup
            first standby
            accept startCmd : CommandSignal
            then warmup;
        
        state warmup {
            entry assign operatingMode := true;
            do action initializeSystem;
        }
        
        transition warmup_to_active
            first warmup
            then active;
        
        state active {
            do action performMeasurement : MeasureCloudBase;
        }
        
        transition active_to_standby
            first active
            accept stopCmd : CommandSignal
            then standby;
        
        transition active_to_fault
            first active
            accept errorCmd : CommandSignal
            then fault;
        
        state fault {
            entry assign operatingMode := false;
            do action runDiagnostics;
        }
        
        transition fault_to_standby
            first fault
            accept resetCmd : CommandSignal
            then standby;
        
        attribute operatingMode : Boolean;
    }
    
    part def Ceilometer {
        attribute maxAltitude : CloudBaseHeight;
        attribute accuracy : ISQ::LengthValue;
        attribute updateFrequency : ISQ::FrequencyValue;
        
        port measurementOutput : MeasurementDataPort;
        
        part transmitter : LaserTransmitter {
            attribute :>> wavelength = 910.0[SI::nm];
            attribute :>> pulseRate = 8.0e3[SI::Hz];
            attribute :>> power = 1.5e-3[SI::W];
        }
        
        part receiver : OpticalReceiver {
            attribute :>> sensitivity = 5.0e-10[SI::W];
            attribute :>> aperture = 0.01[SI::m] * 0.01[SI::m];
        }
        
        part processor : SignalProcessor {
            attribute :>> samplingRate = 1.0e6[SI::Hz];
            attribute :>> resolution = 10.0[SI::m];
        }
        
        connection opticalPath connect transmitter.laserOut to receiver.detectorIn;
        
        perform action measure : MeasureCloudBase {
            in maxRange = 7500.0[SI::m];
            in measurementInterval = 15.0[SI::s];
            out measurements;
        }
        
        exhibit state systemState : CeilometerStates;
    }
    
    requirement def CloudDetectionCapability {
        doc /* The ceilometer shall detect cloud base height from ground level 
               to 7500 meters altitude with accuracy of ±10 meters. */
        
        subject system : Ceilometer;
        
        require constraint rangeRequirement {
            system.maxAltitude >= 7500.0[SI::m]
        }
        
        require constraint accuracyRequirement {
            system.accuracy <= 10.0[SI::m]
        }
    }
    
    requirement def MeasurementFrequency {
        doc /* The ceilometer shall provide cloud base measurements 
               at intervals not exceeding 15 seconds. */
        
        subject system : Ceilometer;
        
        require constraint updateRate {
            system.updateFrequency >= (1.0 / 15.0)[SI::Hz]
        }
    }
    
    requirement def OperationalEnvironment {
        doc /* The ceilometer shall operate in varying atmospheric conditions
               including precipitation, fog, and temperature extremes. */
        
        subject system : Ceilometer;
        
        assume constraint environmentalConditions {
            doc /* System operates in temperature range -40°C to +60°C. */
        }
    }
    
    requirement <'SYS-REQ'> ceilometerSystemRequirement {
        doc /* The ceilometer system shall measure and report cloud base height
               and vertical visibility for meteorological and aviation applications
               by transmitting laser pulses and analyzing backscattered light. */
        
        subject ceilometerSystem : Ceilometer;
        
        require cloudDetectionReq : CloudDetectionCapability;
        require measurementFreqReq : MeasurementFrequency;
        require operationalEnvReq : OperationalEnvironment;
    }
    
    part ceilometer : Ceilometer {
        attribute :>> maxAltitude = 7500.0[SI::m];
        attribute :>> accuracy = 10.0[SI::m];
        attribute :>> updateFrequency = (1.0 / 15.0)[SI::Hz];
        
        satisfy ceilometerSystemRequirement;
    }
}
