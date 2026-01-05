package 'Global Positioning System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def SatelliteIdentifier;
    attribute def SignalQuality;
    attribute def PseudorangeValue :> LengthValue;
    attribute def DopplerShiftValue :> FrequencyValue;
    
    item def GeodeticPosition {
        attribute latitude : ISQ::planeAngleValue;
        attribute longitude : ISQ::planeAngleValue;
        attribute altitude : LengthValue;
    }
    
    item def VelocityVector {
        attribute northVelocity : SpeedValue;
        attribute eastVelocity : SpeedValue;
        attribute upVelocity : SpeedValue;
    }
    
    item def NavigationData {
        attribute ephemeris : String;
        attribute almanac : String;
        attribute clockCorrection : TimeValue;
    }
    
    item def RFSignal {
        attribute carrierFrequency : FrequencyValue;
        attribute modulationCode : String;
        attribute navigationMessage : NavigationData;
        attribute transmitTime : TimeValue;
    }
    
    item def ProcessedMeasurement {
        attribute satelliteID : SatelliteIdentifier;
        attribute pseudorange : PseudorangeValue;
        attribute dopplerShift : DopplerShiftValue;
        attribute signalQuality : SignalQuality;
        attribute receiveTime : TimeValue;
    }
    
    port def RFInputPort {
        in rfSignal : RFSignal;
    }
    
    port def MeasurementPort {
        out measurement : ProcessedMeasurement;
    }
    
    port def PositionOutputPort {
        out position : GeodeticPosition;
        out velocity : VelocityVector;
        out timeEstimate : TimeValue;
    }
    
    part def GPSAntenna {
        port rfOut {
            out signal : RFSignal;
        }
        
        perform action captureSignal {
            out capturedSignal : RFSignal;
        }
    }
    
    part def RFReceiver {
        port rfIn : RFInputPort;
        port measurementOut : MeasurementPort;
        
        perform action downconvertSignal {
            in rfSignal : RFSignal;
            out intermediateFrequencySignal : RFSignal;
        }
    }
    
    part def CorrelationEngine {
        port measurementIn {
            in rawSignal : RFSignal;
        }
        port measurementOut : MeasurementPort;
        
        perform action correlatePRN {
            in signal : RFSignal;
            out measurement : ProcessedMeasurement;
        }
    }
    
    part def NavigationProcessor {
        port measurementIn {
            in measurements : ProcessedMeasurement[4..*];
        }
        port solutionOut : PositionOutputPort;
        
        action def SolveNavigation {
            in measurements : ProcessedMeasurement[4..*];
            out position : GeodeticPosition;
            out velocity : VelocityVector;
            out timeOut : TimeValue;
        }
        
        perform action computeSolution {
            in measurements : ProcessedMeasurement[4..*];
            out position : GeodeticPosition;
            out velocity : VelocityVector;
            out timeOut : TimeValue;
            
            action solve : SolveNavigation {
                in measurements = computeSolution::measurements;
                out position;
                out velocity;
                out timeOut;
            }
        }
    }
    
    part def UserDisplay {
        port positionIn : PositionOutputPort;
        
        perform action displayLocation {
            in position : GeodeticPosition;
            in velocity : VelocityVector;
            in timeIn : TimeValue;
        }
    }
    
    part def GPSReceiverSystem {
        part antenna : GPSAntenna;
        part rfReceiver : RFReceiver;
        part correlator : CorrelationEngine;
        part navProcessor : NavigationProcessor;
        part display : UserDisplay;
        
        connection antToRF connect 
            antenna.rfOut.signal to rfReceiver.rfIn.rfSignal;
        
        connection rfToCorr connect 
            rfReceiver.measurementOut.measurement to correlator.measurementIn.rawSignal;
        
        connection corrToNav connect 
            correlator.measurementOut.measurement to navProcessor.measurementIn.measurements;
        
        connection navToDisp connect 
            navProcessor.solutionOut.position to display.positionIn.position;
        
        connection navVelToDisp connect 
            navProcessor.solutionOut.velocity to display.positionIn.velocity;
        
        connection navTimeToDisp connect 
            navProcessor.solutionOut.timeEstimate to display.positionIn.timeEstimate;
        
        perform action determinePosition[*] ordered references positionDetermination;
    }
    
    action def AcquireSatelliteSignals {
        out signals : RFSignal[*];
    }
    
    action def ProcessSignals {
        in rawSignals : RFSignal[*];
        out measurements : ProcessedMeasurement[*];
    }
    
    action def ValidateMeasurements {
        in measurements : ProcessedMeasurement[*];
        out validMeasurements : ProcessedMeasurement[*];
        out isValid : Boolean;
        out measurementCount : Integer;
    }
    
    action def ComputeNavigationSolution {
        in measurements : ProcessedMeasurement[4..*];
        out position : GeodeticPosition;
        out velocity : VelocityVector;
        out timeOut : TimeValue;
    }
    
    action def PresentSolution {
        in position : GeodeticPosition;
        in velocity : VelocityVector;
        in timeIn : TimeValue;
    }
    
    action positionDetermination {
        out finalPosition : GeodeticPosition;
        out finalVelocity : VelocityVector;
        out finalTime : TimeValue;
        
        first start;
        then merge continuousTracking;
        
        action acquire : AcquireSatelliteSignals {
            out satelliteSignals : RFSignal[*];
        }
        
        then action process : ProcessSignals {
            in rawSignals = acquire.satelliteSignals;
            out measurements : ProcessedMeasurement[*];
        }
        
        then action validate : ValidateMeasurements {
            in measurements = process.measurements;
            out validMeasurements : ProcessedMeasurement[*];
            out isValid : Boolean;
            out measurementCount : Integer;
        }
        
        then decide;
            if validate.isValid and validate.measurementCount >= 4 then computeSolution;
            if not validate.isValid or validate.measurementCount < 4 then continuousTracking;
        
        action computeSolution : ComputeNavigationSolution {
            in measurements = validate.validMeasurements;
            out position : GeodeticPosition;
            out velocity : VelocityVector;
            out timeOut : TimeValue;
        }
        
        then action present : PresentSolution {
            in position = computeSolution.position;
            in velocity = computeSolution.velocity;
            in timeIn = computeSolution.timeOut;
        }
        
        then assign finalPosition := computeSolution.position;
        then assign finalVelocity := computeSolution.velocity;
        then assign finalTime := computeSolution.timeOut;
        then continuousTracking;
    }
    
    requirement def FunctionalRequirement;
    requirement def PerformanceRequirement;
    requirement def AccuracyRequirement;
    
    requirement <'GPS-FR-001'> positionDeterminationFunction : FunctionalRequirement {
        doc /* The GPS receiver system shall continuously determine and output the user's 
                three-dimensional geodetic position (latitude, longitude, altitude), velocity, 
                and precise time by receiving and processing signals from multiple GPS satellites. */
        subject receiver : GPSReceiverSystem;
    }
    
    requirement <'GPS-PR-001'> minimumSatellites : PerformanceRequirement {
        doc /* The system shall acquire and track signals from at least four GPS satellites 
                simultaneously to compute a valid navigation solution. */
        subject receiver : GPSReceiverSystem;
    }
    
    requirement <'GPS-AR-001'> horizontalAccuracy : AccuracyRequirement {
        doc /* The system shall provide horizontal position accuracy of 5 meters or better 
                under nominal operating conditions (95% confidence level). */
        subject receiver : GPSReceiverSystem;
    }
    
    requirement <'GPS-AR-002'> verticalAccuracy : AccuracyRequirement {
        doc /* The system shall provide vertical position accuracy of 10 meters or better 
                under nominal operating conditions (95% confidence level). */
        subject receiver : GPSReceiverSystem;
    }
    
    requirement <'GPS-PR-002'> updateRate : PerformanceRequirement {
        doc /* The system shall update the position, velocity, and time solution at a rate 
                of at least 1 Hz during continuous operation. */
        subject receiver : GPSReceiverSystem;
    }
    
    requirement <'GPS-PR-003'> timeToFirstFix : PerformanceRequirement {
        doc /* The system shall achieve first position fix within 45 seconds from cold start 
                when at least four satellites are visible. */
        subject receiver : GPSReceiverSystem;
    }
    
    requirement <'GPS-SYS-001'> gpsSystemMission {
        doc /* The GPS receiver system shall provide continuous, accurate positioning, navigation, 
                and timing services to the user by processing satellite signals. */
        
        subject receiver : GPSReceiverSystem;
        
        assume constraint satelliteConstellation {
            doc /* A sufficient number of GPS satellites are visible above the horizon and 
                    transmitting valid navigation signals. */
        }
        
        assume constraint signalPropagation {
            doc /* GPS signals can propagate from satellites to the receiver antenna with 
                    acceptable signal strength and minimal interference. */
        }
        
        require positionDeterminationFunction;
        require minimumSatellites;
        require horizontalAccuracy;
        require verticalAccuracy;
        require updateRate;
        require timeToFirstFix;
    }
    
    part gpsReceiver : GPSReceiverSystem {
        satisfy gpsSystemMission;
        
        part antenna : GPSAntenna {
            perform positionDetermination.acquire;
        }
        
        part rfReceiver : RFReceiver {
            perform positionDetermination.process;
        }
        
        part correlator : CorrelationEngine {
            perform positionDetermination.validate;
        }
        
        part navProcessor : NavigationProcessor {
            perform positionDetermination.computeSolution;
        }
        
        part display : UserDisplay {
            perform positionDetermination.present;
        }
    }
}
