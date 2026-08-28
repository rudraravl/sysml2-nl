package RDFSystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQSpace::*;
    import ISQTime::*;

    // ---- Value types with units ----
    value type Frequency :> ISQ::Frequency {
        unit "Hz";
    }
    value type PhaseAngle :> ISQ::PlaneAngle {
        unit "rad";
    }
    value type Bearing :> ISQ::PlaneAngle {
        unit "deg";
    }
    value type Confidence :> Real {
        unit "percent";
    }
    value type Distance :> ISQ::Length {
        unit "m";
    }
    value type TimeDelay :> ISQ::Time {
        unit "s";
    }
    value type SignalStrength :> Real {
        unit "dBm";
    }
    value type UpdateRate :> Real {
        unit "Hz";
    }

    // ---- Item definitions ----
    item def RFSignal {
        attribute frequency : Frequency;
        attribute strength : SignalStrength;
        attribute phase : PhaseAngle;
        attribute timestamp : Time;
    }

    item def BearingSolution {
        attribute bearing : Bearing;
        attribute confidence : Confidence;
        attribute timestamp : Time;
        attribute targetFrequency : Frequency;
    }

    item def ControlCommand {
        attribute targetFrequency : Frequency;
        attribute mode : String;
    }

    item def DisplayUpdate {
        attribute solution : BearingSolution;
        attribute plotType : String;
    }

    // ---- Port definitions ----
    port def RFOutPort {
        out item signal : RFSignal;
    }

    port def RFInPort {
        in item signal : RFSignal;
    }

    port def BearingOutPort {
        out item solution : BearingSolution;
    }

    port def BearingInPort {
        in item solution : BearingSolution;
    }

    port def CommandOutPort {
        out item command : ControlCommand;
    }

    port def CommandInPort {
        in item command : ControlCommand;
    }

    // ---- Antenna element ----
    part def AntennaElement {
        attribute elementId : Integer;
        attribute angularPosition : Bearing;
        attribute radius : Distance;
        port rfOut : RFOutPort;

        action def Receive {
            in targetFreq : Frequency;
            out signal : RFSignal;
        }
    }

    // ---- Antenna array (4 elements, circular) ----
    part def AntennaArray {
        attribute arrayRadius : Distance = 0.5 [m];
        attribute elementCount : Integer = 4;
        port rfOut1, rfOut2, rfOut3, rfOut4 : RFOutPort;

        part element1 : AntennaElement {
            attribute elementId = 1;
            attribute angularPosition = 0 [deg];
            attribute radius = 0.5 [m];
        }
        part element2 : AntennaElement {
            attribute elementId = 2;
            attribute angularPosition = 90 [deg];
            attribute radius = 0.5 [m];
        }
        part element3 : AntennaElement {
            attribute elementId = 3;
            attribute angularPosition = 180 [deg];
            attribute radius = 0.5 [m];
        }
        part element4 : AntennaElement {
            attribute elementId = 4;
            attribute angularPosition = 270 [deg];
            attribute radius = 0.5 [m];
        }

        flow from element1.rfOut.signal to rfOut1.signal;
        flow from element2.rfOut.signal to rfOut2.signal;
        flow from element3.rfOut.signal to rfOut3.signal;
        flow from element4.rfOut.signal to rfOut4.signal;
    }

    // ---- RF receiver ----
    part def RFReceiver {
        attribute receiverId : Integer;
        attribute tunedFrequency : Frequency;
        attribute bandwidth : Frequency;
        attribute gain : Real;
        port rfIn : RFInPort;
        port ifOut : RFOutPort;

        action def Tune {
            in freq : Frequency;
            then update tunedFrequency = freq;
        }

        action def Downconvert {
            in signal : RFSignal;
            out converted : RFSignal;
        }

        action def ReceiveChain {
            in signal : RFSignal;
            in targetFreq : Frequency;
            out converted : RFSignal;
            perform Tune(targetFreq);
            perform Downconvert(signal) -> converted;
        }
    }

    // ---- Signal processor ----
    part def SignalProcessor {
        attribute arrayRadius : Distance = 0.5 [m];
        attribute minConfidence : Confidence = 50;
        port ifIn1, ifIn2, ifIn3, ifIn4 : RFInPort;
        port bearingOut : BearingOutPort;
        port cmdIn : CommandInPort;

        action def ComputePhaseDifferences {
            in s1, s2, s3, s4 : RFSignal;
            out phaseDiffs : PhaseAngle[6];
        }

        action def ComputeTimeDelays {
            in phaseDiffs : PhaseAngle[6];
            in frequency : Frequency;
            out delays : TimeDelay[6];
        }

        action def ComputeBearing {
            in delays : TimeDelay[6];
            in radius : Distance;
            out solution : BearingSolution;
        }

        action def ProcessCycle {
            in s1, s2, s3, s4 : RFSignal;
            out solution : BearingSolution;
            perform ComputePhaseDifferences(s1, s2, s3, s4) -> phaseDiffs;
            perform ComputeTimeDelays(phaseDiffs, s1.frequency) -> delays;
            perform ComputeBearing(delays, arrayRadius) -> solution;
        }
    }

    // ---- Display unit ----
    part def DisplayUnit {
        attribute plotType : String = "polar";
        attribute refreshRate : UpdateRate = 10;
        port displayIn : BearingInPort;

        action def RenderPolarPlot {
            in solution : BearingSolution;
        }

        action def UpdateDisplay {
            in solution : BearingSolution;
            perform RenderPolarPlot(solution);
        }
    }

    // ---- Control unit ----
    part def ControlUnit {
        attribute targetFrequency : Frequency;
        attribute mode : String;
        port cmdOut : CommandOutPort;

        action def SetFrequency {
            in freq : Frequency;
            then update targetFrequency = freq;
            then send ControlCommand{targetFrequency = freq, mode = mode} to cmdOut;
        }

        action def SetMode {
            in newMode : String;
            then update mode = newMode;
            then send ControlCommand{targetFrequency = targetFrequency, mode = newMode} to cmdOut;
        }
    }

    // ---- Top-level RDF system ----
    part def RDFSystem {
        attribute operatingFrequency : Frequency;
        attribute updateRate : UpdateRate = 10;
        attribute bearingError : Bearing;
        port operatorCmd : CommandInPort;

        part antennaArray : AntennaArray;
        part receiver1 : RFReceiver { attribute receiverId = 1; }
        part receiver2 : RFReceiver { attribute receiverId = 2; }
        part receiver3 : RFReceiver { attribute receiverId = 3; }
        part receiver4 : RFReceiver { attribute receiverId = 4; }
        part processor : SignalProcessor;
        part display : DisplayUnit;
        part controller : ControlUnit;

        // RF connections: antenna array to receivers
        flow from antennaArray.rfOut1.signal to receiver1.rfIn.signal;
        flow from antennaArray.rfOut2.signal to receiver2.rfIn.signal;
        flow from antennaArray.rfOut3.signal to receiver3.rfIn.signal;
        flow from antennaArray.rfOut4.signal to receiver4.rfIn.signal;

        // IF connections: receivers to processor
        flow from receiver1.ifOut.signal to processor.ifIn1.signal;
        flow from receiver2.ifOut.signal to processor.ifIn2.signal;
        flow from receiver3.ifOut.signal to processor.ifIn3.signal;
        flow from receiver4.ifOut.signal to processor.ifIn4.signal;

        // Bearing connection: processor to display
        flow from processor.bearingOut.solution to display.displayIn.solution;

        // Command connection: controller to processor
        flow from controller.cmdOut.command to processor.cmdIn.command;

        // Operator command to controller
        flow from operatorCmd.command to controller.cmdOut.command;

        // ---- System behavior: state machine ----
        exhibit state machine RDFBehavior {
            entry;
            then powerOff;

            state powerOff;

            transition on powerOn
                from powerOff to standby;

            state standby {
                entry / perform SelfTest();
                do / perform MonitorHealth();
            }

            transition on testComplete
                from standby to ready;

            state ready {
                entry / perform InitializeReceivers();
            }

            transition on activate
                from ready to tracking;

            transition on deactivate
                from tracking to ready;

            transition on powerOffCmd
                from ready to powerOff;

            state tracking {
                entry / perform StartTracking();

                state Scanning;
                state Processing;
                state Updating;

                transition on signalDetected
                    from Scanning to Processing;
                transition on bearingComputed
                    from Processing to Updating;
                transition on displayUpdated
                    from Updating to Scanning;

                do / {
                    perform Scan();
                    perform Process();
                    perform UpdateDisplay();
                }
            }

            transition on powerOffCmd
                from tracking to powerOff;
        }

        action def SelfTest;
        action def MonitorHealth;
        action def InitializeReceivers;
        action def StartTracking;
        action def Scan;
        action def Process;
        action def UpdateDisplay;
    }

    // ---- Requirements ----
    requirement def AccuracyRequirement {
        attribute maxBearingError : Bearing = 2 [deg];
        subject rdf : RDFSystem;
        require that rdf.bearingError <= maxBearingError;
    }

    requirement def FrequencyRangeRequirement {
        attribute minFreq : Frequency = 3e6 [Hz];
        attribute maxFreq : Frequency = 3e9 [Hz];
        subject rdf : RDFSystem;
        require that rdf.operatingFrequency >= minFreq
            and rdf.operatingFrequency <= maxFreq;
    }

    requirement def UpdateRateRequirement {
        attribute minUpdateRate : UpdateRate = 10;
        subject rdf : RDFSystem;
        require that rdf.updateRate >= minUpdateRate;
    }

    requirement def ConfidenceRequirement {
        attribute minConfidence : Confidence = 50;
        subject processor : SignalProcessor;
        require that processor.minConfidence >= minConfidence;
    }

    requirement def ArrayGeometryRequirement {
        attribute nominalRadius : Distance = 0.5 [m];
        subject array : AntennaArray;
        require that array.arrayRadius == nominalRadius
            and array.elementCount == 4;
    }

    requirement def TrackingResponsivenessRequirement {
        attribute maxLatency : TimeDelay = 0.1 [s];
        subject rdf : RDFSystem;
        require that maxLatency >= 1.0 / rdf.updateRate;
    }
}
