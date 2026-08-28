package MatibabuDiagnosticSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====
    value def Wavelength :> Real { unit 'nm'; }
    value def LuminousIntensity :> Real { unit 'cd'; }
    value def MagneticFluxDensity :> Real { unit 'T'; }
    value def Voltage :> Real { unit 'V'; }
    value def Current :> Real { unit 'A'; }
    value def Power :> Real { unit 'W'; }
    value def Energy :> Real { unit 'J'; }
    value def Duration :> Real { unit 's'; }
    value def Temperature :> Real { unit 'K'; }
    value def Frequency :> Real { unit 'Hz'; }
    value def Percentage :> Real { unit '%'; }

    // ===== Enumerations =====
    enum def DiagnosticResult {
        positive;
        negative;
        inconclusive;
    }

    enum def ParasiteType {
        none;
        plasmodiumFalciparum;
        plasmodiumVivax;
        plasmodiumMalariae;
        plasmodiumOvale;
        mixed;
        unknown;
    }

    enum def DeviceState {
        poweredOff;
        ready;
        guiding;
        scanning;
        analyzing;
        reporting;
        error;
    }

    enum def FingerPositionStatus {
        absent;
        misaligned;
        aligned;
    }

    enum def BatteryLevel {
        critical;
        low;
        adequate;
        full;
    }

    // ===== Item Definitions =====
    item def LightBeam {
        attribute wavelength : Wavelength;
        attribute intensity : LuminousIntensity;
    }

    item def ReflectedLight {
        attribute wavelength : Wavelength;
        attribute intensity : LuminousIntensity;
        attribute patternId : String;
    }

    item def MagneticReading {
        attribute fluxDensity : MagneticFluxDensity;
        attribute frequency : Frequency;
        attribute hemozoinConfidence : Percentage;
    }

    item def OpticalData {
        attribute reflectedSamples : ReflectedLight[0..*];
        attribute sampleCount : Integer;
        attribute acquisitionTime : Duration;
    }

    item def MagneticData {
        attribute readings : MagneticReading[0..*];
        attribute sampleCount : Integer;
        attribute acquisitionTime : Duration;
    }

    item def DiagnosticReport {
        attribute result : DiagnosticResult;
        attribute parasite : ParasiteType;
        attribute confidence : Percentage;
        attribute timestamp : String;
        attribute testDuration : Duration;
        attribute operatorNotes : String;
    }

    item def PowerCommand;
    item def StartTestCommand;
    item def CancelCommand;
    item def DisplayContent {
        attribute text : String;
        attribute result : DiagnosticResult;
        attribute parasite : ParasiteType;
    }

    // ===== Port Definitions =====
    port def OpticalOutPort {
        out light : LightBeam;
    }

    port def OpticalInPort {
        in reflected : ReflectedLight;
    }

    port def MagneticOutPort {
        out reading : MagneticReading;
    }

    port def DataOutPort {
        out optical : OpticalData;
        out magnetic : MagneticData;
    }

    port def DataInPort {
        in optical : OpticalData;
        in magnetic : MagneticData;
    }

    port def ReportPort {
        out report : DiagnosticReport;
    }

    port def DisplayPort {
        in content : DisplayContent;
    }

    port def CommandPort {
        in start : StartTestCommand;
        in cancel : CancelCommand;
        in power : PowerCommand;
    }

    port def PowerOutPort {
        out voltage : Voltage;
        out current : Current;
    }

    port def PowerInPort {
        in voltage : Voltage;
        in current : Current;
    }

    // ===== Parts =====
    part def LEDEmitter {
        attribute emittedWavelength : Wavelength = 850 [nm];
        attribute maxIntensity : LuminousIntensity = 5.0 [cd];
        attribute operatingPower : Power = 0.1 [W];

        port opticalOut : OpticalOutPort;
        port powerIn : PowerInPort;

        attribute isEmitting : Boolean = false;

        action emitLight {
            out beam : LightBeam;
        }
    }

    part def PhotodetectorArray {
        attribute pixelCount : Integer = 64;
        attribute sensitivity : Percentage = 95.0 [%];
        attribute samplingRate : Frequency = 1000 [Hz];

        port opticalIn : OpticalInPort;
        port dataOut : DataOutPort;
        port powerIn : PowerInPort;

        action captureReflectedLight {
            in reflected : ReflectedLight;
            out optical : OpticalData;
        }
    }

    part def MagnetometerSensor {
        attribute sensitivity : MagneticFluxDensity = 1.0e-9 [T];
        attribute samplingRate : Frequency = 500 [Hz];
        attribute operatingRange : MagneticFluxDensity = 100.0e-6 [T];

        port magneticOut : MagneticOutPort;
        port dataOut : DataOutPort;
        port powerIn : PowerInPort;

        action measureMagneticField {
            out reading : MagneticReading;
        }
    }

    part def SignalProcessor {
        attribute clockSpeed : Frequency = 100.0e6 [Hz];
        attribute algorithmVersion : String = "Matibabu-v3.2";
        attribute analysisTimeout : Duration = 30 [s];

        port dataIn : DataInPort;
        port reportOut : ReportPort;
        port powerIn : PowerInPort;

        action analyzeData {
            in optical : OpticalData;
            in magnetic : MagneticData;
            out report : DiagnosticReport;

            // Decision logic placeholders as attributes
            attribute result : DiagnosticResult;
            attribute parasite : ParasiteType;
            attribute confidence : Percentage;
        }
    }

    part def DisplayModule {
        attribute resolution : String = "320x240";
        attribute backlight : Boolean = true;
        attribute contrast : Percentage = 80.0 [%];

        port displayIn : DisplayPort;
        port powerIn : PowerInPort;

        action renderReport {
            in content : DisplayContent;
        }
    }

    part def Battery {
        attribute nominalVoltage : Voltage = 3.7 [V];
        attribute capacity : Energy = 30.0e3 [J];
        attribute currentLevel : BatteryLevel = BatteryLevel::full;
        attribute chargePercentage : Percentage = 100.0 [%];

        port powerOut : PowerOutPort;

        action supplyPower {
            out voltage : Voltage;
            out current : Current;
        }
    }

    part def PowerController {
        attribute conversionEfficiency : Percentage = 92.0 [%];
        attribute outputVoltage : Voltage = 3.3 [V];

        port batteryIn : PowerInPort;
        port regulatedOut : PowerOutPort;

        action regulatePower {
            in rawVoltage : Voltage;
            in rawCurrent : Current;
            out regulatedVoltage : Voltage;
            out regulatedCurrent : Current;
        }
    }

    part def FingerGuide {
        attribute slotDiameter : Real = 20.0 [mm];
        attribute alignmentSensorActive : Boolean = true;

        port positionStatus : >> DataOutPort;

        action detectFinger {
            out status : FingerPositionStatus;
        }
    }

    part def SensingProbe {
        attribute probeId : String;
        attribute sterilizationCycleCount : Integer = 0;

        part led : LEDEmitter;
        part photodetector : PhotodetectorArray;
        part magnetometer : MagnetometerSensor;
        part fingerGuide : FingerGuide;

        port powerIn : PowerInPort;
        port dataOut : DataOutPort;
        port positionOut : >> DataOutPort;

        connection ledEmission from led.opticalOut to photodetector.opticalIn;
        connection photodetectorData from photodetector.dataOut to dataOut;
        connection magnetometerData from magnetometer.dataOut to dataOut;
        connection fingerGuideData from fingerGuide.positionStatus to positionOut;

        flow from powerIn to led.powerIn;
        flow from powerIn to photodetector.powerIn;
        flow from powerIn to magnetometer.powerIn;
    }

    part def MatibabuDevice {
        attribute deviceId : String;
        attribute firmwareVersion : String = "Matibabu-OS-2.1";
        attribute maxTestDuration : Duration = 120 [s];
        attribute operatingTemperatureRange : Temperature = 273.15 [K] .. 313.15 [K];

        part battery : Battery;
        part powerController : PowerController;
        part sensingProbe : SensingProbe;
        part signalProcessor : SignalProcessor;
        part display : DisplayModule;

        port commandPort : CommandPort;
        port reportPort : ReportPort;

        connection batteryToController from battery.powerOut to powerController.batteryIn;
        connection controllerToProbe from powerController.regulatedOut to sensingProbe.powerIn;
        connection controllerToProcessor from powerController.regulatedOut to signalProcessor.powerIn;
        connection controllerToDisplay from powerController.regulatedOut to display.powerIn;
        connection probeToProcessor from sensingProbe.dataOut to signalProcessor.dataIn;
        connection processorToDisplay from signalProcessor.reportOut to display.displayIn;
        connection processorReport from signalProcessor.reportOut to reportPort;

        // ===== State Machine =====
        state def DeviceStateMachine {
            entry action initialize {
                // Power-on self test
            }

            state poweredOff {
                entry action shutdownSequence;
                transition on commandPort.power to ready;
            }

            state ready {
                entry action showReadyPrompt {
                    display.displayIn.content.text := "Insert finger to begin test";
                }
                transition on commandPort.start to guiding;
                transition on commandPort.power to poweredOff;
            }

            state guiding {
                entry action guideUser {
                    display.displayIn.content.text := "Align finger in probe slot";
                }
                do action monitorFinger {
                    // Continuously check fingerGuide.detectFinger().status
                }
                transition when (sensingProbe.fingerGuide.detectFinger().status == FingerPositionStatus::aligned) to scanning;
                transition on commandPort.cancel to ready;
                transition on commandPort.power to poweredOff;
            }

            state scanning {
                entry action beginAcquisition {
                    sensingProbe.led.isEmitting := true;
                    sensingProbe.led.emitLight();
                    sensingProbe.photodetector.captureReflectedLight();
                    sensingProbe.magnetometer.measureMagneticField();
                }
                do action acquireData {
                    // Collect optical and magnetic data for up to maxTestDuration
                }
                transition after 60 [s] to analyzing;
                transition on commandPort.cancel to ready;
                transition on commandPort.power to poweredOff;
            }

            state analyzing {
                entry action runAnalysis {
                    signalProcessor.analyzeData();
                }
                do action processSignals {
                    // Execute malaria detection algorithm
                }
                transition when (signalProcessor.analyzeData().report.result != DiagnosticResult::inconclusive) to reporting;
                transition after signalProcessor.analysisTimeout to reporting;
                transition on commandPort.power to poweredOff;
            }

            state reporting {
                entry action compileReport {
                    display.displayIn.content.text := "Test complete";
                    display.displayIn.content.result := signalProcessor.analyzeData().report.result;
                    display.displayIn.content.parasite := signalProcessor.analyzeData().report.parasite;
                    display.renderReport();
                }
                transition after 10 [s] to ready;
                transition on commandPort.power to poweredOff;
            }

            state error {
                entry action reportError {
                    display.displayIn.content.text := "Error: please restart device";
                }
                transition on commandPort.power to poweredOff;
            }

            transition from ready to error when (battery.chargePercentage < 10.0 [%]);
            transition from guiding to error when (battery.chargePercentage < 10.0 [%]);
            transition from scanning to error when (battery.chargePercentage < 10.0 [%]);
        }

        part behavior : DeviceStateMachine;

        // ===== Requirements Satisfaction =====
        satisfy req RapidDiagnosisRequirement by maxTestDuration;
        satisfy req NonInvasiveOperationRequirement by sensingProbe;
        satisfy req OpticalDetectionRequirement by sensingProbe.led, sensingProbe.photodetector;
        satisfy req MagneticDetectionRequirement by sensingProbe.magnetometer;
        satisfy req ParasiteIdentificationRequirement by signalProcessor;
        satisfy req UserGuidanceRequirement by behavior;
    }

    // ===== Requirements =====
    requirement def RapidDiagnosisRequirement {
        doc "The device shall complete a full diagnostic test in under two minutes."
        constraint { maxTestDuration <= 120 [s] }
    }

    requirement def NonInvasiveOperationRequirement {
        doc "The device shall perform diagnosis without requiring a blood sample."
        constraint { sensingProbe.slotDiameter > 15.0 [mm] }
    }

    requirement def OpticalDetectionRequirement {
        doc "The device shall detect malaria using optical properties of blood via LED and photodetector."
        constraint { sensingProbe.led.emittedWavelength == 850 [nm] }
        constraint { sensingProbe.photodetector.sensitivity > 90.0 [%] }
    }

    requirement def MagneticDetectionRequirement {
        doc "The device shall measure magnetic signature of hemozoin crystals."
        constraint { sensingProbe.magnetometer.sensitivity <= 10.0e-9 [T] }
    }

    requirement def ParasiteIdentificationRequirement {
        doc "The device shall identify the malaria parasite type when a positive result is detected."
        constraint { signalProcessor.algorithmVersion != "" }
    }

    requirement def UserGuidanceRequirement {
        doc "The device shall guide the user through finger positioning before scanning."
        constraint { sensingProbe.fingerGuide.alignmentSensorActive == true }
    }

    requirement def BatteryPoweredRequirement {
        doc "The device shall be self-contained and battery-powered."
        constraint { battery.nominalVoltage >= 3.0 [V] }
        constraint { battery.capacity >= 20.0e3 [J] }
    }

    requirement def DisplayResultRequirement {
        doc "The device shall display the diagnostic result on a built-in display module."
        constraint { display.resolution != "" }
    }

    requirement def ResourceLimitedSettingRequirement {
        doc "The device shall be suitable for use in resource-limited settings without laboratory equipment."
        constraint { MatibabuDevice.operatingTemperatureRange.min <= 273.15 [K] }
        constraint { MatibabuDevice.operatingTemperatureRange.max >= 313.15 [K] }
    }

    requirement MatibabuSystemRequirements {
        subject device : MatibabuDevice;

        requirement rapidDiagnosis : RapidDiagnosisRequirement;
        requirement nonInvasive : NonInvasiveOperationRequirement;
        requirement opticalDetection : OpticalDetectionRequirement;
        requirement magneticDetection : MagneticDetectionRequirement;
        requirement parasiteId : ParasiteIdentificationRequirement;
        requirement userGuidance : UserGuidanceRequirement;
        requirement batteryPowered : BatteryPoweredRequirement;
        requirement displayResult : DisplayResultRequirement;
        requirement resourceLimited : ResourceLimitedSettingRequirement;
    }
}
