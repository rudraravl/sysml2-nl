package GlobalPositioningSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Latitude :> Real {
        unit = degree;
    }

    attribute def Longitude :> Real {
        unit = degree;
    }

    attribute def Altitude :> Real {
        unit = metre;
    }

    attribute def Velocity :> Real {
        unit = metrePerSecond;
    }

    attribute def TimeStamp :> Real {
        unit = second;
    }

    attribute def SignalPower :> Real {
        unit = watt;
    }

    attribute def Accuracy :> Real {
        unit = metre;
    }

    attribute def Frequency :> Real {
        unit = hertz;
    }

    item def NavigationSignal {
        attribute carrierFrequency : Frequency;
        attribute pseudorandomCodeId : Integer;
        attribute transmitTime : TimeStamp;
        attribute satelliteEphemerisAge : TimeStamp;
        attribute signalPower : SignalPower;
    }

    item def SatelliteEphemeris {
        attribute satelliteId : Integer;
        attribute orbitReferenceTime : TimeStamp;
        attribute semiMajorAxis : LengthValue;
        attribute inclination : Real;
        attribute rightAscension : Real;
        attribute eccentricity : Real;
        attribute clockBias : TimeStamp;
    }

    item def PseudorangeMeasurement {
        attribute satelliteId : Integer;
        attribute receiveTime : TimeStamp;
        attribute transmitTime : TimeStamp;
        attribute pseudorange : LengthValue;
        attribute signalToNoiseRatio : Real;
    }

    item def PositionFix {
        attribute latitude : Latitude;
        attribute longitude : Longitude;
        attribute altitude : Altitude;
        attribute groundSpeed : Velocity;
        attribute heading : Real;
        attribute fixTime : TimeStamp;
        attribute horizontalAccuracy : Accuracy;
        attribute verticalAccuracy : Accuracy;
        attribute satellitesUsed : Integer;
    }

    item def NavigationStatus {
        attribute receiverReady : Boolean;
        attribute antennaConnected : Boolean;
        attribute fixValid : Boolean;
        attribute satellitesTracked : Integer;
        attribute estimatedAccuracy : Accuracy;
    }

    port def RadioSignalInputPort {
        in item signal : NavigationSignal;
    }

    port def MeasurementPort {
        out item measurement : PseudorangeMeasurement;
    }

    port def EphemerisPort {
        out item ephemeris : SatelliteEphemeris;
    }

    port def PositionOutputPort {
        out item position : PositionFix;
    }

    port def StatusOutputPort {
        out item status : NavigationStatus;
    }

    port def UserCommandPort {
        in item requestedUpdateRateHz : Frequency;
    }

    part def GPSSatellite {
        attribute satelliteId : Integer;
        attribute nominalCarrierFrequency : Frequency = 1575.42 [MHz];
        attribute orbitAltitude : Altitude = 20200000 [m];

        port navigationBroadcast : RadioSignalInputPort;

        action transmitNavigationSignal {
            out item broadcastSignal : NavigationSignal;
        }
    }

    part def GPSAntenna {
        attribute gain : Real;
        attribute minimumDetectablePower : SignalPower = 1.0e-16 [W];

        port receivedSignal : RadioSignalInputPort;
        port conditionedSignal : RadioSignalInputPort;

        action receiveSatelliteSignals {
            in item incomingSignal : NavigationSignal;
            out item filteredSignal : NavigationSignal;
        }
    }

    part def RFFrontEnd {
        attribute l1Frequency : Frequency = 1575.42 [MHz];
        attribute intermediateFrequency : Frequency = 4.092 [MHz];
        attribute noiseFigure : Real;

        port rawSignal : RadioSignalInputPort;
        port sampledSignal : RadioSignalInputPort;

        action amplifyFilterAndDigitize {
            in item antennaSignal : NavigationSignal;
            out item digitalSignal : NavigationSignal;
        }
    }

    part def CorrelatorBank {
        attribute maxTrackedSatellites : Integer = 32;
        attribute acquisitionThreshold : Real = 35.0;

        port sampledSignalIn : RadioSignalInputPort;
        port measurementOut : MeasurementPort;
        port ephemerisOut : EphemerisPort;

        action acquireSatellite {
            in item candidateSignal : NavigationSignal;
            out item measurement : PseudorangeMeasurement;
            out item ephemeris : SatelliteEphemeris;
        }

        action trackSatellite {
            in item trackedSignal : NavigationSignal;
            out item updatedMeasurement : PseudorangeMeasurement;
        }
    }

    part def NavigationProcessor {
        attribute requiredSatellitesFor3DFix : Integer = 4;
        attribute maximumAllowedHorizontalError : Accuracy = 10.0 [m];

        port measurementIn : MeasurementPort;
        port ephemerisIn : EphemerisPort;
        port positionOut : PositionOutputPort;
        port statusOut : StatusOutputPort;

        action computePositionVelocityTime {
            in item measurement : PseudorangeMeasurement;
            in item ephemeris : SatelliteEphemeris;
            out item fix : PositionFix;
        }

        action estimateNavigationAccuracy {
            in item fix : PositionFix;
            out item status : NavigationStatus;
        }
    }

    part def TimeReference {
        attribute oscillatorStability : Real;
        attribute receiverClockBias : TimeStamp;
        attribute receiverClockDrift : Real;

        action disciplineClock {
            in item fix : PositionFix;
            out item correctedClockBias : TimeStamp;
        }
    }

    part def UserInterface {
        attribute configuredUpdateRate : Frequency = 1.0 [Hz];

        port commandIn : UserCommandPort;
        port positionDisplayIn : PositionOutputPort;
        port statusDisplayIn : StatusOutputPort;

        action presentPosition {
            in item position : PositionFix;
        }

        action presentStatus {
            in item status : NavigationStatus;
        }
    }

    part def GlobalPositioningSystem {
        attribute nominalUpdateRate : Frequency = 1.0 [Hz];
        attribute coldStartTimeLimit : TimeStamp = 60.0 [s];
        attribute warmStartTimeLimit : TimeStamp = 15.0 [s];
        attribute nominalHorizontalAccuracy : Accuracy = 5.0 [m];

        part satellites[24..32] : GPSSatellite;
        part antenna : GPSAntenna;
        part frontEnd : RFFrontEnd;
        part correlators : CorrelatorBank;
        part navigationProcessor : NavigationProcessor;
        part timeReference : TimeReference;
        part userInterface : UserInterface;

        port radioReception : RadioSignalInputPort;
        port positionOutput : PositionOutputPort;
        port statusOutput : StatusOutputPort;
        port commandInput : UserCommandPort;

        connect radioReception to antenna.receivedSignal;
        connect antenna.conditionedSignal to frontEnd.rawSignal;
        connect frontEnd.sampledSignal to correlators.sampledSignalIn;
        connect correlators.measurementOut to navigationProcessor.measurementIn;
        connect correlators.ephemerisOut to navigationProcessor.ephemerisIn;
        connect navigationProcessor.positionOut to positionOutput;
        connect navigationProcessor.statusOut to statusOutput;
        connect positionOutput to userInterface.positionDisplayIn;
        connect statusOutput to userInterface.statusDisplayIn;
        connect commandInput to userInterface.commandIn;

        action providePositionNavigationAndTiming {
            in item receivedSignal : NavigationSignal;
            out item positionFix : PositionFix;
            out item receiverStatus : NavigationStatus;

            first start;
            then receiveSignals;
            then conditionSignals;
            then acquireAndTrackSatellites;
            then calculatePseudoranges;
            then solvePositionVelocityTime;
            then validateFix;
            then publishNavigationSolution;
            then done;

            action receiveSignals {
                in item receivedSignal : NavigationSignal;
                out item antennaSignal : NavigationSignal;
            }

            action conditionSignals {
                in item antennaSignal : NavigationSignal;
                out item sampledSignal : NavigationSignal;
            }

            action acquireAndTrackSatellites {
                in item sampledSignal : NavigationSignal;
                out item measurement : PseudorangeMeasurement;
                out item ephemeris : SatelliteEphemeris;
            }

            action calculatePseudoranges {
                in item measurement : PseudorangeMeasurement;
                out item correctedMeasurement : PseudorangeMeasurement;
            }

            action solvePositionVelocityTime {
                in item correctedMeasurement : PseudorangeMeasurement;
                in item ephemeris : SatelliteEphemeris;
                out item positionFix : PositionFix;
            }

            action validateFix {
                in item positionFix : PositionFix;
                out item receiverStatus : NavigationStatus;
            }

            action publishNavigationSolution {
                in item positionFix : PositionFix;
                in item receiverStatus : NavigationStatus;
            }
        }

        state def ReceiverOperatingState {
            entry action initializeReceiver;

            state Off;
            state PowerOnSelfTest;
            state Searching;
            state Acquiring;
            state Tracking;
            state Navigating;
            state DegradedNavigation;
            state Fault;

            transition initial then Off;

            transition PowerApplied
                first Off
                then PowerOnSelfTest;

            transition SelfTestPassed
                first PowerOnSelfTest
                then Searching;

            transition SelfTestFailed
                first PowerOnSelfTest
                then Fault;

            transition SignalDetected
                first Searching
                then Acquiring;

            transition EphemerisDecoded
                first Acquiring
                then Tracking;

            transition FourOrMoreSatellitesTracked
                first Tracking
                then Navigating;

            transition AccuracyBelowRequired
                first Navigating
                then DegradedNavigation;

            transition AccuracyRecovered
                first DegradedNavigation
                then Navigating;

            transition SignalLost
                first Navigating
                then Searching;

            transition CriticalReceiverFault
                first Searching
                then Fault;

            transition PowerRemoved
                first Fault
                then Off;
        }
    }

    requirement def GPSPrimaryFunctionRequirement {
        subject gps : GlobalPositioningSystem;

        doc /* The Global Positioning System shall determine a user's geographic position, velocity, and precise time by receiving navigation signals from multiple orbiting satellites, measuring signal propagation time, computing pseudoranges, and solving for latitude, longitude, altitude, speed, heading, and clock correction. */

        require constraint {
            gps.nominalHorizontalAccuracy <= 5.0 [m]
        }

        require constraint {
            gps.nominalUpdateRate >= 1.0 [Hz]
        }
    }

    requirement def MinimumSatelliteRequirement {
        subject processor : NavigationProcessor;

        doc /* The navigation processor shall use measurements from at least four satellites to compute a three-dimensional position fix and receiver clock correction. */

        require constraint {
            processor.requiredSatellitesFor3DFix == 4
        }
    }

    requirement def PositionOutputRequirement {
        subject gps : GlobalPositioningSystem;

        doc /* The system shall output a validated position fix containing latitude, longitude, altitude, ground speed, heading, fix time, accuracy estimates, and the number of satellites used. */

        require constraint {
            gps.nominalUpdateRate >= 1.0 [Hz]
        }
    }

    requirement def StartupPerformanceRequirement {
        subject gps : GlobalPositioningSystem;

        doc /* The system shall produce a valid initial position fix within the required startup limits when sufficient satellite signals are available. */

        require constraint {
            gps.coldStartTimeLimit <= 60.0 [s]
        }

        require constraint {
            gps.warmStartTimeLimit <= 15.0 [s]
        }
    }

    satisfy GPSPrimaryFunctionRequirement by GlobalPositioningSystem;
    satisfy MinimumSatelliteRequirement by NavigationProcessor;
    satisfy PositionOutputRequirement by GlobalPositioningSystem;
    satisfy StartupPerformanceRequirement by GlobalPositioningSystem;

}