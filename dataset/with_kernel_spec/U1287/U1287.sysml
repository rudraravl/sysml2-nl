package GPSReceiverSystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    item def RFSignal {
        attribute frequency :> ISQ::frequency;
        attribute power :> ISQ::power;
    }

    item def DigitalSignal {
        attribute sampleRate :> ISQ::frequency;
        attribute bitDepth : Integer;
    }

    item def SatelliteMeasurement {
        attribute satelliteId : Integer;
        attribute pseudorange :> ISQ::length;
        attribute dopplerShift :> ISQ::frequency;
        attribute satellitePositionX :> ISQ::length;
        attribute satellitePositionY :> ISQ::length;
        attribute satellitePositionZ :> ISQ::length;
        attribute transmitTime :> ISQ::time;
    }

    item def NavigationSolution {
        attribute latitude :> ISQ::angle;
        attribute longitude :> ISQ::angle;
        attribute altitude :> ISQ::length;
        attribute velocityNorth :> ISQ::speed;
        attribute velocityEast :> ISQ::speed;
        attribute velocityUp :> ISQ::speed;
        attribute timeEstimate :> ISQ::time;
    }

    part def GPSAntenna {
        port signalOut {
            out signal : RFSignal;
        }
    }

    part def RFReceiver {
        port signalIn {
            in signal : RFSignal;
        }
        port digitalOut {
            out digitalSignal : DigitalSignal;
        }
    }

    part def CorrelationEngine {
        port digitalIn {
            in digitalSignal : DigitalSignal;
        }
        port measurementOut {
            out measurements : SatelliteMeasurement[4..*];
        }
    }

    part def NavigationProcessor {
        port measurementIn {
            in measurements : SatelliteMeasurement[4..*];
        }
        port solutionOut {
            out solution : NavigationSolution;
        }
    }

    part def UserDisplay {
        port solutionIn {
            in solution : NavigationSolution;
        }
    }

    calc def SolveNavigation {
        in measurements : SatelliteMeasurement[4..*];
        return solution : NavigationSolution;
    }

    action def ProcessGPS {
        in rfSignal : RFSignal;
        out solution : NavigationSolution;
        attribute updateInterval :> ISQ::time = 1 [s];
    }

    state def OperatingStates {
        state Off;
        state ColdStart;
        state Tracking;
        transition from Off to ColdStart;
        transition from ColdStart to Tracking;
    }

    part def GPSReceiver {
        part antenna : GPSAntenna;
        part rfReceiver : RFReceiver;
        part correlationEngine : CorrelationEngine;
        part navigationProcessor : NavigationProcessor;
        part userDisplay : UserDisplay;

        flow rfFlow of RFSignal from antenna.signalOut.signal to rfReceiver.signalIn.signal;
        flow digitalFlow of DigitalSignal from rfReceiver.digitalOut.digitalSignal to correlationEngine.digitalIn.digitalSignal;
        flow measurementFlow of SatelliteMeasurement from correlationEngine.measurementOut.measurements to navigationProcessor.measurementIn.measurements;
        flow solutionFlow of NavigationSolution from navigationProcessor.solutionOut.solution to userDisplay.solutionIn.solution;

        attribute coldStartTime :> ISQ::time = 45 [s];
        attribute updateRate :> ISQ::frequency = 1 [Hz];
        attribute horizontalAccuracy :> ISQ::length = 5 [m];

        state machine : OperatingStates;
    }

    requirement def GPSPerformanceRequirements {
        subject receiver : GPSReceiver;
        requirement coldStartFixTime {
            doc /* The receiver shall achieve a position fix within 45 seconds from a cold start. */
            constraint { receiver.coldStartTime <= 45 [s] }
        }
        requirement horizontalAccuracyReq {
            doc /* The receiver shall maintain a horizontal accuracy of 5 meters or better under normal conditions. */
            constraint { receiver.horizontalAccuracy <= 5 [m] }
        }
        requirement updateRateReq {
            doc /* The receiver shall update the navigation solution at least once per second. */
            constraint { receiver.updateRate >= 1 [Hz] }
        }
    }
}
