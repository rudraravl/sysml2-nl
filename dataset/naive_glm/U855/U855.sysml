package RingLaserGyroscope {
    import ScalarValues::*;
    import ISQ::*;

    // ---- Unit Definitions ----
    unit 'rad/s' :> ISQ::AngularVelocityUnit;
    unit 'Hz' :> ISQ::FrequencyUnit;
    unit 'nm' :> ISQ::LengthUnit;
    unit 'm' :> ISQ::LengthUnit;
    unit 'm^2' :> ISQ::AreaUnit;
    unit 'V' :> ISQ::ElectricVoltageUnit;
    unit 's' :> ISQ::TimeUnit;
    unit 'mW' :> ISQ::PowerUnit;
    unit 'K' :> ISQ::ThermodynamicTemperatureUnit;

    // ---- Value Types ----
    value def AngularVelocityValue :> Real {
        unit 'rad/s';
    }
    value def FrequencyValue :> Real {
        unit 'Hz';
    }
    value def WavelengthValue :> Real {
        unit 'nm';
    }
    value def LengthValue :> Real {
        unit 'm';
    }
    value def AreaValue :> Real {
        unit 'm^2';
    }
    value def VoltageValue :> Real {
        unit 'V';
    }
    value def TimeStampValue :> Real {
        unit 's';
    }
    value def PowerValue :> Real {
        unit 'mW';
    }
    value def TemperatureValue :> Real {
        unit 'K';
    }

    // ---- Item Definitions ----
    item def LaserBeam {
        attribute wavelength : WavelengthValue;
        attribute frequency : FrequencyValue;
        attribute direction : String; // "CW" or "CCW"
        attribute intensity : PowerValue;
    }

    item def ElectricalSignal {
        attribute amplitude : VoltageValue;
        attribute beatFrequency : FrequencyValue;
    }

    item def RotationData {
        attribute timeStamp : TimeStampValue;
        attribute angularVelocity : AngularVelocityValue;
        attribute qualityFlag : Boolean;
    }

    // ---- Port Definitions ----
    port def OpticalPort {
        out beam : LaserBeam;
    }

    port def ElectricalOutputPort {
        out signal : ElectricalSignal;
    }

    port def DataOutputPort {
        out data : RotationData;
    }

    // ---- Part Definitions ----
    part def LaserGainMedium {
        attribute mediumType : String = "Helium-Neon";
        attribute nominalWavelength : WavelengthValue = 632.8 ['nm'];
        attribute outputPower : PowerValue = 5.0 ['mW'];
        attribute operatingTemperature : TemperatureValue = 293.15 ['K'];

        port opticalOut : OpticalPort;

        action def generateBeam {
            in wavelength : WavelengthValue;
            out beam : LaserBeam;
        }

        perform action generateBeam {
            in wavelength = nominalWavelength;
            out beam = opticalOut.beam;
        }
    }

    part def BeamSplitter {
        attribute splittingRatio : Real = 0.5;

        port input : OpticalPort;
        port cwOut : OpticalPort;
        port ccwOut : OpticalPort;

        action def splitBeam {
            in incomingBeam : LaserBeam;
            out cwBeam : LaserBeam;
            out ccwBeam : LaserBeam;
        }

        perform action splitBeam {
            in incomingBeam = input.beam;
            out cwBeam = cwOut.beam;
            out ccwBeam = ccwOut.beam;
        }
    }

    part def Mirror {
        attribute reflectivity : Real = 0.9999;
        attribute positionAngle : Real; // degrees

        port inPort : OpticalPort;
        port outPort : OpticalPort;

        action def reflect {
            in incomingBeam : LaserBeam;
            out reflectedBeam : LaserBeam;
        }

        perform action reflect {
            in incomingBeam = inPort.beam;
            out reflectedBeam = outPort.beam;
        }
    }

    part def RingCavity {
        attribute perimeter : LengthValue = 0.5 ['m'];
        attribute area : AreaValue = 0.02 ['m^2'];
        attribute numMirrors : Integer = 4;
        attribute cavityQFactor : Real = 1.0e6;

        part mirrors : Mirror[4] {
            attribute positionAngle = [0.0, 90.0, 180.0, 270.0];
        }

        port cwInput : OpticalPort;
        port ccwInput : OpticalPort;
        port cwOutput : OpticalPort;
        port ccwOutput : OpticalPort;

        action def propagateBeam {
            in inputBeam : LaserBeam;
            in direction : String;
            out outputBeam : LaserBeam;
        }

        perform action propagateBeam {
            in inputBeam = cwInput.beam;
            in direction = "CW";
            out outputBeam = cwOutput.beam;
        }

        perform action propagateBeam {
            in inputBeam = ccwInput.beam;
            in direction = "CCW";
            out outputBeam = ccwOutput.beam;
        }
    }

    part def Photodetector {
        attribute responsivity : Real = 0.5; // A/W
        attribute bandwidth : FrequencyValue = 100.0e6 ['Hz'];
        attribute darkCurrent : Real = 2.0e-9; // A

        port cwIn : OpticalPort;
        port ccwIn : OpticalPort;
        port electricalOut : ElectricalOutputPort;

        action def detectBeatFrequency {
            in cwBeam : LaserBeam;
            in ccwBeam : LaserBeam;
            out signal : ElectricalSignal;
        }

        perform action detectBeatFrequency {
            in cwBeam = cwIn.beam;
            in ccwBeam = ccwIn.beam;
            out signal = electricalOut.signal;
        }
    }

    part def SignalProcessor {
        attribute cavityPerimeter : LengthValue;
        attribute cavityArea : AreaValue;
        attribute laserWavelength : WavelengthValue;
        attribute samplingRate : FrequencyValue = 1000.0 ['Hz'];
        attribute scaleFactor : Real; // K = 4*A / (lambda * P)

        port signalIn : ElectricalOutputPort;
        port dataOut : DataOutputPort;

        action def calculateAngularVelocity {
            in signal : ElectricalSignal;
            in cavityPerimeter : LengthValue;
            in cavityArea : AreaValue;
            in laserWavelength : WavelengthValue;
            out data : RotationData;
        }

        perform action calculateAngularVelocity {
            in signal = signalIn.signal;
            in cavityPerimeter = cavityPerimeter;
            in cavityArea = cavityArea;
            in laserWavelength = laserWavelength;
            out data = dataOut.data;
        }
    }

    // ---- Main RLG Assembly ----
    part def RingLaserGyroscopeSystem {
        attribute systemId : String;
        attribute systemStatus : String;

        part gainMedium : LaserGainMedium;
        part splitter : BeamSplitter;
        part cavity : RingCavity {
            redefines perimeter = 0.5 ['m'];
            redefines area = 0.02 ['m^2'];
        }
        part detector : Photodetector;
        part processor : SignalProcessor {
            redefines cavityPerimeter = cavity.perimeter;
            redefines cavityArea = cavity.area;
            redefines laserWavelength = gainMedium.nominalWavelength;
        }

        // Connections
        connect gainMedium.opticalOut to splitter.input;
        connect splitter.cwOut to cavity.cwInput;
        connect splitter.ccwOut to cavity.ccwInput;
        connect cavity.cwOutput to detector.cwIn;
        connect cavity.ccwOutput to detector.ccwIn;
        connect detector.electricalOut to processor.signalIn;

        // Operational state attributes
        attribute powerOn : Boolean = false;
        attribute thermalStable : Boolean = false;
        attribute frequencyLocked : Boolean = false;
        attribute shutdownCommand : Boolean = false;

        // ---- State Machine ----
        state def OperationalStates {
            state Standby {
                entry : powerOn = false;
            }
            state Warmup {
                entry : powerOn = true;
                do : gainMedium.generateBeam;
            }
            state Locking {
                entry : thermalStable = true;
                do : cavity.propagateBeam;
            }
            state Operating {
                entry : frequencyLocked = true;
                do : detector.detectBeatFrequency;
                do : processor.calculateAngularVelocity;
            }

            transition Standby to Warmup
                when powerOn == true;
            transition Warmup to Locking
                when thermalStable == true;
            transition Locking to Operating
                when frequencyLocked == true;
            transition Operating to Standby
                when shutdownCommand == true;
        }

        exhibit state OperationalStates;

        // External interface
        port rotationDataOut : DataOutputPort;
        connect processor.dataOut to rotationDataOut;
    }

    // ---- Requirements ----
    requirement def MeasurementAccuracyRequirement {
        subject rlg : RingLaserGyroscopeSystem;
        requirement : the angular velocity measurement accuracy shall be better than 0.001 ['rad/s'];
    }

    requirement def BeatFrequencyProportionalityRequirement {
        subject detector : Photodetector;
        requirement : the beat frequency shall be directly proportional to the rate of rotation per the Sagnac effect;
    }

    requirement def OperationalStateRequirement {
        subject rlg : RingLaserGyroscopeSystem;
        requirement : the system shall transition through Standby, Warmup, Locking, and Operating states;
    }

    requirement def TimeStampedOutputRequirement {
        subject processor : SignalProcessor;
        requirement : the processor shall output time-stamped rotation data via the data output port;
    }

    requirement def CavityIntegrityRequirement {
        subject cavity : RingCavity;
        requirement : the ring cavity shall maintain mirror reflectivity above 0.9999 for all mirrors;
    }

    requirement def LaserStabilityRequirement {
        subject gainMedium : LaserGainMedium;
        requirement : the laser gain medium shall produce a coherent beam at 632.8 ['nm'] wavelength;
    }

    // ---- Requirement Satisfaction ----
    part def RLGVerification {
        subject rlg : RingLaserGyroscopeSystem;
        satisfy MeasurementAccuracyRequirement by rlg;
        satisfy OperationalStateRequirement by rlg;
        satisfy TimeStampedOutputRequirement by rlg.processor;
        satisfy BeatFrequencyProportionalityRequirement by rlg.detector;
        satisfy CavityIntegrityRequirement by rlg.cavity;
        satisfy LaserStabilityRequirement by rlg.gainMedium;
    }
}
