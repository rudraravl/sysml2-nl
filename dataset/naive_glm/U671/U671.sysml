package FabryPerotSystem {
    // Value Types with Units
    value def WavelengthValue :> Real {
        attribute unit : String = "nm";
    }
    value def LengthValue :> Real {
        attribute unit : String = "nm";
    }
    value def VoltageValue :> Real {
        attribute unit : String = "V";
    }
    value def PowerValue :> Real {
        attribute unit : String = "mW";
    }
    value def TemperatureValue :> Real {
        attribute unit : String = "K";
    }
    value def DisplacementValue :> Real {
        attribute unit : String = "nm";
    }

    // Items
    item def OpticalBeam {
        attribute wavelength : WavelengthValue;
        attribute power : PowerValue;
    }
    item def IntensityMeasurement {
        attribute measuredPower : PowerValue;
    }
    item def ControlSignal {
        attribute voltage : VoltageValue;
    }

    // Events
    event def ScanCommand;
    event def LockCommand;
    event def StopCommand;

    // Ports
    port def OpticalOutputPort {
        out beam : OpticalBeam;
    }
    port def OpticalInputPort {
        in beam : OpticalBeam;
    }
    port def MeasurementOutputPort {
        out measurement : IntensityMeasurement;
    }
    port def MeasurementInputPort {
        in measurement : IntensityMeasurement;
    }
    port def ControlOutputPort {
        out signal : ControlSignal;
    }
    port def ControlInputPort {
        in signal : ControlSignal;
    }

    // Action Definitions
    action def EmitLight {
        out beam : OpticalBeam;
    }
    action def AdjustDisplacement {
        in signal : ControlSignal;
        out displacement : DisplacementValue;
    }
    action def ProcessResonance {
        in inputBeam : OpticalBeam;
        in length : LengthValue;
        out outputBeam : OpticalBeam;
    }
    action def MeasureIntensity {
        in beam : OpticalBeam;
        out measurement : IntensityMeasurement;
    }
    action def GenerateScanSignal {
        out signal : ControlSignal;
    }
    action def CalculateCorrection {
        in measurement : IntensityMeasurement;
        in setpoint : PowerValue;
        out signal : ControlSignal;
    }
    action def CauseThermalDrift {
        out drift : DisplacementValue;
    }

    // Part Definitions
    part def Mirror {
        attribute reflectivity : Real = 0.995;
        attribute position : LengthValue;
    }

    part def PiezoActuator {
        port controlIn : ControlInputPort;
        action adjustDisplacement : AdjustDisplacement;
        flow controlIn.signal to adjustDisplacement.signal;
    }

    part def LaserSource {
        port opticalOut : OpticalOutputPort;
        attribute outputWavelength : WavelengthValue = 632.8;
        attribute outputPower : PowerValue = 5.0;
        action emitLight : EmitLight;
        flow emitLight.beam to opticalOut.beam;
    }

    part def Photodetector {
        port opticalIn : OpticalInputPort;
        port measurementOut : MeasurementOutputPort;
        action measureIntensity : MeasureIntensity;
        flow opticalIn.beam to measureIntensity.beam;
        flow measureIntensity.measurement to measurementOut.measurement;
    }

    part def OpticalCavity {
        port opticalIn : OpticalInputPort;
        port opticalOut : OpticalOutputPort;
        port actuatorControl : ControlInputPort;
        
        part mirror1 : Mirror {
            attribute :>> position = 0.0;
        }
        part mirror2 : Mirror {
            attribute :>> position = 50000.0;
        }
        part actuator : PiezoActuator;
        
        attribute cavityLength : LengthValue;
        action processResonance : ProcessResonance;
        
        connection actuatorControl to actuator.controlIn;
        flow actuator.adjustDisplacement.displacement to cavityLength;
        flow opticalIn.beam to processResonance.inputBeam;
        flow cavityLength to processResonance.length;
        flow processResonance.outputBeam to opticalOut.beam;
    }

    part def StabilizationController {
        port measurementIn : MeasurementInputPort;
        port controlOut : ControlOutputPort;
        
        attribute setpoint : PowerValue = 4.8;
        attribute proportionalGain : Real = 0.05;
        
        action generateScanSignal : GenerateScanSignal;
        action calculateCorrection : CalculateCorrection;
        
        flow measurementIn.measurement to calculateCorrection.measurement;
        flow setpoint to calculateCorrection.setpoint;
        flow generateScanSignal.signal to controlOut.signal;
        flow calculateCorrection.signal to controlOut.signal;
        
        state machine ControllerStates {
            state Idle;
            state Scanning {
                do generateScanSignal;
            }
            state Locked {
                do calculateCorrection;
            }
            transition Idle to Scanning on ScanCommand;
            transition Scanning to Locked on LockCommand;
            transition Locked to Scanning on ScanCommand;
            transition Scanning to Idle on StopCommand;
            transition Locked to Idle on StopCommand;
        }
    }

    part def ThermalEnvironment {
        attribute ambientTemperature : TemperatureValue = 298.15;
        action causeThermalDrift : CauseThermalDrift;
    }

    part def FabryPerotInterferometer {
        part laserSource : LaserSource;
        part opticalCavity : OpticalCavity;
        part photodetector : Photodetector;
        part stabilizationController : StabilizationController;
        part thermalEnvironment : ThermalEnvironment;
        
        connection laserSource.opticalOut to opticalCavity.opticalIn;
        connection opticalCavity.opticalOut to photodetector.opticalIn;
        connection photodetector.measurementOut to stabilizationController.measurementIn;
        connection stabilizationController.controlOut to opticalCavity.actuatorControl;
        
        flow thermalEnvironment.causeThermalDrift.drift to opticalCavity.cavityLength;
    }

    // Requirements
    requirement def InterferometerRequirement {
        doc /* The system must be a high-precision optical system for spectral analysis and wavelength filtering. */
    }
    requirement def ResonantCavityRequirement {
        doc /* The core must be a resonant optical cavity formed by two highly reflective, parallel mirrors separated by a precise distance. */
    }
    requirement def WavelengthTransmissionRequirement {
        doc /* The system must selectively transmit light of specific wavelengths that satisfies a resonance condition and filter out all other wavelengths. */
    }
    requirement def PhotodetectorMeasureRequirement {
        doc /* A photodetector must be placed at the output of the cavity to measure the intensity of the transmitted light. */
    }
    requirement def PiezoActuatorControlRequirement {
        doc /* The critical distance between the mirrors must be controlled with extreme precision by a piezo actuator, making adjustments on the nanometer scale in response to a control voltage. */
    }
    requirement def StabilizationFeedbackRequirement {
        doc /* A stabilization controller must form a feedback loop, monitoring the transmitted intensity and sending correction signals to the piezo actuator to keep the cavity locked on a resonance peak. */
    }
    requirement def DisturbanceCompensationRequirement {
        doc /* The system must compensate for disturbances like temperature fluctuations or vibrations. */
    }
    requirement def OperationModeRequirement {
        doc /* The interferometer must support spectral analysis mode by scanning the mirror spacing, and locked resonance peak mode for narrow-band optical filtering. */
    }

    // Requirement Usages
    requirement iver : InterferometerRequirement {
        subject system : FabryPerotInterferometer;
    }
    requirement rcr : ResonantCavityRequirement {
        subject system : FabryPerotInterferometer;
    }
    requirement wtr : WavelengthTransmissionRequirement {
        subject system : FabryPerotInterferometer;
    }
    requirement pmr : PhotodetectorMeasureRequirement {
        subject system : FabryPerotInterferometer;
    }
    requirement pcr : PiezoActuatorControlRequirement {
        subject system : FabryPerotInterferometer;
    }
    requirement sfr : StabilizationFeedbackRequirement {
        subject system : FabryPerotInterferometer;
    }
    requirement dcr : DisturbanceCompensationRequirement {
        subject system : FabryPerotInterferometer;
    }
    requirement omr : OperationModeRequirement {
        subject system : FabryPerotInterferometer;
    }

    // Satisfactions
    satisfy iver by laserSource;
    satisfy rcr by opticalCavity;
    satisfy wtr by opticalCavity.processResonance;
    satisfy pmr by photodetector;
    satisfy pcr by opticalCavity.actuator;
    satisfy sfr by stabilizationController;
    satisfy dcr by stabilizationController;
    satisfy omr by stabilizationController;
}
