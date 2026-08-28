package AngleSensitivePixelSystem {

    import ScalarValues::*;

    // ========== Value Types with Units ==========
    value def Angle :> Real {
        doc "Angular measurement in radians";
        unit "rad";
    }

    value def AngleDeg :> Real {
        doc "Angular measurement in degrees";
        unit "deg";
    }

    value def Irradiance :> Real {
        doc "Radiant power per unit area";
        unit "W/m^2";
    }

    value def VoltageValue :> Real {
        doc "Electrical voltage";
        unit "V";
    }

    value def CurrentValue :> Real {
        doc "Electrical current";
        unit "A";
    }

    value def PowerValue :> Real {
        doc "Power consumption";
        unit "W";
    }

    value def TimeValue :> Real {
        doc "Time in seconds";
        unit "s";
    }

    value def Confidence :> Real {
        doc "Confidence level, dimensionless 0 to 1";
    }

    value def WavelengthValue :> Real {
        doc "Wavelength of light";
        unit "nm";
    }

    value def SpatialFrequency :> Real {
        doc "Grating spatial frequency";
        unit "lines/mm";
    }

    value def FocalLength :> Real {
        doc "Focal length of microlens";
        unit "mm";
    }

    value def Responsivity :> Real {
        doc "Photodetector responsivity";
        unit "A/W";
    }

    value def Efficiency :> Real {
        doc "Grating diffraction efficiency, dimensionless";
    }

    // ========== Item Types ==========
    item def LightBeam {
        doc "Represents a beam of light incident on the pixel";
        attribute wavelength : WavelengthValue;
        attribute irradiance : Irradiance;
        attribute incidenceAngle : Angle;
    }

    item def DiffractedBeam :> LightBeam {
        doc "Light beam after passing through a diffraction grating";
        attribute diffractionOrder : Integer;
        attribute bendingAngle : Angle;
    }

    item def ElectricalSignal {
        doc "Electrical signal produced by a photodetector";
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
        attribute timestamp : TimeValue;
    }

    item def CalibrationMatrix {
        doc "Calibration matrix for angle computation";
        attribute coefficients : Real[2, 2];
        attribute referenceWavelength : WavelengthValue;
        attribute validRangeMin : Angle;
        attribute validRangeMax : Angle;
    }

    item def AngleDataPacket {
        doc "Final output data packet containing measurement results";
        attribute measuredAngle : Angle;
        attribute confidence : Confidence;
        attribute timestamp : TimeValue;
        attribute pixelId : String;
    }

    // ========== Port Definitions ==========
    port def LightInPort {
        in light : LightBeam;
    }

    port def LightOutPort {
        out light : LightBeam;
    }

    port def SignalOutPort {
        out signal : ElectricalSignal;
    }

    port def SignalInPort {
        in signal : ElectricalSignal;
    }

    port def DataOutPort {
        out packet : AngleDataPacket;
    }

    port def ControlInPort {
        in trigger : Boolean;
    }

    // ========== Requirements ==========
    requirement def AngleMeasurementRequirement {
        doc "The sensor shall determine the angle of incidence of incoming light";
        attribute measurementAccuracy : AngleDeg = 0.5 [deg];
        attribute measurementRangeMin : Angle = -0.785 [rad];
        attribute measurementRangeMax : Angle = 0.785 [rad];
    }

    requirement def DualChannelRequirement {
        doc "The system shall employ two diffraction gratings with distinct spatial frequencies";
        attribute gratingCount : Integer = 2;
        attribute grating1Frequency : SpatialFrequency = 100 [lines/mm];
        attribute grating2Frequency : SpatialFrequency = 150 [lines/mm];
    }

    requirement def PowerEfficiencyRequirement {
        doc "The pixel shall support idle, ready, and measuring power states";
        attribute idlePower : PowerValue = 0.001 [W];
        attribute readyPower : PowerValue = 0.01 [W];
        attribute measuringPower : PowerValue = 0.05 [W];
    }

    requirement def OutputFormatRequirement {
        doc "Output shall contain measured angle, confidence level, and timestamp";
        attribute requiredFields : String = "measuredAngle, confidence, timestamp";
    }

    // ========== Action Definitions ==========
    action def FocusLight {
        doc "Focus incoming light beam through the microlens";
        in incoming : LightBeam;
        out focused : LightBeam;
    }

    action def SplitBeam {
        doc "Split focused light beam into two separate paths";
        in incoming : LightBeam;
        out beam1 : LightBeam;
        out beam2 : LightBeam;
    }

    action def DiffractBeam {
        doc "Diffract light beam based on incidence angle";
        in incoming : LightBeam;
        out diffracted : DiffractedBeam;
    }

    action def DetectLight {
        doc "Convert incident light beam into electrical signal";
        in incoming : LightBeam;
        out signal : ElectricalSignal;
    }

    action def ComputeAngle {
        doc "Compute angle of incidence from two electrical signals using calibration matrix";
        in signal1 : ElectricalSignal;
        in signal2 : ElectricalSignal;
        in calibration : CalibrationMatrix;
        out packet : AngleDataPacket;

        attribute signalDifference : VoltageValue = signal1.voltage - signal2.voltage;
        attribute signalSum : VoltageValue = signal1.voltage + signal2.voltage;
        attribute angleEstimate : Angle = calibration.coefficients[1][1] * signalDifference + calibration.coefficients[2][1] * signalSum;
        attribute confidenceValue : Confidence = 1.0 - abs(signalDifference) / (signalSum + 0.001 [V]);
    }

    action def SetPower {
        doc "Set the power consumption level of the pixel";
        in level : PowerValue;
    }

    action def AwaitLight {
        doc "Wait for incoming light exceeding activation threshold";
    }

    action def MonitorLightLevel {
        doc "Monitor incoming light level and validate stability";
    }

    action def PerformAngleMeasurement {
        doc "Execute full angle measurement sequence using dual-channel path";
    }

    // ========== Part Definitions ==========
    part def Microlens {
        doc "Focuses incoming light onto the beam splitter";
        attribute focalLength : FocalLength = 0.5 [mm];
        attribute apertureDiameter : Real = 0.1 [mm];
        attribute transmittance : Real = 0.95;

        port lightIn : LightInPort;
        port focusedOut : LightOutPort;
    }

    part def BeamSplitter {
        doc "Splits focused light into two separate paths for dual-channel processing";
        attribute splitRatio : Real = 0.5;
        attribute insertionLoss : Real = 0.05;

        port lightIn : LightInPort;
        port split1Out : LightOutPort;
        port split2Out : LightOutPort;
    }

    part def DiffractionGrating {
        doc "Bends light in unique, predictable ways based on its angle of incidence";
        attribute spatialFrequency : SpatialFrequency;
        attribute diffractionEfficiency : Efficiency;
        attribute designOrder : Integer = 1;

        port lightIn : LightInPort;
        port diffractedOut : LightOutPort;
    }

    part def Photodetector {
        doc "Converts received light into an electrical signal";
        attribute responsivity : Responsivity = 0.5 [A/W];
        attribute darkCurrent : CurrentValue = 1e-9 [A];
        attribute activeArea : Real = 0.01 [mm^2];

        port lightIn : LightInPort;
        port signalOut : SignalOutPort;
    }

    part def AngleComputationUnit {
        doc "Receives electrical signals from both photodetectors and computes angle of incidence";
        attribute calibration : CalibrationMatrix;
        attribute signalThreshold : VoltageValue = 0.01 [V];
        attribute computationTime : TimeValue = 0.001 [s];

        port signalIn1 : SignalInPort;
        port signalIn2 : SignalInPort;
        port dataOut : DataOutPort;
    }

    // ========== State Machine ==========
    state def PixelPowerState {
        doc "Power state machine governing pixel operation modes";

        attribute lightIntensity : Irradiance;
        attribute triggerSignal : Boolean;
        attribute measurementComplete : Boolean;

        state idle {
            doc "Low-power idle mode, waiting for light";
            entry / SetPower(0.001 [W]);
            do / AwaitLight;
            exit / wakeUp;
        }

        state ready {
            doc "Light detected, ready for measurement trigger";
            entry / SetPower(0.01 [W]);
            do / MonitorLightLevel;
            exit / prepareForMeasurement;
        }

        state measuring {
            doc "Full-power measurement state performing angle calculation";
            entry / SetPower(0.05 [W]);
            do / PerformAngleMeasurement;
            exit / finalizeMeasurement;
        }

        transition from idle to ready when lightIntensity > 0.01 [W/m^2];
        transition from ready to measuring when triggerSignal == true;
        transition from measuring to ready when measurementComplete == true;
        transition from measuring to idle when lightIntensity < 0.001 [W/m^2];
        transition from ready to idle when lightIntensity < 0.001 [W/m^2];
    }

    // ========== Top-level Part: Angle-Sensitive Pixel ==========
    part AngleSensitivePixel {
        doc "An individual angle-sensitive pixel for light-field imaging applications";

        attribute pixelId : String = "ASP-001";
        attribute lightIntensityThreshold : Irradiance = 0.01 [W/m^2];
        attribute minActiveLight : Irradiance = 0.001 [W/m^2];

        state powerState : PixelPowerState;

        port lightInPort : LightInPort;
        port dataOutPort : DataOutPort;
        port controlPort : ControlInPort;

        part microlens : Microlens {
            focalLength = 0.5 [mm];
        }

        part beamSplitter : BeamSplitter {
            splitRatio = 0.5;
        }

        part grating1 : DiffractionGrating {
            spatialFrequency = 100 [lines/mm];
            diffractionEfficiency = 0.85;
        }

        part grating2 : DiffractionGrating {
            spatialFrequency = 150 [lines/mm];
            diffractionEfficiency = 0.78;
        }

        part photodetector1 : Photodetector {
            responsivity = 0.55 [A/W];
            darkCurrent = 1e-9 [A];
        }

        part photodetector2 : Photodetector {
            responsivity = 0.55 [A/W];
            darkCurrent = 1e-9 [A];
        }

        part computationUnit : AngleComputationUnit {
            signalThreshold = 0.01 [V];
            computationTime = 0.001 [s];
        }

        // ========== Connections ==========
        flow light from lightInPort to microlens.lightIn;
        flow light from microlens.focusedOut to beamSplitter.lightIn;
        flow light from beamSplitter.split1Out to grating1.lightIn;
        flow light from beamSplitter.split2Out to grating2.lightIn;
        flow light from grating1.diffractedOut to photodetector1.lightIn;
        flow light from grating2.diffractedOut to photodetector2.lightIn;
        flow signal from photodetector1.signalOut to computationUnit.signalIn1;
        flow signal from photodetector2.signalOut to computationUnit.signalIn2;
        flow packet from computationUnit.dataOut to dataOutPort;

        // ========== Requirement Satisfaction ==========
        satisfy AngleMeasurementRequirement;
        satisfy DualChannelRequirement;
        satisfy PowerEfficiencyRequirement;
        satisfy OutputFormatRequirement;
    }
}
