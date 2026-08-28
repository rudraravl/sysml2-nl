package GPSReceiverSystem {
    import ScalarValues::*;
    
    value type FrequencyValue :> Real { unit "Hz"; }
    value type PowerValue :> Real { unit "dBm"; }
    value type TimeValue :> Real { unit "s"; }
    value type DistanceValue :> Real { unit "m"; }
    value type VelocityValue :> Real { unit "m/s"; }
    value type AngleValue :> Real { unit "deg"; }
    
    item def RFSignal {
        attribute frequency : FrequencyValue;
        attribute power : PowerValue;
        attribute satelliteId : Integer;
        attribute navData : String;
    }
    
    item def DigitalSignal {
        attribute sampleRate : FrequencyValue;
        attribute data : String;
    }
    
    item def SatelliteMeasurement {
        attribute satelliteId : Integer;
        attribute pseudorange : DistanceValue;
        attribute dopplerShift : FrequencyValue;
        attribute satellitePosition : String;
    }
    
    item def NavigationSolution {
        attribute latitude : AngleValue;
        attribute longitude : AngleValue;
        attribute altitude : DistanceValue;
        attribute velocityNorth : VelocityValue;
        attribute velocityEast : VelocityValue;
        attribute velocityUp : VelocityValue;
        attribute time : TimeValue;
    }
    
    port def RFPort {
        out item rfSignal : RFSignal;
    }
    
    port def DigitalPort {
        out item digitalSignal : DigitalSignal;
    }
    
    port def MeasurementPort {
        out item measurement : SatelliteMeasurement;
    }
    
    port def SolutionPort {
        out item solution : NavigationSolution;
    }
    
    part def GPSAntenna {
        port out rfOut : RFPort;
        
        action def CaptureSignals {
            in satelliteSignals : RFSignal[0..*];
            out captured : RFSignal[0..*];
        }
        
        perform action capture : CaptureSignals {
            out captured = rfOut.rfSignal;
        }
    }
    
    part def RFReceiver {
        port in rfIn : RFPort;
        port out digitalOut : DigitalPort;
        
        action def DownConvert {
            in rfSignal : RFSignal;
            out digitalSignal : DigitalSignal;
        }
        
        perform action downConvert : DownConvert {
            in rfSignal = rfIn.rfSignal;
            out digitalSignal = digitalOut.digitalSignal;
        }
    }
    
    part def CorrelationEngine {
        port in digitalIn : DigitalPort;
        port out measurementOut : MeasurementPort;
        
        action def Correlate {
            in digitalSignal : DigitalSignal;
            out measurements : SatelliteMeasurement[4..*];
        }
        
        perform action correlate : Correlate {
            in digitalSignal = digitalIn.digitalSignal;
            out measurements = measurementOut.measurement;
        }
    }
    
    part def NavigationProcessor {
        port in measurementIn : MeasurementPort;
        port out solutionOut : SolutionPort;
        
        action def ComputeSolution {
            in measurements : SatelliteMeasurement[4..*];
            out solution : NavigationSolution;
        }
        
        perform action compute : ComputeSolution {
            in measurements = measurementIn.measurement;
            out solution = solutionOut.solution;
        }
    }
    
    part def UserDisplay {
        port in solutionIn : SolutionPort;
        
        action def DisplaySolution {
            in solution : NavigationSolution;
        }
        
        perform action display : DisplaySolution {
            in solution = solutionIn.solution;
        }
    }
    
    part def GPSReceiver {
        attribute coldStartFixTime : TimeValue;
        attribute horizontalAccuracy : DistanceValue;
        attribute updateRate : FrequencyValue;
        attribute fixAchieved : Boolean;
        
        requirement fixTimeReq {
            doc "The system must achieve a position fix within 45 seconds from a cold start."
            attribute maxFixTime : TimeValue = 45 [s];
            require coldStartFixTime <= maxFixTime;
        }
        
        requirement accuracyReq {
            doc "The system must maintain a horizontal accuracy of 5 meters or better under normal conditions."
            attribute maxHorizontalError : DistanceValue = 5 [m];
            require horizontalAccuracy <= maxHorizontalError;
        }
        
        requirement updateRateReq {
            doc "The system must update the navigation solution at least once per second."
            attribute minUpdateRate : FrequencyValue = 1 [Hz];
            require updateRate >= minUpdateRate;
        }
        
        part antenna : GPSAntenna;
        part rfReceiver : RFReceiver;
        part correlationEngine : CorrelationEngine;
        part navigationProcessor : NavigationProcessor;
        part userDisplay : UserDisplay;
        
        connection antennaToRF connect antenna.rfOut to rfReceiver.rfIn;
        connection rfToCorrelator connect rfReceiver.digitalOut to correlationEngine.digitalIn;
        connection correlatorToNav connect correlationEngine.measurementOut to navigationProcessor.measurementIn;
        connection navToDisplay connect navigationProcessor.solutionOut to userDisplay.solutionIn;
        
        state def OperatingStates {
            state ColdStart;
            state Tracking;
            transition coldToTracking first ColdStart then Tracking when fixAchieved;
        }
        
        state operatingState : OperatingStates;
    }
}
