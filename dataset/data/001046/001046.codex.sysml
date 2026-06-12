package FabryPerotInterferometerModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    value def LengthValue {
        unit = SI::m;
        quantity kind = ISQ::length;
    }

    value def WavelengthValue {
        unit = SI::nm;
        quantity kind = ISQ::length;
    }

    value def FrequencyValue {
        unit = SI::Hz;
        quantity kind = ISQ::frequency;
    }

    value def PowerValue {
        unit = SI::W;
        quantity kind = ISQ::power;
    }

    value def VoltageValue {
        unit = SI::V;
        quantity kind = ISQ::electricPotential;
    }

    value def TemperatureValue {
        unit = SI::K;
        quantity kind = ISQ::thermodynamicTemperature;
    }

    value def Reflectance {
        : Real;
        constraint { 0.0 <= self and self <= 1.0 }
    }

    value def Transmittance {
        : Real;
        constraint { 0.0 <= self and self <= 1.0 }
    }

    value def Finesse {
        : Real;
        constraint { self > 0.0 }
    }

    value def PhaseRadians {
        unit = SI::rad;
        quantity kind = ISQ::planeAngle;
    }

    item def OpticalBeam {
        attribute wavelength : WavelengthValue;
        attribute opticalPower : PowerValue;
        attribute frequency : FrequencyValue;
        attribute phase : PhaseRadians;
        attribute polarizationState : String;
        attribute spatialMode : String;
    }

    item def ElectricalSignal {
        attribute voltage : VoltageValue;
        attribute bandwidth : FrequencyValue;
        attribute signalName : String;
    }

    item def ControlCommand {
        attribute targetCavityLength : LengthValue;
        attribute targetTemperature : TemperatureValue;
        attribute lockEnabled : Boolean;
    }

    port def OpticalInputPort {
        in item beamIn : OpticalBeam;
    }

    port def OpticalOutputPort {
        out item beamOut : OpticalBeam;
    }

    port def OpticalBidirectionalPort {
        in item incidentBeam : OpticalBeam;
        out item reflectedBeam : OpticalBeam;
    }

    port def ElectricalOutputPort {
        out item signalOut : ElectricalSignal;
    }

    port def ElectricalInputPort {
        in item signalIn : ElectricalSignal;
    }

    port def ControlInputPort {
        in item commandIn : ControlCommand;
    }

    part def LaserSource {
        attribute centerWavelength : WavelengthValue = 632.8 [SI::nm];
        attribute outputPower : PowerValue = 5.0e-3 [SI::W];
        attribute linewidth : FrequencyValue = 1.0e6 [SI::Hz];

        port opticalOut : OpticalOutputPort;

        action emitCoherentBeam {
            out item emitted : OpticalBeam;
        }
    }

    part def InputModeCleaner {
        attribute couplingEfficiency : Real = 0.92;
        attribute acceptedSpatialMode : String = "TEM00";

        port opticalIn : OpticalInputPort;
        port opticalOut : OpticalOutputPort;

        action filterSpatialMode {
            in item rawBeam : OpticalBeam;
            out item cleanedBeam : OpticalBeam;
        }
    }

    part def BeamSplitter {
        attribute splitRatio : Real = 0.50;

        port opticalIn : OpticalInputPort;
        port transmittedOut : OpticalOutputPort;
        port reflectedOut : OpticalOutputPort;
        port returnInOut : OpticalBidirectionalPort;

        action splitBeam {
            in item inputBeam : OpticalBeam;
            out item cavityBeam : OpticalBeam;
            out item referenceBeam : OpticalBeam;
        }
    }

    part def PartiallyReflectiveMirror {
        attribute reflectance : Reflectance;
        attribute transmittance : Transmittance;
        attribute surfaceFlatness : LengthValue = 1.0e-9 [SI::m];

        port frontFace : OpticalBidirectionalPort;
        port rearFace : OpticalBidirectionalPort;
    }

    part def PiezoelectricSpacer {
        attribute nominalLength : LengthValue = 0.050 [SI::m];
        attribute displacementRange : LengthValue = 2.0e-6 [SI::m];
        attribute currentLength : LengthValue = 0.050 [SI::m];

        port driveInput : ElectricalInputPort;

        action adjustCavityLength {
            in item driveSignal : ElectricalSignal;
            out displacement : LengthValue;
        }
    }

    part def FabryPerotCavity {
        attribute cavityLength : LengthValue = 0.050 [SI::m];
        attribute freeSpectralRange : FrequencyValue = 3.0e9 [SI::Hz];
        attribute finesse : Finesse = 120.0;
        attribute resonanceWavelength : WavelengthValue = 632.8 [SI::nm];

        part inputMirror : PartiallyReflectiveMirror {
            attribute reflectance = 0.96;
            attribute transmittance = 0.04;
        }

        part outputMirror : PartiallyReflectiveMirror {
            attribute reflectance = 0.96;
            attribute transmittance = 0.04;
        }

        part spacer : PiezoelectricSpacer;

        port opticalIn : OpticalInputPort;
        port reflectedOut : OpticalOutputPort;
        port transmittedOut : OpticalOutputPort;
        port lengthControlIn : ElectricalInputPort;

        connect opticalIn.beamIn to inputMirror.frontFace.incidentBeam;
        connect inputMirror.rearFace.reflectedBeam to outputMirror.frontFace.incidentBeam;
        connect outputMirror.frontFace.reflectedBeam to inputMirror.rearFace.incidentBeam;
        connect outputMirror.rearFace.reflectedBeam to transmittedOut.beamOut;
        connect inputMirror.frontFace.reflectedBeam to reflectedOut.beamOut;
        connect lengthControlIn.signalIn to spacer.driveInput.signalIn;

        action resonate {
            in item incidentBeam : OpticalBeam;
            in length : LengthValue;
            out item transmittedBeam : OpticalBeam;
            out item reflectedBeam : OpticalBeam;
        }

        state def CavityOperationalState {
            state Unaligned;
            state Scanning;
            state NearResonance;
            state Locked;
            state Saturated;

            transition first Unaligned then Scanning;

            transition Scanning then NearResonance
                accept OpticalBeam
                if phaseError < 0.10 [SI::rad];

            transition NearResonance then Locked
                accept ControlCommand
                if lockRequest == true;

            transition Locked then Scanning
                accept ControlCommand
                if lockRequest == false;

            transition Locked then Saturated
                accept OpticalBeam
                if intracavityPower > 0.50 [SI::W];

            transition Saturated then Scanning
                accept ControlCommand
                if resetRequested == true;

            attribute phaseError : PhaseRadians;
            attribute intracavityPower : PowerValue;
            attribute lockRequest : Boolean;
            attribute resetRequested : Boolean;
        }
    }

    part def Photodetector {
        attribute responsivity : Real = 0.45;
        attribute darkCurrentEquivalentVoltage : VoltageValue = 1.0e-3 [SI::V];
        attribute detectionBandwidth : FrequencyValue = 1.0e6 [SI::Hz];

        port opticalIn : OpticalInputPort;
        port electricalOut : ElectricalOutputPort;

        action convertOpticalPowerToVoltage {
            in item detectedBeam : OpticalBeam;
            out item detectorSignal : ElectricalSignal;
        }
    }

    part def LockInController {
        attribute modulationFrequency : FrequencyValue = 20.0e3 [SI::Hz];
        attribute proportionalGain : Real = 0.80;
        attribute integralGain : Real = 25.0;
        attribute lockTolerance : VoltageValue = 5.0e-3 [SI::V];

        port detectorInput : ElectricalInputPort;
        port actuatorOutput : ElectricalOutputPort;
        port commandInput : ControlInputPort;

        action computeErrorSignal {
            in item detectorSignal : ElectricalSignal;
            out item actuatorDrive : ElectricalSignal;
        }

        state def LockControlState {
            state Idle;
            state Sweep;
            state Acquire;
            state MaintainLock;
            state Fault;

            transition first Idle then Sweep
                accept ControlCommand
                if lockEnabled == true;

            transition Sweep then Acquire
                accept ElectricalSignal
                if abs(signalIn.voltage) < lockTolerance;

            transition Acquire then MaintainLock
                accept ElectricalSignal
                if abs(signalIn.voltage) < lockTolerance;

            transition MaintainLock then Sweep
                accept ElectricalSignal
                if abs(signalIn.voltage) >= 10.0e-3 [SI::V];

            transition MaintainLock then Idle
                accept ControlCommand
                if lockEnabled == false;

            transition Sweep then Fault
                accept ElectricalSignal
                if signalIn.voltage > 10.0 [SI::V];

            attribute lockEnabled : Boolean;
            attribute signalIn : ElectricalSignal;
        }
    }

    part def DataAcquisitionUnit {
        attribute sampleRate : FrequencyValue = 100.0e3 [SI::Hz];
        attribute resolutionBits : Integer = 16;

        port transmittedSignalIn : ElectricalInputPort;
        port reflectedSignalIn : ElectricalInputPort;

        action recordInterferenceFringes {
            in item transmittedVoltage : ElectricalSignal;
            in item reflectedVoltage : ElectricalSignal;
        }
    }

    part def ThermalEnclosure {
        attribute setPoint : TemperatureValue = 293.15 [SI::K];
        attribute stability : TemperatureValue = 0.01 [SI::K];

        port commandInput : ControlInputPort;

        action stabilizeTemperature {
            in item thermalCommand : ControlCommand;
            out achievedTemperature : TemperatureValue;
        }
    }

    part def FabryPerotInterferometerSystem {
        attribute primaryFunction : String =
            "Transmit or suppress incident coherent light according to optical cavity resonance, producing interference fringes that reveal wavelength, frequency, phase, or cavity-length changes.";

        part laser : LaserSource;
        part modeCleaner : InputModeCleaner;
        part splitter : BeamSplitter;
        part cavity : FabryPerotCavity;
        part transmittedDetector : Photodetector;
        part reflectedDetector : Photodetector;
        part controller : LockInController;
        part acquisition : DataAcquisitionUnit;
        part enclosure : ThermalEnclosure;

        port systemOpticalOutput : OpticalOutputPort;
        port systemCommandInput : ControlInputPort;

        connect laser.opticalOut.beamOut to modeCleaner.opticalIn.beamIn;
        connect modeCleaner.opticalOut.beamOut to splitter.opticalIn.beamIn;
        connect splitter.transmittedOut.beamOut to cavity.opticalIn.beamIn;
        connect cavity.transmittedOut.beamOut to transmittedDetector.opticalIn.beamIn;
        connect cavity.reflectedOut.beamOut to reflectedDetector.opticalIn.beamIn;
        connect transmittedDetector.electricalOut.signalOut to acquisition.transmittedSignalIn.signalIn;
        connect reflectedDetector.electricalOut.signalOut to acquisition.reflectedSignalIn.signalIn;
        connect reflectedDetector.electricalOut.signalOut to controller.detectorInput.signalIn;
        connect controller.actuatorOutput.signalOut to cavity.lengthControlIn.signalIn;
        connect cavity.transmittedOut.beamOut to systemOpticalOutput.beamOut;
        connect systemCommandInput.commandIn to controller.commandInput.commandIn;
        connect systemCommandInput.commandIn to enclosure.commandInput.commandIn;

        action measureOpticalResonance {
            in item incidentCommand : ControlCommand;
            out item transmittedSignal : ElectricalSignal;
            out item reflectedSignal : ElectricalSignal;
        }

        state def SystemState {
            state PoweredOff;
            state WarmUp;
            state Aligning;
            state Measuring;
            state LockedMeasurement;
            state Fault;

            transition first PoweredOff then WarmUp;

            transition WarmUp then Aligning
                if temperatureStable == true;

            transition Aligning then Measuring
                if opticalAlignmentComplete == true;

            transition Measuring then LockedMeasurement
                accept ControlCommand
                if commandIn.lockEnabled == true;

            transition LockedMeasurement then Measuring
                accept ControlCommand
                if commandIn.lockEnabled == false;

            transition Measuring then Fault
                if detectorSaturated == true;

            transition LockedMeasurement then Fault
                if lockLost == true and recoveryAttempts > 3;

            attribute temperatureStable : Boolean;
            attribute opticalAlignmentComplete : Boolean;
            attribute detectorSaturated : Boolean;
            attribute lockLost : Boolean;
            attribute recoveryAttempts : Integer;
            attribute commandIn : ControlCommand;
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc
        /* The system shall use multiple-beam interference in a Fabry-Perot cavity to convert small changes in wavelength, optical frequency, phase, or cavity length into measurable variations in transmitted and reflected optical intensity. */
    }

    requirement def ResonantTransmissionRequirement {
        doc
        /* When the round-trip optical phase is an integer multiple of 2*pi, the cavity shall provide a transmitted intensity maximum and a reflected intensity minimum for the incident coherent beam. */
    }

    requirement def CavityTuningRequirement {
        doc
        /* The system shall tune the optical cavity length over at least one free spectral range using the piezoelectric spacer. */

        require constraint {
            FabryPerotInterferometerSystem::cavity::spacer.displacementRange >=
            FabryPerotInterferometerSystem::cavity.resonanceWavelength / 2.0
        }
    }

    requirement def DetectorSignalRequirement {
        doc
        /* The transmitted and reflected photodetectors shall produce electrical signals proportional to detected optical power for acquisition and feedback control. */
    }

    requirement def LockingRequirement {
        doc
        /* The controller shall maintain the cavity near a selected resonance by driving the piezoelectric spacer from a detector-derived error signal. */
    }

    requirement def ThermalStabilityRequirement {
        doc
        /* The thermal enclosure shall stabilize the cavity environment to reduce resonance drift during measurement. */

        require constraint {
            FabryPerotInterferometerSystem::enclosure.stability <= 0.01 [SI::K]
        }
    }

    satisfy PrimaryFunctionRequirement by FabryPerotInterferometerSystem;
    satisfy ResonantTransmissionRequirement by FabryPerotInterferometerSystem::cavity;
    satisfy CavityTuningRequirement by FabryPerotInterferometerSystem::cavity::spacer;
    satisfy DetectorSignalRequirement by FabryPerotInterferometerSystem::transmittedDetector;
    satisfy DetectorSignalRequirement by FabryPerotInterferometerSystem::reflectedDetector;
    satisfy LockingRequirement by FabryPerotInterferometerSystem::controller;
    satisfy ThermalStabilityRequirement by FabryPerotInterferometerSystem::enclosure;
}